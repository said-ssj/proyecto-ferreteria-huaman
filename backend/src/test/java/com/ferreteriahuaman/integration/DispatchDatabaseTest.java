package com.ferreteriahuaman.integration;

import com.ferreteriahuaman.dto.DispatchModels.*;
import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.PurchaseModels.Opening;
import com.ferreteriahuaman.dto.SaleModels.Confirm;
import com.ferreteriahuaman.dto.SaleModels.Create;
import com.ferreteriahuaman.dto.SaleModels.Payment;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.*;

@SpringBootTest
@ActiveProfiles({"local", "db"})
@Transactional
@EnabledIfEnvironmentVariable(named = "HUAMAN_DB_INTEGRATION", matches = "true")
class DispatchDatabaseTest {
    @Autowired DispatchService dispatchService;
    @Autowired SaleService sales;
    @Autowired CustomerService customers;
    @Autowired ProductService products;
    @Autowired CatalogService catalog;
    @Autowired PurchaseService purchases;
    @Autowired CashService cash;
    @Autowired AuthStore auth;
    @Autowired Environment env;
    @Autowired JdbcTemplate jdbc;

    Identity actor;
    String unique;
    long category;

    BigDecimal n(String s) {
        return new BigDecimal(s);
    }

    @BeforeEach
    void setup() {
        var u = auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();
        auth.context(u.username(), "INTEGRATION_ROLLBACK");
        UUID token = UUID.randomUUID();
        auth.createSession(u.id(), token, LocalDateTime.now(ZoneId.of("America/Lima")));
        actor = new Identity(u.id(), u.username(), u.nombres(), u.apellidos(), u.rol(), false, auth.permissions(u.id()), token, OffsetDateTime.now().plusMinutes(30));
        unique = "INTEGRACION_" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        category = catalog.createCategory(actor, "INTEGRATION_ROLLBACK", new com.ferreteriahuaman.dto.CatalogModels.CategoryInput(unique, null, null)).id();
    }

    void openCash() {
        Assumptions.assumeTrue(jdbc.queryForObject("select count(*) from huaman.caja_diaria where estado_caja='ABIERTA' or fecha=timezone('America/Lima',now())::date", Long.class) == 0, "No interferir con cajas reales");
        cash.open(actor, "INTEGRATION_ROLLBACK", new com.ferreteriahuaman.dto.CashModels.Open(n("0"), null, UUID.randomUUID()));
    }

    Product product() {
        long unit = jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat='NIU'", Long.class);
        return products.create(actor, "INTEGRATION_ROLLBACK", new ProductInput(unique, "Herramienta despacho", null, category, unit, false, n("1"), n("1"), "GRANEL", n("0"), null, "Unidad", n("50"), null));
    }

    long pres(Product p) {
        return products.details(actor, p.id()).presentaciones().getFirst().id();
    }

    @Test
    void completeDispatchLifecycleWithRollback() {
        openCash();
        var p = product();
        purchases.opening(actor, "INTEGRATION_ROLLBACK", new Opening(p.id(), n("10"), n("20"), UUID.randomUUID(), List.of()));

        // Sale with entregaInmediata = false
        var draft = sales.create(actor, "INTEGRATION_ROLLBACK", new Create(null, "N", false, UUID.randomUUID(), List.of(new com.ferreteriahuaman.dto.SaleModels.Line(pres(p), n("2"), 1))));
        long saleId = ((Number) draft.venta().get("id")).longValue();

        long series = jdbc.queryForObject("select min(id_serie) from huaman.serie_comprobante where tipo_comprobante='N' and estado='A'", Long.class);
        sales.confirm(actor, "INTEGRATION_ROLLBACK", saleId, new Confirm(series, LocalDateTime.parse(draft.venta().get("version").toString()), List.of(new Payment("EFECTIVO", n("100"), n("100"), null, null, null)), List.of()));

        // Check despacho created
        var row = jdbc.queryForMap("select * from huaman.despacho where id_venta=?", saleId);
        long dispatchId = ((Number) row.get("id_despacho")).longValue();
        assertThat(row.get("estado_despacho")).isEqualTo("PENDIENTE");

        // Verify summary
        var summary = dispatchService.summary(actor);
        assertThat(summary.pendientes()).isGreaterThanOrEqualTo(1);

        // Verify list
        var list = dispatchService.list(actor, "PENDIENTE", "", null, null, 0, 20);
        assertThat(list.items()).anyMatch(d -> d.id() == dispatchId && d.estado().equals("PENDIENTE"));

        // Verify detail
        var detail = dispatchService.detail(actor, dispatchId);
        assertThat(detail.items()).hasSize(1);
        assertThat(detail.items().get(0).productoNombre()).contains("Herramienta despacho");

        // Prepare dispatch
        UUID prepKey = UUID.randomUUID();
        var prepared = dispatchService.preparar(actor, "INTEGRATION_ROLLBACK", dispatchId, new PrepareRequest(prepKey, "Productos embalados"));
        assertThat(prepared.despacho().estado()).isEqualTo("PREPARADO");
        assertThat(prepared.despacho().preparadoPor()).contains(actor.nombres());
        assertThat(prepared.despacho().observacionPreparacion()).isEqualTo("Productos embalados");

        // Re-execute prepare with same key (idempotency)
        var preparedReplay = dispatchService.preparar(actor, "INTEGRATION_ROLLBACK", dispatchId, new PrepareRequest(prepKey, "Productos embalados"));
        assertThat(preparedReplay.despacho().estado()).isEqualTo("PREPARADO");

        // Deliver dispatch
        UUID deliverKey = UUID.randomUUID();
        var delivered = dispatchService.entregar(actor, "INTEGRATION_ROLLBACK", dispatchId, new DeliverRequest(deliverKey, "Carlos Ruiz", "Recibido completo"));
        assertThat(delivered.despacho().estado()).isEqualTo("ENTREGADO");
        assertThat(delivered.despacho().entregadoPor()).contains(actor.nombres());
        assertThat(delivered.despacho().recibeNombre()).isEqualTo("Carlos Ruiz");
        assertThat(delivered.despacho().observacionEntrega()).isEqualTo("Recibido completo");

        // Re-execute deliver with same key (idempotency)
        var deliveredReplay = dispatchService.entregar(actor, "INTEGRATION_ROLLBACK", dispatchId, new DeliverRequest(deliverKey, "Carlos Ruiz", "Recibido completo"));
        assertThat(deliveredReplay.despacho().estado()).isEqualTo("ENTREGADO");

        // Cannot deliver again with different key (already delivered)
        assertThatThrownBy(() -> dispatchService.entregar(actor, "INTEGRATION_ROLLBACK", dispatchId, new DeliverRequest(UUID.randomUUID(), "Otro", null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("ya fue entregado por");
    }
}

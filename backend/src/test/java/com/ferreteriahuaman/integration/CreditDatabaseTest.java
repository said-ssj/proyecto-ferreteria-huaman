package com.ferreteriahuaman.integration;

import com.ferreteriahuaman.dto.CreditModels.*;
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
class CreditDatabaseTest {
    @Autowired CreditService credits;
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
        jdbc.update("update huaman.parametro_sistema set valor='Negocio de integración' where clave='NEGOCIO.RAZON_SOCIAL'");
    }

    Product product() {
        long unit = jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat='NIU'", Long.class);
        return products.create(actor, "INTEGRATION_ROLLBACK", new ProductInput(unique, "Herramienta crédito", null, category, unit, false, n("1"), n("1"), "GRANEL", n("0"), null, "Unidad", n("50"), null));
    }

    long pres(Product p) {
        return products.details(actor, p.id()).presentaciones().getFirst().id();
    }

    long createCustomer(String doc) {
        var c = customers.save(actor, "INTEGRATION_ROLLBACK", null, new com.ferreteriahuaman.dto.CustomerModels.Input("DNI", doc, "Cliente Fiado " + unique, "999888777", null, null, null));
        customers.credit(actor, "INTEGRATION_ROLLBACK", c.id(), new com.ferreteriahuaman.dto.CustomerModels.Credit(n("500"), c.version()));
        return c.id();
    }

    @Test
    void creditSaleGeneratesAccountAndPaymentsReduceBalanceUntilCanceled() {
        openCash();
        var p = product();
        purchases.opening(actor, "INTEGRATION_ROLLBACK", new Opening(p.id(), n("10"), n("20"), UUID.randomUUID(), List.of()));

        String doc = String.format("%08d", (int)(Math.random() * 89999999 + 10000000));
        long clienteId = createCustomer(doc);

        // Prepare sale with CREDITO
        var draft = sales.create(actor, "INTEGRATION_ROLLBACK", new Create(clienteId, "N", true, UUID.randomUUID(), List.of(new com.ferreteriahuaman.dto.SaleModels.Line(pres(p), n("2"), 1))));
        long saleId = ((Number) draft.venta().get("id")).longValue();

        long series = jdbc.queryForObject("select min(id_serie) from huaman.serie_comprobante where tipo_comprobante='N' and estado='A'", Long.class);
        sales.confirm(actor, "INTEGRATION_ROLLBACK", saleId, new Confirm(series, LocalDateTime.parse(draft.venta().get("version").toString()), List.of(new Payment("CREDITO", n("100"), null, null, null, null)), List.of()));

        // Check account exists
        var list = credits.list(actor, doc, "PENDIENTE", false, null, null, 0, 20);
        assertThat(list.total()).isEqualTo(1);
        var account = list.items().getFirst();
        long cuentaId = ((Number) account.get("id")).longValue();
        assertThat(account.get("saldo")).isEqualTo("100.00");
        assertThat(account.get("estadoCuenta")).isEqualTo("PENDIENTE");

        // Statement
        var statement = credits.statement(actor, clienteId);
        assertThat(statement.cliente().deudaTotal()).isEqualByComparingTo("100.00");
        assertThat(statement.cuentas()).hasSize(1);
        assertThat(statement.abonos()).isEmpty();

        // Summary
        var summary = credits.summary(actor);
        assertThat(summary.totalPorCobrar()).isGreaterThanOrEqualTo(n("100.00"));

        // Register partial payment: 40 with EFECTIVO
        UUID key1 = UUID.randomUUID();
        var receipt1 = credits.registerPayment(actor, "INTEGRATION_ROLLBACK", new RegisterPayment(cuentaId, n("40.00"), "EFECTIVO", key1, null, null, null, "Primer abono"));
        assertThat(receipt1.monto()).isEqualByComparingTo("40.00");
        assertThat(receipt1.saldoActualCuenta()).isEqualByComparingTo("60.00");

        // Idempotency check with same key
        var replayReceipt = credits.registerPayment(actor, "INTEGRATION_ROLLBACK", new RegisterPayment(cuentaId, n("40.00"), "EFECTIVO", key1, null, null, null, "Primer abono"));
        assertThat(replayReceipt.id()).isEqualTo(receipt1.id());

        // Verify remaining balance: 60
        var accountAfter = credits.statement(actor, clienteId).cuentas().getFirst();
        assertThat(accountAfter.get("saldo")).isEqualTo("60.00");
        assertThat(accountAfter.get("estadoCuenta")).isEqualTo("PENDIENTE");

        // Register payment exceeding balance: should be rejected with 400
        UUID keyExceed = UUID.randomUUID();
        assertThatThrownBy(() -> credits.registerPayment(actor, "INTEGRATION_ROLLBACK", new RegisterPayment(cuentaId, n("70.00"), "EFECTIVO", keyExceed, null, null, null, null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("El abono supera el saldo");

        // Final payment with YAPE: 60
        UUID key2 = UUID.randomUUID();
        var receipt2 = credits.registerPayment(actor, "INTEGRATION_ROLLBACK", new RegisterPayment(cuentaId, n("60.00"), "YAPE", key2, "12345678", null, null, "Cancelación"));
        assertThat(receipt2.saldoActualCuenta()).isEqualByComparingTo("0.00");

        // Now account is CANCELADA
        var accountFinal = credits.statement(actor, clienteId).cuentas().getFirst();
        assertThat(accountFinal.get("saldo")).isEqualTo("0.00");
        assertThat(accountFinal.get("estadoCuenta")).isEqualTo("CANCELADA");

        // Debt for customer is now 0
        assertThat(credits.statement(actor, clienteId).cliente().deudaTotal()).isEqualByComparingTo("0.00");
        // Old receipts preserve the balance at the time of each payment.
        assertThat(credits.receipt(actor,receipt1.id()).saldoAnteriorCuenta()).isEqualByComparingTo("100");
        assertThat(credits.receipt(actor,receipt1.id()).saldoActualCuenta()).isEqualByComparingTo("60");
        assertThat(credits.registerPayment(actor,"INTEGRATION_ROLLBACK",new RegisterPayment(cuentaId,n("60"),"YAPE",key2,"12345678",null,null,"Cancelación")).id()).isEqualTo(receipt2.id());
        var register=cash.current().caja();
        cash.close(actor,"INTEGRATION_ROLLBACK",register.id(),new com.ferreteriahuaman.dto.CashModels.Close(n("40"),n("60"),n("0"),null,UUID.randomUUID()));
        // Recovery is valid even after the box was closed and the debt was settled.
        assertThat(credits.registerPayment(actor,"INTEGRATION_ROLLBACK",new RegisterPayment(cuentaId,n("40"),"EFECTIVO",key1,null,null,null,"Primer abono")).id()).isEqualTo(receipt1.id());
        assertThat(jdbc.queryForObject("select count(*) from huaman.abono_credito where id_cuenta=?",Long.class,cuentaId)).isEqualTo(2);
        jdbc.execute("set constraints all immediate");
        assertThatThrownBy(()->credits.registerPayment(actor,"INTEGRATION_ROLLBACK",new RegisterPayment(cuentaId,n("39"),"EFECTIVO",key1,null,null,null,"Primer abono"))).isInstanceOf(AuthFailure.class).hasMessageContaining("otro abono");
    }
}

package com.ferreteriahuaman.integration;

import com.ferreteriahuaman.FerreteriaHuamanApplication;
import com.ferreteriahuaman.dto.CashModels.*;
import com.ferreteriahuaman.dto.CatalogModels.CategoryInput;
import com.ferreteriahuaman.dto.CreditModels.RegisterPayment;
import com.ferreteriahuaman.dto.CustomerModels;
import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.PurchaseModels.Opening;
import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.dto.SaleModels.*;
import com.ferreteriahuaman.dto.SaleModels.Details;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.*;
import java.math.BigDecimal;
import java.sql.*;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;

/** Real commits on separate connections; never enable against a business database.
 * Each test clones a marked, loopback-only disposable template and drops its own clone.
 */
@EnabledIfEnvironmentVariable(named="HUAMAN_CONCURRENCY_DB", matches="true")
class ConcurrencyDatabaseTest {
    private static final String MARKER = "HUAMAN_DISPOSABLE_CONCURRENCY_TEMPLATE";
    private String baseUrl, database;
    private ConfigurableApplicationContext context;
    private JdbcTemplate jdbc;
    private SaleService sales;
    private CashService cash;
    private CreditService credits;
    private ReturnService returns;
    private ProductService products;
    private Identity first, second;
    private long cashId;

    @BeforeEach void setup() throws Exception {
        String templateUrl = System.getenv("HUAMAN_CONCURRENCY_TEMPLATE_URL");
        // Exact database name, host and URL shape prevent reuse of Supabase/.env credentials.
        assertThat(templateUrl).matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{4,5}/huaman_concurrency_template");
        baseUrl = templateUrl.substring(0, templateUrl.lastIndexOf('/') + 1);
        database = "huaman_race_" + UUID.randomUUID().toString().replace("-", "");
        try (var c = maintenance(); var s = c.createStatement()) {
            try (var r = s.executeQuery("select shobj_description(oid,'pg_database') from pg_database where datname='huaman_concurrency_template'")) {
                assertThat(r.next()).isTrue();
                assertThat(r.getString(1)).isEqualTo(MARKER);
            }
            s.execute("create database " + database + " template huaman_concurrency_template");
        }
        try {
            context = new SpringApplicationBuilder(FerreteriaHuamanApplication.class)
                .web(WebApplicationType.SERVLET).run(
                    "--spring.profiles.active=local,db", "--server.port=0",
                    "--spring.config.import=", "--spring.datasource.url=" + baseUrl + database + "?socketTimeout=30&connectTimeout=5",
                    "--spring.datasource.username=postgres", "--spring.datasource.password=",
                    "--spring.datasource.hikari.maximum-pool-size=5",
                    "--spring.datasource.hikari.connection-init-sql=SET statement_timeout TO '15s'",
                    "--logging.level.root=WARN", "--spring.main.banner-mode=off");
            jdbc = context.getBean(JdbcTemplate.class);
            assertThat(jdbc.queryForObject("select count(*) from huaman.venta", Long.class)).isZero();
            assertThat(jdbc.queryForObject("select count(*) from huaman.caja_diaria", Long.class)).isZero();
            assertThat(jdbc.queryForObject("select count(*) from huaman.usuario where username<>'workflow.admin'", Long.class)).isZero();
            sales = context.getBean(SaleService.class); cash = context.getBean(CashService.class);
            credits = context.getBean(CreditService.class); returns = context.getBean(ReturnService.class);
            products = context.getBean(ProductService.class);
            var auth = context.getBean(AuthStore.class);
            context.getBean(TransactionTemplate.class).executeWithoutResult(status -> {
                auth.context("workflow.admin", "CONCURRENCY_TEST");
                // No usable password or business account is copied into the fixture.
                jdbc.update("insert into huaman.usuario(username,clave_hash,nombres,apellidos,dni,id_rol,clave_temporal) select 'workflow.admin',?,'Primero','Operador','12345678',id_rol,false from huaman.rol where codigo='ADM' and not exists(select 1 from huaman.usuario where username='workflow.admin')", "$2a$10$" + "A".repeat(53));
                jdbc.update("insert into huaman.usuario(username,clave_hash,nombres,apellidos,dni,id_rol,clave_temporal) select 'race.second',clave_hash,'Segundo','Operador','87654321',id_rol,false from huaman.usuario where username='workflow.admin'");
                first = identity(auth, "workflow.admin"); second = identity(auth, "race.second");
                cashId = cash.open(first, "CONCURRENCY_TEST", new Open(n("0"), null, UUID.randomUUID())).id();
                jdbc.update("update huaman.parametro_sistema set valor='20123456789' where clave='NEGOCIO.RUC'");
                jdbc.update("update huaman.parametro_sistema set valor='Dirección de prueba local' where clave='NEGOCIO.DIRECCION'");
            });
        } catch (Throwable failure) { cleanup(); throw failure; }
    }

    private Connection maintenance() throws SQLException { return DriverManager.getConnection(baseUrl + "postgres", "postgres", ""); }
    @AfterEach void cleanup() throws Exception {
        if (context != null) { context.close(); context = null; }
        if (database != null && baseUrl != null) {
            assertThat(database).matches("huaman_race_[a-f0-9]{32}");
            try (var c = maintenance(); var s = c.createStatement()) { s.execute("drop database if exists " + database + " with (force)"); }
            database = null;
        }
    }

    private Identity identity(AuthStore auth, String username) {
        var u = auth.lockUsername(username).orElseThrow();
        UUID token = UUID.randomUUID();
        auth.createSession(u.id(), token, LocalDateTime.now(ZoneId.of("America/Lima")));
        return new Identity(u.id(), u.username(), u.nombres(), u.apellidos(), u.rol(), false,
            auth.permissions(u.id()), token, OffsetDateTime.now().plusMinutes(30));
    }
    private BigDecimal n(String value) { return new BigDecimal(value); }
    private long count(String table) { return jdbc.queryForObject("select count(*) from huaman." + table, Long.class); }
    private long id(Details detail) { return ((Number) detail.venta().get("id")).longValue(); }
    private long presentation(Product p) { return products.details(first, p.id()).presentaciones().getFirst().id(); }
    private Product product(String stock) {
        String code = "RACE" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        long category = context.getBean(CatalogService.class).createCategory(first, "CONCURRENCY_TEST", new CategoryInput(code, null, null)).id();
        long unit = jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat='NIU'", Long.class);
        var p = products.create(first, "CONCURRENCY_TEST", new ProductInput(code, "Producto de concurrencia", null, category, unit,
            false, n("1"), n("1"), "GRANEL", n("0"), null, "Unidad", n("10"), null));
        context.getBean(PurchaseService.class).opening(first, "CONCURRENCY_TEST", new Opening(p.id(), n(stock), n("1"), UUID.randomUUID(), List.of()));
        return p;
    }
    private Create creation(Product p, UUID key, Long client) { return new Create(client, "N", true, key, List.of(new Line(presentation(p), n("1"), 1))); }
    private Details draft(Identity actor, Product p, Long client) { return sales.create(actor, "CONCURRENCY_TEST", creation(p, UUID.randomUUID(), client)); }
    private Confirm confirmation(Details draft, String medium) {
        long series = jdbc.queryForObject("select min(id_serie) from huaman.serie_comprobante where tipo_comprobante='N' and estado='A'", Long.class);
        return new Confirm(series, LocalDateTime.parse(draft.venta().get("version").toString()),
            List.of(new Payment(medium, n("10"), medium.equals("EFECTIVO") ? n("10") : null, null, null, null)), List.of());
    }
    private long creditAccount(Product p) {
        var customers = context.getBean(CustomerService.class);
        var client = customers.save(first, "CONCURRENCY_TEST", null,
            new CustomerModels.Input("DNI", "23456789", "Cliente de concurrencia", null, null, null, null));
        customers.credit(first, "CONCURRENCY_TEST", client.id(), new CustomerModels.Credit(n("100"), client.version()));
        var draft = draft(first, p, client.id());
        sales.confirm(first, "CONCURRENCY_TEST", id(draft), confirmation(draft, "CREDITO"));
        return ((Number) credits.statement(first, client.id()).cuentas().getFirst().get("id")).longValue();
    }
    private RegisterPayment payment(long account, UUID key, String amount) { return new RegisterPayment(account, n(amount), "EFECTIVO", key, null, null, null, "Prueba concurrente"); }
    private BigDecimal debt(long account) { return jdbc.queryForObject("select saldo from huaman.cuenta_por_cobrar where id_cuenta=?", BigDecimal.class, account); }
    private Close closing() { return new Close(n("0"), n("0"), n("0"), "Cierre de prueba concurrente", UUID.randomUUID()); }
    private void stock(Product p, String expected) { assertThat(n(products.details(first, p.id()).producto().stockActual())).isEqualByComparingTo(expected); }
    private void money(String expected) { assertThat(n(cash.current().caja().efectivo())).isEqualByComparingTo(expected); }

    private record Outcome(Object value, Throwable failure) { boolean success() { return failure == null; } }
    private Outcome attempt(Supplier<?> action) { try { return new Outcome(action.get(), null); } catch (RuntimeException e) { return new Outcome(null, e); } }

    /** A third connection holds the cash row until BOTH real transactions are waiting on locks.
     * This proves overlap, rather than hoping two quickly submitted tasks happen to overlap.
     */
    private List<Outcome> race(Supplier<?> left, Supplier<?> right) throws Exception {
        return race(left, right, false);
    }
    private void awaitWaiting(long minimum) throws Exception {
        long until = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        // A separate autocommit monitor avoids the statistics snapshot cached by
        // PostgreSQL when this helper is called from a long-running transaction.
        try (var monitor = DriverManager.getConnection(baseUrl + database, "postgres", ""); var statement = monitor.createStatement()) {
            long waiting;
            do {
                try (var rows = statement.executeQuery("select count(*) from pg_stat_activity where datname=current_database() and wait_event_type='Lock'")) { rows.next(); waiting = rows.getLong(1); }
                if (waiting >= minimum) break;
                Thread.sleep(20);
            } while (System.nanoTime() < until);
            assertThat(waiting).as("Transacciones realmente esperando bloqueos").isGreaterThanOrEqualTo(minimum);
        }
    }
    private List<Outcome> race(Supplier<?> left, Supplier<?> right, boolean rightFirst) throws Exception {
        var ready = new CountDownLatch(2); var startLeft = new CountDownLatch(1); var startRight = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(2);
        try (var blocker = DriverManager.getConnection(baseUrl + database, "postgres", "")) {
            blocker.setAutoCommit(false);
            try (var s = blocker.createStatement()) { s.executeQuery("select id_caja from huaman.caja_diaria where id_caja=" + cashId + " for update").close(); }
            var a = pool.submit(() -> { ready.countDown(); if (!startLeft.await(12, TimeUnit.SECONDS)) throw new AssertionError("No se inició la carrera"); return attempt(left); });
            var b = pool.submit(() -> { ready.countDown(); if (!startRight.await(12, TimeUnit.SECONDS)) throw new AssertionError("No se inició la carrera"); return attempt(right); });
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            try {
                (rightFirst ? startRight : startLeft).countDown(); awaitWaiting(1);
                (rightFirst ? startLeft : startRight).countDown(); awaitWaiting(2);
            } finally { blocker.commit(); }
            return List.of(a.get(20, TimeUnit.SECONDS), b.get(20, TimeUnit.SECONDS));
        } finally {
            startLeft.countDown(); startRight.countDown(); pool.shutdownNow();
            assertThat(pool.awaitTermination(35, TimeUnit.SECONDS)).as("Sin tareas pendientes tras la prueba").isTrue();
        }
    }
    private void succeeded(Outcome result) { assertThat(result.failure()).isNull(); }
    private void businessRejection(Outcome result) {
        assertThat(result.failure()).isNotNull();
        if (result.failure() instanceof AuthFailure e) { assertThat(e.status()).isIn(400, 409); return; }
        Throwable cause = result.failure();
        while (cause != null && !(cause instanceof SQLException)) cause = cause.getCause();
        assertThat(cause).as("Rechazo de negocio, no error inesperado").isInstanceOf(SQLException.class);
        assertThat(((SQLException) cause).getSQLState()).isEqualTo("P0001");
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void accountLockStillSerializesSecurityChanges(boolean byUsername) throws Exception {
        var tx = context.getBean(TransactionTemplate.class); var auth = context.getBean(AuthStore.class);
        var pool = Executors.newSingleThreadExecutor();
        try {
            Future<?> update = tx.execute(status -> {
                if (byUsername) auth.lockUsername(first.usuario()).orElseThrow();
                else auth.lockUser(first.id()).orElseThrow();
                var pending = pool.submit(() -> tx.executeWithoutResult(other -> {
                    auth.context(second.usuario(), "CONCURRENCY_TEST");
                    jdbc.update("update huaman.usuario set bloqueado_hasta=timezone('America/Lima',now())+interval '1 hour' where id_usuario=?", first.id());
                }));
                try { awaitWaiting(1); } catch (Exception e) { throw new AssertionError(e); }
                assertThat(pending.isDone()).isFalse();
                assertThat(jdbc.queryForObject("select bloqueado_hasta is null from huaman.usuario where id_usuario=?", Boolean.class, first.id())).isTrue();
                return pending;
            });
            update.get(20, TimeUnit.SECONDS);
            assertThatThrownBy(() -> cash.manual(first, "CONCURRENCY_TEST", cashId,
                new Manual("INGRESO_MANUAL", n("1"), "Operación bloqueada de prueba", UUID.randomUUID())))
                .isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(401));
            money("0"); assertThat(count("movimiento_caja")).isZero();
        } finally { pool.shutdownNow(); assertThat(pool.awaitTermination(35, TimeUnit.SECONDS)).isTrue(); }
    }

    @Test void simultaneousCreationAndLostResponseRetryCreateOnlyOneDraft() throws Exception {
        var p = product("2"); var request = creation(p, UUID.randomUUID(), null);
        var results = race(() -> sales.create(first, "CONCURRENCY_TEST", request), () -> sales.create(first, "CONCURRENCY_TEST", request));
        results.forEach(this::succeeded);
        long sale = id((Details) results.getFirst().value());
        assertThat(id((Details) results.getLast().value())).isEqualTo(sale);
        assertThat(id(sales.create(first, "CONCURRENCY_TEST", request))).isEqualTo(sale);
        assertThat(count("venta")).isEqualTo(1); assertThat(count("detalle_venta")).isEqualTo(1);
        assertThat(count("pago")).isZero(); stock(p, "2"); money("0");
        var changed = new Create(null, "N", true, request.clave(), List.of(new Line(presentation(p), n("2"), 1)));
        assertThatThrownBy(() -> sales.create(first, "CONCURRENCY_TEST", changed)).isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(409));
        assertThatThrownBy(() -> sales.create(second, "CONCURRENCY_TEST", request)).isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(409));
        assertThat(count("venta")).isEqualTo(1); assertThat(count("detalle_venta")).isEqualTo(1);
    }

    @Test void simultaneousConfirmationAndLostResponseRetryChargeOnlyOnce() throws Exception {
        var p = product("2"); var draft = draft(first, p, null); var request = confirmation(draft, "EFECTIVO");
        var results = race(() -> sales.confirm(first, "CONCURRENCY_TEST", id(draft), request), () -> sales.confirm(first, "CONCURRENCY_TEST", id(draft), request));
        results.forEach(this::succeeded);
        assertThat(sales.confirm(first, "CONCURRENCY_TEST", id(draft), request).venta().get("estado")).isEqualTo("CONFIRMADA");
        stock(p, "1"); money("10");
        assertThat(count("pago")).isEqualTo(1); assertThat(count("comprobante_venta")).isEqualTo(1);
        assertThat(count("movimiento_caja")).isEqualTo(1); assertThat(count("movimiento_inventario")).isEqualTo(2);
        var changed = new Confirm(request.serieId(), request.version(), List.of(new Payment("EFECTIVO", n("10"), n("20"), null, null, null)), List.of());
        assertThatThrownBy(() -> sales.confirm(first, "CONCURRENCY_TEST", id(draft), changed)).isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(409));
        stock(p, "1"); money("10"); assertThat(count("pago")).isEqualTo(1);
    }

    @Test void twoOperatorsCannotSellTheSameLastUnit() throws Exception {
        var p = product("1"); var a = draft(first, p, null); var b = draft(second, p, null);
        var ca = confirmation(a, "EFECTIVO"); var cb = confirmation(b, "EFECTIVO");
        var results = race(() -> sales.confirm(first, "CONCURRENCY_TEST", id(a), ca), () -> sales.confirm(second, "CONCURRENCY_TEST", id(b), cb));
        assertThat(results.stream().filter(Outcome::success).count()).isEqualTo(1);
        results.stream().filter(r -> !r.success()).forEach(this::businessRejection);
        stock(p, "0"); money("10"); assertThat(count("pago")).isEqualTo(1);
        assertThat(count("comprobante_venta")).isEqualTo(1); assertThat(count("movimiento_inventario")).isEqualTo(2);
        assertThat(jdbc.queryForList("select estado_venta from huaman.venta", String.class)).containsExactlyInAnyOrder("CONFIRMADA", "BORRADOR");
    }

    @Test void twoOperatorsCannotCollectMoreThanTheDebt() throws Exception {
        long account = creditAccount(product("2"));
        var a = payment(account, UUID.randomUUID(), "7"); var b = payment(account, UUID.randomUUID(), "7");
        var results = race(() -> credits.registerPayment(first, "CONCURRENCY_TEST", a), () -> credits.registerPayment(second, "CONCURRENCY_TEST", b));
        assertThat(results.stream().filter(Outcome::success).count()).isEqualTo(1);
        results.stream().filter(r -> !r.success()).forEach(this::businessRejection);
        assertThat(debt(account)).isEqualByComparingTo("3"); money("7"); assertThat(count("abono_credito")).isEqualTo(1);
        var winner = results.getFirst().success() ? first : second; var request = results.getFirst().success() ? a : b;
        credits.registerPayment(winner, "CONCURRENCY_TEST", request);
        assertThat(debt(account)).isEqualByComparingTo("3"); money("7"); assertThat(count("abono_credito")).isEqualTo(1);
    }

    @Test void simultaneousPaymentRetryUsesTheSameReceiptAndRejectsChangedPayload() throws Exception {
        long account = creditAccount(product("2")); var request = payment(account, UUID.randomUUID(), "7");
        var results = race(() -> credits.registerPayment(first, "CONCURRENCY_TEST", request), () -> credits.registerPayment(first, "CONCURRENCY_TEST", request));
        results.forEach(this::succeeded); assertThat(results.getFirst().value()).isEqualTo(results.getLast().value());
        credits.registerPayment(first, "CONCURRENCY_TEST", request);
        assertThat(count("abono_credito")).isEqualTo(1); assertThat(debt(account)).isEqualByComparingTo("3"); money("7");
        assertThatThrownBy(() -> credits.registerPayment(first, "CONCURRENCY_TEST", payment(account, request.clave(), "6")))
            .isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(409));
        assertThatThrownBy(() -> credits.registerPayment(second, "CONCURRENCY_TEST", request))
            .isInstanceOfSatisfying(AuthFailure.class, e -> assertThat(e.status()).isEqualTo(409));
        assertThat(count("abono_credito")).isEqualTo(1); assertThat(debt(account)).isEqualByComparingTo("3"); money("7");
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void closingAndPaymentLeaveNoCollectionOutsideTheClosedCash(boolean closeFirst) throws Exception {
        long account = creditAccount(product("2")); var request = payment(account, UUID.randomUUID(), "7"); var close = closing();
        var results = race(() -> credits.registerPayment(second, "CONCURRENCY_TEST", request), () -> cash.close(first, "CONCURRENCY_TEST", cashId, close), closeFirst);
        succeeded(results.getLast()); assertThat(cash.current().caja().estado()).isEqualTo("CERRADA");
        boolean collected = results.getFirst().success();
        assertThat(collected).isEqualTo(!closeFirst);
        if (!collected) businessRejection(results.getFirst());
        assertThat(debt(account)).isEqualByComparingTo(collected ? "3" : "10"); money(collected ? "7" : "0");
        assertThat(count("abono_credito")).isEqualTo(collected ? 1 : 0);
        assertThat(n(cash.current().caja().diferenciaEfectivo())).isEqualByComparingTo(collected ? "-7" : "0");
        cash.close(first, "CONCURRENCY_TEST", cashId, close); // lost close response
        if (collected) credits.registerPayment(second, "CONCURRENCY_TEST", request); // replay after closure
        else assertThatThrownBy(() -> credits.registerPayment(second, "CONCURRENCY_TEST", request)).isInstanceOf(AuthFailure.class);
        assertThat(count("abono_credito")).isEqualTo(collected ? 1 : 0);
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void closingAndConfirmationCannotLeaveAnUnaccountedSale(boolean closeFirst) throws Exception {
        var p = product("1"); var draft = draft(second, p, null); var request = confirmation(draft, "EFECTIVO");
        var results = race(() -> sales.confirm(second, "CONCURRENCY_TEST", id(draft), request), () -> cash.close(first, "CONCURRENCY_TEST", cashId, closing()), closeFirst);
        succeeded(results.getFirst()); if (!results.getLast().success()) businessRejection(results.getLast());
        assertThat(results.getLast().success()).isEqualTo(!closeFirst);
        stock(p, "0"); money("10"); assertThat(count("comprobante_venta")).isEqualTo(1);
        assertThat(cash.current().caja().estado()).isEqualTo(results.getLast().success() ? "CERRADA" : "ABIERTA");
        if (results.getLast().success()) assertThat(n(cash.current().caja().diferenciaEfectivo())).isEqualByComparingTo("-10");
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void closingAndReturnApprovalCannotPartiallyRefundOrRestock(boolean closeFirst) throws Exception {
        var p = product("1"); var draft = draft(first, p, null);
        var sale = sales.confirm(first, "CONCURRENCY_TEST", id(draft), confirmation(draft, "EFECTIVO"));
        long line = ((Number) sale.lineas().getFirst().get("id")).longValue();
        var pending = returns.solicitar(first, "CONCURRENCY_TEST", new SolicitRequest(id(sale), "EFECTIVO", "Retorno de prueba concurrente",
            List.of(new ReturnItemRequest(line, n("1"), "APTO", List.of())), UUID.randomUUID(), false, null, null, null));
        var approve = new ApproveRequest(cashId, UUID.randomUUID(), null, "Producto recibido conforme");
        var results = race(() -> returns.aprobar(second, "CONCURRENCY_TEST", pending.cabecera().id(), approve), () -> cash.close(first, "CONCURRENCY_TEST", cashId, closing()), closeFirst);
        succeeded(results.getLast()); boolean approved = results.getFirst().success();
        assertThat(approved).as("Resultado de aprobación: %s", results.getFirst().failure()).isEqualTo(!closeFirst);
        if (!approved) businessRejection(results.getFirst());
        assertThat(cash.current().caja().estado()).isEqualTo("CERRADA"); stock(p, approved ? "1" : "0"); money(approved ? "0" : "10");
        assertThat(returns.detail(first, pending.cabecera().id()).cabecera().estadoDevolucion()).isEqualTo(approved ? "APROBADA" : "PENDIENTE");
        assertThat(count("movimiento_inventario")).isEqualTo(approved ? 3 : 2);
        assertThat(n(cash.current().caja().diferenciaEfectivo())).isEqualByComparingTo(approved ? "0" : "-10");
        if (approved) returns.aprobar(second, "CONCURRENCY_TEST", pending.cabecera().id(), approve);
        stock(p, approved ? "1" : "0"); money(approved ? "0" : "10");
    }
}

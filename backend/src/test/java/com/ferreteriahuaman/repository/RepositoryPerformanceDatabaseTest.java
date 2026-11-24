package com.ferreteriahuaman.repository;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zaxxer.hikari.HikariDataSource;
import com.ferreteriahuaman.dto.ReportModels.Filter;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.sql.*;
import java.time.LocalDate;
import java.util.*;
import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.*;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;

/** Opt-in measurements, not machine-dependent CI latency assertions. Every sample
 * verifies the returned data; the production repositories execute the real SQL.
 */
@EnabledIfEnvironmentVariable(named="HUAMAN_PERFORMANCE_DB",matches="true")
class RepositoryPerformanceDatabaseTest {
    private String base, database;
    private JdbcTemplate jdbc;
    private HikariDataSource source;
    private ProductRepository products;
    private ReportRepository reports;
    private PurchaseRepository inventory;
    private final Map<String,Object> measurements = new LinkedHashMap<>();
    private Connection maintenance() throws SQLException { return DriverManager.getConnection(base + "postgres", "postgres", ""); }

    @BeforeEach void setup() throws Exception {
        String template = System.getenv("HUAMAN_PERFORMANCE_TEMPLATE_URL");
        assertThat(template).matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]{4,5}/huaman_concurrency_template");
        base = template.substring(0,template.lastIndexOf('/')+1);
        database = "huaman_perf_" + UUID.randomUUID().toString().replace("-", "");
        try (var c=maintenance(); var s=c.createStatement(); var rows=s.executeQuery("select shobj_description(oid,'pg_database') from pg_database where datname='huaman_concurrency_template'")) {
            assertThat(rows.next()).isTrue(); assertThat(rows.getString(1)).isEqualTo("HUAMAN_DISPOSABLE_CONCURRENCY_TEMPLATE");
        }
        try (var c=maintenance(); var s=c.createStatement()) { s.execute("create database " + database + " template huaman_concurrency_template"); }
        source = new HikariDataSource(); source.setJdbcUrl(base+database+"?socketTimeout=300&connectTimeout=5");
        source.setUsername("postgres"); source.setPassword(""); source.setMaximumPoolSize(5); source.setMinimumIdle(1);
        jdbc = new ObservedJdbcTemplate(source); jdbc.setQueryTimeout(240);
        assertThat(jdbc.queryForObject("select count(*) from huaman.producto",Long.class)).isZero();
        assertThat(jdbc.queryForObject("select count(*) from huaman.venta",Long.class)).isZero();
        assertThat(jdbc.queryForObject("select count(*) from huaman.caja_diaria",Long.class)).isZero();
        assertThat(jdbc.queryForObject("select count(*) from huaman.usuario where username<>'workflow.admin'",Long.class)).isZero();
        String seed;
        try (var stream=getClass().getResourceAsStream("/performance/seed.sql")) { assertThat(stream).isNotNull(); seed=new String(stream.readAllBytes(),StandardCharsets.UTF_8); }
        new TransactionTemplate(new DataSourceTransactionManager(source)).executeWithoutResult(status -> jdbc.execute(seed));
        jdbc.execute("ANALYZE");
        jdbc.setQueryTimeout(15);
        products=new ProductRepository(jdbc); reports=new ReportRepository(new NamedParameterJdbcTemplate(jdbc)); inventory=new PurchaseRepository(jdbc);
        measurements.put("postgres",jdbc.queryForObject("show server_version",String.class));
        measurements.put("rows",Map.of("products",count("producto"),"barcodes",count("codigo_presentacion"),"sales",count("venta"),"inventoryMovements",count("movimiento_inventario")));
    }
    @AfterEach void cleanup() throws Exception {
        if (source!=null) source.close();
        if (base!=null && database!=null) {
            assertThat(database).matches("huaman_perf_[a-f0-9]{32}");
            try (var c=maintenance();var s=c.createStatement()) { s.execute("drop database if exists " + database + " with (force)"); }
        }
    }
    private long count(String table) { return jdbc.queryForObject("select count(*) from huaman."+table,Long.class); }
    private void amount(Object value,String expected) { assertThat(new BigDecimal(value.toString())).isEqualByComparingTo(expected); }
    private void measure(String name,Supplier<?> action) {
        action.get(); action.get(); // warm-up, deliberately excluded
        var samples=new ArrayList<Double>();
        for (int i=0;i<7;i++) { long start=System.nanoTime(); action.get(); samples.add((System.nanoTime()-start)/1_000_000.0); }
        var sorted=samples.stream().sorted().toList();
        measurements.put(name,Map.of("medianMs",sorted.get(3),"maxMs",sorted.get(6),"samplesMs",samples));
    }
    private record Query(String sql,Object[] args) {}
    private static class ObservedJdbcTemplate extends JdbcTemplate {
        boolean capture;
        final List<Query> reads = new ArrayList<>();
        ObservedJdbcTemplate(HikariDataSource source) { super(source); }
        @Override public <T>T queryForObject(String sql,Class<T> type,Object...args) {
            if(capture) reads.add(new Query(sql,args.clone()));
            return super.queryForObject(sql,type,args);
        }
        @Override public <T>List<T> query(String sql,RowMapper<T> mapper,Object...args) {
            if(capture) reads.add(new Query(sql,args.clone()));
            return super.query(sql,mapper,args);
        }
    }
    private Object plans(String search) throws Exception {
        var observed=(ObservedJdbcTemplate)jdbc; observed.reads.clear(); observed.capture=true;
        try { products.list(search,"A",null,0,20,false); } finally { observed.capture=false; }
        assertThat(observed.reads).hasSize(2);
        var result=new ArrayList<Object>(); var mapper=new ObjectMapper();
        for(var query:observed.reads) result.add(mapper.readTree(jdbc.queryForObject("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) "+query.sql(),String.class,query.args())));
        return result;
    }
    @Test void measureCatalogInventoryAndReportsWithValidatedBusinessData() throws Exception {
        LocalDate today=reports.today(); long target=jdbc.queryForObject("select id_producto from huaman.producto where codigo='PF00001'",Long.class);
        var filter=new Filter(today.minusDays(29),today,null,"",0);
        measure("catalog-first",()->{var r=products.list("","A",null,0,20,false);assertThat(r.total()).isEqualTo(10000);assertThat(r.items()).hasSize(20);return r;});
        measure("catalog-last",()->{var r=products.list("","A",null,499,20,false);assertThat(r.items()).hasSize(20);return r;});
        measure("search-name",()->{var r=products.list("Herramienta de prueba 09999","A",null,0,20,false);assertThat(r.total()).isEqualTo(1);return r;});
        measure("search-code",()->{var r=products.list("PF09999","A",null,0,20,false);assertThat(r.total()).isEqualTo(1);return r;});
        measure("search-barcode",()->{var r=products.list("BCPF09999","A",null,0,20,false);assertThat(r.total()).isEqualTo(1);return r;});
        measure("search-missing",()->{var r=products.list("NO-EXISTE-EN-CATALOGO","A",null,0,20,false);assertThat(r.total()).isZero();return r;});
        measure("inventory-kardex",()->{var r=inventory.movements(target,0,20,true);assertThat(r.total()).isEqualTo(31);assertThat(r.items()).hasSize(20);return r;});
        measure("report-inventory",()->{var r=reports.inventory(filter,25,false);assertThat(r.registros().total()).isEqualTo(10000);amount(r.resumen().get("valor"),"19994000");return r;});
        measure("report-sales",()->{var r=reports.sales(filter);amount(r.resumen().get("ventas"),"3000");amount(r.resumen().get("neto"),"30000");amount(r.resumen().get("costo"),"6000");amount(r.resumen().get("margen"),"24000");return r;});
        measure("report-product",()->{var r=reports.sales(new Filter(filter.desde(),today,target,"",0));amount(r.resumen().get("ventas"),"30");amount(r.resumen().get("neto"),"300");return r;});
        measure("report-empty-period",()->{var r=reports.sales(new Filter(today.minusDays(60),today.minusDays(31),null,"",0));amount(r.resumen().get("ventas"),"0");amount(r.resumen().get("neto"),"0");return r;});
        measure("report-cash",()->{var r=reports.cash(filter,25,false);amount(r.resumen().get("cajas"),"1");amount(r.resumen().get("saldos"),"30000");return r;});
        measure("report-product-picker",()->{var r=reports.productOptions("PF09999",0);assertThat(r).hasSize(1);return r;});
        measurements.put("catalogPlans",plans("")); measurements.put("barcodePlans",plans("BCPF09999"));
        String label=System.getProperty("huaman.performance.run","baseline"); assertThat(label).matches("[a-z-]+");
        Path output=Path.of("target","performance-"+label+".json"); Files.createDirectories(output.getParent());
        new ObjectMapper().writerWithDefaultPrettyPrinter().writeValue(output.toFile(),measurements);
    }
}

package com.ferreteriahuaman.repository;
import java.time.*;import java.util.*;import java.math.BigDecimal;import org.junit.jupiter.api.*;import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.context.SpringBootTest;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;import org.springframework.test.context.ActiveProfiles;import org.springframework.transaction.annotation.Transactional;import static org.assertj.core.api.Assertions.*;
@SpringBootTest @ActiveProfiles({"local","db"}) @Transactional @EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class ReportLedgerDatabaseTest{
 @Autowired JdbcTemplate jdbc;@Autowired NamedParameterJdbcTemplate named;
 @BeforeEach void setup(){
 jdbc.execute("create temporary table venta(id_venta bigint,fecha_venta timestamp,fecha_anulacion timestamp,estado text,estado_venta text) on commit drop");
 jdbc.execute("create temporary table detalle_venta(id_detalle_venta bigint,id_venta bigint,id_producto bigint,producto_nombre text,unidad_base_simbolo text,cantidad_base numeric,importe numeric,costo_unitario_base numeric,estado text) on commit drop");
 jdbc.execute("create temporary table devolucion(id_devolucion bigint,fecha_decision timestamp,estado text,estado_devolucion text) on commit drop");
 jdbc.execute("create temporary table detalle_devolucion(id_devolucion bigint,id_detalle_venta bigint,id_producto bigint,unidad_base_simbolo text,cantidad_base numeric,importe numeric,costo_unitario_base numeric,estado_producto text,estado text) on commit drop");
 jdbc.execute("insert into pg_temp.venta values(1,'2026-10-10',null,'A','CONFIRMADA'),(2,'2026-10-10','2026-10-11','A','ANULADA'),(3,'2026-10-10',null,'A','BORRADOR')");
 jdbc.execute("insert into pg_temp.detalle_venta values(1,1,10,'Producto a granel','kg',10,100,3,'A'),(2,2,20,'Producto por unidad','und',4,40,4,'A'),(3,3,10,'Borrador','kg',9,90,1,'A')");
 jdbc.execute("insert into pg_temp.devolucion values(1,'2026-10-12','A','APROBADA'),(2,'2026-10-13','A','APROBADA'),(3,'2026-10-13','A','PENDIENTE')");
 jdbc.execute("insert into pg_temp.detalle_devolucion values(1,1,10,'kg',2,20,3,'APTO','A'),(2,1,10,'kg',1,10,3,'DANADO','A'),(3,1,10,'kg',1,10,3,'APTO','A')");
 }
 Map<String,Object> totals(String from,String to,Long product){var p=new HashMap<String,Object>();p.put("start",LocalDate.parse(from).atStartOfDay());p.put("end",LocalDate.parse(to).plusDays(1).atStartOfDay());p.put("product",product);return named.queryForMap(ReportRepository.LEDGER.replace("huaman.","pg_temp.")+"select coalesce(sum(importe),0) neto,coalesce(sum(costo),0) costo,coalesce(sum(importe-costo),0) margen from ledger",p);}
 void amount(Map<String,Object> map,String key,String expected){assertThat((BigDecimal)map.get(key)).isEqualByComparingTo(expected);}
 @Test void handlesSalesAnnulmentsApprovedAndDamagedReturns(){var r=totals("2026-10-10","2026-10-13",null);amount(r,"neto","70");amount(r,"costo","24");amount(r,"margen","46");}
 @Test void returnAffectsApprovalDayEvenWhenSaleIsOutsideRange(){var r=totals("2026-10-12","2026-10-12",10L);amount(r,"neto","-20");amount(r,"costo","-6");amount(r,"margen","-14");}
 @Test void damagedReturnDoesNotReverseConsumedCost(){var r=totals("2026-10-13","2026-10-13",10L);amount(r,"neto","-10");amount(r,"costo","0");amount(r,"margen","-10");}
 @Test void productFilterDoesNotMixDifferentUnits(){var r=totals("2026-10-10","2026-10-10",20L);amount(r,"neto","40");amount(r,"costo","16");}
}

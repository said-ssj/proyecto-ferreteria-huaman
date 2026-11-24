package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.ReportModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.sql.*;import java.math.BigDecimal;import java.time.*;import java.util.*;import org.springframework.context.annotation.Profile;import org.springframework.jdbc.core.RowMapper;import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;import org.springframework.stereotype.Repository;
@Repository @Profile("db") public class ReportRepository{
 private final NamedParameterJdbcTemplate jdbc;public ReportRepository(NamedParameterJdbcTemplate jdbc){this.jdbc=jdbc;}
 private final RowMapper<Map<String,Object>> row=(r,n)->{var map=new LinkedHashMap<String,Object>();var meta=r.getMetaData();for(int i=1;i<=meta.getColumnCount();i++){Object value=r.getObject(i);if(value instanceof BigDecimal d)value=d.toPlainString();else if(value instanceof java.sql.Date d)value=d.toLocalDate().toString();map.put(meta.getColumnLabel(i),value);}return map;};
 public LocalDate today(){return jdbc.getJdbcTemplate().queryForObject("select timezone('America/Lima',now())::date",LocalDate.class);}
 private Map<String,Object> params(Filter f){var p=new HashMap<String,Object>();p.put("start",f.desde().atStartOfDay());p.put("end",f.hasta().plusDays(1).atStartOfDay());p.put("from",f.desde());p.put("to",f.hasta());p.put("product",f.producto());p.put("q",f.buscar().strip());p.put("offset",(long)f.pagina()*25);return p;}
 static final String LEDGER="""
 with ledger as (
 select v.fecha_venta::date dia,d.id_producto,d.producto_nombre producto,d.unidad_base_simbolo unidad,d.cantidad_base cantidad,d.importe importe,d.cantidad_base*d.costo_unitario_base costo,v.id_venta venta,d.importe bruto,0::numeric anulacion,0::numeric devolucion
 from huaman.venta v join huaman.detalle_venta d using(id_venta)
 where v.estado='A' and v.estado_venta in ('CONFIRMADA','ANULADA') and d.estado='A' and v.fecha_venta>=:start and v.fecha_venta<:end and (:product::bigint is null or d.id_producto=:product)
 union all
 select v.fecha_anulacion::date,d.id_producto,d.producto_nombre,d.unidad_base_simbolo,-d.cantidad_base,-d.importe,-d.cantidad_base*d.costo_unitario_base,null::bigint,0::numeric,d.importe,0::numeric
 from huaman.venta v join huaman.detalle_venta d using(id_venta)
 where v.estado='A' and v.estado_venta='ANULADA' and d.estado='A' and v.fecha_anulacion>=:start and v.fecha_anulacion<:end and (:product::bigint is null or d.id_producto=:product)
 union all
 select r.fecha_decision::date,d.id_producto,v.producto_nombre,d.unidad_base_simbolo,-d.cantidad_base,-d.importe,case when d.estado_producto='APTO' then -d.cantidad_base*d.costo_unitario_base else 0 end,null::bigint,0::numeric,0::numeric,d.importe
 from huaman.devolucion r join huaman.detalle_devolucion d using(id_devolucion) join huaman.detalle_venta v using(id_detalle_venta)
 where r.estado='A' and r.estado_devolucion='APROBADA' and d.estado='A' and r.fecha_decision>=:start and r.fecha_decision<:end and (:product::bigint is null or d.id_producto=:product)
 )
 """;
 private static final String TOTALS="count(distinct venta) ventas,coalesce(sum(bruto),0) bruto,coalesce(sum(anulacion),0) anulaciones,coalesce(sum(devolucion),0) devoluciones,coalesce(sum(importe),0) neto,coalesce(sum(costo),0) costo,coalesce(sum(importe-costo),0) margen";
 public Sales sales(Filter f){var p=params(f);var summary=jdbc.queryForObject(LEDGER+"select "+TOTALS+" from ledger",p,row);
 var days=jdbc.query(LEDGER+", totals as(select dia,"+TOTALS+" from ledger group by dia) select x::date fecha,coalesce(t.ventas,0) ventas,coalesce(t.neto,0) neto,coalesce(t.costo,0) costo,coalesce(t.margen,0) margen from generate_series(:from::date,:to::date,interval '1 day') x left join totals t on t.dia=x::date order by x",p,row);
 var products=jdbc.query(LEDGER+"select id_producto id,max(producto) producto,unidad,sum(cantidad) cantidad,sum(importe) neto,sum(costo) costo,sum(importe-costo) margen from ledger group by id_producto,unidad order by neto desc,id_producto limit 10",p,row);
 return new Sales(f.desde(),f.hasta(),summary,days,products);}
 public List<Map<String,Object>> productOptions(String q,int page){return jdbc.query("select p.id_producto id,p.codigo,p.nombre,u.abreviatura unidad,p.estado from huaman.producto p join huaman.unidad_medida u using(id_unidad) where position(lower(:q) in lower(p.nombre||' '||p.codigo))>0 order by p.nombre,p.id_producto limit 25 offset :offset",Map.of("q",q,"offset",(long)page*25),row);}
 private static final String STOCK="""
 from huaman.producto p join huaman.unidad_medida u using(id_unidad)
 left join (select id_producto,sum(case when sentido='E' then cantidad else 0 end) entradas,sum(case when sentido='S' then cantidad else 0 end) salidas from huaman.movimiento_inventario where estado='A' and feccre>=:start and feccre<:end group by id_producto) m using(id_producto)
 where p.estado='A' and position(lower(:q) in lower(p.nombre||' '||p.codigo))>0
 """;
 public Tabular inventory(Filter f,int limit,boolean export){var p=params(f);p.put("limit",limit);if(export)p.put("offset",0L);var summary=jdbc.queryForObject("select count(*) productos,count(*) filter(where p.stock_actual<=p.stock_minimo) bajos,count(*) filter(where p.stock_actual=0) agotados,coalesce(sum(p.stock_actual*p.costo_promedio),0) valor"+" "+STOCK,p,row);
 var items=jdbc.query("select p.id_producto id,p.codigo,p.nombre producto,u.abreviatura unidad,p.stock_actual stock,p.stock_minimo minimo,p.costo_promedio costo,p.stock_actual*p.costo_promedio valor,coalesce(m.entradas,0) entradas,coalesce(m.salidas,0) salidas"+" "+STOCK+" order by p.nombre,p.id_producto limit :limit offset :offset",p,row);
 return new Tabular(f.desde(),f.hasta(),summary,new Page<>(items,((Number)summary.get("productos")).longValue(),f.pagina(),limit));}
 private static final String CASH="""
 with movements as(select id_caja,coalesce(sum(importe) filter(where tipo_movimiento='APERTURA'),0) inicial,coalesce(sum(importe) filter(where sentido='I' and tipo_movimiento<>'APERTURA'),0) ingresos,coalesce(sum(importe) filter(where sentido='E'),0) egresos,coalesce(sum(case when sentido='I' then importe else -importe end) filter(where medio='EFECTIVO'),0) efectivo,coalesce(sum(case when sentido='I' then importe else -importe end) filter(where medio='YAPE'),0) yape,coalesce(sum(case when sentido='I' then importe else -importe end) filter(where medio='DEBITO'),0) debito from huaman.movimiento_caja where estado='A' group by id_caja), cajas as(
 select c.id_caja id,c.fecha,c.estado_caja estado,coalesce(m.inicial,0) inicial,coalesce(m.ingresos,0) ingresos,coalesce(m.egresos,0) egresos,coalesce(m.efectivo,0) efectivo,coalesce(m.yape,0) yape,coalesce(m.debito,0) debito,case when c.estado_caja='CERRADA' then c.diferencia_efectivo+c.diferencia_yape+c.diferencia_debito end diferencia from huaman.caja_diaria c left join movements m using(id_caja) where c.estado='A' and c.fecha>=:from and c.fecha<=:to)
 """;
 public Tabular cash(Filter f,int limit,boolean export){var p=params(f);p.put("limit",limit);if(export)p.put("offset",0L);var summary=jdbc.queryForObject(CASH+"select count(*) cajas,coalesce(sum(inicial),0) inicial,coalesce(sum(ingresos),0) ingresos,coalesce(sum(egresos),0) egresos,coalesce(sum(efectivo+yape+debito),0) saldos,coalesce(sum(diferencia),0) diferencias,count(*) filter(where estado='ABIERTA') abiertas from cajas",p,row);
 return new Tabular(f.desde(),f.hasta(),summary,new Page<>(jdbc.query(CASH+"select * from cajas order by fecha desc,id desc limit :limit offset :offset",p,row),((Number)summary.get("cajas")).longValue(),f.pagina(),limit));}
 public void audit(long actor,String type,Filter f){jdbc.getJdbcTemplate().update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,valor_nuevo) values(?,'REP.EXPORTAR','reporte',jsonb_build_object('tipo',?::text,'desde',?::text,'hasta',?::text))",actor,type,f.desde().toString(),f.hasta().toString());}
}

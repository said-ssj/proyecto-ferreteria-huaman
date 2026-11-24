package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.XmlTrialModels.*;import java.time.LocalDateTime;import java.util.*;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Repository;
@Repository @Profile("db") public class XmlTrialRepository{
 private final JdbcTemplate jdbc;public XmlTrialRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 public Optional<Document> get(long id,boolean lock){return jdbc.query("""
 select v.id_venta,c.tipo_comprobante,c.serie,c.numero,c.fecha_emision,c.negocio_nombre,c.negocio_ruc,c.negocio_direccion,c.cliente_nombre,c.cliente_tipo_doc,c.cliente_nro_doc,v.igv_porcentaje,c.base_imponible,c.igv,c.total,v.estado_venta,c.estado_comprobante,c.estado_tributario
 from huaman.venta v join huaman.comprobante_venta c using(id_venta) where v.id_venta=? and v.estado='A' and c.estado='A'
 """+(lock?" for share of v,c":""),(r,n)->new Document(r.getLong(1),r.getString(2),r.getString(3),r.getInt(4),r.getObject(5,LocalDateTime.class),r.getString(6),r.getString(7),r.getString(8),r.getString(9),r.getString(10),r.getString(11),r.getBigDecimal(12),r.getBigDecimal(13),r.getBigDecimal(14),r.getBigDecimal(15),r.getString(16),r.getString(17),r.getString(18),lines(id)),id).stream().findFirst();}
 private List<Line> lines(long id){return jdbc.query("select id_detalle_venta,producto_nombre,presentacion_nombre,codigo_unidad_sunat,cantidad,precio_unitario,importe,base_imponible_linea,igv_linea from huaman.detalle_venta where id_venta=? and estado='A' order by id_detalle_venta limit 501",(r,n)->new Line(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getBigDecimal(5),r.getBigDecimal(6),r.getBigDecimal(7),r.getBigDecimal(8),r.getBigDecimal(9)),id);}
 public void audit(long actor,Long sale,String type){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,valor_nuevo) values(?,'VEN.XML_PRUEBA','xml_prueba',?,jsonb_build_object('modo','LOCAL_SIN_FIRMA','tipo',?::text,'validezTributaria',false))",actor,sale,type);}
}

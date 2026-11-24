package com.ferreteriahuaman.dto;
import java.time.LocalDateTime;import java.math.BigDecimal;import java.util.List;
public final class XmlTrialModels{
 private XmlTrialModels(){}
 public record Line(long id,String producto,String presentacion,String unidad,BigDecimal cantidad,BigDecimal precio,BigDecimal importe,BigDecimal base,BigDecimal igv){}
 public record Document(long venta,String tipo,String serie,int numero,LocalDateTime fecha,String emisor,String ruc,String direccion,String cliente,String tipoDocumento,String documento,BigDecimal porcentaje,BigDecimal base,BigDecimal igv,BigDecimal total,String estadoVenta,String estadoComprobante,String estadoTributario,List<Line> lineas){}
 public record Preview(String modo,boolean enviosHabilitados,boolean validezTributaria,boolean generable,String comprobante,List<String> errores,List<String> advertencias,String xml){}
 public record Download(String nombre,byte[] contenido,String sha256){}
 public record Status(String modo,boolean enviosHabilitados,boolean firmaDigital,boolean validezTributaria){}
}

package com.ferreteriahuaman.dto;
import java.time.LocalDate;import java.util.*;import com.ferreteriahuaman.dto.CatalogModels.Page;
public final class ReportModels{
 private ReportModels(){}
 public record Filter(LocalDate desde,LocalDate hasta,Long producto,String buscar,int pagina){}
 public record Sales(LocalDate desde,LocalDate hasta,Map<String,Object> resumen,List<Map<String,Object>> dias,List<Map<String,Object>> productos){}
 public record Tabular(LocalDate desde,LocalDate hasta,Map<String,Object> resumen,Page<Map<String,Object>> registros){}
 public record Dates(LocalDate hoy){}
}

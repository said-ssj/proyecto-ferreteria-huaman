package com.ferreteriahuaman.dto;
import java.time.*;import java.util.List;import com.fasterxml.jackson.databind.JsonNode;
public final class AuditModels {
 private AuditModels(){}
 public record Filter(LocalDate desde,LocalDate hasta,String usuario,String accion,String grupo,int pagina,int tamano){}
 public record Event(long id,LocalDateTime fecha,String usuario,String accion,String entidad,Long registro,String equipo){}
 public record Raw(Event evento,String anterior,String nuevo){}
 public record Detail(Event evento,JsonNode anterior,JsonNode nuevo){}
 public record Options(List<String> acciones){}
}

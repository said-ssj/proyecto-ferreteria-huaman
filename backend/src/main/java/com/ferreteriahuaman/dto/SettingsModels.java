package com.ferreteriahuaman.dto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
public final class SettingsModels {
 private SettingsModels(){}
 public record Parameter(String clave,String grupo,String valor,String tipo,BigDecimal minimo,BigDecimal maximo,String descripcion,boolean editable,LocalDateTime version){}
 public record Change(@NotBlank @Size(max=50) String clave,@NotNull @Size(max=300) String valor,LocalDateTime version){}
 public record Changes(@NotEmpty @Size(max=30) List<@Valid Change> cambios){}
 public record Series(long id,String tipo,String serie,int inicial,int ultimo,String estado,boolean usada,LocalDateTime version){}
 public record SeriesInput(@NotBlank @Pattern(regexp="B|F|N") String tipo,@NotBlank @Pattern(regexp="[BFN][0-9]{3}") String serie,@Min(1) @Max(2147483646) int inicial,LocalDateTime version){}
 public record State(@NotBlank @Pattern(regexp="A|I") String estado,@NotNull LocalDateTime version){}
 public record LabelRequest(@Positive long productoId,@Positive long presentacionId,@Positive Long codigoId,@Min(1) @Max(200) int cantidad){}
 public record Label(String producto,String presentacion,String codigo,String simbologia,String precio,int cantidad){}
}

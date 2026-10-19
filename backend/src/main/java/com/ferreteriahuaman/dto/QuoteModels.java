package com.ferreteriahuaman.dto;
import java.math.BigDecimal;import java.time.LocalDateTime;import java.util.*;import jakarta.validation.Valid;import jakarta.validation.constraints.*;
public final class QuoteModels {
 private QuoteModels(){}
 public record Line(@Positive long presentacionId,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad){}
 public record Save(@Positive Long clienteId,@Size(max=150) @Pattern(regexp="[^<>]*") String interesado,@Size(max=300) @Pattern(regexp="[^<>]*") String observacion,@NotNull UUID clave,LocalDateTime version,@NotEmpty @Size(max=100) List<@Valid Line> lineas){}
 public record Action(@NotNull UUID clave,@NotNull LocalDateTime version,@NotNull @Min(1) Integer revision,@Size(min=10,max=200) @Pattern(regexp="[^<>]*") String motivo){}
 public record Convert(@NotNull UUID clave,@NotNull LocalDateTime version,@NotBlank @Pattern(regexp="B|F|N") String tipo){}
 public record Details(Map<String,Object> cotizacion,List<Map<String,Object>> lineas){}
 public record Conversion(long ventaId){}
}

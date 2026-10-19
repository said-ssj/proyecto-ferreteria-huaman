package com.ferreteriahuaman.dto;
import java.math.BigDecimal;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
public final class InventoryModels {
 private InventoryModels(){}
 public record Physical(Long unidadId,@Pattern(regexp="ENVASE|SUELTO|TRAMO") String condicion,Long presentacionId,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad){}
 public record Adjustment(@Positive long productoId,@NotBlank @Pattern(regexp="AUMENTO|DISMINUCION") String tipo,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad,@Positive long motivoId,
  @NotBlank @Size(min=5,max=300) @Pattern(regexp="[^<>]*") String observacion,@NotNull UUID clave,@NotNull @Size(max=1000) List<@Valid Physical> unidades){}
 public record Transformation(@Positive long origenId,@NotBlank @Pattern(regexp="ABRIR|CORTAR") String operacion,
  @NotNull @Size(max=1000) List<@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal> longitudes,
  @NotBlank @Size(min=5,max=200) @Pattern(regexp="[^<>]*") String motivo,@NotNull UUID clave){}
 public record Start(@NotBlank @Pattern(regexp="TODO|CATEGORIA") String alcance,Long categoriaId,@Size(max=300) @Pattern(regexp="[^<>]*") String observacion,@NotNull UUID clave){}
 public record Count(@Positive long productoId,@NotNull @DecimalMin("0") @Digits(integer=12,fraction=6) BigDecimal cantidad,
  @NotNull @Min(0) Integer revision,@NotNull UUID clave,@NotNull @Size(max=1000) List<@Valid Physical> unidades){}
 public record Transition(@NotNull @Min(0) Integer revision,@NotNull UUID clave,@Size(max=300) @Pattern(regexp="[^<>]*") String motivo){}
 public record Result(long id){}
}


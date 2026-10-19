package com.ferreteriahuaman.dto;
import java.math.BigDecimal;import java.time.LocalDateTime;import java.util.*;import jakarta.validation.Valid;import jakarta.validation.constraints.*;
public final class SaleModels {
 private SaleModels(){}
 public record Line(@Positive long presentacionId,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad,@Min(1) @Max(1000) int piezas){}
 public record Create(@Positive Long clienteId,@NotBlank @Pattern(regexp="B|F|N") String tipo,boolean entregaInmediata,@NotNull UUID clave,@NotEmpty @Size(max=100) List<@Valid Line> lineas){}
 public record Payment(@NotBlank @Pattern(regexp="EFECTIVO|YAPE|DEBITO|CREDITO") String medio,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=16,fraction=2) BigDecimal monto,@DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal recibido,@Size(max=40) String operacion,@Size(max=30) String marca,@Pattern(regexp="[0-9]{4}") String ultimosCuatro){}
 public record Assignment(@Positive long lineaId,@Positive long unidadId,@Min(1) @Max(1000) int pieza,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad){}
 public record Confirm(@Positive long serieId,@NotNull LocalDateTime version,@NotEmpty @Size(max=4) List<@Valid Payment> pagos,@NotNull @Size(max=1000) List<@Valid Assignment> asignaciones){}
 public record Discard(@NotNull UUID clave,@NotNull LocalDateTime version,@NotBlank @Size(min=5,max=200) String motivo){}
 public record Details(Map<String,Object> venta,List<Map<String,Object>> lineas,List<Map<String,Object>> pagos,Map<String,Object> comprobante){}
}

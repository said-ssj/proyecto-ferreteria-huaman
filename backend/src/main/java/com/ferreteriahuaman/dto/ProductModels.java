package com.ferreteriahuaman.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import jakarta.validation.constraints.*;

public final class ProductModels {
 private ProductModels(){}
 public record Product(long id,String codigo,String nombre,String descripcion,long categoriaId,String categoria,long unidadId,String unidad,
  boolean admiteFracciones,String incrementoBase,String minimoVentaBase,String modoControl,String stockMinimo,String ubicacion,
  String stockActual,String precioBase,String ultimoCostoCompra,String costoPromedio,String estado,LocalDateTime version){}
 public record ProductInput(@NotBlank @Size(max=30) @Pattern(regexp="[A-Z0-9._-]+") String codigo,@NotBlank @Size(max=120) String nombre,
  @Size(max=300) String descripcion,@Positive long categoriaId,@Positive long unidadId,boolean admiteFracciones,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal incrementoBase,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal minimoVentaBase,
  @NotBlank @Pattern(regexp="GRANEL|ENVASES|TRAMOS") String modoControl,
  @NotNull @DecimalMin("0") @Digits(integer=12,fraction=6) BigDecimal stockMinimo,@Size(max=60) String ubicacion,
  @Size(max=60) String nombreBase,@DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal precioBase,LocalDateTime version){}
 public record Presentation(long id,long productoId,String nombre,Long unidadVentaId,String unidad,String factorBase,boolean esBase,boolean permiteVenta,
  boolean admiteFracciones,String incrementoVenta,String minimoVenta,String precioNormal,String estado,LocalDateTime version){}
 public record PresentationInput(@NotBlank @Size(max=60) String nombre,Long unidadVentaId,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal factorBase,boolean permiteVenta,boolean admiteFracciones,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal incrementoVenta,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal minimoVenta,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal precioNormal,LocalDateTime version){}
 public record Wholesale(long id,long presentacionId,String cantidadMinima,String precio,String estado,LocalDateTime version){}
 public record WholesaleInput(@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidadMinima,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal precio,LocalDateTime version){}
 public record Barcode(long id,long presentacionId,String codigo,String simbologia,String estado,LocalDateTime version){}
 public record BarcodeInput(@NotBlank @Size(max=80) String codigo,@NotBlank @Pattern(regexp="CODE128|EAN13") String simbologia){}
 public record Details(Product producto,List<Presentation> presentaciones,List<Wholesale> preciosMayoristas,List<Barcode> codigos){}
}

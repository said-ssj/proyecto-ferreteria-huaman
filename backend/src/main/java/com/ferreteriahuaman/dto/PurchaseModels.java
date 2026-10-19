package com.ferreteriahuaman.dto;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public final class PurchaseModels {
 private PurchaseModels(){}
 public record Supplier(long id,String ruc,String razonSocial,String contacto,String telefono,String correo,String direccion,String estado,LocalDateTime version){}
 public record SupplierInput(@NotBlank @Pattern(regexp="[0-9]{11}") String ruc,@NotBlank @Size(max=150) String razonSocial,@Size(max=100) String contacto,@Size(max=20) String telefono,@Email @Size(max=100) String correo,@Size(max=200) String direccion,LocalDateTime version){}
 public record Document(long id,long numero,long proveedorId,String proveedor,LocalDate fecha,LocalDate entregaEstimada,Long ordenId,String guia,String observacion,String total,String estado,LocalDateTime version){}
 public record DocumentInput(@Positive long proveedorId,@NotNull LocalDate fecha,LocalDate entregaEstimada,Long ordenId,@Size(max=30) String guia,@Size(max=300) String observacion,LocalDateTime version,UUID clave){}
 public record Line(long id,long productoId,String producto,long presentacionId,String presentacion,String unidad,String factorBase,String cantidad,String cantidadBase,String recibidoBase,String canceladoBase,String costoUnitario,String importe,Long detalleOrdenId,String condicion,Integer piezas,String estado){}
 public record Details(Document documento,List<Line> lineas){}
 public record LineInput(@Positive long productoId,@Positive long presentacionId,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal costoUnitario,
  Long detalleOrdenId,@Pattern(regexp="GRANEL|ENVASE|TRAMO") String condicion,@Min(1) @Max(10000) Integer piezas,@NotNull LocalDateTime version){}
 public record Action(@NotNull UUID clave,@NotNull LocalDateTime version,@Size(max=200) String motivo){}
 public record PhysicalUnit(@NotBlank @Size(max=60) String identificador,@NotBlank @Pattern(regexp="ENVASE|SUELTO|TRAMO") String condicion,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad,Long presentacionId){}
 public record Opening(@Positive long productoId,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal cantidad,
  @NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=12,fraction=6) BigDecimal costoUnitarioBase,@NotNull UUID clave,@NotNull @Size(max=1000) List<@Valid PhysicalUnit> unidades){}
 public record Movement(long id,String tipo,String sentido,String cantidad,String saldoAnterior,String saldo,String costoUnitarioBase,LocalDateTime fecha){}
 public record Existence(long id,String identificador,String condicion,String cantidadInicial,String cantidadDisponible,Long presentacionId,String estado){}
 public record OpeningResult(long movimientoId){}
}

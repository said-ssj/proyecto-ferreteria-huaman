package com.ferreteriahuaman.dto;
import java.math.BigDecimal;import java.time.*;import java.util.UUID;import jakarta.validation.constraints.*;
public final class CashModels {
 private CashModels(){}
 public record Register(long id,LocalDate fecha,String estado,String fondo,String apertura,String cierre,LocalDateTime fechaApertura,LocalDateTime fechaCierre,String observacionApertura,String observacionCierre,String efectivo,String yape,String debito,String efectivoContado,String yapeReportado,String debitoReportado,String diferenciaEfectivo,String diferenciaYape,String diferenciaDebito,long ventasPendientes){}
 public record Current(LocalDate fechaServidor,Register caja){}
 public record Movement(long id,String tipo,String medio,String sentido,String importe,String motivo,LocalDateTime fecha,String usuario,Long ventaId){}
 public record Open(@NotNull @DecimalMin("0") @Digits(integer=10,fraction=2) BigDecimal fondo,@Size(max=300) String observacion,@NotNull UUID clave){}
 public record Manual(@NotBlank @Pattern(regexp="INGRESO_MANUAL|EGRESO_MANUAL") String tipo,@NotNull @DecimalMin(value="0",inclusive=false) @Digits(integer=16,fraction=2) BigDecimal importe,@NotBlank @Size(min=10,max=200) String motivo,@NotNull UUID clave){}
 public record Close(@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal efectivo,@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal yape,@NotNull @DecimalMin("0") @Digits(integer=16,fraction=2) BigDecimal debito,@Size(max=200) String observacion,@NotNull UUID clave){}
 public record Result(long id){}
}

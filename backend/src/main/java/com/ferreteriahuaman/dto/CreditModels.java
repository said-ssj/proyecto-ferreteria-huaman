package com.ferreteriahuaman.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;

public final class CreditModels {
    private CreditModels() {}

    public record Summary(
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal totalPorCobrar,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal totalVencido,
        long clientesDeudores
    ) {}

    public record AccountRow(
        long id,
        long ventaId,
        long clienteId,
        String cliente,
        String documento,
        String tipoComprobante,
        String serie,
        Integer numero,
        String comprobante,
        LocalDate fechaVenta,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal montoOriginal,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal montoAbonado,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal saldo,
        LocalDate fechaVencimiento,
        String situacion,
        String estadoCuenta,
        LocalDateTime version
    ) {}

    public record CustomerCreditInfo(
        long id,
        String nombre,
        String tipoDocumento,
        String documento,
        String telefono,
        String correo,
        String direccion,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal limiteCredito,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal deudaTotal,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal creditoDisponible
    ) {}

    public record Statement(
        CustomerCreditInfo cliente,
        List<Map<String, Object>> cuentas,
        List<Map<String, Object>> abonos
    ) {}

    public record PaymentReceipt(
        long id,
        long cuentaId,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal monto,
        String medio,
        String operacion,
        String marca,
        String ultimosCuatro,
        String observacion,
        LocalDateTime fecha,
        String registradoPor,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal montoOriginalCuenta,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal saldoActualCuenta,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal saldoAnteriorCuenta,
        String comprobante,
        long clienteId,
        String cliente,
        String tipoDocumento,
        String documento,
        String negocioNombre,
        String negocioRuc,
        String negocioDireccion,
        String negocioTelefono
    ) {}

    public record RegisterPayment(
        @NotNull Long cuentaId,
        @NotNull @DecimalMin(value="0.01") @Digits(integer=16, fraction=2) BigDecimal monto,
        @NotBlank @Pattern(regexp="EFECTIVO|YAPE|DEBITO") String medio,
        @NotNull UUID clave,
        @Size(max=40) String operacion,
        @Size(max=30) String marca,
        @Pattern(regexp="^[0-9]{4}$") String ultimosCuatro,
        @Size(max=300) String observacion
    ) {}
}

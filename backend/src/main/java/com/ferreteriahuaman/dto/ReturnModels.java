package com.ferreteriahuaman.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class ReturnModels {

    public record Summary(
        long pendientes,
        long aprobadasHoy,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal montoReintegradoHoy
    ) {}

    public record ReturnRow(
        Long id,
        String codigo,
        Long ventaId,
        String comprobante,
        String tipoComprobante,
        String clienteNombre,
        String clienteDocumento,
        String fechaSolicitud,
        String estadoDevolucion,
        String formaReintegro,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal montoReintegro,
        String motivo,
        Long solicitanteId,
        String solicitanteNombre,
        Long autorizadorId,
        String autorizadorNombre,
        String fechaDecision,
        String motivoRechazo,
        Long cajaId,
        String observacionAprobacion,
        int totalItems
    ) {}

    public record ReturnItem(
        Long id,
        Long idDetalleVenta,
        Long productoId,
        String codigoProducto,
        String nombreProducto,
        Long presentacionId,
        String presentacionNombre,
        String unidadBaseSimbolo,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal factorBase,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal cantidad,
        String estadoProducto,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal importe,
        String unidadesRetorno
    ) {}

    public record ReturnDetail(
        ReturnRow cabecera,
        List<ReturnItem> items
    ) {}

    public record SaleLookup(
        Long idVenta,
        String codigoVenta,
        String tipoComprobante,
        String serie,
        Integer correlativo,
        String comprobante,
        String fechaVenta,
        int diasTranscurridos,
        String clienteNombre,
        String clienteDocumento,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal total,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal saldoDeuda,
        String mediosPago
    ) {}

    public record SaleItemLookup(
        Long idDetalleVenta,
        Long productoId,
        String codigoProducto,
        String nombreProducto,
        String modoControl,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal incrementoBase,
        Long presentacionId,
        String presentacionNombre,
        String unidadBaseSimbolo,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal factorBase,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal cantidadVendida,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal precioUnitario,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal importeOriginal,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal yaDevuelto,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal disponibleDevolver,
        List<ReturnPresentation> presentacionesRetorno
    ) {}

    public record ReturnPresentation(long id, String nombre, @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal factorBase) {}

    public record SaleDetailLookup(
        SaleLookup venta,
        List<SaleItemLookup> items,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal cobradoEfectivoDisponible,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal cobradoYapeDisponible,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal cobradoDebitoDisponible,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal totalMonetarioDisponible,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal saldoDeuda
    ) {}

    public record CashOption(
        Long idCaja,
        LocalDate fecha,
        String estadoCaja,
        @com.fasterxml.jackson.databind.annotation.JsonSerialize(using=com.fasterxml.jackson.databind.ser.std.ToStringSerializer.class) BigDecimal efectivoDisponible
    ) {}

    public record ReturnItemRequest(
        @NotNull Long idDetalleVenta,
        @NotNull BigDecimal cantidad,
        @NotBlank String estadoProducto,
        List<Map<String, Object>> unidades
    ) {}

    public record SolicitRequest(
        @NotNull Long ventaId,
        @NotBlank String forma,
        @NotBlank String motivo,
        @NotNull List<ReturnItemRequest> lineas,
        @NotNull UUID clave,
        Boolean autoAprobar,
        Long cajaId,
        String referencia,
        String observacion
    ) {}

    public record ApproveRequest(
        @NotNull Long cajaId,
        @NotNull UUID clave,
        String referencia,
        String observacion
    ) {}

    public record RejectRequest(
        @NotNull UUID clave,
        @NotBlank String motivo
    ) {}
}

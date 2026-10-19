package com.ferreteriahuaman.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import jakarta.validation.constraints.*;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;

public final class DispatchModels {
    private DispatchModels() {}

    public record Summary(
        long pendientes,
        long preparados,
        long entregados,
        long anulados
    ) {}

    public record DispatchRow(
        long id,
        long numero,
        String numeroFormateado,
        long ventaId,
        String comprobante,
        String tipoComprobante,
        String clienteNombre,
        String clienteDocumento,
        String fechaVenta,
        String estado,
        int totalItems,
        String preparadoPor,
        String fechaPreparacion,
        String observacionPreparacion,
        String entregadoPor,
        String fechaEntrega,
        String recibeNombre,
        String observacionEntrega,
        String version
    ) {}

    public record DispatchItem(
        long id,
        long productoId,
        String codigoProducto,
        String productoNombre,
        String presentacionNombre,
        String unidadBase,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal cantidad,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal factorBase,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal cantidadBase,
        String ubicacion,
        String modoControl
    ) {}

    public record DispatchDetail(
        DispatchRow despacho,
        List<DispatchItem> items,
        String vendedor,
        @JsonSerialize(using=ToStringSerializer.class) BigDecimal totalVenta,
        String observacionVenta
    ) {}

    public record PrepareRequest(
        @NotNull UUID clave,
        @Size(max = 300) String observacion
    ) {}

    public record DeliverRequest(
        @NotNull UUID clave,
        @Size(max = 100) String recibe,
        @Size(max = 300) String observacion
    ) {}
}

package com.ferreteriahuaman.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public final class OfferModels {
    private OfferModels() {}

    public record OfferSummary(
        long vigentes,
        long programadas,
        long vencidas,
        long inactivas
    ) {}

    public record OfferRow(
        long id,
        String nombre,
        long productoId,
        String codigoProducto,
        String nombreProducto,
        long categoriaId,
        String categoriaNombre,
        long presentacionId,
        String presentacionNombre,
        String unidadBase,
        String precioRegular,
        String precioOferta,
        String descuentoPorcentaje,
        String costoReferencial,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        String estadoLogico,
        String estadoOperativo,
        @jakarta.validation.constraints.NotNull LocalDateTime version
    ) {}

    public record ProductPresentationOption(
        long productoId,
        String codigoProducto,
        String nombreProducto,
        long presentacionId,
        String presentacionNombre,
        String unidadBase,
        String precioRegular,
        String costoReferencial,
        boolean permiteVenta
    ) {}

    public record OfferCreateRequest(
        Long productoId,
        Long presentacionId,
        String nombre,
        BigDecimal precioOferta,
        LocalDate fechaInicio,
        LocalDate fechaFin
    ) {}

    public record OfferUpdateRequest(
        String nombre,
        BigDecimal precioOferta,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        @jakarta.validation.constraints.NotNull LocalDateTime version
    ) {}

    public record OfferStateRequest(
        String estado,
        @jakarta.validation.constraints.NotNull LocalDateTime version
    ) {}

    public record OfferListResponse(
        List<OfferRow> items,
        long total,
        int pagina,
        int tamano
    ) {}
}

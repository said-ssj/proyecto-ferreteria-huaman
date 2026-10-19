package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.OfferModels.*;
import com.ferreteriahuaman.repository.CatalogRepository;
import com.ferreteriahuaman.repository.OfferRepository;
import com.ferreteriahuaman.repository.OfferRepository.PresentationPricing;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

@Service
@Profile("db")
public class OfferService {
    private final OfferRepository repo;
    private final CatalogRepository catalog;
    private final BusinessTransactions tx;
    private final ObjectMapper mapper;
    private final Clock clock;

    private static final ZoneId LIMA = ZoneId.of("America/Lima");

    public OfferService(OfferRepository repo, CatalogRepository catalog, BusinessTransactions tx, ObjectMapper mapper, Clock clock) {
        this.repo = repo;
        this.catalog = catalog;
        this.tx = tx;
        this.mapper = mapper;
        this.clock = clock;
    }

    private LocalDate today() {
        return LocalDate.now(clock.withZone(LIMA));
    }

    private void sanitizeName(String name) {
        if (name == null || name.trim().length() < 3 || name.trim().length() > 80) {
            throw new AuthFailure(400, "El nombre de la oferta debe tener entre 3 y 80 caracteres");
        }
        if (name.contains("<") || name.contains(">")) {
            throw new AuthFailure(400, "El nombre de la oferta no puede contener caracteres HTML");
        }
    }

    private void event(Identity actor, String action, long id, Object before, Object after) {
        try {
            catalog.event(
                actor.id(),
                action,
                "oferta",
                id,
                before == null ? null : mapper.writeValueAsString(before),
                after == null ? null : mapper.writeValueAsString(after)
            );
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("No se pudo registrar la auditoría de oferta");
        }
    }

    public OfferSummary summary() {
        return repo.summary();
    }

    public OfferListResponse list(String search, String estado, Long categoriaId, int page, int size) {
        if (page < 0 || size < 1 || size > 100) {
            throw new AuthFailure(400, "Parámetros de paginación inválidos");
        }
        return repo.list(search, estado, categoriaId, page, size);
    }

    public OfferRow get(long id) {
        return repo.get(id, false).orElseThrow(() -> new AuthFailure(404, "Oferta no encontrada"));
    }

    public List<ProductPresentationOption> searchAvailableProducts(String search) {
        return repo.searchAvailableProducts(search);
    }

    public OfferRow create(Identity actor, String equipo, OfferCreateRequest req) {
        return tx.write(actor, equipo, "COC.OFERTAS", () -> {
            if (req.productoId() == null || req.productoId() <= 0) {
                throw new AuthFailure(400, "Debe seleccionar un producto válido");
            }
            if (req.presentacionId() == null || req.presentacionId() <= 0) {
                throw new AuthFailure(400, "Debe seleccionar una presentación válida");
            }
            sanitizeName(req.nombre());

            if (req.precioOferta() == null || req.precioOferta().compareTo(BigDecimal.ZERO) <= 0) {
                throw new AuthFailure(400, "El precio de oferta debe ser mayor a cero");
            }
            if (req.fechaInicio() == null || req.fechaFin() == null) {
                throw new AuthFailure(400, "Las fechas de inicio y fin son obligatorias");
            }
            if (req.fechaFin().isBefore(req.fechaInicio())) {
                throw new AuthFailure(400, "La fecha de fin no puede ser anterior a la fecha de inicio");
            }

            LocalDate hoy = today();
            if (req.fechaInicio().isBefore(hoy)) {
                throw new AuthFailure(400, "La fecha de inicio de la oferta no puede ser anterior a hoy");
            }

            PresentationPricing pricing = repo.getPresentationPricing(req.presentacionId())
                .orElseThrow(() -> new AuthFailure(404, "La presentación no existe"));

            if (pricing.productoId() != req.productoId()) {
                throw new AuthFailure(400, "La presentación seleccionada no corresponde al producto");
            }
            if (!"A".equals(pricing.estadoProducto()) || !"A".equals(pricing.estadoPresentacion()) || !pricing.permiteVenta()) {
                throw new AuthFailure(400, "El producto o la presentación seleccionada no están disponibles para la venta");
            }

            if (req.precioOferta().compareTo(pricing.precioNormal()) >= 0) {
                throw new AuthFailure(400, "El precio de oferta (S/ " + req.precioOferta() + ") debe ser menor al precio regular (S/ " + pricing.precioNormal() + ")");
            }

            if (pricing.costo() != null && pricing.costo().signum() > 0 && req.precioOferta().compareTo(pricing.costo()) < 0) {
                throw new AuthFailure(400, "El precio de oferta (S/ " + req.precioOferta() + ") no puede ser menor al costo del producto (S/ " + pricing.costo() + ")");
            }

            if (repo.hasOverlap(req.presentacionId(), null, req.fechaInicio(), req.fechaFin())) {
                throw new AuthFailure(409, "Ya existe una oferta activa para este producto y presentación que se solapa con las fechas indicadas");
            }

            long id;
            try {
                id = repo.create(
                    req.productoId(),
                    req.presentacionId(),
                    req.nombre().trim(),
                    req.precioOferta(),
                    req.fechaInicio(),
                    req.fechaFin()
                );
            } catch (DataIntegrityViolationException e) {
                if (e.getMessage() != null && e.getMessage().contains("oferta_")) {
                    throw new AuthFailure(409, "Ya existe una oferta activa para este producto y presentación que se solapa con las fechas indicadas");
                }
                throw new AuthFailure(400, "No se pudo registrar la oferta: datos inconsistentes");
            }

            OfferRow created = repo.get(id, false).orElseThrow();
            event(actor, "OFERTA_CREAR", id, null, created);
            return created;
        });
    }

    public OfferRow update(Identity actor, String equipo, long id, OfferUpdateRequest req) {
        return tx.write(actor, equipo, "COC.OFERTAS", () -> {
            OfferRow before = repo.get(id, true)
                .orElseThrow(() -> new AuthFailure(404, "Oferta no encontrada"));

            if (req.version() == null || !req.version().equals(before.version())) {
                throw new AuthFailure(409, "La oferta ha sido modificada por otro usuario. Vuelve a cargarla antes de guardar");
            }

            if ("INACTIVA".equals(before.estadoOperativo())) {
                throw new AuthFailure(400, "No se puede editar una oferta inactiva. Reactívela primero si aún está dentro de fechas");
            }
            if ("VENCIDA".equals(before.estadoOperativo())) {
                throw new AuthFailure(400, "No se puede editar una oferta que ya ha vencido");
            }

            sanitizeName(req.nombre());

            if (req.precioOferta() == null || req.precioOferta().compareTo(BigDecimal.ZERO) <= 0) {
                throw new AuthFailure(400, "El precio de oferta debe ser mayor a cero");
            }

            LocalDate hoy = today();
            LocalDate fechaInicioFinal;
            LocalDate fechaFinFinal = req.fechaFin();

            if (fechaFinFinal == null) {
                throw new AuthFailure(400, "La fecha de fin es obligatoria");
            }

            if ("VIGENTE".equals(before.estadoOperativo())) {
                fechaInicioFinal = before.fechaInicio();
                if (fechaFinFinal.isBefore(hoy)) {
                    throw new AuthFailure(400, "La fecha de fin de una oferta vigente no puede ser anterior a hoy");
                }
            } else {
                // PROGRAMADA
                fechaInicioFinal = req.fechaInicio() != null ? req.fechaInicio() : before.fechaInicio();
                if (fechaInicioFinal.isBefore(hoy)) {
                    throw new AuthFailure(400, "La fecha de inicio de la oferta no puede ser anterior a hoy");
                }
            }

            if (fechaFinFinal.isBefore(fechaInicioFinal)) {
                throw new AuthFailure(400, "La fecha de fin no puede ser anterior a la fecha de inicio");
            }

            PresentationPricing pricing = repo.getPresentationPricing(before.presentacionId())
                .orElseThrow(() -> new AuthFailure(404, "La presentación asociada ya no existe"));

            if (req.precioOferta().compareTo(pricing.precioNormal()) >= 0) {
                throw new AuthFailure(400, "El precio de oferta (S/ " + req.precioOferta() + ") debe ser menor al precio regular (S/ " + pricing.precioNormal() + ")");
            }

            if (pricing.costo() != null && pricing.costo().signum() > 0 && req.precioOferta().compareTo(pricing.costo()) < 0) {
                throw new AuthFailure(400, "El precio de oferta (S/ " + req.precioOferta() + ") no puede ser menor al costo del producto (S/ " + pricing.costo() + ")");
            }

            if (repo.hasOverlap(before.presentacionId(), id, fechaInicioFinal, fechaFinFinal)) {
                throw new AuthFailure(409, "Ya existe otra oferta activa para este producto y presentación que se solapa con las fechas indicadas");
            }

            try {
                repo.update(id, req.nombre().trim(), req.precioOferta(), fechaInicioFinal, fechaFinFinal);
            } catch (DataIntegrityViolationException e) {
                throw new AuthFailure(409, "Ya existe otra oferta activa para este producto y presentación que se solapa con las fechas indicadas");
            }

            OfferRow updated = repo.get(id, false).orElseThrow();
            event(actor, "OFERTA_EDITAR", id, before, updated);
            return updated;
        });
    }

    public OfferRow changeState(Identity actor, String equipo, long id, OfferStateRequest req) {
        return tx.write(actor, equipo, "COC.OFERTAS", () -> {
            OfferRow before = repo.get(id, true)
                .orElseThrow(() -> new AuthFailure(404, "Oferta no encontrada"));

            if (req.version() == null || !req.version().equals(before.version())) {
                throw new AuthFailure(409, "La oferta ha sido modificada por otro usuario. Vuelve a cargarla");
            }

            String targetState = req.estado();
            if (!"A".equals(targetState) && !"I".equals(targetState)) {
                throw new AuthFailure(400, "Estado inválido. Solo se admite 'A' o 'I'");
            }

            if (before.estadoLogico().equals(targetState)) {
                return before;
            }

            LocalDate hoy = today();
            if ("A".equals(targetState)) {
                if (before.fechaFin().isBefore(hoy)) {
                    throw new AuthFailure(400, "No se puede reactivar una oferta cuya fecha de fin ya expiró");
                }
                var pricing=repo.getPresentationPricing(before.presentacionId()).orElseThrow(()->new AuthFailure(404,"Presentación no encontrada"));
                if (!"A".equals(pricing.estadoProducto()) || !"A".equals(pricing.estadoPresentacion()) || !pricing.permiteVenta())
                    throw new AuthFailure(409,"La presentación ya no está disponible para venta");
                var price=new BigDecimal(before.precioOferta());
                if (price.compareTo(pricing.precioNormal())>=0 || (pricing.costo()!=null && price.compareTo(pricing.costo())<0))
                    throw new AuthFailure(409,"Revisa el precio regular y el costo de la presentación antes de reactivar");
                if (repo.hasOverlap(before.presentacionId(), id, before.fechaInicio(), before.fechaFin())) {
                    throw new AuthFailure(409, "Ya existe otra oferta activa para este producto y presentación en ese rango de fechas");
                }
            }

            repo.state(id, targetState);
            OfferRow result = repo.get(id, false).orElseThrow();
            event(actor, "A".equals(targetState) ? "OFERTA_REACTIVAR" : "OFERTA_INACTIVAR", id, before, result);
            return result;
        });
    }
}

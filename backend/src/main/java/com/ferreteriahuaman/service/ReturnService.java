package com.ferreteriahuaman.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.repository.ReturnRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

@Service
@Profile("db")
public class ReturnService {
    private final ReturnRepository repo;
    private final BusinessTransactions tx;
    private final ObjectMapper mapper;

    public ReturnService(ReturnRepository repo, BusinessTransactions tx, ObjectMapper mapper) {
        this.repo = repo;
        this.tx = tx;
        this.mapper = mapper;
    }

    private boolean isAdmin(Identity a) {
        return a != null && "ADM".equalsIgnoreCase(a.rol());
    }

    public Summary summary(Identity a) {
        Long solicitanteId = isAdmin(a) ? null : a.id();
        return repo.summary(solicitanteId);
    }

    public Page<ReturnRow> list(Identity a, String estado, String q, LocalDate desde, LocalDate hasta, int page, int size) {
        if (q != null && q.length() > 100 || page < 0 || page > 1000000 || size < 1 || size > 100
            || (desde != null && hasta != null && desde.isAfter(hasta))) {
            throw new AuthFailure(400, "Revisa los filtros y la paginación");
        }
        String cleanState = estado == null ? "" : estado.strip().toUpperCase(Locale.ROOT);
        if (!Set.of("", "TODAS", "PENDIENTE", "APROBADA", "RECHAZADA").contains(cleanState)) {
            throw new AuthFailure(400, "Estado de devolución no válido");
        }
        Long solicitanteId = isAdmin(a) ? null : a.id();
        return repo.list(cleanState, q != null ? q.strip() : null, desde, hasta, solicitanteId, page, size);
    }

    @org.springframework.transaction.annotation.Transactional(readOnly=true, isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public ReturnDetail detail(Identity a, long id) {
        ReturnDetail detail = repo.getDetail(id).orElseThrow(() -> new AuthFailure(404, "Devolución no encontrada"));
        if (!isAdmin(a) && detail.cabecera().solicitanteId() != null && detail.cabecera().solicitanteId() != a.id()) {
            throw new AuthFailure(403, "No tiene permisos para ver esta devolución");
        }
        return detail;
    }

    public List<SaleLookup> searchSales(Identity a, String termino) {
        int maxDays = repo.getReturnDays();
        return repo.searchSales(termino != null ? termino.strip() : "", maxDays);
    }

    @org.springframework.transaction.annotation.Transactional(readOnly=true, isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public SaleDetailLookup getSaleDetail(Identity a, long idVenta) {
        int maxDays = repo.getReturnDays();
        return repo.getSaleForReturn(idVenta, maxDays).orElseThrow(() -> new AuthFailure(404, "Venta no encontrada o no disponible para devolución"));
    }

    public Optional<CashOption> getTodayCash(Identity a) {
        return repo.getTodayCash();
    }

    public ReturnDetail solicitar(Identity a, String pc, SolicitRequest req) {
        if (req.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }
        if (req.ventaId() == null) {
            throw new AuthFailure(400, "Venta de origen obligatoria");
        }
        String forma = req.forma() == null ? "" : req.forma().strip().toUpperCase(Locale.ROOT);
        if (!Set.of("EFECTIVO", "YAPE", "DEBITO", "DESCUENTO_DEUDA").contains(forma)) {
            throw new AuthFailure(400, "Forma de reintegro no válida");
        }
        String motivo = req.motivo() == null ? null : req.motivo().strip();
        if (motivo == null || motivo.length() < 10 || motivo.length() > 200) {
            throw new AuthFailure(400, "El motivo debe contener entre 10 y 200 caracteres");
        }
        if (motivo.contains("<") || motivo.contains(">")) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }
        if (req.lineas() == null || req.lineas().isEmpty()) {
            throw new AuthFailure(400, "Debe seleccionar al menos un producto a devolver");
        }

        List<Map<String, Object>> serializedLines = new ArrayList<>();
        Set<Long> seenIds = new HashSet<>();
        for (ReturnItemRequest l : req.lineas()) {
            if (l.idDetalleVenta() == null) {
                throw new AuthFailure(400, "Línea de venta obligatoria");
            }
            if (seenIds.contains(l.idDetalleVenta())) {
                throw new AuthFailure(400, "No se puede repetir la misma línea de venta");
            }
            seenIds.add(l.idDetalleVenta());

            if (l.cantidad() == null || l.cantidad().compareTo(BigDecimal.ZERO) <= 0) {
                throw new AuthFailure(400, "La cantidad a devolver debe ser mayor a cero");
            }
            String estadoProd = l.estadoProducto() == null ? "" : l.estadoProducto().strip().toUpperCase(Locale.ROOT);
            if (!Set.of("APTO", "DANADO").contains(estadoProd)) {
                throw new AuthFailure(400, "Estado del producto debe ser APTO o DANADO");
            }

            Map<String, Object> itemMap = new HashMap<>();
            itemMap.put("id_detalle_venta", l.idDetalleVenta());
            itemMap.put("cantidad", l.cantidad());
            itemMap.put("estado_producto", estadoProd);
            itemMap.put("unidades", l.unidades() != null ? l.unidades() : List.of());
            serializedLines.add(itemMap);
        }

        String linesJson;
        try {
            linesJson = mapper.writeValueAsString(serializedLines);
        } catch (Exception e) {
            throw new AuthFailure(400, "Error al procesar las líneas de la devolución");
        }

        boolean autoAprobar = Boolean.TRUE.equals(req.autoAprobar());
        if (autoAprobar && !isAdmin(a)) {
            throw new AuthFailure(403, "Solo el administrador puede autorizar devoluciones de inmediato");
        }

        String ref = req.referencia() == null ? null : req.referencia().strip();
        if (ref != null && ref.isBlank()) ref = null;
        if (ref != null && ref.length() > 40) {
            throw new AuthFailure(400, "La referencia no puede exceder 40 caracteres");
        }

        String obs = req.observacion() == null ? null : req.observacion().strip();
        if (obs != null && obs.isBlank()) obs = null;
        if (obs != null && obs.length() > 300) {
            throw new AuthFailure(400, "La observación no puede superar 300 caracteres");
        }
        if (obs != null && (obs.contains("<") || obs.contains(">"))) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        final String finalRef = ref;
        final String finalObs = obs;
        try {
            return tx.write(a, pc, "VEN.DEVOLVER", () -> {
                String request = json(req);
                var replay = repo.replay(a.id(), "VEN.DEV_SOLICITAR_API", req.clave(), request);
                if (replay.isPresent()) return repo.getDetail(replay.get()).orElseThrow();
                Long id = repo.solicitarDevolucion(req.ventaId(), forma, motivo, linesJson, req.clave());
                if (autoAprobar) {
                    if (req.cajaId() == null) {
                        throw new AuthFailure(400, "Seleccione la caja abierta para autorizar el reintegro");
                    }
                    UUID claveAprobacion = UUID.nameUUIDFromBytes(("RETURN_APPROVE:"+req.clave()).getBytes(java.nio.charset.StandardCharsets.UTF_8));
                    repo.aprobarDevolucion(id, req.cajaId(), claveAprobacion, finalRef, finalObs);
                }
                repo.record(a.id(), "VEN.DEV_SOLICITAR_API", id, req.clave(), request);
                return repo.getDetail(id).orElseThrow();
            });
        } catch (DataAccessException ex) {
            handleSqlException(ex);
            throw ex;
        }
    }

    public ReturnDetail aprobar(Identity a, String pc, long id, ApproveRequest req) {
        if (!isAdmin(a)) {
            throw new AuthFailure(403, "Solo el administrador puede autorizar devoluciones");
        }
        if (req.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }
        if (req.cajaId() == null) {
            throw new AuthFailure(400, "Caja del día obligatoria para autorizar");
        }

        String ref = req.referencia() == null ? null : req.referencia().strip();
        if (ref != null && ref.isBlank()) ref = null;
        if (ref != null && ref.length() > 40) {
            throw new AuthFailure(400, "La referencia no puede exceder 40 caracteres");
        }

        String obs = req.observacion() == null ? null : req.observacion().strip();
        if (obs != null && obs.isBlank()) obs = null;
        if (obs != null && obs.length() > 300) {
            throw new AuthFailure(400, "La observación no puede superar 300 caracteres");
        }
        if (obs != null && (obs.contains("<") || obs.contains(">"))) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        final String finalRef = ref;
        final String finalObs = obs;
        try {
            return tx.write(a, pc, "VEN.DEVOLVER", () -> {
                String request = json(Map.of("id", id, "datos", req));
                var replay = repo.replay(a.id(), "VEN.DEV_APROBAR_API", req.clave(), request);
                if (replay.isPresent()) return repo.getDetail(replay.get()).orElseThrow();
                repo.aprobarDevolucion(id, req.cajaId(), req.clave(), finalRef, finalObs);
                repo.record(a.id(), "VEN.DEV_APROBAR_API", id, req.clave(), request);
                return repo.getDetail(id).orElseThrow();
            });
        } catch (DataAccessException ex) {
            handleSqlException(ex);
            throw ex;
        }
    }

    public ReturnDetail rechazar(Identity a, String pc, long id, RejectRequest req) {
        if (!isAdmin(a)) {
            throw new AuthFailure(403, "Solo el administrador puede rechazar devoluciones");
        }
        if (req.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }
        String motivo = req.motivo() == null ? null : req.motivo().strip();
        if (motivo == null || motivo.length() < 10 || motivo.length() > 200) {
            throw new AuthFailure(400, "El motivo de rechazo debe contener entre 10 y 200 caracteres");
        }
        if (motivo.contains("<") || motivo.contains(">")) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        final String finalMotivo = motivo;
        try {
            return tx.write(a, pc, "VEN.DEVOLVER", () -> {
                String request = json(Map.of("id", id, "datos", req));
                var replay = repo.replay(a.id(), "VEN.DEV_RECHAZAR_API", req.clave(), request);
                if (replay.isPresent()) return repo.getDetail(replay.get()).orElseThrow();
                repo.rechazarDevolucion(id, req.clave(), finalMotivo);
                repo.record(a.id(), "VEN.DEV_RECHAZAR_API", id, req.clave(), request);
                return repo.getDetail(id).orElseThrow();
            });
        } catch (DataAccessException ex) {
            handleSqlException(ex);
            throw ex;
        }
    }

    private String json(Object request) {
        try { return mapper.writeValueAsString(request); }
        catch (com.fasterxml.jackson.core.JsonProcessingException e) { throw new IllegalStateException("No se pudo preparar la operación", e); }
    }

    private void handleSqlException(DataAccessException ex) {
        Throwable cause = ex.getMostSpecificCause();
        String msg = cause.getMessage();
        if (msg != null) {
            if (msg.contains("Solo administrador aprueba devoluciones") ||
                msg.contains("Solo administrador rechaza devoluciones")) {
                throw new AuthFailure(403, msg);
            }
            if (msg.contains("Ya hay una solicitud pendiente para esta venta") ||
                msg.contains("Venta fuera del plazo de devolucion configurado") ||
                msg.contains("Venta fuera de plazo configurado") ||
                msg.contains("Devolucion acumulada supera cantidad vendida") ||
                msg.contains("No hay deuda suficiente para descontar") ||
                msg.contains("Saldo de deuda insuficiente") ||
                msg.contains("Reintegro monetario supera lo efectivamente cobrado") ||
                msg.contains("Reintegro supera dinero efectivamente cobrado") ||
                msg.contains("Reintegro de debito supera cobro de tarjeta disponible") ||
                msg.contains("Egreso supera saldo disponible") ||
                msg.contains("Caja abierta del dia requerida") ||
                msg.contains("Se requiere caja abierta del dia") ||
                msg.contains("Solicitud ya decidida") ||
                msg.contains("Verificar entrega fisica antes de aprobar devolucion") ||
                msg.contains("Clave usada con otra solicitud") ||
                msg.contains("Clave usada con otro rechazo") ||
                msg.contains("Clave usada con otra operacion")) {
                throw new AuthFailure(409, msg);
            }
            if (msg.contains("Datos de solicitud invalidos") ||
                msg.contains("Datos de rechazo invalidos") ||
                msg.contains("Datos de aprobacion invalidos") ||
                msg.contains("Referencia o datos de pago invalidos") ||
                msg.contains("Referencia de reintegro incompatible o faltante") ||
                msg.contains("Plan fisico invalido") ||
                msg.contains("Cantidad base no respeta precision fisica del producto")) {
                throw new AuthFailure(400, msg);
            }
        }
    }
}

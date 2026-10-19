package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.DispatchModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.repository.DispatchRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.time.LocalDate;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

@Service
@Profile("db")
public class DispatchService {
    private final DispatchRepository repo;
    private final BusinessTransactions tx;

    public DispatchService(DispatchRepository repo, BusinessTransactions tx) {
        this.repo = repo;
        this.tx = tx;
    }

    public Summary summary(Identity a) {
        return repo.summary();
    }

    public Page<DispatchRow> list(Identity a, String estado, String q, LocalDate desde, LocalDate hasta, int page, int size) {
        if (q.length() > 100 || page < 0 || page > 1000000 || size < 1 || size > 100
            || (desde != null && hasta != null && desde.isAfter(hasta))) {
            throw new AuthFailure(400, "Revisa los filtros y la paginación");
        }
        String cleanState = estado == null ? "" : estado.strip().toUpperCase(Locale.ROOT);
        if (!Set.of("", "TODOS", "PENDIENTE", "PREPARADO", "ENTREGADO", "ANULADO").contains(cleanState)) {
            throw new AuthFailure(400, "Estado de despacho no válido");
        }
        return repo.list(cleanState, q.strip(), desde, hasta, page, size);
    }

    public DispatchDetail detail(Identity a, long id) {
        return repo.getDetail(id).orElseThrow(() -> new AuthFailure(404, "Despacho no encontrado"));
    }

    public DispatchDetail preparar(Identity a, String pc, long id, PrepareRequest req) {
        if (req.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }
        String obs = req.observacion() == null ? null : req.observacion().strip();
        if (obs != null && obs.isBlank()) obs = null;
        if (obs != null && obs.length() > 300) {
            throw new AuthFailure(400, "La observación no puede superar 300 caracteres");
        }
        if (obs != null && (obs.contains("<") || obs.contains(">"))) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        final String finalObs = obs;
        try {
            return tx.write(a, pc, "DES.GESTIONAR", () -> {
                var row = repo.findById(id).orElseThrow(() -> new AuthFailure(404, "Despacho no encontrado"));
                if (!"PENDIENTE".equals(row.estado()) && !"PREPARADO".equals(row.estado())) {
                    throw new AuthFailure(409, "Este despacho ya no se encuentra pendiente");
                }
                repo.prepararDespacho(id, req.clave(), finalObs);
                return repo.getDetail(id).orElseThrow();
            });
        } catch (DataAccessException ex) {
            handleSqlException(ex);
            throw ex;
        }
    }

    public DispatchDetail entregar(Identity a, String pc, long id, DeliverRequest req) {
        if (req.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }
        String recibe = req.recibe() == null ? null : req.recibe().strip();
        if (recibe != null && recibe.isBlank()) recibe = null;
        if (recibe != null && recibe.length() > 100) {
            throw new AuthFailure(400, "El nombre de quien recibe no puede superar 100 caracteres");
        }
        if (recibe != null && (recibe.contains("<") || recibe.contains(">"))) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        String obs = req.observacion() == null ? null : req.observacion().strip();
        if (obs != null && obs.isBlank()) obs = null;
        if (obs != null && obs.length() > 300) {
            throw new AuthFailure(400, "La observación no puede superar 300 caracteres");
        }
        if (obs != null && (obs.contains("<") || obs.contains(">"))) {
            throw new AuthFailure(400, "Ingresar texto simple sin etiquetas HTML");
        }

        final String finalRecibe = recibe;
        final String finalObs = obs;
        try {
            return tx.write(a, pc, "DES.GESTIONAR", () -> {
                var row = repo.findById(id).orElseThrow(() -> new AuthFailure(404, "Despacho no encontrado"));
                if (!"PREPARADO".equals(row.estado()) && !"ENTREGADO".equals(row.estado())) {
                    throw new AuthFailure(409, "Primero marque el despacho como preparado");
                }
                repo.entregarDespacho(id, req.clave(), finalRecibe, finalObs);
                return repo.getDetail(id).orElseThrow();
            });
        } catch (DataAccessException ex) {
            handleSqlException(ex);
            throw ex;
        }
    }

    private void handleSqlException(DataAccessException ex) {
        Throwable cause = ex.getMostSpecificCause();
        String msg = cause.getMessage();
        if (msg != null) {
            if (msg.contains("Este despacho ya fue entregado por") ||
                msg.contains("Primero marque el despacho como preparado") ||
                msg.contains("Este despacho ya fue preparado") ||
                msg.contains("Clave de preparacion usada con otros datos") ||
                msg.contains("Clave de entrega usada con otros datos") ||
                msg.contains("Clave usada en otra operacion de despacho") ||
                msg.contains("Despacho no disponible para esta venta")) {
                throw new AuthFailure(409, msg);
            }
            if (msg.contains("Ingresar texto simple sin etiquetas HTML") ||
                msg.contains("Datos de despacho invalidos")) {
                throw new AuthFailure(400, msg);
            }
        }
    }
}

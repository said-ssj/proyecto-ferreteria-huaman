package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.CreditModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.repository.CashRepository;
import com.ferreteriahuaman.repository.CreditRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
@Profile("db")
public class CreditService {
    private final CreditRepository repo;
    private final CashRepository cash;
    private final BusinessTransactions tx;

    public CreditService(CreditRepository repo, CashRepository cash, BusinessTransactions tx) {
        this.repo = repo;
        this.cash = cash;
        this.tx = tx;
    }

    public Summary summary(Identity a) {
        return repo.summary();
    }

    public Page<Map<String, Object>> list(Identity a, String q, String estado, Boolean soloVencidas,
                                          LocalDate desde, LocalDate hasta, int page, int size) {
        if (q.length() > 100 || page < 0 || page > 1000000 || size < 1 || size > 100
            || (desde != null && hasta != null && desde.isAfter(hasta))) {
            throw new AuthFailure(400, "Revisa los filtros y la paginación");
        }
        String cleanState = estado == null ? "" : estado.strip();
        if (!Set.of("", "TODAS", "PENDIENTE", "VENCIDA", "CANCELADA", "ANULADA").contains(cleanState.toUpperCase(Locale.ROOT))) {
            throw new AuthFailure(400, "Estado de cuenta no válido");
        }
        return repo.list(q.strip(), cleanState, soloVencidas, desde, hasta, page, size);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public Statement statement(Identity a, long clienteId) {
        var cliente = repo.customerCredit(clienteId)
            .orElseThrow(() -> new AuthFailure(404, "Cliente no encontrado"));
        var cuentas = repo.customerAccounts(clienteId);
        var abonos = repo.customerPayments(clienteId);
        return new Statement(cliente, cuentas, abonos);
    }

    public Map<String, Object> options() {
        var c = cash.current();
        var result = new LinkedHashMap<String, Object>();
        result.put("fecha", c.fechaServidor());
        result.put("caja", c.caja() == null ? null : Map.of(
            "id", c.caja().id(),
            "fecha", c.caja().fecha(),
            "estado", c.caja().estado()
        ));
        return result;
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PaymentReceipt receipt(Identity a, long abonoId) {
        return repo.receipt(abonoId)
            .orElseThrow(() -> new AuthFailure(404, "Constancia de abono no encontrada"));
    }

    public PaymentReceipt registerPayment(Identity a, String pc, RegisterPayment i) {
        if (i.cuentaId() == null || i.cuentaId() <= 0) {
            throw new AuthFailure(400, "Cuenta por cobrar inválida");
        }
        if (i.monto() == null || i.monto().compareTo(BigDecimal.ZERO) <= 0 || i.monto().scale() > 2) {
            throw new AuthFailure(400, "El monto del abono debe ser mayor a 0 con hasta 2 decimales");
        }
        if (i.clave() == null) {
            throw new AuthFailure(400, "Clave de operación obligatoria");
        }

        String medio = (i.medio() == null ? "" : i.medio()).toUpperCase(Locale.ROOT);
        String ref = i.operacion() == null ? null : i.operacion().strip();
        if (ref != null && ref.isBlank()) ref = null;
        String marca = i.marca() == null ? null : i.marca().strip();
        if (marca != null && marca.isBlank()) marca = null;
        String ultimos = i.ultimosCuatro() == null ? null : i.ultimosCuatro().strip();
        if (ultimos != null && ultimos.isBlank()) ultimos = null;
        String obs = i.observacion() == null ? null : i.observacion().strip();
        if (obs != null && obs.isBlank()) obs = null;

        if (obs != null && obs.length() > 300) {
            throw new AuthFailure(400, "La observación no puede superar 300 caracteres");
        }

        switch (medio) {
            case "EFECTIVO" -> {
                if (ref != null || marca != null || ultimos != null) {
                    throw new AuthFailure(400, "Un abono en efectivo no admite número de operación ni datos de tarjeta");
                }
            }
            case "YAPE" -> {
                if (ref == null || !ref.matches("^[0-9]{6,20}$")) {
                    throw new AuthFailure(400, "El número de operación de Yape debe contener entre 6 y 20 dígitos numéricos");
                }
                if (marca != null || ultimos != null) {
                    throw new AuthFailure(400, "Yape no admite datos de tarjeta");
                }
            }
            case "DEBITO" -> {
                if (ref == null || ref.length() > 40) {
                    throw new AuthFailure(400, "El número de operación de débito es obligatorio (máximo 40 caracteres)");
                }
                if (marca != null && marca.length() > 30) {
                    throw new AuthFailure(400, "La marca de tarjeta no puede superar 30 caracteres");
                }
                if (ultimos != null && !ultimos.matches("^[0-9]{4}$")) {
                    throw new AuthFailure(400, "Los últimos dígitos de la tarjeta deben ser exactamente 4 números");
                }
            }
            default -> throw new AuthFailure(400, "Medio de pago no admitido. Usa Efectivo, Yape o Débito");
        }

        final String finalRef = ref;
        final String finalMarca = marca;
        final String finalUltimos = ultimos;
        final String finalObs = obs;

        return tx.write(a, pc, "CRE.ABONAR", () -> {
            repo.lockKey(i.clave());

            var replay = repo.replayPayment(a.id(), i.cuentaId(), i.monto(), medio, i.clave(), finalRef, finalMarca, finalUltimos, finalObs);
            if (replay.isPresent()) return repo.receipt(replay.get()).orElseThrow();
            var current = cash.current();
            if (current.caja() == null || !"ABIERTA".equals(current.caja().estado()) || !current.caja().fecha().equals(current.fechaServidor())) {
                throw new AuthFailure(409, "Abra la caja para registrar el abono");
            }
            long cajaId = current.caja().id();
            repo.lockCash(cajaId);

            var account = repo.getAccount(i.cuentaId(), true)
                .orElseThrow(() -> new AuthFailure(404, "Cuenta por cobrar no encontrada"));

            String estado = (String) account.get("estadoCuenta");
            BigDecimal saldo = new BigDecimal(account.get("saldo").toString());

            if (saldo.compareTo(BigDecimal.ZERO) <= 0 || !Set.of("PENDIENTE", "VENCIDA").contains(estado)) {
                throw new AuthFailure(409, "La cuenta ya no tiene deuda pendiente");
            }

            if (i.monto().compareTo(saldo) > 0) {
                throw new AuthFailure(400, "El abono supera el saldo (S/ " + saldo.setScale(2).toPlainString() + ")");
            }

            long abonoId = repo.registerPayment(
                i.cuentaId(),
                cajaId,
                i.monto(),
                medio,
                i.clave(),
                finalRef,
                finalMarca,
                finalUltimos,
                finalObs
            );

            return repo.receipt(abonoId)
                .orElseThrow(() -> new IllegalStateException("No se pudo generar la constancia del abono"));
        });
    }
}

package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.CreditModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.CreditService;
import java.time.LocalDate;
import java.util.Map;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("db")
@RequestMapping("/api/creditos")
public class CreditController {
    private final CreditService service;

    public CreditController(CreditService service) {
        this.service = service;
    }

    @GetMapping("/resumen")
    public Summary summary(@AuthenticationPrincipal Identity a) {
        return service.summary(a);
    }

    @GetMapping
    public Page<Map<String, Object>> list(
        @AuthenticationPrincipal Identity a,
        @RequestParam(defaultValue = "") String buscar,
        @RequestParam(defaultValue = "") String estado,
        @RequestParam(required = false) Boolean soloVencidas,
        @RequestParam(required = false) LocalDate desde,
        @RequestParam(required = false) LocalDate hasta,
        @RequestParam(defaultValue = "0") int pagina,
        @RequestParam(defaultValue = "20") int tamano
    ) {
        return service.list(a, buscar, estado, soloVencidas, desde, hasta, pagina, tamano);
    }

    @GetMapping("/opciones")
    public Map<String, Object> options() {
        return service.options();
    }

    @GetMapping("/clientes/{clienteId}/estado-cuenta")
    public Statement statement(@AuthenticationPrincipal Identity a, @PathVariable long clienteId) {
        return service.statement(a, clienteId);
    }

    @GetMapping("/abonos/{id}/constancia")
    public PaymentReceipt receipt(@AuthenticationPrincipal Identity a, @PathVariable long id) {
        return service.receipt(a, id);
    }

    @PostMapping("/abonos")
    public PaymentReceipt registerPayment(
        @AuthenticationPrincipal Identity a,
        @Valid @RequestBody RegisterPayment input,
        HttpServletRequest req
    ) {
        return service.registerPayment(a, req.getRemoteAddr(), input);
    }
}

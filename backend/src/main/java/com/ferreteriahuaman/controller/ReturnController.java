package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.ReturnService;
import java.time.LocalDate;
import java.util.List;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("db")
@RequestMapping("/api/devoluciones")
public class ReturnController {
    private final ReturnService service;

    public ReturnController(ReturnService service) {
        this.service = service;
    }

    private String pc(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].strip();
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr() : "LOCAL";
    }

    @GetMapping("/resumen")
    public Summary summary(@AuthenticationPrincipal Identity a) {
        return service.summary(a);
    }

    @GetMapping
    public Page<ReturnRow> list(
        @AuthenticationPrincipal Identity a,
        @RequestParam(defaultValue = "") String estado,
        @RequestParam(defaultValue = "") String buscar,
        @RequestParam(required = false) LocalDate desde,
        @RequestParam(required = false) LocalDate hasta,
        @RequestParam(defaultValue = "0") int pagina,
        @RequestParam(defaultValue = "20") int tamano
    ) {
        return service.list(a, estado, buscar, desde, hasta, pagina, tamano);
    }

    @GetMapping("/{id}")
    public ReturnDetail detail(@AuthenticationPrincipal Identity a, @PathVariable long id) {
        return service.detail(a, id);
    }

    @GetMapping("/ventas/buscar")
    public List<SaleLookup> searchSales(
        @AuthenticationPrincipal Identity a,
        @RequestParam(defaultValue = "") String termino
    ) {
        return service.searchSales(a, termino);
    }

    @GetMapping("/ventas/{idVenta}/items")
    public SaleDetailLookup getSaleDetail(
        @AuthenticationPrincipal Identity a,
        @PathVariable long idVenta
    ) {
        return service.getSaleDetail(a, idVenta);
    }

    @GetMapping("/opciones-caja")
    public CashOption getTodayCash(@AuthenticationPrincipal Identity a) {
        return service.getTodayCash(a).orElse(null);
    }

    @PostMapping("/solicitar")
    public ReturnDetail solicitar(
        @AuthenticationPrincipal Identity a,
        @Valid @RequestBody SolicitRequest req,
        HttpServletRequest request
    ) {
        return service.solicitar(a, pc(request), req);
    }

    @PostMapping("/{id}/aprobar")
    public ReturnDetail aprobar(
        @AuthenticationPrincipal Identity a,
        @PathVariable long id,
        @Valid @RequestBody ApproveRequest req,
        HttpServletRequest request
    ) {
        return service.aprobar(a, pc(request), id, req);
    }

    @PostMapping("/{id}/rechazar")
    public ReturnDetail rechazar(
        @AuthenticationPrincipal Identity a,
        @PathVariable long id,
        @Valid @RequestBody RejectRequest req,
        HttpServletRequest request
    ) {
        return service.rechazar(a, pc(request), id, req);
    }
}

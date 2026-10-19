package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.OfferModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.OfferService;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("db")
@RequestMapping("/api/ofertas")
public class OfferController {
    private final OfferService service;

    public OfferController(OfferService service) {
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
    public OfferSummary summary() {
        return service.summary();
    }

    @GetMapping
    public OfferListResponse list(
        @RequestParam(defaultValue = "") String buscar,
        @RequestParam(defaultValue = "") String estado,
        @RequestParam(required = false) Long categoriaId,
        @RequestParam(defaultValue = "0") int pagina,
        @RequestParam(defaultValue = "20") int tamano
    ) {
        return service.list(buscar, estado, categoriaId, pagina, tamano);
    }

    @GetMapping("/{id}")
    public OfferRow get(@PathVariable long id) {
        return service.get(id);
    }

    @GetMapping("/productos-disponibles")
    public List<ProductPresentationOption> availableProducts(
        @RequestParam(defaultValue = "") String buscar
    ) {
        return service.searchAvailableProducts(buscar);
    }

    @PostMapping
    public OfferRow create(
        @AuthenticationPrincipal Identity actor,
        @jakarta.validation.Valid @RequestBody OfferCreateRequest req,
        HttpServletRequest request
    ) {
        return service.create(actor, pc(request), req);
    }

    @PutMapping("/{id}")
    public OfferRow update(
        @AuthenticationPrincipal Identity actor,
        @PathVariable long id,
        @jakarta.validation.Valid @RequestBody OfferUpdateRequest req,
        HttpServletRequest request
    ) {
        return service.update(actor, pc(request), id, req);
    }

    @PatchMapping("/{id}/estado")
    public OfferRow changeState(
        @AuthenticationPrincipal Identity actor,
        @PathVariable long id,
        @jakarta.validation.Valid @RequestBody OfferStateRequest req,
        HttpServletRequest request
    ) {
        return service.changeState(actor, pc(request), id, req);
    }
}

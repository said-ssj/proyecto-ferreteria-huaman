package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.DispatchModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.DispatchService;
import java.time.LocalDate;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("db")
@RequestMapping("/api/despachos")
public class DispatchController {
    private final DispatchService service;

    public DispatchController(DispatchService service) {
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
    public Page<DispatchRow> list(
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
    public DispatchDetail detail(@AuthenticationPrincipal Identity a, @PathVariable long id) {
        return service.detail(a, id);
    }

    @PostMapping("/{id}/preparar")
    public DispatchDetail preparar(
        @AuthenticationPrincipal Identity a,
        @PathVariable long id,
        @Valid @RequestBody PrepareRequest req,
        HttpServletRequest request
    ) {
        return service.preparar(a, pc(request), id, req);
    }

    @PostMapping("/{id}/entregar")
    public DispatchDetail entregar(
        @AuthenticationPrincipal Identity a,
        @PathVariable long id,
        @Valid @RequestBody DeliverRequest req,
        HttpServletRequest request
    ) {
        return service.entregar(a, pc(request), id, req);
    }
}

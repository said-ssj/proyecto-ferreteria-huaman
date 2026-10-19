package com.ferreteriahuaman.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.repository.ReturnRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class ReturnServiceTest {
    ReturnRepository repo = mock(ReturnRepository.class);
    BusinessTransactions tx = mock(BusinessTransactions.class);
    ObjectMapper mapper = new ObjectMapper();
    ReturnService service = new ReturnService(repo, tx, mapper);

    Identity admin = new Identity(1, "admin", "Admin", "User", "ADM", false, Set.of("VEN.DEVOLVER"), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30));
    Identity vendedor = new Identity(2, "vendedor", "Vendedor", "User", "VEN", false, Set.of("VEN.DEVOLVER"), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30));

    @Test
    void rejectsInvalidFiltersBeforeQuery() {
        assertThatThrownBy(() -> service.list(admin, "ESTADO_INEXISTENTE", "", null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(admin, "", "", LocalDate.of(2026, 2, 1), LocalDate.of(2026, 1, 1), 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(admin, "", "", null, null, -1, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(admin, "", "", null, null, 0, 101))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(admin, "", "a".repeat(101), null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        verifyNoInteractions(repo);
    }

    @Test
    void validatesSolicitarInput() {
        // Null clave
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "Motivo de prueba con más de diez caracteres", List.of(), null, false, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Motivo too short
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "Corto", List.of(), UUID.randomUUID(), false, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Motivo with HTML
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "<script>alert(1)</script>", List.of(), UUID.randomUUID(), false, null, null, null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("HTML");

        // Invalid forma
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "BITCOIN", "Motivo de prueba con más de diez caracteres", List.of(), UUID.randomUUID(), false, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Empty lines
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "Motivo de prueba con más de diez caracteres", List.of(), UUID.randomUUID(), false, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Quantity <= 0
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "Motivo de prueba con más de diez caracteres", List.of(new ReturnItemRequest(10L, BigDecimal.ZERO, "APTO", List.of())), UUID.randomUUID(), false, null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Non-admin cannot auto-approve
        assertThatThrownBy(() -> service.solicitar(vendedor, "127.0.0.1", new SolicitRequest(1L, "EFECTIVO", "Motivo de prueba con más de diez caracteres", List.of(new ReturnItemRequest(10L, BigDecimal.ONE, "APTO", List.of())), UUID.randomUUID(), true, 1L, null, null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("administrador");
    }

    @Test
    void nonAdminCannotApproveOrReject() {
        assertThatThrownBy(() -> service.aprobar(vendedor, "127.0.0.1", 1L, new ApproveRequest(1L, UUID.randomUUID(), null, null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("administrador");

        assertThatThrownBy(() -> service.rechazar(vendedor, "127.0.0.1", 1L, new RejectRequest(UUID.randomUUID(), "Motivo de rechazo de prueba")))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("administrador");
    }
}

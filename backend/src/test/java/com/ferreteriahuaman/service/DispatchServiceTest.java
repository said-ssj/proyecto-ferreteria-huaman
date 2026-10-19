package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.DispatchModels.*;
import com.ferreteriahuaman.repository.DispatchRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class DispatchServiceTest {
    DispatchRepository repo = mock(DispatchRepository.class);
    BusinessTransactions tx = mock(BusinessTransactions.class);
    DispatchService service = new DispatchService(repo, tx);
    Identity actor = new Identity(1, "usuario", "Nombre", "Apellido", "ALM", false, Set.of("DES.VER", "DES.GESTIONAR"), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30));

    @Test
    void rejectsInvalidFiltersBeforeQuery() {
        assertThatThrownBy(() -> service.list(actor, "ESTADO_INEXISTENTE", "", null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "", LocalDate.of(2026, 2, 1), LocalDate.of(2026, 1, 1), 0, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "", null, null, -1, 20))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "", null, null, 0, 101))
            .isInstanceOf(AuthFailure.class);
        assertThatThrownBy(() -> service.list(actor, "", "a".repeat(101), null, null, 0, 20))
            .isInstanceOf(AuthFailure.class);
        verifyNoInteractions(repo);
    }

    @Test
    void validatesPrepareInput() {
        // Null clave
        assertThatThrownBy(() -> service.preparar(actor, "127.0.0.1", 1L, new PrepareRequest(null, null)))
            .isInstanceOf(AuthFailure.class);

        // HTML tags in observation
        assertThatThrownBy(() -> service.preparar(actor, "127.0.0.1", 1L, new PrepareRequest(UUID.randomUUID(), "<script>alert(1)</script>")))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("HTML");

        // Observation too long
        assertThatThrownBy(() -> service.preparar(actor, "127.0.0.1", 1L, new PrepareRequest(UUID.randomUUID(), "x".repeat(301))))
            .isInstanceOf(AuthFailure.class);
    }

    @Test
    void validatesDeliverInput() {
        // Null clave
        assertThatThrownBy(() -> service.entregar(actor, "127.0.0.1", 1L, new DeliverRequest(null, null, null)))
            .isInstanceOf(AuthFailure.class);

        // Recibe too long
        assertThatThrownBy(() -> service.entregar(actor, "127.0.0.1", 1L, new DeliverRequest(UUID.randomUUID(), "r".repeat(101), null)))
            .isInstanceOf(AuthFailure.class);

        // HTML tags in recibe
        assertThatThrownBy(() -> service.entregar(actor, "127.0.0.1", 1L, new DeliverRequest(UUID.randomUUID(), "<b>Juan</b>", null)))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("HTML");

        // HTML tags in observation
        assertThatThrownBy(() -> service.entregar(actor, "127.0.0.1", 1L, new DeliverRequest(UUID.randomUUID(), "Juan", "<tag>")))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("HTML");

        // Observation too long
        assertThatThrownBy(() -> service.entregar(actor, "127.0.0.1", 1L, new DeliverRequest(UUID.randomUUID(), "Juan", "o".repeat(301))))
            .isInstanceOf(AuthFailure.class);
    }
}

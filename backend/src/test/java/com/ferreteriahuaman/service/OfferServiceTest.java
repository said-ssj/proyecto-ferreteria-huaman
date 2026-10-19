package com.ferreteriahuaman.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.dto.OfferModels.*;
import com.ferreteriahuaman.repository.CatalogRepository;
import com.ferreteriahuaman.repository.OfferRepository;
import com.ferreteriahuaman.repository.OfferRepository.PresentationPricing;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class OfferServiceTest {
    OfferRepository repo = mock(OfferRepository.class);
    CatalogRepository catalog = mock(CatalogRepository.class);
    BusinessTransactions tx = mock(BusinessTransactions.class);
    ObjectMapper mapper = new ObjectMapper();
    Clock clock = Clock.fixed(Instant.parse("2026-10-18T10:00:00Z"), ZoneId.of("America/Lima"));
    OfferService service;

    Identity admin = new Identity(1, "admin", "Admin", "User", "ADM", false, Set.of("COC.OFERTAS"), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30));

    @BeforeEach
    void setup() {
        reset(repo, catalog, tx);
        service = new OfferService(repo, catalog, tx, mapper, clock);
        when(tx.write(any(), anyString(), anyString(), any())).thenAnswer(call -> ((Supplier<?>) call.getArgument(3)).get());
    }

    @Test
    void rejectsInvalidPagingAndName() {
        assertThatThrownBy(() -> service.list("", "", null, -1, 20))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("paginación");

        assertThatThrownBy(() -> service.list("", "", null, 0, 101))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("paginación");

        // Name with HTML
        OfferCreateRequest reqWithHtml = new OfferCreateRequest(
            1L, 1L, "<script>oferta</script>", new BigDecimal("25.00"),
            LocalDate.of(2026, 10, 18), LocalDate.of(2026, 10, 25)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqWithHtml))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("HTML");

        // Name too short
        OfferCreateRequest reqShort = new OfferCreateRequest(
            1L, 1L, "AB", new BigDecimal("25.00"),
            LocalDate.of(2026, 10, 18), LocalDate.of(2026, 10, 25)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqShort))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("3 y 80 caracteres");
    }

    @Test
    void validatesCreateOfferBusinessRules() {
        LocalDate hoy = LocalDate.of(2026, 10, 18);

        // Date in past
        OfferCreateRequest reqPast = new OfferCreateRequest(
            1L, 1L, "Oferta Pasada", new BigDecimal("25.00"),
            LocalDate.of(2026, 10, 10), LocalDate.of(2026, 10, 20)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqPast))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("anterior a hoy");

        // End before start
        OfferCreateRequest reqEndBeforeStart = new OfferCreateRequest(
            1L, 1L, "Oferta Fin Menor", new BigDecimal("25.00"),
            LocalDate.of(2026, 10, 20), LocalDate.of(2026, 10, 19)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqEndBeforeStart))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("anterior a la fecha de inicio");

        // Pricing: presentation regular price = 30.00, cost = 20.00
        when(repo.getPresentationPricing(1L)).thenReturn(Optional.of(new PresentationPricing(
            1L, 1L, new BigDecimal("30.00"), true, "A", "A", new BigDecimal("20.00")
        )));

        // Price >= regular
        OfferCreateRequest reqHighPrice = new OfferCreateRequest(
            1L, 1L, "Oferta Cara", new BigDecimal("30.00"),
            hoy, LocalDate.of(2026, 10, 25)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqHighPrice))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("menor al precio regular");

        // Price < cost
        OfferCreateRequest reqBelowCost = new OfferCreateRequest(
            1L, 1L, "Oferta Bajo Costo", new BigDecimal("15.00"),
            hoy, LocalDate.of(2026, 10, 25)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqBelowCost))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("menor al costo");

        // Overlapping offer
        when(repo.hasOverlap(1L, null, hoy, LocalDate.of(2026, 10, 25))).thenReturn(true);
        OfferCreateRequest reqOverlap = new OfferCreateRequest(
            1L, 1L, "Oferta Solapada", new BigDecimal("25.00"),
            hoy, LocalDate.of(2026, 10, 25)
        );
        assertThatThrownBy(() -> service.create(admin, "127.0.0.1", reqOverlap))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("solapa");
    }

    @Test
    void validatesUpdateAndStateChanges() {
        LocalDate hoy = LocalDate.of(2026, 10, 18);

        OfferRow expiredRow = new OfferRow(
            1L, "Oferta Expirada", 1L, "COD-1", "Prod 1", 1L, "Cat", 1L, "Unidad", "NIU",
            "30.00", "25.00", "16.67", "20.00",
            LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 10), "I", "INACTIVA", LocalDateTime.now()
        );
        when(repo.get(1L, true)).thenReturn(Optional.of(expiredRow));

        // Cannot update inactive
        assertThatThrownBy(() -> service.update(admin, "127.0.0.1", 1L, new OfferUpdateRequest(
            "Nuevo Nombre", new BigDecimal("24.00"), null, LocalDate.of(2026, 10, 30), expiredRow.version()
        ))).isInstanceOf(AuthFailure.class)
          .hasMessageContaining("inactiva");

        // Cannot reactivate expired
        assertThatThrownBy(() -> service.changeState(admin, "127.0.0.1", 1L, new OfferStateRequest("A", expiredRow.version())))
            .isInstanceOf(AuthFailure.class)
            .hasMessageContaining("ya expiró");

        OfferRow activeRow = new OfferRow(
            2L, "Oferta Activa", 1L, "COD-1", "Prod 1", 1L, "Cat", 1L, "Unidad", "NIU",
            "30.00", "25.00", "16.67", "20.00",
            LocalDate.of(2026, 10, 15), LocalDate.of(2026, 10, 25), "A", "VIGENTE", LocalDateTime.now()
        );
        when(repo.get(2L, true)).thenReturn(Optional.of(activeRow));

        // On active offer, end date cannot be in past
        assertThatThrownBy(() -> service.update(admin, "127.0.0.1", 2L, new OfferUpdateRequest(
            "Oferta Activa Editada", new BigDecimal("24.00"), null, LocalDate.of(2026, 10, 16), activeRow.version()
        ))).isInstanceOf(AuthFailure.class)
          .hasMessageContaining("anterior a hoy");
    }
}

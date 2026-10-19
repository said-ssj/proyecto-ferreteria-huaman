package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.OfferController;
import com.ferreteriahuaman.dto.OfferModels.*;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.service.OfferService;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(OfferController.class)
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class, SecurityConfig.class, ApiExceptionHandler.class})
class OfferApiTest {
    @Autowired MockMvc mvc;
    @MockBean AuthService auth;
    @MockBean OfferService service;

    void login(String role, String... permissions) {
        when(auth.authenticate(anyString(), anyString())).thenReturn(
            new Identity(1, "prueba", "Nombre", "Apellido", role, false, Set.of(permissions), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30))
        );
    }

    @Test
    void anonymousCannotAccessOffers() throws Exception {
        mvc.perform(get("/api/ofertas")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/ofertas/resumen")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/ofertas")).andExpect(status().isUnauthorized());
    }

    @Test
    void userWithoutCocOfertasIsForbidden() throws Exception {
        login("VEN", "VEN.VENDER", "VEN.HISTORIAL");
        mvc.perform(get("/api/ofertas").header("Authorization", "Bearer test"))
            .andExpect(status().isForbidden());

        mvc.perform(post("/api/ofertas")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
            .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void authorizedUserCanAccessOffers() throws Exception {
        login("ADM", "COC.OFERTAS");
        when(service.summary()).thenReturn(new OfferSummary(2, 1, 0, 0));
        when(service.list(any(), any(), any(), anyInt(), anyInt()))
            .thenReturn(new OfferListResponse(List.of(), 0, 0, 20));

        mvc.perform(get("/api/ofertas/resumen").header("Authorization", "Bearer test"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.vigentes").value(2));

        mvc.perform(get("/api/ofertas").header("Authorization", "Bearer test"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void createAndUpdateEndpointsExecuteWithPermission() throws Exception {
        login("ADM", "COC.OFERTAS");
        OfferRow sampleRow = new OfferRow(
            1L, "Super Oferta", 1L, "TAL-001", "Taladro", 1L, "Herramientas", 1L, "Unidad", "NIU",
            "100.00", "80.00", "20.00", "50.00",
            LocalDate.of(2026, 10, 18), LocalDate.of(2026, 10, 25), "A", "VIGENTE", LocalDateTime.now()
        );

        when(service.create(any(), any(), any())).thenReturn(sampleRow);
        when(service.update(any(), any(), eq(1L), any())).thenReturn(sampleRow);
        when(service.changeState(any(), any(), eq(1L), any())).thenReturn(sampleRow);

        String createJson = """
            {
              "productoId": 1,
              "presentacionId": 1,
              "nombre": "Super Oferta",
              "precioOferta": 80.00,
              "fechaInicio": "2026-10-18",
              "fechaFin": "2026-10-25"
            }
            """;

        mvc.perform(post("/api/ofertas")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(createJson))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.nombre").value("Super Oferta"));

        String updateJson = """
            {
              "nombre": "Super Oferta Actualizada",
              "precioOferta": 75.00,
              "fechaFin": "2026-10-28",
              "version": "2026-10-18T10:00:00"
            }
            """;

        mvc.perform(put("/api/ofertas/1")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(updateJson))
            .andExpect(status().isOk());

        String stateJson = """
            {
              "estado": "I",
              "version": "2026-10-18T10:00:00"
            }
            """;

        mvc.perform(patch("/api/ofertas/1/estado")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(stateJson))
            .andExpect(status().isOk());
    }
    @Test void missingVersionCannotBypassConcurrencyChecks() throws Exception {
        login("ADM","COC.OFERTAS");
        mvc.perform(put("/api/ofertas/1").header("Authorization","Bearer test").contentType(MediaType.APPLICATION_JSON).content("{\"nombre\":\"Oferta nueva\",\"precioOferta\":20,\"fechaFin\":\"2026-10-28\"}")).andExpect(status().isBadRequest());
        mvc.perform(patch("/api/ofertas/1/estado").header("Authorization","Bearer test").contentType(MediaType.APPLICATION_JSON).content("{\"estado\":\"I\"}")).andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

}

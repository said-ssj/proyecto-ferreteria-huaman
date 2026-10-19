package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.DispatchController;
import com.ferreteriahuaman.dto.DispatchModels.*;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.service.DispatchService;
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

@WebMvcTest(DispatchController.class)
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class, SecurityConfig.class, ApiExceptionHandler.class})
class DispatchApiTest {
    @Autowired MockMvc mvc;
    @MockBean AuthService auth;
    @MockBean DispatchService service;

    void login(String... permissions) {
        when(auth.authenticate(anyString(), anyString())).thenReturn(
            new Identity(1, "prueba", "Nombre", "Apellido", "ALM", false, Set.of(permissions), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30))
        );
    }

    @Test
    void anonymousCannotReadDispatches() throws Exception {
        mvc.perform(get("/api/despachos")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/despachos/resumen")).andExpect(status().isUnauthorized());
    }

    @Test
    void unrelatedRoleDoesNotGrantDispatchAccess() throws Exception {
        login("VEN.VENDER");
        mvc.perform(get("/api/despachos").header("Authorization", "Bearer test"))
            .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void viewingRequiresDesVer() throws Exception {
        login("DES.VER");
        mvc.perform(get("/api/despachos").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/despachos/resumen").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
    }

    @Test
    void viewingOnlyCannotPrepareOrDeliver() throws Exception {
        login("DES.VER");
        String body = """
            {"clave":"%s","observacion":"Listo"}
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/despachos/1/preparar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
            .andExpect(status().isForbidden());

        mvc.perform(post("/api/despachos/1/entregar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(body))
            .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void managingPermissionPermitsPreparingAndDelivering() throws Exception {
        login("DES.GESTIONAR", "DES.VER");
        DispatchRow row = new DispatchRow(
            1L, 1L, "DP-000001", 101L, "B001-00000045", "B",
            "Juan Perez", "12345678", "2026-10-18 10:00:00",
            "PREPARADO", 2, "Almacenero", "2026-10-18 10:30:00",
            null, null, null, null, null, "2026-10-18T10:00:00"
        );
        DispatchDetail detail = new DispatchDetail(row, List.of(), "Vendedor", java.math.BigDecimal.TEN, null);

        when(service.preparar(any(), any(), eq(1L), any())).thenReturn(detail);
        when(service.entregar(any(), any(), eq(1L), any())).thenReturn(detail);

        String prepareBody = """
            {"clave":"%s","observacion":"Listo"}
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/despachos/1/preparar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(prepareBody))
            .andExpect(status().isOk());

        String deliverBody = """
            {"clave":"%s","recibe":"Juan Perez","observacion":"Entregado"}
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/despachos/1/entregar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content(deliverBody))
            .andExpect(status().isOk());
    }

    @Test
    void prepareRequiresKey() throws Exception {
        login("DES.GESTIONAR");
        mvc.perform(post("/api/despachos/1/preparar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void deliverRequiresKey() throws Exception {
        login("DES.GESTIONAR");
        mvc.perform(post("/api/despachos/1/entregar")
            .header("Authorization", "Bearer test")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{}"))
            .andExpect(status().isBadRequest());
    }
}

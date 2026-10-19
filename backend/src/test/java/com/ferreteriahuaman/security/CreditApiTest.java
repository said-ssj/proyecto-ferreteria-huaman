package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.CreditController;
import com.ferreteriahuaman.dto.CreditModels.*;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.service.CreditService;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CreditController.class)
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class, SecurityConfig.class, ApiExceptionHandler.class})
class CreditApiTest {
    @Autowired MockMvc mvc;
    @MockBean AuthService auth;
    @MockBean CreditService service;

    void login(String... permissions) {
        when(auth.authenticate(anyString(), anyString())).thenReturn(
            new Identity(1, "prueba", "Nombre", "Apellido", "VEN", false, Set.of(permissions), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30))
        );
    }

    @Test
    void anonymousCannotReadCredits() throws Exception {
        mvc.perform(get("/api/creditos")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/creditos/resumen")).andExpect(status().isUnauthorized());
    }

    @Test
    void sellingAloneDoesNotGrantCreditAccess() throws Exception {
        login("VEN.VENDER");
        mvc.perform(get("/api/creditos").header("Authorization", "Bearer test"))
            .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void viewingRequiresCreVer() throws Exception {
        login("CRE.VER");
        mvc.perform(get("/api/creditos").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/creditos/resumen").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
    }

    @Test
    void registeringPaymentRequiresCreAbonar() throws Exception {
        login("CRE.VER");
        String payload = """
            {
              "cuentaId": 1,
              "monto": 50.00,
              "medio": "EFECTIVO",
              "clave": "550e8400-e29b-41d4-a716-446655440000"
            }
            """;
        mvc.perform(post("/api/creditos/abonos").header("Authorization", "Bearer test")
            .contentType("application/json").content(payload))
            .andExpect(status().isForbidden());
        verify(service, never()).registerPayment(any(), any(), any());
    }

    @Test
    void invalidPaymentBodyIsRejectedWithBadRequest() throws Exception {
        login("CRE.ABONAR");
        // Invalid amount
        String payload = """
            {
              "cuentaId": 1,
              "monto": -10.00,
              "medio": "EFECTIVO",
              "clave": "550e8400-e29b-41d4-a716-446655440000"
            }
            """;
        mvc.perform(post("/api/creditos/abonos").header("Authorization", "Bearer test")
            .contentType("application/json").content(payload))
            .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

    @Test
    void creditsHaveNoPhysicalDelete() throws Exception {
        login("CRE.VER", "CRE.ABONAR");
        mvc.perform(delete("/api/creditos/1").header("Authorization", "Bearer test"))
            .andExpect(status().isForbidden());
    }
}

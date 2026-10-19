package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.ReturnController;
import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.service.ReturnService;
import java.math.BigDecimal;
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

@WebMvcTest(ReturnController.class)
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class, SecurityConfig.class, ApiExceptionHandler.class})
class ReturnApiTest {
    @Autowired MockMvc mvc;
    @MockBean AuthService auth;
    @MockBean ReturnService service;

    void login(String role, String... permissions) {
        when(auth.authenticate(anyString(), anyString())).thenReturn(
            new Identity(1, "prueba", "Nombre", "Apellido", role, false, Set.of(permissions), UUID.randomUUID(), OffsetDateTime.now().plusMinutes(30))
        );
    }

    @Test
    void anonymousCannotAccessReturns() throws Exception {
        mvc.perform(get("/api/devoluciones")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/devoluciones/resumen")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/devoluciones/solicitar")).andExpect(status().isUnauthorized());
    }

    @Test
    void unrelatedRoleDoesNotGrantReturnAccess() throws Exception {
        login("ALM", "INV.VER");
        mvc.perform(get("/api/devoluciones").header("Authorization", "Bearer test"))
            .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void viewingRequiresVenDevolver() throws Exception {
        login("VEN", "VEN.DEVOLVER");
        when(service.list(any(), any(), any(), any(), any(), anyInt(), anyInt()))
            .thenReturn(new Page<>(List.of(), 0, 0, 20));
        when(service.summary(any()))
            .thenReturn(new Summary(0, 0, BigDecimal.ZERO));

        mvc.perform(get("/api/devoluciones").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
        mvc.perform(get("/api/devoluciones/resumen").header("Authorization", "Bearer test"))
            .andExpect(status().isOk());
    }

    @Test
    void solicitRequestAcceptedForVendor() throws Exception {
        login("VEN", "VEN.DEVOLVER");
        when(service.solicitar(any(), any(), any())).thenReturn(
            new ReturnDetail(
                new ReturnRow(1L, "DV-000001", 10L, "B001-00000001", "BOLETA", "Cliente", "12345678", "2026-10-18 10:00:00", "PENDIENTE", "EFECTIVO", new BigDecimal("50.00"), "Motivo prueba", 1L, "Vendedor", null, null, null, null, null, null, 1),
                List.of()
            )
        );

        String json = """
            {
              "ventaId": 10,
              "forma": "EFECTIVO",
              "motivo": "Producto defectuoso detectado en tienda",
              "clave": "%s",
              "lineas": [
                {
                  "idDetalleVenta": 101,
                  "cantidad": 1.0,
                  "estadoProducto": "APTO"
                }
              ]
            }
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/devoluciones/solicitar")
                .header("Authorization", "Bearer test")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.cabecera.estadoDevolucion").value("PENDIENTE"));
    }

    @Test
    void nonAdminFailsToApprove() throws Exception {
        login("VEN", "VEN.DEVOLVER");
        when(service.aprobar(any(), any(), anyLong(), any()))
            .thenThrow(new AuthFailure(403, "Solo el administrador puede autorizar devoluciones"));

        String json = """
            {
              "cajaId": 1,
              "clave": "%s"
            }
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/devoluciones/1/aprobar")
                .header("Authorization", "Bearer test")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isForbidden());
    }

    @Test
    void adminCanApprove() throws Exception {
        login("ADM", "VEN.DEVOLVER");
        when(service.aprobar(any(), any(), anyLong(), any())).thenReturn(
            new ReturnDetail(
                new ReturnRow(1L, "DV-000001", 10L, "B001-00000001", "BOLETA", "Cliente", "12345678", "2026-10-18 10:00:00", "APROBADA", "EFECTIVO", new BigDecimal("50.00"), "Motivo prueba", 2L, "Vendedor", 1L, "Admin", "2026-10-18 10:30:00", null, 1L, "Aprobado", 1),
                List.of()
            )
        );

        String json = """
            {
              "cajaId": 1,
              "clave": "%s"
            }
            """.formatted(UUID.randomUUID());

        mvc.perform(post("/api/devoluciones/1/aprobar")
                .header("Authorization", "Bearer test")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.cabecera.estadoDevolucion").value("APROBADA"));
    }
    @Test void returnDetailsDoNotExposeCostsAndPreserveDecimalStrings() throws Exception {
        login("VEN","VEN.DEVOLVER");
        var item=new ReturnItem(1L,2L,3L,"PR-1","Producto",4L,"Bolsa","KGM",new BigDecimal("50"),BigDecimal.ONE,"APTO",BigDecimal.TEN,"[]");
        when(service.detail(any(),eq(1L))).thenReturn(new ReturnDetail(null,List.of(item)));
        mvc.perform(get("/api/devoluciones/1").header("Authorization","Bearer test"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.items[0].costoUnitarioBase").doesNotExist())
            .andExpect(jsonPath("$.items[0].factorBase").isString());
    }

}

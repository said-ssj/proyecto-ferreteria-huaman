package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.AuthController;
import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import com.ferreteriahuaman.security.AuthModels.*;
import java.time.OffsetDateTime;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers=AuthController.class,properties="app.cors.allowed-origins=http://localhost:4200")
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class AuthApiTest {
    @Autowired MockMvc mvc;@MockBean AuthService service;
    Identity identity(Set<String> permissions){return new Identity(1,"operador","Nombre","Apellido","VEN",false,permissions,UUID.randomUUID(),OffsetDateTime.parse("2026-10-17T12:30:00-05:00"));}
    @Test void missingTokenGets401WithoutCookie()throws Exception{mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized()).andExpect(header().doesNotExist("Set-Cookie"));}
    @Test void badTokenGets401()throws Exception{when(service.authenticate(anyString(),anyString())).thenThrow(AuthFailure.expired());mvc.perform(get("/api/auth/me").header("Authorization","Bearer incorrecto")).andExpect(status().isUnauthorized());}
    @Test void basicCredentialsAreNotAccepted()throws Exception{mvc.perform(get("/api/auth/me").header("Authorization","Basic dXNlcjpwYXNz")).andExpect(status().isUnauthorized());}
    @Test void profileOmitsSessionIdentifierAndSecrets()throws Exception{when(service.authenticate(anyString(),anyString())).thenReturn(identity(Set.of("SEG.PERFIL")));
        mvc.perform(get("/api/auth/me").header("Authorization","Bearer token")).andExpect(status().isOk()).andExpect(jsonPath("$.usuario").value("operador")).andExpect(jsonPath("$.sessionToken").doesNotExist()).andExpect(jsonPath("$.hash").doesNotExist()).andExpect(header().string("Cache-Control","no-store"));}
    @Test void missingPermissionGets403()throws Exception{when(service.authenticate(anyString(),anyString())).thenReturn(identity(Set.of()));
        mvc.perform(put("/api/auth/clave").header("Authorization","Bearer token").contentType("application/json").content("{}"))
            .andExpect(status().isForbidden());verify(service,never()).changePassword(any(),any(),any());}
    @Test void invalidLoginBodyGets400WithoutCallingService()throws Exception{mvc.perform(post("/api/auth/login").contentType("application/json").content("{}"))
        .andExpect(status().isBadRequest());verify(service,never()).login(any(),any());}
    @Test void failedLoginGets401()throws Exception{when(service.login(any(),any())).thenReturn(new LoginResult(null,AuthFailure.credentials()));
        mvc.perform(post("/api/auth/login").contentType("application/json").content("{\"usuario\":\"operador\",\"clave\":\"Clave1234\"}"))
            .andExpect(status().isUnauthorized());}
    @Test void successfulLoginIssuesTokenWithNoCaching()throws Exception{var profile=UserProfile.of(identity(Set.of("SEG.PERFIL")));
        when(service.login(any(),any())).thenReturn(new LoginResult(new LoginResponse("token","Bearer",profile),null));
        mvc.perform(post("/api/auth/login").contentType("application/json").content("{\"usuario\":\"operador\",\"clave\":\"Clave1234\"}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.tokenType").value("Bearer")).andExpect(header().string("Cache-Control","no-store"));}
}

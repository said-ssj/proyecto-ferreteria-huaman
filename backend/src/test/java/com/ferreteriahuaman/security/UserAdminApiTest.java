package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.UserAdminController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import java.time.*;import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(UserAdminController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class UserAdminApiTest{
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean UserAdminService service;
 void login(String...p){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"admin.test","N","A","ADM",false,Set.of(p),UUID.randomUUID(),OffsetDateTime.now().plusHours(1)));}
 @Test void anonymousUsersAndRolesReturn401()throws Exception{mvc.perform(get("/api/usuarios")).andExpect(status().isUnauthorized());mvc.perform(get("/api/roles")).andExpect(status().isUnauthorized());}
 @Test void salespersonCannotListOrMutateUsers()throws Exception{login("VEN.VENDER");mvc.perform(get("/api/usuarios").header("Authorization","Bearer test")).andExpect(status().isForbidden());mvc.perform(post("/api/usuarios/2/restablecer-clave").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void roleReaderCannotCreateUsers()throws Exception{login("SEG.PERMISOS");when(service.roles(any(),eq(false))).thenReturn(List.of());mvc.perform(get("/api/roles").header("Authorization","Bearer test")).andExpect(status().isOk());mvc.perform(post("/api/usuarios").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void invalidUserBodyReturns400()throws Exception{login("SEG.USUARIOS");mvc.perform(post("/api/usuarios").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void resetRequiresVersion()throws Exception{login("SEG.USUARIOS");mvc.perform(post("/api/usuarios/2/restablecer-clave").header("Authorization","Bearer test").contentType("application/json").content("{\"claveTemporal\":\"Temporal123\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void deletionAndRoleWritesRemainDenied()throws Exception{login("SEG.USUARIOS","SEG.PERMISOS");mvc.perform(delete("/api/usuarios/2").header("Authorization","Bearer test")).andExpect(status().isForbidden());mvc.perform(put("/api/roles/2").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void auditFieldsCannotBeSubmitted()throws Exception{login("SEG.USUARIOS");mvc.perform(post("/api/usuarios/2/restablecer-clave").header("Authorization","Bearer test").contentType("application/json").content("{\"claveTemporal\":\"Temporal123\",\"version\":\"2026-10-24T12:00:00\",\"usucre\":\"falso\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
}

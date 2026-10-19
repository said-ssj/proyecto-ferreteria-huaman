package com.ferreteriahuaman.security;

import com.ferreteriahuaman.controller.CatalogController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.dao.DataIntegrityViolationException;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(CatalogController.class)
@ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class CatalogApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean CatalogService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","VEN",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadCatalogs()throws Exception{mvc.perform(get("/api/catalogos/categorias")).andExpect(status().isUnauthorized());}
 @Test void productReaderCanReadButCannotCreateCategory()throws Exception{login("PRO.VER");when(service.categories("","",0,20)).thenReturn(new Page<>(List.of(),0,0,20));mvc.perform(get("/api/catalogos/categorias").header("Authorization","Bearer test")).andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty());mvc.perform(post("/api/catalogos/categorias").header("Authorization","Bearer test").contentType("application/json").content("{}" )).andExpect(status().isForbidden());verify(service,never()).createCategory(any(),any(),any());}
 @Test void categoryPermissionDoesNotAllowUnitWrites()throws Exception{login("CAT.GESTIONAR");mvc.perform(post("/api/catalogos/unidades").header("Authorization","Bearer test").contentType("application/json").content("{}" )).andExpect(status().isForbidden());}
 @Test void emptyCategoryNameGets400()throws Exception{login("CAT.GESTIONAR");mvc.perform(post("/api/catalogos/categorias").header("Authorization","Bearer test").contentType("application/json").content("{}" )).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void malformedUnitGets400()throws Exception{login("UNI.GESTIONAR");mvc.perform(post("/api/catalogos/unidades").header("Authorization","Bearer test").contentType("application/json").content("{}" )).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void invalidNumericQueryGets400()throws Exception{login("PRO.VER");mvc.perform(get("/api/catalogos/categorias?pagina=texto").header("Authorization","Bearer test")).andExpect(status().isBadRequest());}
 @Test void databaseConflictDoesNotLeakSql()throws Exception{login("CAT.GESTIONAR");when(service.createCategory(any(),any(),any())).thenThrow(new DataIntegrityViolationException("SQL y detalles internos"));mvc.perform(post("/api/catalogos/categorias").header("Authorization","Bearer test").contentType("application/json").content("{\"nombre\":\"Prueba\"}" )).andExpect(status().isConflict()).andExpect(jsonPath("$.detail").value("Ya existe un registro con esos datos o una relación impide el cambio"));}
 @Test void physicalDeletionRemainsDenied()throws Exception{login("CAT.GESTIONAR","UNI.GESTIONAR");mvc.perform(delete("/api/catalogos/categorias/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}

 @Test void cannotSendAuditFieldsFromBrowser()throws Exception{login("CAT.GESTIONAR");mvc.perform(post("/api/catalogos/categorias").header("Authorization","Bearer test").contentType("application/json").content("""
 {"nombre":"Prueba","usucre":"actor_falso"}
 """)).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void fractionalPrecisionIsNotSilentlyRounded()throws Exception{login("UNI.GESTIONAR");mvc.perform(post("/api/catalogos/unidades").header("Authorization","Bearer test").contentType("application/json").content("""
 {"nombre":"Unidad","abreviatura":"u","codigoSunat":"Z9","descripcionComercial":"Prueba","admiteDecimales":true,"magnitud":"PESO","factorReferencia":"0.001","precisionCantidad":1.5}
 """)).andExpect(status().isBadRequest());verifyNoInteractions(service);}
}

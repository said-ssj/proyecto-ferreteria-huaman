package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.InventoryController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import java.time.*;import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(InventoryController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class InventoryApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean InventoryService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadAlerts()throws Exception{mvc.perform(get("/api/inventario/alertas")).andExpect(status().isUnauthorized());}
 @Test void countingPermissionCannotApproveOrAdjust()throws Exception{login("INV.TOMA_CONTAR");for(String path:new String[]{"/api/inventario/tomas/1/acciones/aprobar","/api/inventario/ajustes","/api/inventario/transformaciones"})mvc.perform(post(path).header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void managerWithoutCountingPermissionCannotSubmitCounts()throws Exception{login("INV.TOMA_GESTIONAR");mvc.perform(post("/api/inventario/tomas/1/conteos").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void cannotAssignStockOrAuditFields()throws Exception{login("INV.AJUSTAR");mvc.perform(post("/api/inventario/ajustes").header("Authorization","Bearer test").contentType("application/json").content("{\"stockActual\":100,\"usucre\":\"otro\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void revisionIsRequiredForCounts()throws Exception{login("INV.TOMA_CONTAR");mvc.perform(post("/api/inventario/tomas/1/conteos").header("Authorization","Bearer test").contentType("application/json").content("{\"productoId\":1,\"cantidad\":\"0\",\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"unidades\":[]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void zeroIsValidForAnExplicitCount()throws Exception{login("INV.TOMA_CONTAR");mvc.perform(post("/api/inventario/tomas/1/conteos").header("Authorization","Bearer test").contentType("application/json").content("{\"productoId\":1,\"cantidad\":\"0\",\"revision\":0,\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"unidades\":[]}")).andExpect(status().isOk());verify(service).count(any(),anyString(),eq(1L),any());}
 @Test void alertsPermissionOnlyReadsAlerts()throws Exception{login("INV.ALERTAS");when(service.alerts("","",0,20)).thenReturn(new Page<>(List.of(),0,0,20));mvc.perform(get("/api/inventario/alertas").header("Authorization","Bearer test")).andExpect(status().isOk());mvc.perform(get("/api/inventario/ajustes").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
 @Test void noPhysicalDeleteEndpoints()throws Exception{login("INV.AJUSTAR","INV.TOMA_GESTIONAR");mvc.perform(delete("/api/inventario/tomas/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.ProductController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
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
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(ProductController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class ProductApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean ProductService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","VEN",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotRead()throws Exception{mvc.perform(get("/api/productos")).andExpect(status().isUnauthorized());}
 @Test void readerCanSearchButCannotCreate()throws Exception{login("PRO.VER");when(service.list(any(),eq("clavo"),eq(""),isNull(),eq(0),eq(20))).thenReturn(new Page<>(List.of(),0,0,20));mvc.perform(get("/api/productos?buscar=clavo").header("Authorization","Bearer test")).andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty());mvc.perform(post("/api/productos").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void managerCannotModifyWholesaleWithoutPermission()throws Exception{login("PRO.GESTIONAR","PRO.PRECIOS");mvc.perform(post("/api/productos/1/presentaciones/2/mayoristas").header("Authorization","Bearer test").contentType("application/json").content("{\"cantidadMinima\":100,\"precio\":5}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void wholesalePermissionDoesNotAllowPresentationWrites()throws Exception{login("PRO.MAYORISTA");mvc.perform(post("/api/productos/1/presentaciones").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
 @Test void missingProductFieldsAreRejected()throws Exception{login("PRO.GESTIONAR");mvc.perform(post("/api/productos").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void browserCannotAssignStockOrCost()throws Exception{login("PRO.GESTIONAR","PRO.PRECIOS");mvc.perform(post("/api/productos").header("Authorization","Bearer test").contentType("application/json").content("{\"codigo\":\"X\",\"stockActual\":100,\"costoPromedio\":1}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void excessiveDecimalPrecisionRejected()throws Exception{login("PRO.PRESENTACIONES");mvc.perform(post("/api/productos/1/presentaciones").header("Authorization","Bearer test").contentType("application/json").content("{\"nombre\":\"Bolsa\",\"factorBase\":\"0.1234567\",\"incrementoVenta\":1,\"minimoVenta\":1,\"precioNormal\":5}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void noPhysicalDeleteEvenForAdministrator()throws Exception{login("PRO.GESTIONAR","PRO.INACTIVAR","PRO.PRECIOS","PRO.PRESENTACIONES","PRO.MAYORISTA");mvc.perform(delete("/api/productos/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

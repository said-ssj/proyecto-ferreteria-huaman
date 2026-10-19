package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.SaleController;
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
@WebMvcTest(SaleController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class SaleApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean SaleService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadSales()throws Exception{mvc.perform(get("/api/ventas/opciones")).andExpect(status().isUnauthorized());}
 @Test void historyPermissionDoesNotGrantSelling()throws Exception{login("VEN.HISTORIAL");mvc.perform(post("/api/ventas/borradores").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void rejectsInjectedPrices()throws Exception{login("VEN.VENDER");mvc.perform(post("/api/ventas/borradores").header("Authorization","Bearer test").contentType("application/json").content("{\"tipo\":\"N\",\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"lineas\":[{\"presentacionId\":1,\"cantidad\":1,\"piezas\":1,\"precio\":0.01}]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void emptyCartIsRejected()throws Exception{login("VEN.VENDER");mvc.perform(post("/api/ventas/borradores").header("Authorization","Bearer test").contentType("application/json").content("{\"tipo\":\"N\",\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"lineas\":[]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void confirmationRequiresPaymentsAndVersion()throws Exception{login("VEN.VENDER");mvc.perform(post("/api/ventas/1/confirmar").header("Authorization","Bearer test").contentType("application/json").content("{\"serieId\":1,\"pagos\":[],\"asignaciones\":[]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void noDirectDeleteOrTotalsUpdate()throws Exception{login("VEN.VENDER");mvc.perform(delete("/api/ventas/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());mvc.perform(put("/api/ventas/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

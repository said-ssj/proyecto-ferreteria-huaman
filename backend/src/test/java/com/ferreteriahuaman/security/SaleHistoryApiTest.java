package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.SaleHistoryController;
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
@WebMvcTest(SaleHistoryController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class SaleHistoryApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean SaleHistoryService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadHistory()throws Exception{mvc.perform(get("/api/historial-ventas")).andExpect(status().isUnauthorized());}
 @Test void sellingDoesNotGrantGeneralHistory()throws Exception{login("VEN.VENDER");mvc.perform(get("/api/historial-ventas").header("Authorization","Bearer test")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void historyReaderCannotCopyCancelOrPrint()throws Exception{login("VEN.HISTORIAL");for(String action:List.of("copia","anulacion","reimpresion"))mvc.perform(post("/api/historial-ventas/1/"+action).header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void cancellationRequiresVersionReturnFlagAndReason()throws Exception{login("VEN.ANULAR");mvc.perform(post("/api/historial-ventas/1/anulacion").header("Authorization","Bearer test").contentType("application/json").content("{\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"motivo\":\"corto\",\"retornos\":[]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void cannotInjectReturnCostOrStock()throws Exception{login("VEN.ANULAR");mvc.perform(post("/api/historial-ventas/1/anulacion").header("Authorization","Bearer test").contentType("application/json").content("{\"stock\":100,\"costo\":0.01}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void printingRequiresAnIdempotencyKey()throws Exception{login("VEN.REIMPRIMIR");mvc.perform(post("/api/historial-ventas/1/reimpresion").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void noPhysicalDeletion()throws Exception{login("VEN.ANULAR");mvc.perform(delete("/api/historial-ventas/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.QuoteController;
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
@WebMvcTest(QuoteController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class QuoteApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean QuoteService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadQuotes()throws Exception{mvc.perform(get("/api/cotizaciones")).andExpect(status().isUnauthorized());}
 @Test void sellingAloneDoesNotGrantQuoting()throws Exception{login("VEN.VENDER");mvc.perform(get("/api/cotizaciones").header("Authorization","Bearer test")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void injectedPriceIsRejected()throws Exception{login("COC.COTIZAR");mvc.perform(post("/api/cotizaciones").header("Authorization","Bearer test").contentType("application/json").content("{\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"lineas\":[{\"presentacionId\":1,\"cantidad\":1,\"precio\":0.01}]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void emptyQuoteIsRejected()throws Exception{login("COC.COTIZAR");mvc.perform(post("/api/cotizaciones").header("Authorization","Bearer test").contentType("application/json").content("{\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"lineas\":[]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void revisionIsRequiredForActions()throws Exception{login("COC.COTIZAR");mvc.perform(post("/api/cotizaciones/1/acciones/emitir").header("Authorization","Bearer test").contentType("application/json").content("{\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"version\":\"2026-10-18T10:00:00\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void cannotInjectCashOrPaymentsIntoConversion()throws Exception{login("COC.COTIZAR","VEN.VENDER");mvc.perform(post("/api/cotizaciones/1/convertir").header("Authorization","Bearer test").contentType("application/json").content("{\"cajaId\":1,\"pagos\":[{\"monto\":1}]}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void quotesHaveNoPhysicalDelete()throws Exception{login("COC.COTIZAR");mvc.perform(delete("/api/cotizaciones/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

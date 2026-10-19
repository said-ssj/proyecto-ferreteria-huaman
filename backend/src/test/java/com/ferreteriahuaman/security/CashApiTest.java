package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.CashController;
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
@WebMvcTest(CashController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class CashApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean CashService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadCash()throws Exception{mvc.perform(get("/api/caja/actual")).andExpect(status().isUnauthorized());}
 @Test void operatorCannotReadHistoricalRegisters()throws Exception{login("CAJ.OPERAR");mvc.perform(get("/api/caja/historial").header("Authorization","Bearer test")).andExpect(status().isForbidden());mvc.perform(get("/api/caja/historial/1/movimientos").header("Authorization","Bearer test")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void historyPermissionCannotOperate()throws Exception{login("CAJ.HISTORIAL");mvc.perform(post("/api/caja/abrir").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());mvc.perform(get("/api/caja/actual").header("Authorization","Bearer test")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void cannotInjectBalancesOrAudit()throws Exception{login("CAJ.OPERAR");mvc.perform(post("/api/caja/abrir").header("Authorization","Bearer test").contentType("application/json").content("{\"fondo\":\"0\",\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\",\"efectivoEsperado\":100}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void openingAcceptsZero()throws Exception{login("CAJ.OPERAR");mvc.perform(post("/api/caja/abrir").header("Authorization","Bearer test").contentType("application/json").content("{\"fondo\":\"0\",\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\"}")).andExpect(status().isOk());verify(service).open(any(),anyString(),any());}
 @Test void manualRequiresPositiveAmountReasonAndKey()throws Exception{login("CAJ.OPERAR");mvc.perform(post("/api/caja/1/movimientos").header("Authorization","Bearer test").contentType("application/json").content("{\"tipo\":\"VENTA\",\"importe\":0,\"motivo\":\"corto\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void closeRequiresAllThreeAmounts()throws Exception{login("CAJ.OPERAR");mvc.perform(post("/api/caja/1/cerrar").header("Authorization","Bearer test").contentType("application/json").content("{\"efectivo\":0,\"yape\":0,\"clave\":\"45c30a76-6a61-4ab7-a744-20e13a5897f1\"}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void noDeleteOrUpdateEndpoints()throws Exception{login("CAJ.OPERAR","CAJ.HISTORIAL");mvc.perform(delete("/api/caja/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());mvc.perform(put("/api/caja/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
}

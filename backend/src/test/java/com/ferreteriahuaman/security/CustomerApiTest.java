package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.CustomerController;
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
@WebMvcTest(CustomerController.class) @ActiveProfiles("db")
@Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class CustomerApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean CustomerService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"prueba","Nombre","Apellido","AYU",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusMinutes(30)));}
 @Test void anonymousCannotReadCustomers()throws Exception{mvc.perform(get("/api/clientes")).andExpect(status().isUnauthorized());}
 @Test void readerCannotEditOrChangeCredit()throws Exception{login("CLI.VER");mvc.perform(post("/api/clientes").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());mvc.perform(patch("/api/clientes/1/credito").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void editorCannotSetCredit()throws Exception{login("CLI.GESTIONAR");mvc.perform(patch("/api/clientes/1/credito").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void cannotInjectCreditIntoCustomerForm()throws Exception{login("CLI.GESTIONAR");mvc.perform(post("/api/clientes").header("Authorization","Bearer test").contentType("application/json").content("{\"tipoDocumento\":\"DNI\",\"documento\":\"87654321\",\"nombre\":\"Persona\",\"limiteCredito\":1000}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void creditRequiresVersionAndNonNegativeAmount()throws Exception{login("CLI.CREDITO");mvc.perform(patch("/api/clientes/1/credito").header("Authorization","Bearer test").contentType("application/json").content("{\"limite\":-1}")).andExpect(status().isBadRequest());verifyNoInteractions(service);}
 @Test void cannotDeleteCustomers()throws Exception{login("CLI.GESTIONAR");mvc.perform(delete("/api/clientes/1").header("Authorization","Bearer test")).andExpect(status().isForbidden());}
 @Test void readerCanSearchDocuments()throws Exception{login("CLI.VER");mvc.perform(get("/api/clientes/buscar-documento").param("documento","87654321").header("Authorization","Bearer test")).andExpect(status().isOk());verify(service).lookup("87654321");}
}

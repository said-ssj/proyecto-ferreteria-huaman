package com.ferreteriahuaman.security;
import com.ferreteriahuaman.controller.BrandController;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.exception.ApiExceptionHandler;
import java.time.OffsetDateTime;import java.util.*;
import org.junit.jupiter.api.Test;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;import org.springframework.boot.test.mock.mockito.MockBean;import org.springframework.context.annotation.Import;import org.springframework.test.context.ActiveProfiles;import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@WebMvcTest(BrandController.class) @ActiveProfiles("db") @Import({ApiSecurityConfig.class,SecurityConfig.class,ApiExceptionHandler.class})
class BrandApiTest {
 @Autowired MockMvc mvc;@MockBean AuthService auth;@MockBean BrandService service;
 void login(String...permissions){when(auth.authenticate(anyString(),anyString())).thenReturn(new Identity(1,"user","N","A","ADM",false,Set.of(permissions),UUID.randomUUID(),OffsetDateTime.now().plusHours(1)));}
 @Test void nameAndLogoAreReadableBeforeLogin()throws Exception{when(service.get()).thenReturn(new BrandService.Metadata("Negocio",null,false,null));mvc.perform(get("/api/identidad-visual")).andExpect(status().isOk()).andExpect(jsonPath("$.nombre").value("Negocio")).andExpect(header().string("Cache-Control","no-store"));String hash="a".repeat(64);when(service.image(hash)).thenReturn(new byte[]{1,2});mvc.perform(get("/api/identidad-visual/logo/"+hash)).andExpect(status().isOk()).andExpect(content().contentType("image/png")).andExpect(header().string("X-Content-Type-Options","nosniff"));}
 @Test void writesRequireSessionAndConfigurationPermission()throws Exception{mvc.perform(put("/api/identidad-visual").contentType("application/json").content("{}")).andExpect(status().isUnauthorized());login("INI.VER");mvc.perform(put("/api/identidad-visual").header("Authorization","Bearer test").contentType("application/json").content("{}")).andExpect(status().isForbidden());verifyNoInteractions(service);}
 @Test void authorizedWriteReachesServiceWithVersion()throws Exception{login("CFG.PARAMETROS");mvc.perform(put("/api/identidad-visual").header("Authorization","Bearer test").contentType("application/json").content("{\"imagenBase64\":null,\"quitarLogo\":true,\"usarLogoComoFavicon\":false,\"version\":null}")).andExpect(status().isOk());verify(service).save(any(),anyString(),argThat(c->c.quitarLogo()&&!c.usarLogoComoFavicon()&&c.version()==null));}
 @Test void oversizedOrUnknownFieldsAreRejected()throws Exception{login("CFG.PARAMETROS");for(String body:List.of("{\"imagenBase64\":\""+"A".repeat(700001)+"\"}","{\"rol\":\"ADM\"}")){mvc.perform(put("/api/identidad-visual").header("Authorization","Bearer test").contentType("application/json").content(body)).andExpect(status().isBadRequest());}verifyNoInteractions(service);}
}

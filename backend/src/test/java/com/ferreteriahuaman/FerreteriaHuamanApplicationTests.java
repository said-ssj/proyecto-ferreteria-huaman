package com.ferreteriahuaman;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import javax.sql.DataSource;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("local")
class FerreteriaHuamanApplicationTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("El contexto de la aplicación arranca correctamente sin base de datos")
    void contextLoads() {
        assertThat(dataSources.stream()).isEmpty();
    }

    @Autowired private ObjectProvider<DataSource> dataSources;

    @Test
    void allowedAngularOriginPassesPreflightWithoutOpeningTheProtectedEndpoint() throws Exception {
        mockMvc.perform(options("/api/ventas").header("Origin", "http://localhost:4200")
                .header("Access-Control-Request-Method", "POST")
                .header("Access-Control-Request-Headers", "Content-Type,Idempotency-Key"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:4200"))
                .andExpect(header().doesNotExist("Access-Control-Allow-Credentials"));
        mockMvc.perform(post("/api/ventas").header("Origin", "http://localhost:4200"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.title").value("Acceso denegado"))
                .andExpect(jsonPath("$.status").value(403));
    }

    @Test
    void untrustedOriginsAreRejected() throws Exception {
        mockMvc.perform(options("/api/ventas").header("Origin", "https://untrusted.invalid")
                .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isForbidden());
    }

    @Test
    void baseDoesNotAcceptBasicAuthenticationOrCreateSessions() throws Exception {
        mockMvc.perform(get("/api/ventas").header("Authorization", "Basic dXNlcjpwYXNz"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist("Set-Cookie"))
                .andExpect(header().doesNotExist("WWW-Authenticate"));
    }

    @Test
    @DisplayName("GET /actuator/health es público, devuelve UP y no expone detalles internos")
    void healthEndpointIsPublicAndDoesNotExposeDetails() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status", is("UP")))
                .andExpect(jsonPath("$.components").doesNotExist())
                .andExpect(jsonPath("$.details").doesNotExist());
    }

    @Test
    @DisplayName("POST /actuator/health es denegado")
    void postHealthEndpointIsDenied() throws Exception {
        mockMvc.perform(post("/actuator/health"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Cualquier otra ruta no autenticada es denegada (403 Forbidden)")
    void otherRoutesAreDenied() throws Exception {
        mockMvc.perform(get("/api/cualquier-ruta"))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Endpoints internos de Actuator distintos de health son denegados")
    void otherActuatorEndpointsAreDenied() throws Exception {
        mockMvc.perform(get("/actuator/info"))
                .andExpect(status().isForbidden());
    }
}

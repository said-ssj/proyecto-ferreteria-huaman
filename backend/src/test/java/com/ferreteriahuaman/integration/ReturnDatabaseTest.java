package com.ferreteriahuaman.integration;

import com.ferreteriahuaman.dto.ReturnModels.*;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.ReturnService;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@ActiveProfiles({"local", "db"})
@Transactional
@EnabledIfEnvironmentVariable(named = "HUAMAN_DB_INTEGRATION", matches = "true")
class ReturnDatabaseTest {
    @Autowired ReturnService returnService;
    @Autowired AuthStore auth;
    @Autowired Environment env;

    Identity actor;

    @BeforeEach
    void setup() {
        var u = auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();
        auth.context(u.username(), "INTEGRATION_ROLLBACK");
        UUID token = UUID.randomUUID();
        auth.createSession(u.id(), token, LocalDateTime.now(ZoneId.of("America/Lima")));
        actor = new Identity(u.id(), u.username(), u.nombres(), u.apellidos(), u.rol(), false, auth.permissions(u.id()), token, OffsetDateTime.now().plusMinutes(30));
    }

    @Test
    void queriesRealDatabaseWithoutLeavingTestData() {
        var summary = returnService.summary(actor);
        assertThat(summary).isNotNull();

        var list = returnService.list(actor, "", "", null, null, 0, 10);
        assertThat(list).isNotNull();

        var sales = returnService.searchSales(actor, "");
        assertThat(sales).isNotNull();

        var cash = returnService.getTodayCash(actor);
        assertThat(cash).isNotNull();
    }
}

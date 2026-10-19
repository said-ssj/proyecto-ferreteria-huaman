package com.ferreteriahuaman.config;

import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import static org.assertj.core.api.Assertions.assertThat;

class EnvFileTest {
    @TempDir Path folder;
    ApplicationContextRunner runner(Path file){return new ApplicationContextRunner()
        .withInitializer(new ConfigDataApplicationContextInitializer())
        .withPropertyValues("spring.config.import=optional:"+file.toUri()+"[.properties]");}
    @Test void loadsUppercaseVariablesAndActivatesDatabaseProfile() throws Exception {
        Path file=folder.resolve(".env");
        Files.writeString(file,"SERVER_PORT=18081\nSPRING_PROFILES_ACTIVE=local,db\n");
        runner(file).run(context->{
            assertThat(context).hasNotFailed();
            assertThat(context.getEnvironment().getProperty("server.port")).isEqualTo("18081");
            assertThat(context.getEnvironment().getActiveProfiles()).contains("local","db");
            assertThat(context.getEnvironment().getProperty("spring.jpa.properties.hibernate.default_schema")).isEqualTo("huaman");
        });
    }
    @Test void missingFileKeepsLocalDefaults(){runner(folder.resolve("missing.env")).run(context->{
        assertThat(context).hasNotFailed();
        assertThat(context.getEnvironment().getProperty("server.port")).isEqualTo("8080");
        assertThat(context.getEnvironment().getActiveProfiles()).contains("local");
    });}
    @Test void explicitRuntimeConfigurationOverridesFile() throws Exception {
        Path file=folder.resolve(".env");Files.writeString(file,"SERVER_PORT=18081\n");
        runner(file).withPropertyValues("server.port=18082").run(context->
            assertThat(context.getEnvironment().getProperty("server.port")).isEqualTo("18082"));
    }
}

package com.ferreteriahuaman.config;

import java.util.List;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.bind.Bindable;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import static org.assertj.core.api.Assertions.assertThat;

class ProfileConfigurationTest {
    private static final String DATASOURCE = "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration";

    @ParameterizedTest
    @ValueSource(strings = {"local", "prod"})
    void databaseRemainsDisabledWithoutExplicitProfile(String profiles) {
        context(profiles).run(context -> {
            List<String> excluded = Binder.get(context.getEnvironment()).bind("spring.autoconfigure.exclude", Bindable.listOf(String.class)).get();
            assertThat(excluded).contains(DATASOURCE);
            assertThat(context.getEnvironment().getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("none");
            assertThat(context.getEnvironment().getProperty("spring.sql.init.mode")).isEqualTo("never");
        });
    }

    @ParameterizedTest
    @ValueSource(strings = {"local,db", "db,local", "prod,db", "db,prod"})
    void explicitDatabaseProfileDoesNotDependOnOrder(String profiles) {
        context(profiles).run(context -> {
            List<String> excluded = Binder.get(context.getEnvironment()).bind("spring.autoconfigure.exclude", Bindable.listOf(String.class)).get();
            assertThat(excluded).doesNotContain(DATASOURCE);
            assertThat(context.getEnvironment().getProperty("spring.jpa.hibernate.ddl-auto")).isEqualTo("none");
            assertThat(context.getEnvironment().getProperty("spring.sql.init.mode")).isEqualTo("never");
            assertThat(context.getEnvironment().getProperty("spring.jpa.properties.hibernate.default_schema")).isEqualTo("huaman");
        });
    }

    private ApplicationContextRunner context(String profiles) {
        return new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues("spring.profiles.active=" + profiles);
    }
}


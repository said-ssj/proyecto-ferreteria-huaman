package com.ferreteriahuaman.security;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.context.annotation.Profile;

@Configuration
@EnableMethodSecurity
public class AuthConfiguration {
    @Bean Clock clock(){return Clock.systemUTC();}
    @Bean PasswordEncoder passwordEncoder(){return new BCryptPasswordEncoder(12);}
    @Bean @Profile("db") TransactionTemplate transactions(PlatformTransactionManager manager){return new TransactionTemplate(manager);}
}

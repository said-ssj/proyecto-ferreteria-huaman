package com.ferreteriahuaman.config;

import java.net.URI;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.cors")
public record CorsProperties(List<String> allowedOrigins) {
    public CorsProperties {
        allowedOrigins = allowedOrigins == null ? List.of() : allowedOrigins.stream()
                .map(String::trim).filter(value -> !value.isEmpty()).distinct().toList();
        for (String origin : allowedOrigins) {
            URI uri;
            try { uri = URI.create(origin); }
            catch (IllegalArgumentException exception) {
                throw new IllegalArgumentException("El origen CORS debe ser una URL HTTP o HTTPS válida");
            }
            if (!("http".equals(uri.getScheme()) || "https".equals(uri.getScheme()))
                    || uri.getHost() == null || uri.getUserInfo() != null
                    || uri.getRawQuery() != null || uri.getRawFragment() != null
                    || (uri.getRawPath() != null && !uri.getRawPath().isEmpty())
                    || uri.getPort() > 65535) {
                throw new IllegalArgumentException("El origen CORS debe incluir solo protocolo, host y puerto, sin comodines");
            }
        }
    }
}

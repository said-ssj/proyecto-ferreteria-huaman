package com.ferreteriahuaman.config;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.assertj.core.api.Assertions.*;

class CorsPropertiesTest {
    @Test
    void emptyOriginsStayEmpty() {
        assertThat(new CorsProperties(null).allowedOrigins()).isEmpty();
        assertThat(new CorsProperties(List.of(" ")).allowedOrigins()).isEmpty();
    }
    @Test
    void exactOriginsAreTrimmedAndDeduplicated() {
        assertThat(new CorsProperties(List.of(" http://localhost:4200 ", "http://localhost:4200"))
                .allowedOrigins()).containsExactly("http://localhost:4200");
    }
    @ParameterizedTest
    @ValueSource(strings = {"*", "https://*.example.com", "https://example.com/path", "https://example.com/", "https://user:pass@example.com", "https://example.com?token=x", "ftp://example.com", "http://localhost:99999"})
    void rejectsWildcardAndNonOriginUrls(String origin) {
        assertThatIllegalArgumentException().isThrownBy(() -> new CorsProperties(List.of(origin)));
    }
}

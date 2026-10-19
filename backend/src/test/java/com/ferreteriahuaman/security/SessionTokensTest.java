package com.ferreteriahuaman.security;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;
class SessionTokensTest {
    SessionTokens tokens=new SessionTokens();
    @Test void issuesIndependentSecretsAndStableDigests(){String first=tokens.issue(),second=tokens.issue();
        assertThat(first).hasSize(43).isNotEqualTo(second);assertThat(tokens.identifier(first)).isEqualTo(tokens.identifier(first)).isNotEqualTo(tokens.identifier(second));}
    @Test void rejectsMalformedOrNonCanonicalTokens(){
        for(String token:new String[]{"", "secret", "a".repeat(44), "a".repeat(42)+"!", "a".repeat(43)})
            assertThatThrownBy(()->tokens.identifier(token)).isInstanceOf(AuthFailure.class);
    }
}

package com.ferreteriahuaman.security;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.nio.ByteBuffer;
import java.util.Base64;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class SessionTokens {
    private final SecureRandom random=new SecureRandom();
    public String issue(){byte[] bytes=new byte[32];random.nextBytes(bytes);return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);}
    // Store a 128-bit SHA-256 digest in the existing UUID column, never the bearer secret.
    public UUID identifier(String token){
        if(token==null || !token.matches("[A-Za-z0-9_-]{43}"))throw AuthFailure.expired();
        byte[] secret=Base64.getUrlDecoder().decode(token);
        if(!Base64.getUrlEncoder().withoutPadding().encodeToString(secret).equals(token))throw AuthFailure.expired();
        try {ByteBuffer hash=ByteBuffer.wrap(MessageDigest.getInstance("SHA-256").digest(secret));
            return new UUID(hash.getLong(),hash.getLong());}
        catch(NoSuchAlgorithmException impossible){throw new IllegalStateException(impossible);}
    }
}

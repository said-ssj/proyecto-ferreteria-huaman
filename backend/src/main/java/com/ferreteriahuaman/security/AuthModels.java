package com.ferreteriahuaman.security;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.Set;
import java.util.UUID;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class AuthModels {
    private AuthModels() {}
    public record Login(@NotBlank @Size(max=30) String usuario,
                        @NotBlank @Size(max=72) String clave) {
        @Override public String toString(){return "Login[credenciales omitidas]";}
    }
    public record PasswordChange(@NotBlank @Size(max=72) String actual,
                                 @NotBlank @Size(min=8,max=72) String nueva,
                                 @NotBlank @Size(max=72) String confirmacion) {
        @Override public String toString(){return "PasswordChange[credenciales omitidas]";}
    }
    public record Account(long id,String username,String hash,String nombres,String apellidos,
                          String rol,boolean activo,boolean temporal,int intentos,LocalDateTime bloqueo) {
        @Override public String toString(){return "Account[id="+id+"]";}
    }
    public record Session(long id,long usuario,UUID token,LocalDateTime actividad,boolean abierta) {}
    public record Identity(long id,String usuario,String nombres,String apellidos,String rol,
                           boolean cambioClaveObligatorio,Set<String> permisos,UUID sessionToken,
                           OffsetDateTime expiraEn) {}
    public record UserProfile(long id,String usuario,String nombres,String apellidos,String rol,
                          boolean cambioClaveObligatorio,Set<String> permisos,OffsetDateTime expiraEn) {
        public static UserProfile of(Identity identity){return new UserProfile(identity.id(),identity.usuario(),
            identity.nombres(),identity.apellidos(),identity.rol(),identity.cambioClaveObligatorio(),
            identity.permisos(),identity.expiraEn());}
    }
    public record LoginResponse(String accessToken,String tokenType,UserProfile usuario) {
        @Override public String toString(){return "LoginResponse[token omitido]";}
    }
    public record LoginResult(LoginResponse response,AuthFailure failure) {}
}

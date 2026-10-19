package com.ferreteriahuaman.service;

import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.*;
import com.ferreteriahuaman.security.AuthModels.*;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
@Profile("db")
public class AuthService {
    private static final ZoneId LIMA=ZoneId.of("America/Lima");
    private final AuthStore store;private final PasswordEncoder encoder;private final SessionTokens tokens;
    private final TransactionTemplate tx;private final Clock clock;private final String dummy;
    public AuthService(AuthStore store,PasswordEncoder encoder,SessionTokens tokens,TransactionTemplate tx,Clock clock){
        this.store=store;this.encoder=encoder;this.tokens=tokens;this.tx=tx;this.clock=clock;
        dummy=encoder.encode(UUID.randomUUID().toString());
    }
    private LocalDateTime now(){return LocalDateTime.ofInstant(clock.instant(),LIMA);}
    private int sessionMinutes(){return store.parameter("SEGURIDAD.SESION_MIN",30,5,120);}
    public LoginResult login(Login request,String equipo){return tx.execute(status->{
        LocalDateTime now=now();Account user=store.lockUsername(request.usuario()).orElse(null);
        if(user==null){encoder.matches(request.clave(),dummy);return new LoginResult(null,AuthFailure.credentials());}
        store.context(user.username(),equipo);
        if(user.bloqueo()!=null && now.isBefore(user.bloqueo()))return new LoginResult(null,new AuthFailure(423,"Cuenta bloqueada temporalmente. Intenta de nuevo más tarde"));
        if(request.clave().getBytes(StandardCharsets.UTF_8).length>72 || !encoder.matches(request.clave(),user.hash())){
            int attempts=user.bloqueo()!=null?1:user.intentos()+1;
            int max=store.parameter("SEGURIDAD.INTENTOS_MAX",5,1,20);
            LocalDateTime until=attempts>=max?now.plusMinutes(store.parameter("SEGURIDAD.BLOQUEO_MIN",15,1,120)):null;
            store.failed(user,attempts,until);store.event(user.id(),until==null?"SEG.LOGIN_FALLIDO":"SEG.BLOQUEO");
            return new LoginResult(null,AuthFailure.credentials());
        }
        if(!user.activo())return new LoginResult(null,AuthFailure.credentials());
        store.resetLogin(user,now);String secret=tokens.issue();UUID id=tokens.identifier(secret);
        store.createSession(user.id(),id,now);store.event(user.id(),"SEG.LOGIN");
        return new LoginResult(new LoginResponse(secret,"Bearer",UserProfile.of(identity(user,id,now))),null);
    });}
    public Identity authenticate(String secret,String equipo){UUID id=tokens.identifier(secret);
        Identity identity=tx.execute(status->{
            Long owner=store.sessionOwner(id).orElse(null);if(owner==null)return null;
            Account user=store.lockUser(owner).orElse(null);if(user==null)return null;
            Session session=store.lockSession(id).orElse(null);if(session==null||!session.abierta()||session.usuario()!=user.id())return null;
            store.context(user.username(),equipo);LocalDateTime now=now();
            if(now.isBefore(session.actividad()))return null;
            if(!user.activo() || (user.bloqueo()!=null&&now.isBefore(user.bloqueo()))){store.close(session.id(),"REVOCADA",now);store.event(user.id(),"SEG.SESION_REVOCADA");return null;}
            if(!now.isBefore(session.actividad().plusMinutes(sessionMinutes()))){store.close(session.id(),"EXPIRADA",now);store.event(user.id(),"SEG.SESION_EXPIRADA");return null;}
            store.touch(session.id(),now);return identity(user,id,now);
        });
        if(identity==null)throw AuthFailure.expired();return identity;
    }
    private Identity identity(Account user,UUID session,LocalDateTime activity){
        Set<String> permissions=user.temporal()?Set.of("SEG.PERFIL"):store.permissions(user.id());
        return new Identity(user.id(),user.username(),user.nombres(),user.apellidos(),user.rol(),user.temporal(),permissions,session,activity.plusMinutes(sessionMinutes()).atZone(LIMA).toOffsetDateTime());
    }
    public void logout(Identity identity,String equipo){tx.executeWithoutResult(status->{
        Account user=store.lockUser(identity.id()).orElseThrow(AuthFailure::expired);
        Session session=store.lockSession(identity.sessionToken()).orElseThrow(AuthFailure::expired);
        if(!session.abierta())return;
        store.context(user.username(),equipo);store.close(session.id(),"LOGOUT",now());store.event(user.id(),"SEG.LOGOUT");
    });}
    public void changePassword(Identity identity,PasswordChange request,String equipo){tx.executeWithoutResult(status->{
        Account user=store.lockUser(identity.id()).orElseThrow(AuthFailure::expired);
        Session session=store.lockSession(identity.sessionToken()).orElseThrow(AuthFailure::expired);
        LocalDateTime now=now();
        if(!session.abierta() || !user.activo() || !now.isBefore(session.actividad().plusMinutes(sessionMinutes())))throw AuthFailure.expired();
        if(request.actual().getBytes(StandardCharsets.UTF_8).length>72 || !encoder.matches(request.actual(),user.hash()))throw new AuthFailure(400,"La contraseña actual no es correcta");
        String next=request.nueva();
        if(!next.equals(request.confirmacion()) || next.length()<8 || next.getBytes(StandardCharsets.UTF_8).length>72
            || !next.chars().anyMatch(Character::isLetter) || !next.chars().anyMatch(Character::isDigit)
            || next.equalsIgnoreCase(user.username()) || encoder.matches(next,user.hash()))
            throw new AuthFailure(400,"La contraseña debe coincidir con su confirmación, tener al menos 8 caracteres con letras y números y ser distinta del usuario y de la actual");
        store.context(user.username(),equipo);store.password(user.id(),encoder.encode(next));
        store.revokeOtherSessions(user.id(),identity.sessionToken(),now);store.event(user.id(),"SEG.CAMBIO_CLAVE");
    });}
}

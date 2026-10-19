package com.ferreteriahuaman.service;

import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.*;
import com.ferreteriahuaman.security.AuthModels.*;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.*;
import org.springframework.transaction.support.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class AuthServiceTest {
    AuthStore store;AuthService service;BCryptPasswordEncoder encoder=new BCryptPasswordEncoder(4);
    SessionTokens tokens=new SessionTokens();LocalDateTime now=LocalDateTime.of(2026,10,17,12,0);
    Account account;UUID token;Identity identity;
    @BeforeEach void prepare(){
        store=mock(AuthStore.class);
        var manager=new AbstractPlatformTransactionManager(){
            protected Object doGetTransaction(){return new Object();}
            protected void doBegin(Object t,TransactionDefinition d){}
            protected void doCommit(DefaultTransactionStatus s){}
            protected void doRollback(DefaultTransactionStatus s){}
        };
        service=new AuthService(store,encoder,tokens,new TransactionTemplate(manager),Clock.fixed(Instant.parse("2026-10-17T17:00:00Z"),ZoneOffset.UTC));
        when(store.parameter(anyString(),anyInt(),anyInt(),anyInt())).thenAnswer(i->i.getArgument(1));
        account=user(false,0,null,true);token=tokens.identifier(tokens.issue());
        identity=new Identity(1,"operador","Nombre","Apellido","VEN",false,Set.of("SEG.PERFIL"),token,now.plusMinutes(30).atOffset(ZoneOffset.ofHours(-5)));
        when(store.lockUsername("operador")).thenReturn(Optional.of(account));
        when(store.lockUser(1)).thenReturn(Optional.of(account));
        when(store.permissions(1)).thenReturn(Set.of("SEG.PERFIL","VEN.VENDER"));
        when(store.sessionOwner(token)).thenReturn(Optional.of(1L));
        when(store.lockSession(token)).thenReturn(Optional.of(session(now.minusMinutes(1),true)));
    }
    Account user(boolean temporal,int attempts,LocalDateTime blocked,boolean active){return new Account(1,"operador",encoder.encode("Clave1234"),"Nombre","Apellido","VEN",active,temporal,attempts,blocked);}
    Session session(LocalDateTime activity,boolean open){return new Session(5,1,token,activity,open);}
    @Test void loginCreatesSessionWithoutReturningPassword(){
        var result=service.login(new Login("operador","Clave1234"),"127.0.0.1");
        assertThat(result.failure()).isNull();assertThat(result.response().accessToken()).hasSize(43);
        assertThat(result.response().usuario().permisos()).contains("VEN.VENDER");
        verify(store).createSession(eq(1L),eq(tokens.identifier(result.response().accessToken())),eq(now));
        verify(store).event(1L,"SEG.LOGIN");
    }
    @Test void unknownUserHasGenericFailureAndNoSession(){when(store.lockUsername("ausente")).thenReturn(Optional.empty());
        assertThat(service.login(new Login("ausente","Clave1234"),"ip").failure().status()).isEqualTo(401);
        verify(store,never()).createSession(anyLong(),any(),any());}
    @Test void fifthFailurePersistsCounterAndFifteenMinuteBlock(){when(store.lockUsername("operador")).thenReturn(Optional.of(user(false,4,null,true)));
        assertThat(service.login(new Login("operador","Incorrecta1"),"ip").failure()).isNotNull();
        verify(store).failed(any(),eq(5),eq(now.plusMinutes(15)));verify(store).event(1L,"SEG.BLOQUEO");}
    @Test void correctPasswordCannotBypassActiveBlock(){when(store.lockUsername("operador")).thenReturn(Optional.of(user(false,5,now.plusMinutes(1),true)));
        assertThat(service.login(new Login("operador","Clave1234"),"ip").failure().status()).isEqualTo(423);
        verify(store,never()).createSession(anyLong(),any(),any());}
    @Test void expiredBlockRestartsFailureCounter(){when(store.lockUsername("operador")).thenReturn(Optional.of(user(false,5,now.minusMinutes(1),true)));
        service.login(new Login("operador","Incorrecta1"),"ip");verify(store).failed(any(),eq(1),isNull());}
    @Test void inactiveUserCannotLogin(){when(store.lockUsername("operador")).thenReturn(Optional.of(user(false,0,null,false)));
        assertThat(service.login(new Login("operador","Clave1234"),"ip").failure().status()).isEqualTo(401);verify(store,never()).createSession(anyLong(),any(),any());}
    @Test void temporaryPasswordOnlyAllowsOwnPasswordChange(){when(store.lockUsername("operador")).thenReturn(Optional.of(user(true,0,null,true)));
        var response=service.login(new Login("operador","Clave1234"),"ip").response();
        assertThat(response.usuario().cambioClaveObligatorio()).isTrue();assertThat(response.usuario().permisos()).containsExactly("SEG.PERFIL");}
    @Test void thirtyMinutesExactlyExpiresWithoutTouchingActivity(){String raw=tokens.issue();UUID id=tokens.identifier(raw);
        when(store.sessionOwner(id)).thenReturn(Optional.of(1L));when(store.lockSession(id)).thenReturn(Optional.of(new Session(5,1,id,now.minusMinutes(30),true)));
        assertThatThrownBy(()->service.authenticate(raw,"ip")).isInstanceOf(AuthFailure.class);
        verify(store).close(5,"EXPIRADA",now);verify(store,never()).touch(anyLong(),any());}
    @Test void activeSessionRenewsActivityAndReloadsPermissions(){String raw=tokens.issue();UUID id=tokens.identifier(raw);
        when(store.sessionOwner(id)).thenReturn(Optional.of(1L));when(store.lockSession(id)).thenReturn(Optional.of(new Session(5,1,id,now.minusMinutes(29),true)));
        assertThat(service.authenticate(raw,"ip").permisos()).contains("VEN.VENDER");verify(store).touch(5,now);verify(store).permissions(1);}
    @Test void closedSessionCannotBeUsed(){String raw=tokens.issue();UUID id=tokens.identifier(raw);
        when(store.sessionOwner(id)).thenReturn(Optional.of(1L));when(store.lockSession(id)).thenReturn(Optional.of(new Session(5,1,id,now,false)));
        assertThatThrownBy(()->service.authenticate(raw,"ip")).isInstanceOf(AuthFailure.class);}
    @Test void logoutClosesAndAuditsSession(){service.logout(identity,"ip");verify(store).close(5,"LOGOUT",now);verify(store).event(1L,"SEG.LOGOUT");}
    @Test void validPasswordChangeHashesAndRevokesOtherSessions(){service.changePassword(identity,new PasswordChange("Clave1234","Nueva1234","Nueva1234"),"ip");
        var hash=org.mockito.ArgumentCaptor.forClass(String.class);verify(store).password(eq(1L),hash.capture());
        assertThat(encoder.matches("Nueva1234",hash.getValue())).isTrue();verify(store).revokeOtherSessions(1,token,now);verify(store).event(1L,"SEG.CAMBIO_CLAVE");}
    @Test void wrongCurrentPasswordCannotChangeAnything(){assertThatThrownBy(()->service.changePassword(identity,new PasswordChange("Erronea123","Nueva1234","Nueva1234"),"ip")).isInstanceOf(AuthFailure.class);verify(store,never()).password(anyLong(),anyString());}
    @Test void rejectsWeakReusedOrMismatchedPasswords(){for(String next:List.of("abcdefgh","12345678","Clave1234","Ab12"))
        assertThatThrownBy(()->service.changePassword(identity,new PasswordChange("Clave1234",next,next),"ip")).isInstanceOf(AuthFailure.class);
        assertThatThrownBy(()->service.changePassword(identity,new PasswordChange("Clave1234","Nueva1234","Distinta123"),"ip")).isInstanceOf(AuthFailure.class);}

    @Test void accountDeactivationRevokesAnExistingSession(){String raw=tokens.issue();UUID id=tokens.identifier(raw);
        when(store.sessionOwner(id)).thenReturn(Optional.of(1L));when(store.lockSession(id)).thenReturn(Optional.of(new Session(5,1,id,now.minusMinutes(1),true)));
        when(store.lockUser(1)).thenReturn(Optional.of(user(false,0,null,false)));
        assertThatThrownBy(()->service.authenticate(raw,"ip")).isInstanceOf(AuthFailure.class);verify(store).close(5,"REVOCADA",now);}
    @Test void passwordChangeRejectsMoreThanSeventyTwoUtf8Bytes(){String next="Á".repeat(40)+"1234";
        assertThatThrownBy(()->service.changePassword(identity,new PasswordChange("Clave1234",next,next),"ip")).isInstanceOf(AuthFailure.class);
        verify(store,never()).password(anyLong(),anyString());}
}

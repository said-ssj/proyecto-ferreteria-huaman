package com.ferreteriahuaman.service;

import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthModels.*;
import com.ferreteriahuaman.security.AuthFailure;
import java.time.*;
import java.util.*;
import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import org.springframework.transaction.*;
import org.springframework.transaction.support.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class BusinessTransactionsTest {
 AuthStore auth;BusinessTransactions transactions;Identity actor;Account user;Session session;LocalDateTime now=LocalDateTime.of(2026,10,17,12,0);
 @BeforeEach void prepare(){auth=mock(AuthStore.class);UUID token=UUID.randomUUID();actor=new Identity(1,"valor_cliente","Nombre","Apellido","ADM",false,Set.of("CAT.GESTIONAR"),token,OffsetDateTime.now().plusMinutes(30));
 user=new Account(1,"usuario_verificado","hash","Nombre","Apellido","ADM",true,false,0,null);session=new Session(2,1,token,now.minusMinutes(1),true);
 when(auth.lockUser(1)).thenReturn(Optional.of(user));when(auth.lockSession(token)).thenReturn(Optional.of(session));when(auth.parameter(anyString(),anyInt(),anyInt(),anyInt())).thenReturn(30);when(auth.permissions(1)).thenReturn(Set.of("CAT.GESTIONAR"));
 var manager=new AbstractPlatformTransactionManager(){protected Object doGetTransaction(){return new Object();}protected void doBegin(Object t,TransactionDefinition d){}protected void doCommit(DefaultTransactionStatus s){}protected void doRollback(DefaultTransactionStatus s){}};
 transactions=new BusinessTransactions(new TransactionTemplate(manager),auth,Clock.fixed(Instant.parse("2026-10-17T17:00:00Z"),ZoneOffset.UTC));}
 @Test void auditActorComesFromDatabaseNotSuppliedIdentity(){assertThat(transactions.write(actor,"equipo","CAT.GESTIONAR",()->"resultado")).isEqualTo("resultado");verify(auth).context("usuario_verificado","equipo");}
 @Test void permissionRemovalBlocksEvenPreviouslyAuthenticatedUser(){when(auth.permissions(1)).thenReturn(Set.of());Supplier<String> operation=mock(Supplier.class);assertThatThrownBy(()->transactions.write(actor,"equipo","CAT.GESTIONAR",operation)).isInstanceOf(AuthFailure.class);verifyNoInteractions(operation);}
 @Test void revokedSessionCannotWrite(){when(auth.lockSession(actor.sessionToken())).thenReturn(Optional.of(new Session(2,1,actor.sessionToken(),now,false)));assertThatThrownBy(()->transactions.write(actor,"equipo","CAT.GESTIONAR",()->"no")).isInstanceOf(AuthFailure.class);}
 @Test void temporaryAccountCannotWriteEvenWithPermission(){when(auth.lockUser(1)).thenReturn(Optional.of(new Account(1,"usuario_verificado","hash","Nombre","Apellido","ADM",true,true,0,null)));assertThatThrownBy(()->transactions.write(actor,"equipo","CAT.GESTIONAR",()->"no")).isInstanceOf(AuthFailure.class);}
 @Test void expiredSessionCannotWrite(){when(auth.lockSession(actor.sessionToken())).thenReturn(Optional.of(new Session(2,1,actor.sessionToken(),now.minusMinutes(30),true)));assertThatThrownBy(()->transactions.write(actor,"equipo","CAT.GESTIONAR",()->"no")).isInstanceOf(AuthFailure.class);}
}

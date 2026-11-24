package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.UserAdminModels.*;
import com.ferreteriahuaman.repository.UserAdminRepository;
import com.ferreteriahuaman.security.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.*;import java.util.*;import java.util.function.Supplier;
import org.junit.jupiter.api.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.support.*;
import static org.assertj.core.api.Assertions.*;import static org.mockito.Mockito.*;import static org.mockito.ArgumentMatchers.*;
class UserAdminServiceTest{
 UserAdminRepository repo;BusinessTransactions tx;PasswordEncoder encoder;UserAdminService service;
 LocalDateTime version=LocalDateTime.of(2026,10,24,12,0);
 Identity admin=new Identity(1,"admin.prueba","Nombre","Apellido","ADM",false,Set.of("SEG.USUARIOS","SEG.PERMISOS"),UUID.randomUUID(),OffsetDateTime.now().plusHours(1));
 User user(long id,String role){return new User(id,"usuario"+id,"Nombre","Apellido","12345678",null,null,role.equals("ADM")?1:2,role,role,"A",false,null,null,version);}
 Input input(String role){return new Input("usuario2","Nombre","Apellido","12345678",null,null,role.equals("ADM")?1:2,version,null);}
 @BeforeEach void setup(){repo=mock(UserAdminRepository.class);tx=mock(BusinessTransactions.class);encoder=mock(PasswordEncoder.class);TransactionTemplate transaction=mock(TransactionTemplate.class);
 when(transaction.execute(any())).thenAnswer(i->((TransactionCallback<?>)i.getArgument(0)).doInTransaction(mock(org.springframework.transaction.TransactionStatus.class)));
 when(tx.write(any(),anyString(),anyString(),any())).thenAnswer(i->((Supplier<?>)i.getArgument(3)).get());
 when(repo.user(1,true)).thenReturn(Optional.of(user(1,"ADM")));when(repo.user(2,true)).thenReturn(Optional.of(user(2,"VEN")));when(repo.user(2,false)).thenReturn(Optional.of(user(2,"VEN")));
 when(repo.role(2)).thenReturn(Optional.of(new Role(2,"VEN","Ventas",null,"A",List.of())));when(repo.role(1)).thenReturn(Optional.of(new Role(1,"ADM","Administración",null,"A",List.of())));
 service=new UserAdminService(repo,tx,transaction,encoder,new ObjectMapper().findAndRegisterModules());}
 @Test void deniesNonAdminEvenWithPermission(){Identity other=new Identity(2,"otro","N","A","VEN",false,admin.permisos(),UUID.randomUUID(),admin.expiraEn());assertThatThrownBy(()->service.list(other,"","",0,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void rejectsInvalidFilters(){assertThatThrownBy(()->service.list(admin,"","X",0,20)).isInstanceOf(AuthFailure.class);verifyNoInteractions(repo);}
 @Test void staleVersionCannotOverwrite(){Input i=new Input("usuario2","N","A","12345678",null,null,2,version.minusSeconds(1),null);assertThatThrownBy(()->service.update(admin,"local",2,i)).isInstanceOf(AuthFailure.class);verify(repo,never()).update(anyLong(),any());}
 @Test void cannotDeactivateOwnAccount(){assertThatThrownBy(()->service.state(admin,"local",1,new State("I",version))).isInstanceOf(AuthFailure.class);verify(repo,never()).state(anyLong(),anyString());}
 @Test void cannotResetOwnPassword(){assertThatThrownBy(()->service.reset(admin,"local",1,new Reset("Temporal123",version))).isInstanceOf(AuthFailure.class);verifyNoInteractions(encoder);}
 @Test void lastAdminCannotBeDemoted(){when(repo.user(2,true)).thenReturn(Optional.of(user(2,"ADM")));when(repo.activeAdmins()).thenReturn(1L);assertThatThrownBy(()->service.update(admin,"local",2,input("VEN"))).isInstanceOf(AuthFailure.class);verify(repo,never()).update(anyLong(),any());}
 @Test void roleChangeRevokesSessionsAndAuditsWithoutCredentials(){service.update(admin,"local",2,input("ADM"));verify(repo).revoke(2);verify(repo).audit(eq(1L),eq("SEG.USUARIO_EDITAR"),eq(2L),anyString(),argThat(s->!s.contains("claveTemporal")&&!s.contains("clave_hash")));}
 @Test void deactivationRevokesSessions(){service.state(admin,"local",2,new State("I",version));verify(repo).state(2,"I");verify(repo).revoke(2);}
 @Test void resetHashesPasswordAndNeverAuditsIt(){when(encoder.encode("Temporal123")).thenReturn("hash-privado");service.reset(admin,"local",2,new Reset("Temporal123",version));verify(repo).reset(2,"hash-privado");verify(repo).revoke(2);verify(repo).audit(eq(1L),eq("SEG.USUARIO_CLAVE"),eq(2L),anyString(),argThat(s->!s.contains("Temporal123")&&!s.contains("hash-privado")));}
 @Test void missingPasswordDoesNotStartTransaction(){assertThatThrownBy(()->service.create(admin,"local",input("VEN"))).isInstanceOf(AuthFailure.class);verify(repo,never()).serialize();}
 @Test void passwordPolicyRejectsUsernameMissingDigitsAndLongUtf8(){for(String value:List.of("usuario2","abcdefgh","12345678","á".repeat(36)+"1")){assertThatThrownBy(()->UserAdminService.password("usuario2",value)).isInstanceOf(AuthFailure.class);}}
 @Test void sensitiveRequestsDoNotPrintPasswords(){assertThat(new Reset("Temporal123",version).toString()).doesNotContain("Temporal123");assertThat(new Input("usuario2","N","A","12345678",null,null,2,null,"Temporal123").toString()).doesNotContain("Temporal123");}
}

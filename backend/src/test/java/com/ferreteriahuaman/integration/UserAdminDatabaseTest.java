package com.ferreteriahuaman.integration;
import com.ferreteriahuaman.service.UserAdminService;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.dto.UserAdminModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.time.*;import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;
@SpringBootTest @ActiveProfiles({"local","db"}) @Transactional
@EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class UserAdminDatabaseTest{
 @Autowired UserAdminService service;@Autowired AuthStore auth;@Autowired Environment env;@Autowired JdbcTemplate jdbc;@Autowired PasswordEncoder encoder;
 Identity actor;String name;long role;String dni;
 @BeforeEach void setup(){var u=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();auth.context(u.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();LocalDateTime now=LocalDateTime.now(ZoneId.of("America/Lima"));auth.createSession(u.id(),token,now);actor=new Identity(u.id(),u.username(),u.nombres(),u.apellidos(),u.rol(),false,auth.permissions(u.id()),token,OffsetDateTime.now().plusHours(1));name="test."+UUID.randomUUID().toString().substring(0,12);dni=String.valueOf(10000000+Math.floorMod(UUID.randomUUID().hashCode(),89999999));role=jdbc.queryForObject("select id_rol from huaman.rol where codigo='VEN'",Long.class);}
 Input input(){return new Input(name,"Prueba","Temporal",dni,null,null,role,null,"Temporal12345");}
 @Test void createReadAndEditUseRealTables(){User created=service.create(actor,"INTEGRATION_ROLLBACK",input());assertThat(created.cambioClaveObligatorio()).isTrue();assertThat(service.list(actor,name,"A",0,20).items()).hasSize(1);String hash=jdbc.queryForObject("select clave_hash from huaman.usuario where id_usuario=?",String.class,created.id());assertThat(encoder.matches("Temporal12345",hash)).isTrue();User edited=service.update(actor,"INTEGRATION_ROLLBACK",created.id(),new Input(name,"Nombre cambiado","Temporal",dni,null,null,role,created.version(),null));assertThat(edited.nombres()).isEqualTo("Nombre cambiado");assertThat(jdbc.queryForObject("select valor_nuevo::text from huaman.bitacora_evento where entidad='usuario' and id_entidad=? order by id_evento desc limit 1",String.class,created.id())).doesNotContain("Temporal12345","clave_hash");}
 @Test void resetRevokesSessionAndForcesPasswordChange(){User created=service.create(actor,"INTEGRATION_ROLLBACK",input());LocalDateTime now=LocalDateTime.now(ZoneId.of("America/Lima"));auth.createSession(created.id(),UUID.randomUUID(),now);User reset=service.reset(actor,"INTEGRATION_ROLLBACK",created.id(),new Reset("OtraTemporal123",created.version()));assertThat(reset.cambioClaveObligatorio()).isTrue();assertThat(jdbc.queryForObject("select count(*) from huaman.sesion_usuario where id_usuario=? and estado='A'",Long.class,created.id())).isZero();String hash=jdbc.queryForObject("select clave_hash from huaman.usuario where id_usuario=?",String.class,created.id());assertThat(encoder.matches("OtraTemporal123",hash)).isTrue();}
 @Test void deactivationAndRolesAreConnected(){User created=service.create(actor,"INTEGRATION_ROLLBACK",input());User inactive=service.state(actor,"INTEGRATION_ROLLBACK",created.id(),new State("I",created.version()));assertThat(inactive.estado()).isEqualTo("I");assertThat(service.roles(actor,false)).anySatisfy(r->{assertThat(r.codigo()).isEqualTo("ADM");assertThat(r.permisos()).anyMatch(p->p.codigo().equals("SEG.USUARIOS"));});}
}

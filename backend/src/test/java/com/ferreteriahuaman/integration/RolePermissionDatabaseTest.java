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
class RolePermissionDatabaseTest{
 @Autowired com.ferreteriahuaman.service.RolePermissionService roles;@Autowired UserAdminService service;@Autowired AuthStore auth;@Autowired Environment env;@Autowired JdbcTemplate jdbc;@Autowired PasswordEncoder encoder;
 Identity actor;String name;long role;String dni;
 @BeforeEach void setup(){var u=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();auth.context(u.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();LocalDateTime now=LocalDateTime.now(ZoneId.of("America/Lima"));auth.createSession(u.id(),token,now);actor=new Identity(u.id(),u.username(),u.nombres(),u.apellidos(),u.rol(),false,auth.permissions(u.id()),token,OffsetDateTime.now().plusHours(1));name="test."+UUID.randomUUID().toString().substring(0,12);dni=String.valueOf(10000000+Math.floorMod(UUID.randomUUID().hashCode(),89999999));role=jdbc.queryForObject("select id_rol from huaman.rol where codigo='VEN'",Long.class);}
 Input input(){return new Input(name,"Prueba","Temporal",dni,null,null,role,null,"Temporal12345");}
 @Test void updatesPermissionsRevokesSessionsAndAudits(){var user=service.create(actor,"INTEGRATION_ROLLBACK",input());UUID token=UUID.randomUUID();auth.createSession(user.id(),token,LocalDateTime.now(ZoneId.of("America/Lima")));var before=roles.get(actor,role);var codes=new ArrayList<>(before.asignados());codes.remove("VEN.DESCUENTO");var result=roles.save(actor,"INTEGRATION_ROLLBACK",role,new com.ferreteriahuaman.dto.RoleModels.Change(before.version(),codes));assertThat(result.rol().asignados()).doesNotContain("VEN.DESCUENTO");assertThat(result.rol().version()).isNotEqualTo(before.version());assertThat(auth.permissions(user.id())).doesNotContain("VEN.DESCUENTO");assertThat(jdbc.queryForObject("select count(*) from huaman.sesion_usuario where id_usuario=? and estado='A'",Long.class,user.id())).isZero();assertThat(jdbc.queryForObject("select count(*) from huaman.bitacora_evento where accion='SEG.ROL_PERMISOS' and pccre='INTEGRATION_ROLLBACK'",Long.class)).isPositive();}
 @Test void reactivatesAssociationWithoutDeletingHistory(){var before=roles.get(actor,role);var codes=new ArrayList<>(before.asignados());codes.remove("VEN.DESCUENTO");var removed=roles.save(actor,"INTEGRATION_ROLLBACK",role,new com.ferreteriahuaman.dto.RoleModels.Change(before.version(),codes));var restored=roles.save(actor,"INTEGRATION_ROLLBACK",role,new com.ferreteriahuaman.dto.RoleModels.Change(removed.rol().version(),before.asignados()));assertThat(restored.rol().asignados()).contains("VEN.DESCUENTO");assertThat(jdbc.queryForObject("select count(*) from huaman.rol_permiso rp join huaman.permiso p using(id_permiso) where id_rol=? and p.codigo='VEN.DESCUENTO'",Long.class,role)).isEqualTo(1);}
 @Test void staleRequestAndProtectedAdminDoNotChangePermissions(){var before=roles.get(actor,role);var codes=new ArrayList<>(before.asignados());codes.remove("VEN.DESCUENTO");roles.save(actor,"INTEGRATION_ROLLBACK",role,new com.ferreteriahuaman.dto.RoleModels.Change(before.version(),codes));assertThatThrownBy(()->roles.save(actor,"INTEGRATION_ROLLBACK",role,new com.ferreteriahuaman.dto.RoleModels.Change(before.version(),before.asignados()))).isInstanceOf(com.ferreteriahuaman.security.AuthFailure.class);long adm=jdbc.queryForObject("select id_rol from huaman.rol where codigo='ADM'",Long.class);var editor=roles.get(actor,adm);assertThatThrownBy(()->roles.save(actor,"INTEGRATION_ROLLBACK",adm,new com.ferreteriahuaman.dto.RoleModels.Change(editor.version(),editor.asignados()))).isInstanceOf(com.ferreteriahuaman.security.AuthFailure.class);}
}

package com.ferreteriahuaman.integration;

import com.ferreteriahuaman.service.CatalogService;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.security.AuthFailure;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

@SpringBootTest
@ActiveProfiles({"local","db"})
@Transactional
@EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class CatalogDatabaseTest {
 @Autowired CatalogService service;@Autowired AuthStore auth;@Autowired Environment env;@Autowired JdbcTemplate jdbc;
 Identity actor;String unique;
 @BeforeEach void prepare(){
  var user=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();
  auth.context(user.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();LocalDateTime now=LocalDateTime.now(ZoneId.of("America/Lima"));
  auth.createSession(user.id(),token,now);actor=new Identity(user.id(),user.username(),user.nombres(),user.apellidos(),user.rol(),false,auth.permissions(user.id()),token,OffsetDateTime.now().plusMinutes(30));
  unique="INTEGRACION_"+UUID.randomUUID().toString().substring(0,8);
 }
 @Test void categoryCrudAndAuditAreRolledBack(){
  Category created=service.createCategory(actor,"INTEGRATION_ROLLBACK",new CategoryInput(unique,"Solo transacción de prueba",null));
  assertThat(created.nombre()).isEqualTo(unique);
  Category edited=service.updateCategory(actor,"INTEGRATION_ROLLBACK",created.id(),new CategoryInput(unique+"_EDITADA","Actualizada",created.version()));
  assertThat(edited.descripcion()).isEqualTo("Actualizada");
  Category inactive=service.categoryState(actor,"INTEGRATION_ROLLBACK",created.id(),new StateInput("I",edited.version()));
  assertThat(inactive.estado()).isEqualTo("I");
  Category active=service.categoryState(actor,"INTEGRATION_ROLLBACK",created.id(),new StateInput("A",inactive.version()));
  assertThat(active.estado()).isEqualTo("A");
  assertThat(jdbc.queryForObject("select count(*) from huaman.bitacora_evento where entidad='categoria' and id_entidad=?",Long.class,created.id())).isEqualTo(4);
 }
 @Test void unitCreationAndStateChangesAreRolledBack(){
  Unit created=service.createUnit(actor,"INTEGRATION_ROLLBACK",new UnitInput(unique,"z9","Z9","Prueba transaccional",true,"PESO",new BigDecimal("0.001"),3,null));
  assertThat(created.factorReferencia()).isEqualByComparingTo("0.001");
  Unit inactive=service.unitState(actor,"INTEGRATION_ROLLBACK",created.id(),new StateInput("I",created.version()));
  assertThat(inactive.estado()).isEqualTo("I");
  Unit active=service.unitState(actor,"INTEGRATION_ROLLBACK",created.id(),new StateInput("A",inactive.version()));
  assertThat(active.estado()).isEqualTo("A");
 }
 @Test void staleVersionIsRejectedAgainstRealDatabase(){
  Category created=service.createCategory(actor,"INTEGRATION_ROLLBACK",new CategoryInput(unique,null,null));
  assertThatThrownBy(()->service.updateCategory(actor,"INTEGRATION_ROLLBACK",created.id(),new CategoryInput("Otra",null,created.version().minusSeconds(1)))).isInstanceOf(AuthFailure.class);
 }
 @Test void literalSearchDoesNotTreatUnderscoreAsWildcard(){
  service.createCategory(actor,"INTEGRATION_ROLLBACK",new CategoryInput(unique,null,null));
  assertThat(service.categories(unique,"",0,20).items()).hasSize(1);
  assertThat(service.categories("%NO_EXISTE%","",0,20).items()).isEmpty();
 }
}

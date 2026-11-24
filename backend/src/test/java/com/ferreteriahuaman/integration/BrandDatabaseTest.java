package com.ferreteriahuaman.integration;
import com.ferreteriahuaman.service.BrandService;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import java.awt.image.BufferedImage;import java.io.*;import java.sql.SQLException;import java.time.*;import java.util.*;import javax.imageio.ImageIO;
import org.junit.jupiter.api.*;import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.context.SpringBootTest;import org.springframework.core.env.Environment;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.test.context.ActiveProfiles;import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;
@SpringBootTest @ActiveProfiles({"local","db"}) @Transactional @EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class BrandDatabaseTest {
 @Autowired BrandService service;@Autowired AuthStore auth;@Autowired JdbcTemplate jdbc;@Autowired Environment env;Identity actor;
 @BeforeEach void setup(){var user=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();auth.context(user.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();auth.createSession(user.id(),token,LocalDateTime.now(ZoneId.of("America/Lima")));actor=new Identity(user.id(),user.username(),user.nombres(),user.apellidos(),user.rol(),false,auth.permissions(user.id()),token,OffsetDateTime.now().plusHours(1));}
 String png()throws Exception{var bytes=new ByteArrayOutputStream();ImageIO.write(new BufferedImage(20,10,BufferedImage.TYPE_INT_ARGB),"png",bytes);return Base64.getEncoder().encodeToString(bytes.toByteArray());}
 @Test void uploadFaviconChoiceAndRemovalPersistAtomicallyWithoutAuditingBytes()throws Exception{
  var initial=service.get();String image=png();var uploaded=service.save(actor,"INTEGRATION_ROLLBACK",new BrandService.Change(image,false,false,initial.version()));
  assertThat(uploaded.logoRuta()).matches("/api/identidad-visual/logo/[0-9a-f]{64}");assertThat(uploaded.usarLogoComoFavicon()).isFalse();assertThat(uploaded.version()).isNotNull();
  String hash=uploaded.logoRuta().substring(uploaded.logoRuta().lastIndexOf('/')+1);var decoded=ImageIO.read(new ByteArrayInputStream(service.image(hash)));assertThat(decoded.getWidth()).isEqualTo(256);
  var enabled=service.save(actor,"INTEGRATION_ROLLBACK",new BrandService.Change(null,false,true,uploaded.version()));assertThat(enabled.usarLogoComoFavicon()).isTrue();assertThat(enabled.logoRuta()).isEqualTo(uploaded.logoRuta());
  var removed=service.save(actor,"INTEGRATION_ROLLBACK",new BrandService.Change(null,true,false,enabled.version()));assertThat(removed.logoRuta()).isNull();assertThat(removed.usarLogoComoFavicon()).isFalse();
  assertThat(jdbc.queryForObject("select logo_png is null and logo_sha256 is null and not usar_logo_favicon from huaman.identidad_visual where id=1",Boolean.class)).isTrue();
  assertThat(jdbc.queryForObject("select string_agg(coalesce(valor_nuevo::text,''),'') from huaman.bitacora_evento where entidad='identidad_visual'",String.class)).doesNotContain(image,"imagenBase64");
 }
 @Test void staleVersionCannotReplaceExistingLogo()throws Exception{var before=service.get();var saved=service.save(actor,"INTEGRATION_ROLLBACK",new BrandService.Change(png(),false,false,before.version()));assertThatThrownBy(()->service.save(actor,"INTEGRATION_ROLLBACK",new BrandService.Change(null,true,false,saved.version().minusSeconds(1)))).isInstanceOfSatisfying(AuthFailure.class,e->assertThat(e.status()).isEqualTo(409));assertThat(service.get().logoRuta()).isEqualTo(saved.logoRuta());}
 @Test void directAnonymousDatabaseReadIsDeniedAndAdministratorNameIsInclusive()throws Exception{
  assertThat(jdbc.queryForObject("select nombre from huaman.rol where codigo='ADM'",String.class)).isEqualTo("Administrador/a");
  try(var connection=jdbc.getDataSource().getConnection();var statement=connection.createStatement()){
   try{statement.execute("set role anon");assertThatThrownBy(()->statement.executeQuery("select * from huaman.identidad_visual")).isInstanceOfSatisfying(SQLException.class,e->assertThat(e.getSQLState()).isEqualTo("42501"));}
   finally{statement.execute("reset role");}
  }
 }
}

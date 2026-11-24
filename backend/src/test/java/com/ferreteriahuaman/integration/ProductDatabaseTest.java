package com.ferreteriahuaman.integration;
import com.ferreteriahuaman.service.*;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.CatalogModels.StateInput;
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

@SpringBootTest @ActiveProfiles({"local","db"}) @Transactional
@EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class ProductDatabaseTest {
 @Autowired ProductImageService images;@Autowired ProductService service;@Autowired AuthStore auth;@Autowired Environment env;@Autowired JdbcTemplate jdbc;
 Identity actor;String code;long category,unit;
 BigDecimal n(String value){return new BigDecimal(value);}
 @BeforeEach void prepare(){var user=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();auth.context(user.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();auth.createSession(user.id(),token,LocalDateTime.now(ZoneId.of("America/Lima")));actor=new Identity(user.id(),user.username(),user.nombres(),user.apellidos(),user.rol(),false,auth.permissions(user.id()),token,OffsetDateTime.now().plusMinutes(30));code="INTEGRACION_"+UUID.randomUUID().toString().substring(0,8).toUpperCase();category=jdbc.queryForObject("select min(id_categoria) from huaman.categoria where estado='A'",Long.class);unit=jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat='KGM'",Long.class);}
 ProductInput input(){return new ProductInput(code,"Producto transaccional",null,category,unit,true,n("0.001"),n("0.001"),"GRANEL",n("0"),null,"Kilogramo",n("10"),null);}
 Product create(){return service.create(actor,"INTEGRATION_ROLLBACK",input());}
 @Test void createsProductAndRequiredBaseAtomically(){var p=create();jdbc.execute("set constraints all immediate");var d=service.details(actor,p.id());assertThat(d.presentaciones()).hasSize(1);assertThat(d.presentaciones().getFirst().esBase()).isTrue();assertThat(p.stockActual()).isEqualTo("0.000000");assertThat(p.costoPromedio()).isEqualTo("0.000000");assertThat(service.list(actor,code,"",null,0,20).items()).hasSize(1);}
 @Test void pagedCatalogPreservesStableOrderingFiltersAndCostVisibility(){
  var a=service.create(actor,"INTEGRATION_ROLLBACK",new ProductInput(code+"A","Página "+code+" A",null,category,unit,true,n("0.001"),n("0.001"),"GRANEL",n("0"),null,"Kilogramo",n("10"),null));
  var b=service.create(actor,"INTEGRATION_ROLLBACK",new ProductInput(code+"B","Página "+code+" A",null,category,unit,true,n("0.001"),n("0.001"),"GRANEL",n("0"),null,"Kilogramo",n("10"),null));
  var inactive=service.create(actor,"INTEGRATION_ROLLBACK",new ProductInput(code+"Z","Página "+code+" Z",null,category,unit,true,n("0.001"),n("0.001"),"GRANEL",n("0"),null,"Kilogramo",n("10"),null));
  service.state(actor,"INTEGRATION_ROLLBACK",inactive.id(),new StateInput("I",inactive.version()));
  long otherCategory=jdbc.queryForObject("insert into huaman.categoria(nombre) values(?) returning id_categoria",Long.class,"Categoría "+code);
  var other=service.create(actor,"INTEGRATION_ROLLBACK",new ProductInput(code+"C","Página "+code+" B",null,otherCategory,unit,true,n("0.001"),n("0.001"),"GRANEL",n("0"),null,"Kilogramo",n("10"),null));
  var first=service.list(actor,code,"A",category,0,1);var second=service.list(actor,code,"A",category,1,1);
  assertThat(first.total()).isEqualTo(2);assertThat(first.items()).extracting(Product::id).containsExactly(a.id());
  assertThat(second.total()).isEqualTo(2);assertThat(second.items()).extracting(Product::id).containsExactly(b.id());
  assertThat(service.list(actor,code,"A",category,2,1).items()).isEmpty();
  assertThat(service.list(actor,code,"",category,0,20).items()).extracting(Product::id).containsExactly(a.id(),b.id(),inactive.id());
  assertThat(service.list(actor,code,"I",category,0,20).items()).extracting(Product::id).containsExactly(inactive.id());
  assertThat(service.list(actor,code,"A",otherCategory,0,20).items()).extracting(Product::id).containsExactly(other.id());
  var reader=new Identity(actor.id(),actor.usuario(),actor.nombres(),actor.apellidos(),"VEN",false,Set.of("PRO.VER"),actor.sessionToken(),actor.expiraEn());
  assertThat(service.list(reader,code,"A",category,0,20).items()).allSatisfy(p->{assertThat(p.costoPromedio()).isNull();assertThat(p.ultimoCostoCompra()).isNull();});
  assertThat(first.items().getFirst().costoPromedio()).isNotNull();jdbc.execute("set constraints all immediate");
 }
 @Test void fractionsWholesaleBarcodeAndSearchRespectEquivalentUnits(){var p=create();long grams=jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat='GRM'",Long.class);var pres=service.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),null,new PresentationInput("Gramo",grams,n("0.001"),true,false,n("1"),n("1"),n("0.05"),null));var rule=service.saveWholesale(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),null,new WholesaleInput(n("100"),n("0.04"),null));assertThat(rule.cantidadMinima()).isEqualTo("100.000000");var barcode=service.createBarcode(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),new BarcodeInput(code+"-B","CODE128"));assertThat(service.list(actor,barcode.codigo(),"",null,0,20).items()).hasSize(1);jdbc.execute("set constraints all immediate");}
 @Test void hidesCostsFromReadersAndRejectsStaleVersion(){var p=create();var reader=new Identity(actor.id(),actor.usuario(),actor.nombres(),actor.apellidos(),"VEN",false,Set.of("PRO.VER"),actor.sessionToken(),actor.expiraEn());assertThat(service.details(reader,p.id()).producto().costoPromedio()).isNull();assertThat(service.details(reader,p.id()).producto().ultimoCostoCompra()).isNull();assertThatThrownBy(()->service.state(actor,"INTEGRATION_ROLLBACK",p.id(),new StateInput("I",p.version().minusSeconds(1)))).isInstanceOf(AuthFailure.class);}
 @Test void preventsHistoricalReinterpretationAndOversizedDiscount(){var p=create();var i=input();assertThatThrownBy(()->service.update(actor,"INTEGRATION_ROLLBACK",p.id(),new ProductInput(i.codigo(),i.nombre(),null,category,unit,true,n("0.01"),n("0.01"),"GRANEL",n("0"),null,null,null,p.version()))).isInstanceOf(AuthFailure.class);var base=service.details(actor,p.id()).presentaciones().getFirst();assertThatThrownBy(()->service.saveWholesale(actor,"INTEGRATION_ROLLBACK",p.id(),base.id(),null,new WholesaleInput(n("100"),n("11"),null))).isInstanceOf(AuthFailure.class);}
 @Test void editAndStateChangesKeepAuditAndBase(){var p=create();var i=input();var edited=service.update(actor,"INTEGRATION_ROLLBACK",p.id(),new ProductInput(i.codigo(),"Nombre actualizado",null,category,unit,true,n("0.001"),n("0.001"),"GRANEL",n("1"),"Estante",null,null,p.version()));assertThat(edited.nombre()).isEqualTo("Nombre actualizado");var inactive=service.state(actor,"INTEGRATION_ROLLBACK",p.id(),new StateInput("I",edited.version()));assertThat(inactive.estado()).isEqualTo("I");var active=service.state(actor,"INTEGRATION_ROLLBACK",p.id(),new StateInput("A",inactive.version()));assertThat(active.estado()).isEqualTo("A");assertThat(jdbc.queryForObject("select count(*) from huaman.bitacora_evento where entidad='producto' and id_entidad=?",Long.class,p.id())).isEqualTo(4);jdbc.execute("set constraints all immediate");}
 @Test void editsPresentationWholesaleAndCodeStatesWithoutDeletingHistory(){
  var p=create();var pres=service.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),null,new PresentationInput("Bolsa",null,n("5"),true,false,n("1"),n("1"),n("40"),null));
  pres=service.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),new PresentationInput("Bolsa 5 kg",null,n("5"),true,false,n("1"),n("1"),n("45"),pres.version()));assertThat(pres.nombre()).isEqualTo("Bolsa 5 kg");
  var w=service.saveWholesale(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),null,new WholesaleInput(n("10"),n("38"),null));w=service.saveWholesale(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),w.id(),new WholesaleInput(n("12"),n("37"),w.version()));assertThat(w.precio()).isEqualTo("37.000000");
  w=service.wholesaleState(actor,"INTEGRATION_ROLLBACK",p.id(),w.id(),new StateInput("I",w.version()));assertThat(w.estado()).isEqualTo("I");w=service.wholesaleState(actor,"INTEGRATION_ROLLBACK",p.id(),w.id(),new StateInput("A",w.version()));assertThat(w.estado()).isEqualTo("A");service.wholesaleState(actor,"INTEGRATION_ROLLBACK",p.id(),w.id(),new StateInput("I",w.version()));
  var b=service.createBarcode(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),new BarcodeInput(code+"-B","CODE128"));b=service.barcodeState(actor,"INTEGRATION_ROLLBACK",p.id(),b.id(),new StateInput("I",b.version()));assertThat(b.estado()).isEqualTo("I");b=service.barcodeState(actor,"INTEGRATION_ROLLBACK",p.id(),b.id(),new StateInput("A",b.version()));assertThat(b.estado()).isEqualTo("A");
  pres=service.presentationState(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),new StateInput("I",pres.version()));assertThat(pres.estado()).isEqualTo("I");pres=service.presentationState(actor,"INTEGRATION_ROLLBACK",p.id(),pres.id(),new StateInput("A",pres.version()));assertThat(pres.estado()).isEqualTo("A");jdbc.execute("set constraints all immediate");
 }

 @Test void imageUploadReadConflictRemovalAndCatalogAreAtomic()throws Exception{
  var p=create();assertThat(p.imagenHash()).isNull();var bytes=new java.io.ByteArrayOutputStream();javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(20,10,java.awt.image.BufferedImage.TYPE_INT_RGB),"png",bytes);String encoded=Base64.getEncoder().encodeToString(bytes.toByteArray());
  var initial=images.get(p.id());assertThat(initial.hash()).isNull();var uploaded=images.save(actor,"INTEGRATION_ROLLBACK",p.id(),new ProductImageService.Change(encoded,false,initial.version()));
  assertThat(uploaded.hash()).matches("[0-9a-f]{64}");assertThat(images.image(p.id(),uploaded.hash()).length).isBetween(1,65536);assertThat(service.details(actor,p.id()).producto().imagenHash()).isEqualTo(uploaded.hash());assertThat(service.list(actor,code,"",null,0,20).items().getFirst().imagenHash()).isEqualTo(uploaded.hash());
  assertThat(service.details(actor,p.id()).producto().version()).isEqualTo(p.version());
  assertThatThrownBy(()->images.save(actor,"INTEGRATION_ROLLBACK",p.id(),new ProductImageService.Change(null,true,uploaded.version().minusSeconds(1)))).isInstanceOfSatisfying(AuthFailure.class,e->assertThat(e.status()).isEqualTo(409));
  var removed=images.save(actor,"INTEGRATION_ROLLBACK",p.id(),new ProductImageService.Change(null,true,uploaded.version()));assertThat(removed.hash()).isNull();assertThatThrownBy(()->images.image(p.id(),uploaded.hash())).isInstanceOf(AuthFailure.class);
  assertThat(jdbc.queryForObject("select string_agg(coalesce(valor_nuevo::text,''),'') from huaman.bitacora_evento where entidad='producto_imagen' and id_entidad=?",String.class,p.id())).doesNotContain(encoded,"imagenBase64");jdbc.execute("set constraints all immediate");
 }
}

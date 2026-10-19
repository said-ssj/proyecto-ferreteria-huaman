package com.ferreteriahuaman.integration;
import com.ferreteriahuaman.service.*;import com.ferreteriahuaman.repository.*;import com.ferreteriahuaman.dto.SaleModels.*;import com.ferreteriahuaman.dto.SaleModels.Details;import com.ferreteriahuaman.dto.SaleModels.Line;import com.ferreteriahuaman.dto.CashModels.Open;import com.ferreteriahuaman.dto.ProductModels.*;import com.ferreteriahuaman.dto.PurchaseModels.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.security.AuthFailure;import java.math.BigDecimal;import java.time.*;import java.util.*;import org.junit.jupiter.api.*;import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;import org.springframework.beans.factory.annotation.Autowired;import org.springframework.boot.test.context.SpringBootTest;import org.springframework.core.env.Environment;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.test.context.ActiveProfiles;import org.springframework.transaction.annotation.Transactional;import static org.assertj.core.api.Assertions.*;
@SpringBootTest @ActiveProfiles({"local","db"}) @Transactional @EnabledIfEnvironmentVariable(named="HUAMAN_DB_INTEGRATION",matches="true")
class AuditWorkflowDatabaseTest {
 @Autowired ReturnService returns; @Autowired OfferService offers; @Autowired InventoryService inventory;@Autowired SaleService service;@Autowired ProductService products;@Autowired PurchaseService purchases;@Autowired CashService cash;@Autowired CatalogService catalog;@Autowired CustomerService customers;@Autowired AuthStore auth;@Autowired Environment env;@Autowired JdbcTemplate jdbc;Identity actor;long category;String unique;BigDecimal n(String s){return new BigDecimal(s);}
 @BeforeEach void setup(){Assumptions.assumeTrue(jdbc.queryForObject("select count(*) from huaman.caja_diaria where estado_caja='ABIERTA' or fecha=timezone('America/Lima',now())::date",Long.class)==0,"No interferir con cajas reales");var u=auth.lockUsername(env.getRequiredProperty("BOOTSTRAP_ADMIN_USUARIO")).orElseThrow();auth.context(u.username(),"INTEGRATION_ROLLBACK");UUID token=UUID.randomUUID();auth.createSession(u.id(),token,LocalDateTime.now(ZoneId.of("America/Lima")));actor=new Identity(u.id(),u.username(),u.nombres(),u.apellidos(),u.rol(),false,auth.permissions(u.id()),token,OffsetDateTime.now().plusMinutes(30));unique="INTEGRACION_"+UUID.randomUUID().toString().substring(0,8).toUpperCase();category=catalog.createCategory(actor,"INTEGRATION_ROLLBACK",new com.ferreteriahuaman.dto.CatalogModels.CategoryInput(unique,null,null)).id();cash.open(actor,"INTEGRATION_ROLLBACK",new Open(n("0"),null,UUID.randomUUID()));jdbc.update("update huaman.parametro_sistema set valor='Negocio de integración' where clave='NEGOCIO.RAZON_SOCIAL'");jdbc.update("update huaman.parametro_sistema set valor='20123456789' where clave='NEGOCIO.RUC'");jdbc.update("update huaman.parametro_sistema set valor='Dirección temporal 123' where clave='NEGOCIO.DIRECCION'");}
 Product product(String mode,String unitCode){long unit=jdbc.queryForObject("select id_unidad from huaman.unidad_medida where codigo_sunat=?",Long.class,unitCode);return products.create(actor,"INTEGRATION_ROLLBACK",new ProductInput(unique+mode.substring(0,1),"Producto "+mode,null,category,unit,true,n("0.001"),n("0.001"),mode,n("0"),null,"Base",n("10"),null));}
 long presentation(Product p){return products.details(actor,p.id()).presentaciones().getFirst().id();}
 long id(Details d){return ((Number)d.venta().get("id")).longValue();}
 Details create(long presentation,String qty,int pieces,String type,Long client){return service.create(actor,"INTEGRATION_ROLLBACK",new Create(client,type,true,UUID.randomUUID(),List.of(new Line(presentation,n(qty),pieces))));}
 long series(String type){return jdbc.queryForObject("select min(id_serie) from huaman.serie_comprobante where tipo_comprobante=? and estado='A'",Long.class,type);}
 Confirm request(Details d,List<Payment> payments,List<Assignment> assignments){return new Confirm(series(d.venta().get("tipo").toString()),LocalDateTime.parse(d.venta().get("version").toString()),payments,assignments);}
 Payment pay(String medium,String amount,String received,String operation){return new Payment(medium,n(amount),received==null?null:n(received),operation,null,null);}

 com.ferreteriahuaman.dto.ReturnModels.SolicitRequest returnRequest(Details sale,boolean auto,List<Map<String,Object>> units,String qty){
   long line=((Number)sale.lineas().getFirst().get("id")).longValue();
   return new com.ferreteriahuaman.dto.ReturnModels.SolicitRequest(id(sale),"EFECTIVO","Producto retornado por el comprador",List.of(new com.ferreteriahuaman.dto.ReturnModels.ReturnItemRequest(line,n(qty),"APTO",units)),UUID.randomUUID(),auto,auto?cash.current().caja().id():null,null,null);
 }
 Details paid(Product p,String qty,String total,List<Assignment> assignments){
   var d=create(presentation(p),qty,1,"N",null);
   return service.confirm(actor,"INTEGRATION_ROLLBACK",id(d),request(d,List.of(pay("EFECTIVO",total,total,null)),assignments));
 }
 @Test void returnedBulkUpdatesStockCashAndReplaysApproval(){
   var p=product("GRANEL","KGM");purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("10"),n("1"),UUID.randomUUID(),List.of()));
   var sale=paid(p,"1","10",List.of());
   assertThat(returns.getSaleDetail(actor,id(sale)).items()).hasSize(1);
   var req=returnRequest(sale,false,List.of(),"1");var pending=returns.solicitar(actor,"INTEGRATION_ROLLBACK",req);
   assertThat(returns.solicitar(actor,"INTEGRATION_ROLLBACK",req).cabecera().id()).isEqualTo(pending.cabecera().id());
   var approve=new com.ferreteriahuaman.dto.ReturnModels.ApproveRequest(cash.current().caja().id(),UUID.randomUUID(),null,"Producto recibido en buen estado");
   var result=returns.aprobar(actor,"INTEGRATION_ROLLBACK",pending.cabecera().id(),approve);
   assertThat(result.cabecera().estadoDevolucion()).isEqualTo("APROBADA");
   assertThat(returns.aprobar(actor,"INTEGRATION_ROLLBACK",pending.cabecera().id(),approve).cabecera().id()).isEqualTo(result.cabecera().id());
   assertThat(products.details(actor,p.id()).producto().stockActual()).isEqualTo("10.000000");assertThat(cash.current().caja().efectivo()).isEqualTo("0.00");
   assertThat(returns.detail(actor,result.cabecera().id()).items()).hasSize(1);
   jdbc.execute("set constraints all immediate");
   assertThatThrownBy(()->returns.aprobar(actor,"INTEGRATION_ROLLBACK",pending.cabecera().id(),new com.ferreteriahuaman.dto.ReturnModels.ApproveRequest(approve.cajaId(),approve.clave(),null,"Otra observación"))).isInstanceOf(AuthFailure.class);
 }
 @Test void autoApprovalReplaysWithoutRepeatingStockOrMoney(){
   var p=product("GRANEL","KGM");purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("10"),n("1"),UUID.randomUUID(),List.of()));var sale=paid(p,"1","10",List.of());
   var req=returnRequest(sale,true,List.of(),"1");var result=returns.solicitar(actor,"INTEGRATION_ROLLBACK",req);
   assertThat(result.cabecera().estadoDevolucion()).isEqualTo("APROBADA");assertThat(returns.solicitar(actor,"INTEGRATION_ROLLBACK",req).cabecera().id()).isEqualTo(result.cabecera().id());
   assertThat(jdbc.queryForObject("select count(*) from huaman.devolucion where id_venta=?",Long.class,id(sale))).isEqualTo(1);
   assertThat(products.details(actor,p.id()).producto().stockActual()).isEqualTo("10.000000");assertThat(cash.current().caja().efectivo()).isEqualTo("0.00");jdbc.execute("set constraints all immediate");
 }
 @Test void rejectionReplaysWithoutReturningStock(){
   var p=product("GRANEL","KGM");purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("10"),n("1"),UUID.randomUUID(),List.of()));var sale=paid(p,"1","10",List.of());var pending=returns.solicitar(actor,"INTEGRATION_ROLLBACK",returnRequest(sale,false,List.of(),"1"));
   var req=new com.ferreteriahuaman.dto.ReturnModels.RejectRequest(UUID.randomUUID(),"La revisión no autoriza el retorno");var result=returns.rechazar(actor,"INTEGRATION_ROLLBACK",pending.cabecera().id(),req);
   assertThat(result.cabecera().estadoDevolucion()).isEqualTo("RECHAZADA");assertThat(returns.rechazar(actor,"INTEGRATION_ROLLBACK",pending.cabecera().id(),req).cabecera().id()).isEqualTo(result.cabecera().id());
   assertThat(products.details(actor,p.id()).producto().stockActual()).isEqualTo("9.000000");assertThat(cash.current().caja().efectivo()).isEqualTo("10.00");jdbc.execute("set constraints all immediate");
 }
 @Test void intactBagReturnsWithItsPhysicalPresentation(){
   var p=product("ENVASES","KGM");var bag=products.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),null,new PresentationInput("Bolsa",null,n("50"),true,false,n("1"),n("1"),n("300"),null));
   purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("50"),n("1"),UUID.randomUUID(),List.of(new PhysicalUnit(unique,"ENVASE",n("50"),bag.id()))));long unit=purchases.existences(p.id(),0,20).items().getFirst().id();var d=create(bag.id(),"1",1,"N",null);long line=((Number)d.lineas().getFirst().get("id")).longValue();var sale=service.confirm(actor,"INTEGRATION_ROLLBACK",id(d),request(d,List.of(pay("EFECTIVO","300","300",null)),List.of(new Assignment(line,unit,1,n("50")))));
   assertThat(returns.getSaleDetail(actor,id(sale)).items().getFirst().presentacionesRetorno()).anyMatch(pr->pr.id()==bag.id());
   var result=returns.solicitar(actor,"INTEGRATION_ROLLBACK",returnRequest(sale,true,List.of(Map.of("condicion","ENVASE","cantidad",n("50"),"id_presentacion",bag.id())),"1"));
   assertThat(result.cabecera().estadoDevolucion()).isEqualTo("APROBADA");assertThat(products.details(actor,p.id()).producto().stockActual()).isEqualTo("50.000000");jdbc.execute("set constraints all immediate");
 }
 @Test void separateReturnedSegmentsRemainSeparatePhysicalUnits(){
   var p=product("TRAMOS","MTR");purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("10"),n("1"),UUID.randomUUID(),List.of(new PhysicalUnit(unique,"TRAMO",n("10"),presentation(p)))));long unit=purchases.existences(p.id(),0,20).items().getFirst().id();var d=create(presentation(p),"2",1,"N",null);long line=((Number)d.lineas().getFirst().get("id")).longValue();var sale=service.confirm(actor,"INTEGRATION_ROLLBACK",id(d),request(d,List.of(pay("EFECTIVO","20","20",null)),List.of(new Assignment(line,unit,1,n("2")))));
   var result=returns.solicitar(actor,"INTEGRATION_ROLLBACK",returnRequest(sale,true,List.of(Map.of("condicion","TRAMO","cantidad",n("0.5")),Map.of("condicion","TRAMO","cantidad",n("1.5"))),"2"));
   assertThat(result.cabecera().estadoDevolucion()).isEqualTo("APROBADA");assertThat(jdbc.queryForObject("select count(*) from huaman.unidad_existencia where id_detalle_devolucion=?",Long.class,result.items().getFirst().id())).isEqualTo(2);assertThat(products.details(actor,p.id()).producto().stockActual()).isEqualTo("10.000000");jdbc.execute("set constraints all immediate");
 }
 @Test void offersUsePresentationCostForBagsAndFractionsAndEnforceVersions(){
   var p=product("GRANEL","KGM");purchases.opening(actor,"INTEGRATION_ROLLBACK",new Opening(p.id(),n("100"),n("2"),UUID.randomUUID(),List.of()));
   var bag=products.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),null,new PresentationInput("Bolsa 50 kg",null,n("50"),true,false,n("1"),n("1"),n("300"),null));
   var small=products.savePresentation(actor,"INTEGRATION_ROLLBACK",p.id(),null,new PresentationInput("100 gramos",null,n("0.1"),true,false,n("1"),n("1"),n("1"),null));
   LocalDate day=LocalDate.now(ZoneId.of("America/Lima"));var created=offers.create(actor,"INTEGRATION_ROLLBACK",new com.ferreteriahuaman.dto.OfferModels.OfferCreateRequest(p.id(),small.id(),"Oferta porción",n("0.80"),day,day.plusDays(2)));
   assertThat(created.costoReferencial()).isEqualTo("0.20");
   var edited=offers.update(actor,"INTEGRATION_ROLLBACK",created.id(),new com.ferreteriahuaman.dto.OfferModels.OfferUpdateRequest("Oferta porción revisada",n("0.70"),day,day.plusDays(3),created.version()));
   var inactive=offers.changeState(actor,"INTEGRATION_ROLLBACK",edited.id(),new com.ferreteriahuaman.dto.OfferModels.OfferStateRequest("I",edited.version()));
   assertThat(offers.changeState(actor,"INTEGRATION_ROLLBACK",inactive.id(),new com.ferreteriahuaman.dto.OfferModels.OfferStateRequest("A",inactive.version())).estadoLogico()).isEqualTo("A");
   jdbc.execute("set constraints all immediate");
   assertThatThrownBy(()->offers.create(actor,"INTEGRATION_ROLLBACK",new com.ferreteriahuaman.dto.OfferModels.OfferCreateRequest(p.id(),bag.id(),"Bolsa bajo costo",n("20"),day,day.plusDays(1)))).isInstanceOf(AuthFailure.class).hasMessageContaining("costo");
   assertThatThrownBy(()->offers.update(actor,"INTEGRATION_ROLLBACK",created.id(),new com.ferreteriahuaman.dto.OfferModels.OfferUpdateRequest("Sin versión",n("0.60"),day,day.plusDays(2),null))).isInstanceOf(AuthFailure.class);
   assertThatThrownBy(()->offers.changeState(actor,"INTEGRATION_ROLLBACK",created.id(),new com.ferreteriahuaman.dto.OfferModels.OfferStateRequest("I",created.version().minusSeconds(1)))).isInstanceOf(AuthFailure.class);
 }
}

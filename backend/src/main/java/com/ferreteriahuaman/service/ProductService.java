package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.repository.*;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service @Profile("db")
public class ProductService {
 private final ProductRepository repo;private final CatalogRepository catalog;private final BusinessTransactions tx;private final ObjectMapper mapper;private final AuthStore auth;
 public ProductService(ProductRepository repo,CatalogRepository catalog,BusinessTransactions tx,ObjectMapper mapper,AuthStore auth){this.repo=repo;this.catalog=catalog;this.tx=tx;this.mapper=mapper;this.auth=auth;}
 private AuthFailure bad(String text){return new AuthFailure(400,text);}
 private void permission(Identity actor,String permission){if(!auth.permissions(actor.id()).contains(permission))throw new AuthFailure(403,"No tienes permiso para modificar precios");}
 private void version(LocalDateTime expected,LocalDateTime actual){if(expected==null)throw bad("Falta la versión del registro");if(!expected.equals(actual))throw new AuthFailure(409,"El registro cambió. Vuelve a cargarlo antes de guardar");}
 private void event(Identity actor,String action,String table,long id,Object before,Object after){try{catalog.event(actor.id(),action,table,id,before==null?null:mapper.writeValueAsString(before),mapper.writeValueAsString(after));}catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException("No se pudo registrar la auditoría");}}
 public Page<Product> list(Identity actor,String search,String state,Long category,int page,int size){if(search.length()>100||!state.matches("A|I|^$")||category!=null&&category<1||page<0||page>1000000||size<1||size>100)throw bad("Revisa los filtros y la paginación");return repo.list(search.strip(),state,category,page,size,actor.permisos().contains("PRO.COSTOS"));}
 private Product product(long id,boolean lock,boolean costs){return repo.get(id,lock,costs).orElseThrow(()->new AuthFailure(404,"Producto no encontrado"));}
 public Details details(Identity actor,long id){return new Details(product(id,false,actor.permisos().contains("PRO.COSTOS")),repo.presentations(id),repo.wholesale(id),repo.barcodes(id));}
 private BigDecimal number(String value){return new BigDecimal(value);}
 private void quantities(boolean fractions,BigDecimal increment,BigDecimal minimum){if(increment.signum()<=0||minimum.signum()<=0||minimum.remainder(increment).signum()!=0)throw bad("La cantidad mínima debe ser múltiplo del incremento permitido");if(!fractions&&(increment.stripTrailingZeros().scale()>0||minimum.stripTrailingZeros().scale()>0))throw bad("Las cantidades deben ser enteras cuando no se admiten fracciones");}
 private void validate(ProductInput i){
  var category=catalog.category(i.categoriaId(),true).orElseThrow(()->bad("Selecciona una categoría existente"));if(!category.estado().equals("A"))throw bad("Selecciona una categoría activa");
  var unit=catalog.unit(i.unidadId(),true).orElseThrow(()->bad("Selecciona una unidad existente"));if(!unit.estado().equals("A"))throw bad("Selecciona una unidad activa");
  quantities(i.admiteFracciones(),i.incrementoBase(),i.minimoVentaBase());if(i.admiteFracciones()&&!unit.admiteDecimales())throw bad("La unidad base no admite decimales");
  if(i.incrementoBase().remainder(BigDecimal.ONE.scaleByPowerOfTen(-unit.precisionCantidad())).signum()!=0)throw bad("El incremento supera la precisión de la unidad");
  if(!i.admiteFracciones()&&i.stockMinimo().stripTrailingZeros().scale()>0)throw bad("El stock mínimo debe ser entero");
  if(i.modoControl().equals("TRAMOS")&&!unit.magnitud().equals("LONGITUD"))throw bad("El control por tramos requiere una unidad de longitud");
 }
 public Product create(Identity actor,String equipo,ProductInput i){return tx.write(actor,equipo,"PRO.GESTIONAR",()->{
  permission(actor,"PRO.PRECIOS");validate(i);if(i.nombreBase()==null||i.nombreBase().isBlank()||i.precioBase()==null)throw bad("Indica el nombre y precio de la presentación base");
  repo.lockCodes();if(repo.barcodeCollision(i.codigo()))throw new AuthFailure(409,"El código ya está utilizado");
  long id=repo.create(i);long base=repo.createPresentation(id,new PresentationInput(i.nombreBase(),i.unidadId(),BigDecimal.ONE,true,i.admiteFracciones(),i.incrementoBase(),i.minimoVentaBase(),i.precioBase(),null),true);
  var result=product(id,false,true);event(actor,"PRO.CREAR","producto",id,null,result);event(actor,"PRO.PRESENTACION_CREAR","presentacion_producto",base,null,repo.presentation(base,false).orElseThrow());return product(id,false,actor.permisos().contains("PRO.COSTOS"));
 });}
 public Product update(Identity actor,String equipo,long id,ProductInput i){return tx.write(actor,equipo,"PRO.GESTIONAR",()->{
  var before=product(id,true,true);version(i.version(),before.version());validate(i);
  if(before.unidadId()!=i.unidadId()||!before.modoControl().equals(i.modoControl())||before.admiteFracciones()!=i.admiteFracciones()||number(before.incrementoBase()).compareTo(i.incrementoBase())!=0)throw new AuthFailure(409,"La unidad, el control y el incremento base son históricos y no pueden reinterpretarse");
  if(i.precioBase()!=null||i.nombreBase()!=null)throw bad("Edita el precio desde Presentaciones y precios");
  for(var p:repo.presentations(id))if(p.estado().equals("A")&&number(p.minimoVenta()).multiply(number(p.factorBase())).compareTo(i.minimoVentaBase())<0)throw bad("El mínimo supera el permitido por una presentación activa");
  repo.lockCodes();if(!before.codigo().equals(i.codigo())&&repo.barcodeCollision(i.codigo()))throw new AuthFailure(409,"El código ya está utilizado");
  repo.update(id,i);var result=product(id,false,true);event(actor,"PRO.EDITAR","producto",id,before,result);return product(id,false,actor.permisos().contains("PRO.COSTOS"));
 });}
 public Product state(Identity actor,String equipo,long id,StateInput i){return tx.write(actor,equipo,"PRO.INACTIVAR",()->{
  var before=product(id,true,true);version(i.version(),before.version());if(before.estado().equals(i.estado()))return product(id,false,actor.permisos().contains("PRO.COSTOS"));
  if(i.estado().equals("A")){
   if(!catalog.category(before.categoriaId(),true).orElseThrow().estado().equals("A"))throw bad("Activa primero la categoría");
   if(repo.presentations(id).stream().noneMatch(p->p.esBase()&&p.estado().equals("A")))throw bad("Activa primero la presentación base");
  }
  repo.state(id,i.estado());event(actor,"PRO.ESTADO","producto",id,before,product(id,false,true));return product(id,false,actor.permisos().contains("PRO.COSTOS"));
 });}
 private Presentation presentation(long id,boolean lock){return repo.presentation(id,lock).orElseThrow(()->new AuthFailure(404,"Presentación no encontrada"));}
 private void validatePresentation(Product p,PresentationInput i){
  quantities(i.admiteFracciones(),i.incrementoVenta(),i.minimoVenta());
  if(i.unidadVentaId()!=null){var u=catalog.unit(i.unidadVentaId(),true).orElseThrow(()->bad("Unidad de venta no encontrada"));var base=catalog.unit(p.unidadId(),false).orElseThrow();
   if(!u.estado().equals("A")||!u.magnitud().equals(base.magnitud()))throw bad("La unidad de venta no es compatible con la unidad base");
   if(i.factorBase().multiply(base.factorReferencia()).compareTo(u.factorReferencia())!=0)throw bad("La equivalencia no coincide con las unidades seleccionadas");
   if(i.admiteFracciones()&&!u.admiteDecimales()||i.incrementoVenta().remainder(BigDecimal.ONE.scaleByPowerOfTen(-u.precisionCantidad())).signum()!=0)throw bad("La cantidad supera la precisión de la unidad de venta");
  }
  if(i.incrementoVenta().multiply(i.factorBase()).remainder(number(p.incrementoBase())).signum()!=0||i.minimoVenta().multiply(i.factorBase()).compareTo(number(p.minimoVentaBase()))<0)throw bad("Las cantidades no respetan el incremento o mínimo del producto");
 }
 public Presentation savePresentation(Identity actor,String equipo,long product,Long id,PresentationInput i){return tx.write(actor,equipo,"PRO.PRESENTACIONES",()->{
  var p=product(product,true,true);Presentation before=id==null?null:presentation(id,true);if(before!=null){if(before.productoId()!=product)throw bad("La presentación no pertenece al producto");version(i.version(),before.version());
   if(!Objects.equals(before.unidadVentaId(),i.unidadVentaId())||number(before.factorBase()).compareTo(i.factorBase())!=0)throw new AuthFailure(409,"La equivalencia es histórica. Crea otra presentación");
   if(before.esBase()&&!i.permiteVenta())throw bad("La presentación base debe permitir la venta");
  }
  if(before==null||number(before.precioNormal()).compareTo(i.precioNormal())!=0)permission(actor,"PRO.PRECIOS");
  validatePresentation(p,i);
  if(id!=null)for(var w:repo.wholesale(product))if(w.presentacionId()==id&&w.estado().equals("A")&&(number(w.precio()).compareTo(i.precioNormal())>0||number(w.cantidadMinima()).compareTo(i.minimoVenta())<0||number(w.cantidadMinima()).remainder(i.incrementoVenta()).signum()!=0||!i.permiteVenta()))throw bad("Ajusta primero las reglas mayoristas activas");
  long saved;if(id==null)saved=repo.createPresentation(product,i,false);else{repo.updatePresentation(id,i);saved=id;}
  var result=presentation(saved,false);event(actor,"PRO.PRESENTACION_GUARDAR","presentacion_producto",saved,before,result);return result;
 });}
 public Presentation presentationState(Identity actor,String equipo,long product,long id,StateInput i){return tx.write(actor,equipo,"PRO.PRESENTACIONES",()->{
  var p=product(product,true,true);var before=presentation(id,true);if(before.productoId()!=product)throw bad("La presentación no pertenece al producto");version(i.version(),before.version());
  if(before.estado().equals(i.estado()))return before;
  if(i.estado().equals("I")&&(before.esBase()&&p.estado().equals("A")))throw bad("Un producto activo requiere su presentación base activa");
  if(i.estado().equals("I")&&repo.wholesale(product).stream().anyMatch(w->w.presentacionId()==id&&w.estado().equals("A")))throw bad("Desactiva primero las reglas mayoristas de esta presentación");
  repo.presentationState(id,i.estado());var result=presentation(id,false);event(actor,"PRO.PRESENTACION_ESTADO","presentacion_producto",id,before,result);return result;
 });}
 public Wholesale saveWholesale(Identity actor,String equipo,long product,long presentation,Long id,WholesaleInput i){return tx.write(actor,equipo,"PRO.MAYORISTA",()->{
  product(product,true,true);var p=presentation(presentation,true);if(p.productoId()!=product)throw bad("La presentación no pertenece al producto");
  Wholesale before=id==null?null:repo.wholesaleById(id).orElseThrow(()->new AuthFailure(404,"Regla no encontrada"));if(before!=null){if(before.presentacionId()!=presentation)throw bad("La regla no pertenece a la presentación");version(i.version(),before.version());}
  validateWholesale(p,i);
  long saved;if(id==null)saved=repo.createWholesale(presentation,i);else{repo.updateWholesale(id,i);saved=id;}
  var result=repo.wholesaleById(saved).orElseThrow();event(actor,"PRO.MAYORISTA_GUARDAR","precio_mayorista",saved,before,result);return result;
 });}
 private void validateWholesale(Presentation p,WholesaleInput i){if(!p.estado().equals("A")||!p.permiteVenta())throw bad("La presentación no está disponible para venta");if(i.precio().compareTo(number(p.precioNormal()))>0)throw bad("El precio mayorista no puede superar el precio normal");if(i.cantidadMinima().compareTo(number(p.minimoVenta()))<0||i.cantidadMinima().remainder(number(p.incrementoVenta())).signum()!=0)throw bad("El mínimo mayorista no respeta las cantidades permitidas");}
 public Wholesale wholesaleState(Identity actor,String equipo,long product,long id,StateInput i){return tx.write(actor,equipo,"PRO.MAYORISTA",()->{
  product(product,true,true);var before=repo.wholesaleById(id).orElseThrow(()->new AuthFailure(404,"Regla no encontrada"));var p=presentation(before.presentacionId(),true);if(p.productoId()!=product)throw bad("La regla no pertenece al producto");version(i.version(),before.version());if(before.estado().equals(i.estado()))return before;
  if(i.estado().equals("A"))validateWholesale(p,new WholesaleInput(number(before.cantidadMinima()),number(before.precio()),null));repo.wholesaleState(id,i.estado());var result=repo.wholesaleById(id).orElseThrow();event(actor,"PRO.MAYORISTA_ESTADO","precio_mayorista",id,before,result);return result;
 });}
 public Barcode createBarcode(Identity actor,String equipo,long product,long presentation,BarcodeInput i){return tx.write(actor,equipo,"PRO.PRESENTACIONES",()->{
  product(product,true,true);var p=presentation(presentation,true);if(p.productoId()!=product)throw bad("La presentación no pertenece al producto");validateBarcode(i);repo.lockCodes();if(repo.barcodeCollision(i.codigo()))throw new AuthFailure(409,"El código ya está utilizado");long id=repo.createBarcode(presentation,i);var result=repo.barcode(id).orElseThrow();event(actor,"PRO.CODIGO_CREAR","codigo_presentacion",id,null,result);return result;
 });}
 public static void validateBarcode(BarcodeInput i){if(i.simbologia().equals("EAN13")){if(!i.codigo().matches("[0-9]{13}"))throw new AuthFailure(400,"EAN-13 requiere 13 dígitos");int sum=0;for(int n=0;n<12;n++)sum+=(i.codigo().charAt(n)-'0')*(n%2==0?1:3);if((10-sum%10)%10!=i.codigo().charAt(12)-'0')throw new AuthFailure(400,"El dígito verificador EAN-13 es incorrecto");}else if(!i.codigo().matches("[!-~][ -~]{0,79}")||!i.codigo().equals(i.codigo().strip()))throw new AuthFailure(400,"Code 128 requiere caracteres imprimibles sin espacios exteriores");}
 public Barcode barcodeState(Identity actor,String equipo,long product,long id,StateInput i){return tx.write(actor,equipo,"PRO.PRESENTACIONES",()->{
  product(product,true,true);var before=repo.barcode(id).orElseThrow(()->new AuthFailure(404,"Código no encontrado"));if(presentation(before.presentacionId(),true).productoId()!=product)throw bad("El código no pertenece al producto");version(i.version(),before.version());if(before.estado().equals(i.estado()))return before;repo.barcodeState(id,i.estado());var result=repo.barcode(id).orElseThrow();event(actor,"PRO.CODIGO_ESTADO","codigo_presentacion",id,before,result);return result;
 });}
}

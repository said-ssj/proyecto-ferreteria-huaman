package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.PurchaseModels.*;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.repository.PurchaseRepository.Kind;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.PurchaseService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api")
public class PurchaseController {
 private final PurchaseService service;public PurchaseController(PurchaseService service){this.service=service;}
 private Kind kind(String type){return switch(type){case "ordenes"->Kind.ORDER;case "ingresos"->Kind.RECEIPT;default->throw new AuthFailure(404,"Tipo de documento no encontrado");};}
 @GetMapping("/proveedores") public Page<Supplier> suppliers(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.suppliers(buscar,estado,pagina,tamano);}
 @GetMapping("/proveedores/{id}") public Supplier supplier(@PathVariable long id){return service.supplier(id);}
 @PostMapping("/proveedores") @ResponseStatus(HttpStatus.CREATED) public Supplier supplier(@AuthenticationPrincipal Identity a,@Valid @RequestBody SupplierInput i,HttpServletRequest r){return service.saveSupplier(a,r.getRemoteAddr(),null,i);}
 @PutMapping("/proveedores/{id}") public Supplier supplier(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody SupplierInput i,HttpServletRequest r){return service.saveSupplier(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/proveedores/{id}/estado") public Supplier supplierState(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.supplierState(a,r.getRemoteAddr(),id,i);}
 @GetMapping("/compras/{tipo}") public Page<Document> list(@PathVariable String tipo,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(required=false)Long proveedor,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(kind(tipo),buscar,estado,proveedor,pagina,tamano);}
 @GetMapping("/compras/{tipo}/{id}") public Details details(@PathVariable String tipo,@PathVariable long id){return service.details(kind(tipo),id);}
 @PostMapping("/compras/{tipo}") @ResponseStatus(HttpStatus.CREATED) public Details create(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@Valid @RequestBody DocumentInput i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),kind(tipo),null,i);}
 @PutMapping("/compras/{tipo}/{id}") public Details update(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long id,@Valid @RequestBody DocumentInput i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),kind(tipo),id,i);}
 @PostMapping("/compras/{tipo}/{doc}/lineas") @ResponseStatus(HttpStatus.CREATED) public Details line(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long doc,@Valid @RequestBody LineInput i,HttpServletRequest r){return service.saveLine(a,r.getRemoteAddr(),kind(tipo),doc,null,i);}
 @PutMapping("/compras/{tipo}/{doc}/lineas/{id}") public Details line(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long doc,@PathVariable long id,@Valid @RequestBody LineInput i,HttpServletRequest r){return service.saveLine(a,r.getRemoteAddr(),kind(tipo),doc,id,i);}
 @PatchMapping("/compras/{tipo}/{doc}/lineas/{id}/estado") public Details lineState(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long doc,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.lineState(a,r.getRemoteAddr(),kind(tipo),doc,id,i);}
 @PostMapping("/compras/{tipo}/{id}/procesar") public Details process(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long id,@Valid @RequestBody Action i,HttpServletRequest r){return service.process(a,r.getRemoteAddr(),kind(tipo),id,i,false);}
 @PostMapping("/compras/{tipo}/{id}/anular") public Details cancel(@AuthenticationPrincipal Identity a,@PathVariable String tipo,@PathVariable long id,@Valid @RequestBody Action i,HttpServletRequest r){return service.process(a,r.getRemoteAddr(),kind(tipo),id,i,true);}
 @PostMapping("/inventario/apertura") public OpeningResult opening(@AuthenticationPrincipal Identity a,@Valid @RequestBody Opening i,HttpServletRequest r){return service.opening(a,r.getRemoteAddr(),i);}
 @GetMapping("/inventario/{producto}/movimientos") public Page<Movement> movements(@AuthenticationPrincipal Identity a,@PathVariable long producto,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.movements(a,producto,pagina,tamano);}
 @GetMapping("/inventario/{producto}/existencias") public Page<Existence> existences(@PathVariable long producto,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.existences(producto,pagina,tamano);}
}

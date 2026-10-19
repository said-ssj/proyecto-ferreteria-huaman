package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.ProductService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @Profile("db") @RequestMapping("/api/productos")
public class ProductController {
 private final ProductService service;public ProductController(ProductService service){this.service=service;}
 @GetMapping public Page<Product> list(@AuthenticationPrincipal Identity actor,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(required=false)Long categoria,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(actor,buscar,estado,categoria,pagina,tamano);}
 @GetMapping("/{id}") public Details details(@AuthenticationPrincipal Identity actor,@PathVariable long id){return service.details(actor,id);}
 @PostMapping @ResponseStatus(HttpStatus.CREATED) public Product create(@AuthenticationPrincipal Identity a,@Valid @RequestBody ProductInput i,HttpServletRequest r){return service.create(a,r.getRemoteAddr(),i);}
 @PutMapping("/{id}") public Product update(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody ProductInput i,HttpServletRequest r){return service.update(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/{id}/estado") public Product state(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.state(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{producto}/presentaciones") @ResponseStatus(HttpStatus.CREATED) public Presentation presentation(@AuthenticationPrincipal Identity a,@PathVariable long producto,@Valid @RequestBody PresentationInput i,HttpServletRequest r){return service.savePresentation(a,r.getRemoteAddr(),producto,null,i);}
 @PutMapping("/{producto}/presentaciones/{id}") public Presentation presentation(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long id,@Valid @RequestBody PresentationInput i,HttpServletRequest r){return service.savePresentation(a,r.getRemoteAddr(),producto,id,i);}
 @PatchMapping("/{producto}/presentaciones/{id}/estado") public Presentation presentationState(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.presentationState(a,r.getRemoteAddr(),producto,id,i);}
 @PostMapping("/{producto}/presentaciones/{presentacion}/mayoristas") @ResponseStatus(HttpStatus.CREATED) public Wholesale wholesale(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long presentacion,@Valid @RequestBody WholesaleInput i,HttpServletRequest r){return service.saveWholesale(a,r.getRemoteAddr(),producto,presentacion,null,i);}
 @PutMapping("/{producto}/presentaciones/{presentacion}/mayoristas/{id}") public Wholesale wholesale(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long presentacion,@PathVariable long id,@Valid @RequestBody WholesaleInput i,HttpServletRequest r){return service.saveWholesale(a,r.getRemoteAddr(),producto,presentacion,id,i);}
 @PatchMapping("/{producto}/mayoristas/{id}/estado") public Wholesale wholesaleState(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.wholesaleState(a,r.getRemoteAddr(),producto,id,i);}
 @PostMapping("/{producto}/presentaciones/{presentacion}/codigos") @ResponseStatus(HttpStatus.CREATED) public Barcode barcode(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long presentacion,@Valid @RequestBody BarcodeInput i,HttpServletRequest r){return service.createBarcode(a,r.getRemoteAddr(),producto,presentacion,i);}
 @PatchMapping("/{producto}/codigos/{id}/estado") public Barcode barcodeState(@AuthenticationPrincipal Identity a,@PathVariable long producto,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.barcodeState(a,r.getRemoteAddr(),producto,id,i);}
}

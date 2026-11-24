package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.service.ProductImageService;
import com.ferreteriahuaman.repository.ProductImageRepository.Metadata;
import com.ferreteriahuaman.security.AuthModels.Identity;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/productos/{id}/imagen")
public class ProductImageController {
 private final ProductImageService service;public ProductImageController(ProductImageService service){this.service=service;}
 @GetMapping public ResponseEntity<Metadata> get(@PathVariable long id){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.get(id));}
 @GetMapping("/{hash}") public ResponseEntity<byte[]> image(@PathVariable long id,@PathVariable String hash){return ResponseEntity.ok().contentType(MediaType.IMAGE_JPEG).cacheControl(CacheControl.noStore()).header("X-Content-Type-Options","nosniff").body(service.image(id,hash));}
 @PutMapping public Metadata save(@PathVariable long id,@AuthenticationPrincipal Identity actor,@Valid @RequestBody ProductImageService.Change input,HttpServletRequest request){return service.save(actor,request.getRemoteAddr(),id,input);}
}

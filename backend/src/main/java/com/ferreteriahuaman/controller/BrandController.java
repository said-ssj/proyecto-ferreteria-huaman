package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.service.BrandService;
import com.ferreteriahuaman.security.AuthModels.Identity;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.concurrent.TimeUnit;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/identidad-visual")
public class BrandController {
 private final BrandService service;public BrandController(BrandService service){this.service=service;}
 @GetMapping public ResponseEntity<BrandService.Metadata> get(){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.get());}
 @GetMapping("/logo/{hash}") public ResponseEntity<byte[]> image(@PathVariable String hash){return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).cacheControl(CacheControl.maxAge(365,TimeUnit.DAYS).cachePublic().immutable()).header("X-Content-Type-Options","nosniff").body(service.image(hash));}
 @PutMapping public BrandService.Metadata save(@AuthenticationPrincipal Identity actor,@Valid @RequestBody BrandService.Change input,HttpServletRequest request){return service.save(actor,request.getRemoteAddr(),input);}
}

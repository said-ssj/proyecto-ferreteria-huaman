package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.SaleModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.SaleService;import java.util.*;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/ventas") public class SaleController {
 private final SaleService service;public SaleController(SaleService service){this.service=service;}
 @GetMapping("/opciones") public Map<String,Object> options(){return service.options();}
 @GetMapping("/borradores") public List<Map<String,Object>> drafts(@AuthenticationPrincipal Identity a){return service.drafts(a);}
 @GetMapping("/{id}") public Details detail(@AuthenticationPrincipal Identity a,@PathVariable long id){return service.details(a,id);}
 @PostMapping("/borradores") public Details create(@AuthenticationPrincipal Identity a,@Valid @RequestBody Create i,HttpServletRequest r){return service.create(a,r.getRemoteAddr(),i);}
 @PostMapping("/{id}/confirmar") public Details confirm(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Confirm i,HttpServletRequest r){return service.confirm(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{id}/descartar") public Details discard(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Discard i,HttpServletRequest r){return service.discard(a,r.getRemoteAddr(),id,i);}
 @GetMapping("/{id}/existencias") public Page<Map<String,Object>> units(@AuthenticationPrincipal Identity a,@PathVariable long id,@RequestParam long linea,@RequestParam(defaultValue="0")int pagina){return service.units(a,id,linea,pagina);}
}

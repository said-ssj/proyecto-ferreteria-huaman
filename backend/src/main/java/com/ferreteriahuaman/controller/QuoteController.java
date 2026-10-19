package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.QuoteModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.QuoteService;import java.time.LocalDate;import java.util.*;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/cotizaciones") public class QuoteController {
 private final QuoteService service;public QuoteController(QuoteService service){this.service=service;}
 @GetMapping public Page<Map<String,Object>> list(@AuthenticationPrincipal Identity a,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(required=false)LocalDate desde,@RequestParam(required=false)LocalDate hasta,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(a,buscar,estado,desde,hasta,pagina,tamano);}
 @GetMapping("/opciones") public Map<String,Object> options(){return service.options();}
 @GetMapping("/{id}") public Details get(@AuthenticationPrincipal Identity a,@PathVariable long id){return service.details(a,id);}
 @PostMapping public Details create(@AuthenticationPrincipal Identity a,@Valid @RequestBody Save i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),null,i);}
 @PutMapping("/{id}") public Details update(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Save i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{id}/acciones/{accion}") public Details action(@AuthenticationPrincipal Identity a,@PathVariable long id,@PathVariable String accion,@Valid @RequestBody Action i,HttpServletRequest r){return service.action(a,r.getRemoteAddr(),id,accion,i);}
 @PostMapping("/{id}/convertir") public Conversion convert(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Convert i,HttpServletRequest r){return service.convert(a,r.getRemoteAddr(),id,i);}
}

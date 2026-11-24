package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.AuditModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.AuditService;
import java.time.LocalDate;import org.springframework.format.annotation.DateTimeFormat;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/bitacora")
public class AuditController {
 private final AuditService service;public AuditController(AuditService service){this.service=service;}
 @GetMapping public Page<Event> list(@AuthenticationPrincipal Identity a,@RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate desde,@RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate hasta,@RequestParam(defaultValue="") String usuario,@RequestParam(defaultValue="") String accion,@RequestParam(defaultValue="") String grupo,@RequestParam(defaultValue="0") int pagina,@RequestParam(defaultValue="25") int tamano){return service.list(a,new Filter(desde,hasta,usuario,accion,grupo,pagina,tamano));}
 @GetMapping("/opciones") public Options options(@AuthenticationPrincipal Identity a){return service.options(a);}
 @GetMapping("/{id}") public Detail detail(@AuthenticationPrincipal Identity a,@PathVariable long id){return service.detail(a,id);}
}

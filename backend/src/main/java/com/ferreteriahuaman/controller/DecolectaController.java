package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.service.DecolectaService;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/consultas/ruc")
public class DecolectaController {
 private final DecolectaService service;
 public DecolectaController(DecolectaService service){this.service=service;}
 @GetMapping public ResponseEntity<DecolectaService.Ruc> lookup(@RequestParam String numero){return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.lookup(numero));}
}

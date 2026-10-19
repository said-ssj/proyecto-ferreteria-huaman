package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.SaleModels.Details;import com.ferreteriahuaman.dto.SaleHistoryModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.SaleHistoryService;import java.time.LocalDate;import java.util.*;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/historial-ventas") public class SaleHistoryController {
 private final SaleHistoryService service;public SaleHistoryController(SaleHistoryService service){this.service=service;}
 @GetMapping public Page<Map<String,Object>> list(@RequestParam(defaultValue="")String buscar,@RequestParam(required=false)LocalDate desde,@RequestParam(required=false)LocalDate hasta,@RequestParam(defaultValue="")String tipo,@RequestParam(defaultValue="")String estado,@RequestParam(required=false)Long vendedor,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(buscar,desde,hasta,tipo,estado,vendedor,pagina,tamano);}
 @GetMapping("/vendedores") public List<Map<String,Object>> sellers(){return service.sellers();}
 @GetMapping("/{id}") public Details details(@PathVariable long id){return service.details(id);}
 @PostMapping("/{id}/reimpresion") public Details print(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Key i,HttpServletRequest r){return service.print(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{id}/copia") public Details copy(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Copy i,HttpServletRequest r){return service.copy(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{id}/anulacion") public Details cancel(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Cancel i,HttpServletRequest r){return service.cancel(a,r.getRemoteAddr(),id,i);}
}

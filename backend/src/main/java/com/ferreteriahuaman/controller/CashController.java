package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.CashModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.CashService;import java.time.LocalDate;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import org.springframework.context.annotation.Profile;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/caja") public class CashController {
 private final CashService service;public CashController(CashService service){this.service=service;}
 @GetMapping("/actual") public Current current(){return service.current();}
 @GetMapping("/actual/movimientos") public Page<Movement> currentMovements(@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.currentMovements(pagina,tamano);}
 @GetMapping("/historial") public Page<Register> history(@RequestParam(required=false)LocalDate desde,@RequestParam(required=false)LocalDate hasta,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.history(desde,hasta,estado,pagina,tamano);}
 @GetMapping("/historial/{id}") public Register detail(@PathVariable long id){return service.get(id);}
 @GetMapping("/historial/{id}/movimientos") public Page<Movement> movements(@PathVariable long id,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.movements(id,pagina,tamano);}
 @PostMapping("/abrir") public Result open(@AuthenticationPrincipal Identity a,@Valid @RequestBody Open i,HttpServletRequest r){return service.open(a,r.getRemoteAddr(),i);}
 @PostMapping("/{id}/movimientos") public Result manual(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Manual i,HttpServletRequest r){return service.manual(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/{id}/cerrar") public Result close(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Close i,HttpServletRequest r){return service.close(a,r.getRemoteAddr(),id,i);}
}

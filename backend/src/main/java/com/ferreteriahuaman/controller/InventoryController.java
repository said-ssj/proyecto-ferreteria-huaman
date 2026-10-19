package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.InventoryModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.InventoryService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/inventario")
public class InventoryController {
 private final InventoryService service;public InventoryController(InventoryService service){this.service=service;}
 @GetMapping("/alertas") public Page<Map<String,Object>> alerts(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.alerts(buscar,estado,pagina,tamano);}
 @GetMapping("/ajustes") public Page<Map<String,Object>> adjustments(@AuthenticationPrincipal Identity a,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.adjustments(a,buscar,estado,pagina,tamano);}
 @GetMapping("/motivos") public List<Map<String,Object>> reasons(){return service.reasons();}
 @PostMapping("/ajustes") public Result adjust(@AuthenticationPrincipal Identity a,@Valid @RequestBody Adjustment i,HttpServletRequest r){return service.adjust(a,r.getRemoteAddr(),i);}
 @PostMapping("/transformaciones") public Result transform(@AuthenticationPrincipal Identity a,@Valid @RequestBody Transformation i,HttpServletRequest r){return service.transform(a,r.getRemoteAddr(),i);}
 @GetMapping("/tomas") public Page<Map<String,Object>> takes(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.takes(buscar,estado,pagina,tamano);}
 @GetMapping("/tomas/{id}") public Map<String,Object> take(@PathVariable long id){return service.take(id);}
 @GetMapping("/tomas/{id}/lineas") public Page<Map<String,Object>> lines(@AuthenticationPrincipal Identity a,@PathVariable long id,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.counts(a,id,buscar,pagina,tamano);}
 @PostMapping("/tomas") public Result start(@AuthenticationPrincipal Identity a,@Valid @RequestBody Start i,HttpServletRequest r){return service.start(a,r.getRemoteAddr(),i);}
 @PostMapping("/tomas/{id}/conteos") public Result count(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Count i,HttpServletRequest r){return service.count(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/tomas/{id}/acciones/{action}") public Result transition(@AuthenticationPrincipal Identity a,@PathVariable long id,@PathVariable String action,@Valid @RequestBody Transition i,HttpServletRequest r){return service.transition(a,r.getRemoteAddr(),id,action,i);}
}

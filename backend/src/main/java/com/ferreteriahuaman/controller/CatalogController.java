package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.CatalogService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @Profile("db") @RequestMapping("/api/catalogos")
public class CatalogController {
    private final CatalogService service;
    public CatalogController(CatalogService service){this.service=service;}
    @GetMapping("/categorias") public Page<Category> categories(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.categories(buscar,estado,pagina,tamano);}
    @GetMapping("/categorias/{id}") public Category category(@PathVariable long id){return service.category(id);}
    @PostMapping("/categorias") @ResponseStatus(HttpStatus.CREATED) public Category createCategory(@AuthenticationPrincipal Identity actor,@Valid @RequestBody CategoryInput input,HttpServletRequest request){return service.createCategory(actor,request.getRemoteAddr(),input);}
    @PutMapping("/categorias/{id}") public Category updateCategory(@AuthenticationPrincipal Identity actor,@PathVariable long id,@Valid @RequestBody CategoryInput input,HttpServletRequest request){return service.updateCategory(actor,request.getRemoteAddr(),id,input);}
    @PatchMapping("/categorias/{id}/estado") public Category categoryState(@AuthenticationPrincipal Identity actor,@PathVariable long id,@Valid @RequestBody StateInput input,HttpServletRequest request){return service.categoryState(actor,request.getRemoteAddr(),id,input);}
    @GetMapping("/unidades") public Page<Unit> units(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.units(buscar,estado,pagina,tamano);}
    @GetMapping("/unidades/{id}") public Unit unit(@PathVariable long id){return service.unit(id);}
    @PostMapping("/unidades") @ResponseStatus(HttpStatus.CREATED) public Unit createUnit(@AuthenticationPrincipal Identity actor,@Valid @RequestBody UnitInput input,HttpServletRequest request){return service.createUnit(actor,request.getRemoteAddr(),input);}
    @PutMapping("/unidades/{id}") public Unit updateUnit(@AuthenticationPrincipal Identity actor,@PathVariable long id,@Valid @RequestBody UnitInput input,HttpServletRequest request){return service.updateUnit(actor,request.getRemoteAddr(),id,input);}
    @PatchMapping("/unidades/{id}/estado") public Unit unitState(@AuthenticationPrincipal Identity actor,@PathVariable long id,@Valid @RequestBody StateInput input,HttpServletRequest request){return service.unitState(actor,request.getRemoteAddr(),id,input);}
}

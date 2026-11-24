package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.SettingsModels.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.SettingsService;
import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import java.util.List;
import org.springframework.context.annotation.Profile;import org.springframework.http.HttpStatus;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/configuracion")
public class SettingsController{
 private final SettingsService service;public SettingsController(SettingsService service){this.service=service;}
 @GetMapping("/parametros") public List<Parameter> parameters(@AuthenticationPrincipal Identity a){return service.parameters(a,false);}
 @PutMapping("/parametros") public List<Parameter> parameters(@AuthenticationPrincipal Identity a,@Valid @RequestBody Changes i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),false,i);}
 @GetMapping("/impresion") public List<Parameter> printing(@AuthenticationPrincipal Identity a){return service.parameters(a,true);}
 @PutMapping("/impresion") public List<Parameter> printing(@AuthenticationPrincipal Identity a,@Valid @RequestBody Changes i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),true,i);}
 @GetMapping("/series") public List<Series> series(@AuthenticationPrincipal Identity a){return service.series(a);}
 @PostMapping("/series") @ResponseStatus(HttpStatus.CREATED) public Series create(@AuthenticationPrincipal Identity a,@Valid @RequestBody SeriesInput i,HttpServletRequest r){return service.create(a,r.getRemoteAddr(),i);}
 @PutMapping("/series/{id}") public Series update(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody SeriesInput i,HttpServletRequest r){return service.update(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/series/{id}/estado") public Series state(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody State i,HttpServletRequest r){return service.state(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/etiquetas") public Label labels(@AuthenticationPrincipal Identity a,@Valid @RequestBody LabelRequest i,HttpServletRequest r){return service.label(a,r.getRemoteAddr(),i);}
}

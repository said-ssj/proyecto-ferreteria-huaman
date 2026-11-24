package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.dto.UserAdminModels.*;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.service.UserAdminService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @Profile("db") @RequestMapping("/api")
public class UserAdminController {
 private final UserAdminService service;
 public UserAdminController(UserAdminService service){this.service=service;}
 @GetMapping("/usuarios") public Page list(@AuthenticationPrincipal Identity a,@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(a,buscar,estado,pagina,tamano);}
 @GetMapping("/usuarios/opciones") public List<Role> options(@AuthenticationPrincipal Identity a){return service.roles(a,true);}
 @GetMapping("/usuarios/{id}") public User user(@AuthenticationPrincipal Identity a,@PathVariable long id){return service.user(a,id);}
 @PostMapping("/usuarios") @ResponseStatus(HttpStatus.CREATED) public User create(@AuthenticationPrincipal Identity a,@Valid @RequestBody Input i,HttpServletRequest r){return service.create(a,r.getRemoteAddr(),i);}
 @PutMapping("/usuarios/{id}") public User update(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Input i,HttpServletRequest r){return service.update(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/usuarios/{id}/estado") public User state(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody State i,HttpServletRequest r){return service.state(a,r.getRemoteAddr(),id,i);}
 @PostMapping("/usuarios/{id}/restablecer-clave") public User reset(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Reset i,HttpServletRequest r){return service.reset(a,r.getRemoteAddr(),id,i);}
 @GetMapping("/roles") public List<Role> roles(@AuthenticationPrincipal Identity a){return service.roles(a,false);}
}

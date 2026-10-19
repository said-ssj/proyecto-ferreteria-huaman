package com.ferreteriahuaman.controller;
import com.ferreteriahuaman.dto.CustomerModels.*;import com.ferreteriahuaman.dto.CatalogModels.*;import com.ferreteriahuaman.security.AuthModels.Identity;import com.ferreteriahuaman.service.CustomerService;import jakarta.servlet.http.HttpServletRequest;import jakarta.validation.Valid;import org.springframework.context.annotation.Profile;import org.springframework.http.HttpStatus;import org.springframework.security.core.annotation.AuthenticationPrincipal;import org.springframework.web.bind.annotation.*;
@RestController @Profile("db") @RequestMapping("/api/clientes") public class CustomerController {
 private final CustomerService service;public CustomerController(CustomerService service){this.service=service;}
 @GetMapping public Page<Customer> list(@RequestParam(defaultValue="")String buscar,@RequestParam(defaultValue="")String estado,@RequestParam(defaultValue="0")int pagina,@RequestParam(defaultValue="20")int tamano){return service.list(buscar,estado,pagina,tamano);}
 @GetMapping("/buscar-documento") public Customer lookup(@RequestParam String documento){return service.lookup(documento);}
 @GetMapping("/{id}") public Customer get(@PathVariable long id){return service.get(id);}
 @PostMapping @ResponseStatus(HttpStatus.CREATED) public Customer create(@AuthenticationPrincipal Identity a,@Valid @RequestBody Input i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),null,i);}
 @PutMapping("/{id}") public Customer update(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Input i,HttpServletRequest r){return service.save(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/{id}/estado") public Customer state(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody StateInput i,HttpServletRequest r){return service.state(a,r.getRemoteAddr(),id,i);}
 @PatchMapping("/{id}/credito") public Customer credit(@AuthenticationPrincipal Identity a,@PathVariable long id,@Valid @RequestBody Credit i,HttpServletRequest r){return service.credit(a,r.getRemoteAddr(),id,i);}
}

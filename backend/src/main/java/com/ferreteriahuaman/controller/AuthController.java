package com.ferreteriahuaman.controller;

import com.ferreteriahuaman.service.AuthService;
import com.ferreteriahuaman.security.AuthModels.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@Profile("db")
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService service;
    public AuthController(AuthService service){this.service=service;}
    @PostMapping("/login") public ResponseEntity<LoginResponse> login(@Valid @RequestBody Login body,HttpServletRequest request){
        LoginResult result=service.login(body,request.getRemoteAddr());if(result.failure()!=null)throw result.failure();return ResponseEntity.ok().cacheControl(org.springframework.http.CacheControl.noStore()).body(result.response());
    }
    @GetMapping("/me") public UserProfile me(@AuthenticationPrincipal Identity identity){return UserProfile.of(identity);}
    @PostMapping("/continuar") public UserProfile keepAlive(@AuthenticationPrincipal Identity identity){return UserProfile.of(identity);}
    @PostMapping("/logout") public ResponseEntity<Void> logout(@AuthenticationPrincipal Identity identity,HttpServletRequest request){service.logout(identity,request.getRemoteAddr());return ResponseEntity.noContent().build();}
    @PutMapping("/clave") public ResponseEntity<Void> password(@AuthenticationPrincipal Identity identity,@Valid @RequestBody PasswordChange body,HttpServletRequest request){service.changePassword(identity,body,request.getRemoteAddr());return ResponseEntity.noContent().build();}
}

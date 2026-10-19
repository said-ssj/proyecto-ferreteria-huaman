package com.ferreteriahuaman.security;

import java.io.IOException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ferreteriahuaman.service.AuthService;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.dao.DataAccessException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

public class BearerSessionFilter extends OncePerRequestFilter {
    private final AuthService service;private final ObjectMapper mapper;
    public BearerSessionFilter(AuthService service,ObjectMapper mapper){this.service=service;this.mapper=mapper;}
    @Override protected boolean shouldNotFilter(HttpServletRequest request){return request.getMethod().equals("POST")&&request.getServletPath().equals("/api/auth/login");}
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws IOException,ServletException{
        String header=request.getHeader("Authorization");
        if(header!=null){
            if(!header.startsWith("Bearer ")){AuthProblems.write(response,mapper,401,"Credencial de sesión no válida");return;}
            try {
                var identity=service.authenticate(header.substring(7),request.getRemoteAddr());
                var auth=new UsernamePasswordAuthenticationToken(identity,null,identity.permisos().stream().map(SimpleGrantedAuthority::new).toList());
                var context=SecurityContextHolder.createEmptyContext();context.setAuthentication(auth);SecurityContextHolder.setContext(context);
            }catch(AuthFailure failure){AuthProblems.write(response,mapper,failure.status(),failure.getMessage());return;}
             catch(DataAccessException failure){AuthProblems.write(response,mapper,503,"No se pudo verificar la sesión. Intenta de nuevo más tarde");return;}
        }
        response.setHeader("Cache-Control","no-store");chain.doFilter(request,response);
    }
}

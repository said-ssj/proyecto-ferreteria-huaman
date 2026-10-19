package com.ferreteriahuaman.security;

import java.io.IOException;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;

public final class AuthProblems {
    private AuthProblems(){}
    public static void write(HttpServletResponse response,ObjectMapper mapper,int status,String message)throws IOException{
        ProblemDetail problem=ProblemDetail.forStatusAndDetail(org.springframework.http.HttpStatusCode.valueOf(status),message);
        problem.setTitle(status==401?"Sesión no válida":status==403?"Acceso denegado":status==503?"Servicio no disponible":"Solicitud no válida");
        response.setStatus(status);response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");response.setHeader("Cache-Control","no-store");
        mapper.writeValue(response.getOutputStream(),problem);
    }
}

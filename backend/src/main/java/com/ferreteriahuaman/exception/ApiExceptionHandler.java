package com.ferreteriahuaman.exception;

import com.ferreteriahuaman.security.AuthFailure;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(AuthFailure.class) ResponseEntity<ProblemDetail> auth(AuthFailure failure){return problem(failure.status(),failure.getMessage());}
    @ExceptionHandler({MethodArgumentNotValidException.class,HttpMessageNotReadableException.class,MethodArgumentTypeMismatchException.class})
    ResponseEntity<ProblemDetail> invalid(Exception failure){return problem(400,"Revisa los datos obligatorios y su formato");}
    @ExceptionHandler(DataIntegrityViolationException.class) ResponseEntity<ProblemDetail> conflict(DataIntegrityViolationException failure){return problem(409,"Ya existe un registro con esos datos o una relación impide el cambio");}
    @ExceptionHandler(DataAccessException.class) ResponseEntity<ProblemDetail> unavailable(DataAccessException failure){
        for(Throwable cause=failure;cause!=null;cause=cause.getCause())if(cause instanceof java.sql.SQLException sql&&"P0001".equals(sql.getSQLState()))return problem(409,"Las reglas del sistema impiden el cambio. Revisa el estado, las cantidades y los registros relacionados");
        return problem(503,"El servicio no está disponible. Intenta de nuevo más tarde");
    }
    private ResponseEntity<ProblemDetail> problem(int status,String message){return ResponseEntity.status(status).cacheControl(CacheControl.noStore()).body(ProblemDetail.forStatusAndDetail(org.springframework.http.HttpStatusCode.valueOf(status),message));}
}


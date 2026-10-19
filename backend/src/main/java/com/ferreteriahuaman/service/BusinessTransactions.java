package com.ferreteriahuaman.service;

import java.time.*;
import java.util.function.Supplier;
import com.ferreteriahuaman.repository.AuthStore;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

@Component @Profile("db")
public class BusinessTransactions {
    private final TransactionTemplate tx;private final AuthStore auth;private final Clock clock;
    public BusinessTransactions(TransactionTemplate tx,AuthStore auth,Clock clock){this.tx=tx;this.auth=auth;this.clock=clock;}
    public <T>T write(Identity actor,String equipo,String permission,Supplier<T> operation){return tx.execute(status->{
        var user=auth.lockUser(actor.id()).orElseThrow(AuthFailure::expired);
        var session=auth.lockSession(actor.sessionToken()).orElseThrow(AuthFailure::expired);
        LocalDateTime now=LocalDateTime.ofInstant(clock.instant(),ZoneId.of("America/Lima"));
        int minutes=auth.parameter("SEGURIDAD.SESION_MIN",30,5,120);
        if(!user.activo()||!session.abierta()||session.usuario()!=user.id()||now.isBefore(session.actividad())
           ||!now.isBefore(session.actividad().plusMinutes(minutes))||(user.bloqueo()!=null&&now.isBefore(user.bloqueo())))throw AuthFailure.expired();
        if(user.temporal()||!auth.permissions(user.id()).contains(permission))throw new AuthFailure(403,"No tienes permiso para realizar esta acción");
        auth.context(user.username(),equipo);return operation.get();
    });}
}

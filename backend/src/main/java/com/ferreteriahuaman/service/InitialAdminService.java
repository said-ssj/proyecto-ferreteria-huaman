package com.ferreteriahuaman.service;

import java.nio.CharBuffer;
import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
@Profile("db")
public class InitialAdminService {
    public record Details(String usuario,String nombres,String apellidos,String dni) {
        @Override public String toString(){return "Details[datos privados omitidos]";}
    }
    private final JdbcTemplate jdbc;
    private final PasswordEncoder encoder;
    private final TransactionTemplate tx;
    public InitialAdminService(JdbcTemplate jdbc,PasswordEncoder encoder,TransactionTemplate tx){
        this.jdbc=jdbc;this.encoder=encoder;this.tx=tx;
    }
    public void create(Details details,char[] password){
        validate(details,password);
        String hash=encoder.encode(CharBuffer.wrap(password));
        tx.executeWithoutResult(status->{
            // Serializes all competing initial-user inserts, not just this command.
            jdbc.execute("lock table huaman.usuario in share row exclusive mode");
            if(!Boolean.FALSE.equals(jdbc.queryForObject("select exists(select 1 from huaman.usuario)",Boolean.class)))
                throw new IllegalStateException("El alta inicial ya no está disponible porque existen usuarios");
            Long role=jdbc.queryForObject("select id_rol from huaman.rol where codigo='ADM' and estado='A' for share",Long.class);
            if(role==null)throw new IllegalStateException("No se encontró el rol administrativo activo");
            jdbc.queryForMap("select set_config('app.usuario',?,true) as actor,set_config('app.equipo','CLI_LOCAL',true) as equipo",details.usuario());
            Long id=jdbc.queryForObject("""
                insert into huaman.usuario(username,clave_hash,nombres,apellidos,dni,id_rol,clave_temporal)
                values(?,?,?,?,?,?,false) returning id_usuario
                """,Long.class,details.usuario(),hash,details.nombres(),details.apellidos(),details.dni(),role);
            jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad) values(?,'SEG.USUARIO_CREAR','usuario',?)",id,id);
        });
    }
    static void validate(Details d,char[] password){
        if(d==null||d.usuario()==null||!d.usuario().matches("[A-Za-z0-9._-]{4,30}")
            ||d.nombres()==null||d.nombres().isBlank()||d.nombres().length()>100
            ||d.apellidos()==null||d.apellidos().isBlank()||d.apellidos().length()>100
            ||d.dni()==null||!d.dni().matches("[0-9]{8}")||d.dni().equals("00000000"))
            throw new IllegalArgumentException("Revisa los datos privados del administrador inicial");
        if(password==null)throw new IllegalArgumentException("Escribe una contraseña");
        CharBuffer chars=CharBuffer.wrap(password);
        if(password.length<8||StandardCharsets.UTF_8.encode(chars).remaining()>72
            ||!CharBuffer.wrap(password).chars().anyMatch(Character::isLetter)
            ||!CharBuffer.wrap(password).chars().anyMatch(Character::isDigit)
            ||CharBuffer.wrap(password).toString().equalsIgnoreCase(d.usuario()))
            throw new IllegalArgumentException("La contraseña debe tener al menos 8 caracteres, letras y números, y ser distinta del usuario (máximo 72 bytes UTF-8)");
    }
}

package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.security.AuthModels.*;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
@Profile("db")
public class JdbcAuthStore implements AuthStore {
    private final JdbcTemplate jdbc;
    public JdbcAuthStore(JdbcTemplate jdbc){this.jdbc=jdbc;}
    private static final String ACCOUNT="""
        select u.id_usuario,u.username,u.clave_hash,u.nombres,u.apellidos,r.codigo,
        (u.estado='A' and r.estado='A') activo,u.clave_temporal,u.intentos_fallidos,u.bloqueado_hasta
        from huaman.usuario u join huaman.rol r on r.id_rol=u.id_rol
        """;
    private Account account(ResultSet r,int row) throws SQLException {
        return new Account(r.getLong("id_usuario"),r.getString("username"),r.getString("clave_hash"),
            r.getString("nombres"),r.getString("apellidos"),r.getString("codigo"),r.getBoolean("activo"),
            r.getBoolean("clave_temporal"),r.getInt("intentos_fallidos"),r.getObject("bloqueado_hasta",LocalDateTime.class));
    }
    private <T> Optional<T> first(String sql,RowMapper<T> mapper,Object...args){return jdbc.query(sql,mapper,args).stream().findFirst();}
    public Optional<Account> lockUsername(String username){return first(ACCOUNT+" where lower(u.username)=lower(?) for update of u",this::account,username);}
    public Optional<Account> lockUser(long id){return first(ACCOUNT+" where u.id_usuario=? for update of u",this::account,id);}
    public Optional<Long> sessionOwner(UUID token){return first("select id_usuario from huaman.sesion_usuario where token_id=?",(r,n)->r.getLong(1),token);}
    public Optional<Session> lockSession(UUID token){return first("""
        select id_sesion,id_usuario,token_id,ultima_actividad,(estado='A' and cerrada_en is null) abierta
        from huaman.sesion_usuario where token_id=? for update
        """,(r,n)->new Session(r.getLong(1),r.getLong(2),r.getObject(3,UUID.class),r.getObject(4,LocalDateTime.class),r.getBoolean(5)),token);}
    public Set<String> permissions(long user){return Set.copyOf(jdbc.queryForList("""
        select p.codigo from huaman.usuario u join huaman.rol r on r.id_rol=u.id_rol
        join huaman.rol_permiso rp on rp.id_rol=r.id_rol join huaman.permiso p on p.id_permiso=rp.id_permiso
        where u.id_usuario=? and u.estado='A' and r.estado='A' and rp.estado='A' and p.estado='A'
        """,String.class,user));}
    public int parameter(String key,int fallback,int min,int max){
        String value=first("select valor from huaman.parametro_sistema where clave=? and estado='A'",(r,n)->r.getString(1),key).orElse(null);
        if(value==null)return fallback;
        int parsed=Integer.parseInt(value);if(parsed<min||parsed>max)throw new IllegalStateException("Parámetro de seguridad fuera de rango");return parsed;
    }
    public void context(String actor,String equipo){jdbc.queryForMap("select set_config('app.usuario',?,true),set_config('app.equipo',?,true)",actor,equipo);}
    public void failed(Account u,int count,LocalDateTime blocked){jdbc.update("update huaman.usuario set intentos_fallidos=?,bloqueado_hasta=? where id_usuario=?",count,blocked,u.id());}
    public void resetLogin(Account u,LocalDateTime now){jdbc.update("update huaman.usuario set intentos_fallidos=0,bloqueado_hasta=null,ultimo_ingreso=? where id_usuario=?",now,u.id());}
    public void createSession(long user,UUID token,LocalDateTime now){jdbc.update("insert into huaman.sesion_usuario(id_usuario,token_id,inicio,ultima_actividad) values(?,?,?,?)",user,token,now,now);}
    public void touch(long id,LocalDateTime now){jdbc.update("update huaman.sesion_usuario set ultima_actividad=? where id_sesion=?",now,id);}
    public void close(long id,String reason,LocalDateTime now){jdbc.update("update huaman.sesion_usuario set cerrada_en=?,motivo_cierre=?,estado='I' where id_sesion=?",now,reason,id);}
    public void password(long id,String hash){jdbc.update("update huaman.usuario set clave_hash=?,clave_temporal=false where id_usuario=?",hash,id);}
    public void revokeOtherSessions(long user,UUID except,LocalDateTime now){jdbc.update("update huaman.sesion_usuario set cerrada_en=?,motivo_cierre='REVOCADA',estado='I' where id_usuario=? and token_id<>? and cerrada_en is null and estado='A'",now,user,except);}
    public void event(Long user,String action){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad) values(?,?,'usuario',?)",user,action,user);}
}

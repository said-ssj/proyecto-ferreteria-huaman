package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.UserAdminModels.Permission;import java.util.*;import java.time.LocalDateTime;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.context.annotation.Profile;import org.springframework.stereotype.Repository;
@Repository @Profile("db") public class RolePermissionRepository{
 private final JdbcTemplate jdbc;public RolePermissionRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 public record Role(long id,String code,String name,String description,String state,LocalDateTime version){}
 public Optional<Role> role(long id,boolean lock){return jdbc.query("select id_rol,codigo,nombre,descripcion,estado,coalesce(fecmod,feccre) version from huaman.rol where id_rol=?"+(lock?" for update":""),(r,n)->new Role(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getObject(6,LocalDateTime.class)),id).stream().findFirst();}
 public List<Permission> catalog(){return jdbc.query("select codigo,modulo,descripcion from huaman.permiso where estado='A' order by codigo",(r,n)->new Permission(r.getString(1),r.getString(2),r.getString(3)));}
 public List<String> assigned(long id){return jdbc.queryForList("select p.codigo from huaman.rol_permiso rp join huaman.permiso p using(id_permiso) where rp.id_rol=? and rp.estado='A' and p.estado='A' order by p.codigo",String.class,id);}
 public long users(long id){return jdbc.queryForObject("select count(*) from huaman.usuario where id_rol=? and estado='A'",Long.class,id);}
 public void lockUsers(long id){jdbc.queryForList("select id_usuario from huaman.usuario where id_rol=? order by id_usuario for update",Long.class,id);}
 public void assignments(long role,Set<String> requested){for(String code:assigned(role))if(!requested.contains(code))jdbc.update("update huaman.rol_permiso set estado='I' where id_rol=? and id_permiso=(select id_permiso from huaman.permiso where codigo=?)",role,code);for(String code:new TreeSet<>(requested))jdbc.update("insert into huaman.rol_permiso as rp(id_rol,id_permiso) select ?,id_permiso from huaman.permiso where codigo=? and estado='A' on conflict(id_rol,id_permiso) do update set estado='A' where rp.estado<>'A'",role,code);}
 public long revoke(long role){return jdbc.update("update huaman.sesion_usuario s set estado='I',cerrada_en=greatest(timezone('America/Lima',now()),ultima_actividad),motivo_cierre='REVOCADA' from huaman.usuario u where s.id_usuario=u.id_usuario and u.id_rol=? and s.estado='A' and s.cerrada_en is null",role);}
 public void audit(long actor,long role,String before,String after){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,valor_anterior,valor_nuevo) values(?,'SEG.ROL_PERMISOS','rol',?,?::jsonb,?::jsonb)",actor,role,before,after);}
}

package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.UserAdminModels.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository @Profile("db")
public class UserAdminRepository {
 private final JdbcTemplate jdbc;
 public UserAdminRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 private static final String SELECT="""
 select u.id_usuario,u.username,u.nombres,u.apellidos,u.dni,u.telefono,u.correo,u.id_rol,r.codigo,r.nombre,
 u.estado,u.clave_temporal,u.bloqueado_hasta,u.ultimo_ingreso,coalesce(u.fecmod,u.feccre) version
 from huaman.usuario u join huaman.rol r on r.id_rol=u.id_rol
 """;
 private User row(ResultSet r,int n)throws SQLException{return new User(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getString(6),r.getString(7),r.getLong(8),r.getString(9),r.getString(10),r.getString(11),r.getBoolean(12),r.getObject(13,LocalDateTime.class),r.getObject(14,LocalDateTime.class),r.getObject(15,LocalDateTime.class));}
 public Page list(String search,String state,int page,int size){
  String esc=Character.toString(92);String q="%"+search.replace(esc,esc+esc).replace("%",esc+"%").replace("_",esc+"_")+"%";
  String filter=" where (u.username ilike ? or concat_ws(' ',u.nombres,u.apellidos) ilike ? or u.dni ilike ?) and (?='' or u.estado=?)";
  long total=Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.usuario u"+filter,Long.class,q,q,q,state,state));
  return new Page(jdbc.query(SELECT+filter+" order by lower(u.username),u.id_usuario limit ? offset ?",this::row,q,q,q,state,state,size,(long)page*size),total,page,size);
 }
 public Optional<User> user(long id,boolean lock){return jdbc.query(SELECT+" where u.id_usuario=?"+(lock?" for update of u":""),this::row,id).stream().findFirst();}
 public List<Role> roles(){return jdbc.query("select id_rol,codigo,nombre,descripcion,estado from huaman.rol order by codigo",(r,n)->new Role(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5),permissions(r.getLong(1))));}
 public List<Permission> permissions(long role){return jdbc.query("""
 select p.codigo,p.modulo,p.descripcion from huaman.rol_permiso rp join huaman.permiso p on p.id_permiso=rp.id_permiso
 where rp.id_rol=? and rp.estado='A' and p.estado='A' order by p.modulo,p.codigo
 """,(r,n)->new Permission(r.getString(1),r.getString(2),r.getString(3)),role);}
 public Optional<Role> role(long id){return jdbc.query("select id_rol,codigo,nombre,descripcion,estado from huaman.rol where id_rol=? for share",(r,n)->new Role(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5),List.of()),id).stream().findFirst();}
 public void serialize(){jdbc.execute("select pg_advisory_xact_lock(73210,200)");}
 public long activeAdmins(){return Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.usuario u join huaman.rol r on r.id_rol=u.id_rol where u.estado='A' and r.estado='A' and r.codigo='ADM' and not u.clave_temporal and (u.bloqueado_hasta is null or u.bloqueado_hasta<=timezone('America/Lima',now()))",Long.class));}
 public long create(Input i,String hash){return Objects.requireNonNull(jdbc.queryForObject("insert into huaman.usuario(username,nombres,apellidos,dni,telefono,correo,id_rol,clave_hash,clave_temporal) values(?,?,?,?,?,?,?,?,true) returning id_usuario",Long.class,i.usuario(),i.nombres().strip(),i.apellidos().strip(),i.dni(),blank(i.telefono()),blank(i.correo()),i.rolId(),hash));}
 private String blank(String v){return v==null||v.isBlank()?null:v.strip();}
 public void update(long id,Input i){jdbc.update("update huaman.usuario set nombres=?,apellidos=?,dni=?,telefono=?,correo=?,id_rol=? where id_usuario=?",i.nombres().strip(),i.apellidos().strip(),i.dni(),blank(i.telefono()),blank(i.correo()),i.rolId(),id);}
 public void state(long id,String state){jdbc.update("update huaman.usuario set estado=? where id_usuario=?",state,id);}
 public void reset(long id,String hash){jdbc.update("update huaman.usuario set clave_hash=?,clave_temporal=true,intentos_fallidos=0,bloqueado_hasta=null where id_usuario=?",hash,id);}
 public void revoke(long id){jdbc.update("update huaman.sesion_usuario set estado='I',cerrada_en=greatest(timezone('America/Lima',now()),ultima_actividad),motivo_cierre='REVOCADA' where id_usuario=? and estado='A' and cerrada_en is null",id);}
 public void audit(long actor,String action,long id,String before,String after){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,valor_anterior,valor_nuevo) values(?,?,'usuario',?,?::jsonb,?::jsonb)",actor,action,id,before,after);}
}

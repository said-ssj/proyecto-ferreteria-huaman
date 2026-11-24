package com.ferreteriahuaman.repository;
import java.time.LocalDateTime;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
@Repository @Profile("db")
public class BrandRepository {
 private final JdbcTemplate jdbc;
 public BrandRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 public record Data(String name,byte[] png,String hash,boolean favicon,LocalDateTime version){}
 public Data get(){return jdbc.queryForObject("select coalesce(nullif((select btrim(valor) from huaman.parametro_sistema where clave='NEGOCIO.NOMBRE_COMERCIAL' and estado='A'),''),'Mi negocio'),i.logo_png,i.logo_sha256,coalesce(i.usar_logo_favicon,false),coalesce(i.fecmod,i.feccre) from (values(1)) x(id) left join huaman.identidad_visual i on i.id=x.id",(r,n)->new Data(r.getString(1),r.getBytes(2),r.getString(3),r.getBoolean(4),r.getObject(5,LocalDateTime.class)));}
 public void lock(){jdbc.execute("select pg_advisory_xact_lock(73210,202)");}
 public void save(byte[] png,String hash,boolean favicon){jdbc.update("insert into huaman.identidad_visual(id,logo_png,logo_sha256,usar_logo_favicon) values(1,?,?,?) on conflict(id) do update set logo_png=excluded.logo_png,logo_sha256=excluded.logo_sha256,usar_logo_favicon=excluded.usar_logo_favicon",png,hash,favicon);}
}

package com.ferreteriahuaman.repository;
import java.time.LocalDateTime;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import com.ferreteriahuaman.security.AuthFailure;
@Repository @Profile("db")
public class ProductImageRepository {
 private final JdbcTemplate jdbc;public ProductImageRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 public record Metadata(long productoId,String hash,LocalDateTime version){}
 public Metadata get(long id){var rows=jdbc.query("select p.id_producto,i.sha256,coalesce(i.fecmod,i.feccre) version from huaman.producto p left join huaman.producto_imagen i using(id_producto) where p.id_producto=?",(r,n)->new Metadata(r.getLong(1),r.getString(2),r.getObject(3,LocalDateTime.class)),id);if(rows.isEmpty())throw new AuthFailure(404,"Producto no encontrado");return rows.getFirst();}
 public byte[] image(long id,String hash){var rows=jdbc.query("select imagen_jpeg from huaman.producto_imagen where id_producto=? and sha256=?",(r,n)->r.getBytes(1),id,hash);if(rows.isEmpty())throw new AuthFailure(404,"Imagen no encontrada");return rows.getFirst();}
 public void lock(long id){jdbc.queryForList("select id_producto from huaman.producto where id_producto=? for update",id);}
 public void save(long id,byte[] jpeg,String hash){jdbc.update("insert into huaman.producto_imagen(id_producto,imagen_jpeg,sha256) values(?,?,?) on conflict(id_producto) do update set imagen_jpeg=excluded.imagen_jpeg,sha256=excluded.sha256",id,jpeg,hash);}
}

package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.SettingsModels.*;
import java.sql.*;import java.time.LocalDateTime;import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
@Repository @Profile("db")
public class SettingsRepository{
 private final JdbcTemplate jdbc;public SettingsRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 private static final String PARAM="select clave,grupo,valor,tipo_dato,valor_min,valor_max,descripcion,coalesce(fecmod,feccre) version from huaman.parametro_sistema where estado='A'";
 private Parameter param(ResultSet r,int n)throws SQLException{return new Parameter(r.getString(1),r.getString(2),r.getString(3),r.getString(4),r.getBigDecimal(5),r.getBigDecimal(6),r.getString(7),true,r.getObject(8,LocalDateTime.class));}
 public List<Parameter> parameters(boolean printing){return jdbc.query(PARAM+(printing?" and grupo='COMPROBANTE'":" and grupo<>'COMPROBANTE'")+" order by grupo,clave",this::param);}
 public Optional<Parameter> parameter(String key,boolean lock){return jdbc.query(PARAM+" and clave=?"+(lock?" for update":""),this::param,key).stream().findFirst();}
 public void value(String key,String value){jdbc.update("update huaman.parametro_sistema set valor=? where clave=? and estado='A'",value,key);}
 public void createTextSize(String value){jdbc.update("insert into huaman.parametro_sistema(clave,grupo,valor,valor_defecto,tipo_dato,descripcion) values('COMPROBANTE.TAMANO_TEXTO','COMPROBANTE',?,'NORMAL','TEXTO','Tamaño de letra para la representación impresa')",value);}
 public void serialize(){jdbc.execute("select pg_advisory_xact_lock(73210,201)");}
 public boolean admin(long id){return Boolean.TRUE.equals(jdbc.queryForObject("select exists(select 1 from huaman.usuario u join huaman.rol r on r.id_rol=u.id_rol where u.id_usuario=? and u.estado='A' and r.estado='A' and r.codigo='ADM')",Boolean.class,id));}
 private static final String SERIES="""
 select s.id_serie,s.tipo_comprobante,s.serie,s.correlativo_inicial,s.ultimo_correlativo,s.estado,
 (s.ultimo_correlativo>=s.correlativo_inicial or exists(select 1 from huaman.comprobante_venta c where c.id_serie=s.id_serie)) usada,
 coalesce(s.fecmod,s.feccre) version from huaman.serie_comprobante s
 """;
 private Series series(ResultSet r,int n)throws SQLException{return new Series(r.getLong(1),r.getString(2),r.getString(3),r.getInt(4),r.getInt(5),r.getString(6),r.getBoolean(7),r.getObject(8,LocalDateTime.class));}
 public List<Series> series(){return jdbc.query(SERIES+" order by tipo_comprobante,serie",this::series);}
 public Optional<Series> series(long id,boolean lock){return jdbc.query(SERIES+" where s.id_serie=?"+(lock?" for update of s":""),this::series,id).stream().findFirst();}
 public long createSeries(SeriesInput i){return Objects.requireNonNull(jdbc.queryForObject("insert into huaman.serie_comprobante(tipo_comprobante,serie,correlativo_inicial,ultimo_correlativo) values(?,?,?,?) returning id_serie",Long.class,i.tipo(),i.serie(),i.inicial(),i.inicial()-1));}
 public void editSeries(long id,SeriesInput i){jdbc.update("update huaman.serie_comprobante set tipo_comprobante=?,serie=?,correlativo_inicial=?,ultimo_correlativo=? where id_serie=?",i.tipo(),i.serie(),i.inicial(),i.inicial()-1,id);}
 public void state(long id,String state){jdbc.update("update huaman.serie_comprobante set estado=? where id_serie=?",state,id);}
 public long otherActive(String type,long except){return Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.serie_comprobante where tipo_comprobante=? and id_serie<>? and estado='A'",Long.class,type,except));}
 public Optional<Label> label(LabelRequest request){return jdbc.query("""
 select p.nombre producto,v.nombre presentacion,p.codigo interno,v.es_base,v.precio_normal,b.codigo,b.simbologia
 from huaman.producto p join huaman.presentacion_producto v on v.id_producto=p.id_producto
 left join huaman.codigo_presentacion b on b.id_presentacion=v.id_presentacion and b.id_codigo=? and b.estado='A'
 where p.id_producto=? and v.id_presentacion=? and p.estado='A' and v.estado='A'
 """,(r,n)->{String code=r.getString("codigo");String format=r.getString("simbologia");if(request.codigoId()!=null&&code==null)return null;if(code==null){if(!r.getBoolean("es_base"))return null;code=r.getString("interno");format="CODE128";}return new Label(r.getString("producto"),r.getString("presentacion"),code,format,r.getBigDecimal("precio_normal").toPlainString(),request.cantidad());},request.codigoId(),request.productoId(),request.presentacionId()).stream().filter(Objects::nonNull).findFirst();}
 public void audit(long actor,String action,String entity,Long id,String before,String after){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,valor_anterior,valor_nuevo) values(?,?,?,?,?::jsonb,?::jsonb)",actor,action,entity,id,before,after);}
}

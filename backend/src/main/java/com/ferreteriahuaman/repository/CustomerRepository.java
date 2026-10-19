package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.CustomerModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.sql.*;import java.time.LocalDateTime;import java.math.BigDecimal;import java.util.*;
import org.springframework.context.annotation.Profile;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.stereotype.Repository;
@Repository @Profile("db") public class CustomerRepository {
 private final JdbcTemplate jdbc;public CustomerRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 private static final String SELECT="select c.id_cliente,c.tipo_documento,c.nro_documento,c.nombre_razon_social,c.telefono,c.correo,c.direccion,c.limite_credito,c.estado,coalesce(c.fecmod,c.feccre) version,(select coalesce(sum(saldo),0) from huaman.cuenta_por_cobrar where id_cliente=c.id_cliente and estado='A') saldo from huaman.cliente c";
 private Customer row(ResultSet r,int n)throws SQLException{return new Customer(r.getLong("id_cliente"),r.getString("tipo_documento"),r.getString("nro_documento"),r.getString("nombre_razon_social"),r.getString("telefono"),r.getString("correo"),r.getString("direccion"),r.getBigDecimal("limite_credito").toPlainString(),r.getBigDecimal("saldo").toPlainString(),r.getString("estado"),r.getObject("version",LocalDateTime.class));}
 public Page<Customer> list(String q,String state,int page,int size){String e=Character.toString(92),p="%"+q.replace(e,e+e).replace("%",e+"%").replace("_",e+"_")+"%",f=" where (c.nro_documento ilike ? or c.nombre_razon_social ilike ?) and (?='' or c.estado=?)";long count=jdbc.queryForObject("select count(*) from huaman.cliente c"+f,Long.class,p,p,state,state);return new Page<>(jdbc.query(SELECT+f+" order by lower(c.nombre_razon_social),c.id_cliente limit ? offset ?",this::row,p,p,state,state,size,(long)page*size),count,page,size);}
 public Optional<Customer> get(long id,boolean lock){return jdbc.query(SELECT+" where c.id_cliente=?"+(lock?" for update of c":""),this::row,id).stream().findFirst();}
 public Optional<Customer> lookup(String document){return jdbc.query(SELECT+" where c.nro_documento=? and c.estado='A'",this::row,document).stream().findFirst();}
 public long create(Input i){return jdbc.queryForObject("insert into huaman.cliente(tipo_documento,nro_documento,nombre_razon_social,telefono,correo,direccion) values(?,?,?,?,?,?) returning id_cliente",Long.class,i.tipoDocumento(),i.documento(),i.nombre().strip(),blank(i.telefono()),blank(i.correo()),blank(i.direccion()));}
 private String blank(String s){return s==null||s.isBlank()?null:s.strip();}
 public void update(long id,Input i){jdbc.update("update huaman.cliente set tipo_documento=?,nro_documento=?,nombre_razon_social=?,telefono=?,correo=?,direccion=? where id_cliente=?",i.tipoDocumento(),i.documento(),i.nombre().strip(),blank(i.telefono()),blank(i.correo()),blank(i.direccion()),id);}
 public void credit(long id,BigDecimal limit){jdbc.update("update huaman.cliente set limite_credito=? where id_cliente=?",limit,id);}
 public void state(long id,String state){jdbc.update("update huaman.cliente set estado=? where id_cliente=?",state,id);}
 public boolean history(long id){return Boolean.TRUE.equals(jdbc.queryForObject("select exists(select 1 from huaman.venta where id_cliente=?) or exists(select 1 from huaman.cotizacion where id_cliente=?)",Boolean.class,id,id));}
}

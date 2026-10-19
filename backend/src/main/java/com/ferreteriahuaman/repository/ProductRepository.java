package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.ProductModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository @Profile("db")
public class ProductRepository {
 private final JdbcTemplate jdbc;
 public ProductRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 private static final String PRODUCT="""
 select p.*,c.nombre categoria,u.abreviatura unidad,coalesce(p.fecmod,p.feccre) version,
 (select precio_normal from huaman.presentacion_producto b where b.id_producto=p.id_producto and b.es_base and b.estado='A') precio_base
 from huaman.producto p join huaman.categoria c on c.id_categoria=p.id_categoria join huaman.unidad_medida u on u.id_unidad=p.id_unidad
 """;
 private String decimal(ResultSet r,String name)throws SQLException{var v=r.getBigDecimal(name);return v==null?null:v.toPlainString();}
 private Product product(ResultSet r,int n,boolean costs)throws SQLException{return new Product(r.getLong("id_producto"),r.getString("codigo"),r.getString("nombre"),r.getString("descripcion"),r.getLong("id_categoria"),r.getString("categoria"),r.getLong("id_unidad"),r.getString("unidad"),r.getBoolean("admite_fracciones"),decimal(r,"incremento_base"),decimal(r,"minimo_venta_base"),r.getString("modo_control"),decimal(r,"stock_minimo"),r.getString("ubicacion"),decimal(r,"stock_actual"),decimal(r,"precio_base"),costs?decimal(r,"ultimo_costo_compra"):null,costs?decimal(r,"costo_promedio"):null,r.getString("estado"),r.getObject("version",LocalDateTime.class));}
 public Page<Product> list(String search,String state,Long category,int page,int size,boolean costs){
  String esc=Character.toString(92),q="%"+search.replace(esc,esc+esc).replace("%",esc+"%").replace("_",esc+"_")+"%";
  String filter=" where (p.nombre ilike ? or p.codigo ilike ? or exists(select 1 from huaman.presentacion_producto v join huaman.codigo_presentacion b on b.id_presentacion=v.id_presentacion where v.id_producto=p.id_producto and b.estado='A' and v.estado='A' and b.codigo ilike ?)) and (?='' or p.estado=?) and (?::bigint is null or p.id_categoria=?)";
  var args=new Object[]{q,q,q,state,state,category,category};
  long total=Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.producto p"+filter,Long.class,args));
  var params=new ArrayList<Object>(Arrays.asList(args));params.add(size);params.add((long)page*size);
  return new Page<>(jdbc.query(PRODUCT+filter+" order by lower(p.nombre),p.id_producto limit ? offset ?",(r,n)->product(r,n,costs),params.toArray()),total,page,size);
 }
 public Optional<Product> get(long id,boolean lock,boolean costs){return jdbc.query(PRODUCT+" where p.id_producto=?"+(lock?" for update of p":""),(r,n)->product(r,n,costs),id).stream().findFirst();}
 public long create(ProductInput i){return Objects.requireNonNull(jdbc.queryForObject("""
 insert into huaman.producto(codigo,nombre,descripcion,id_categoria,id_unidad,admite_fracciones,incremento_base,minimo_venta_base,modo_control,stock_minimo,ubicacion)
 values(?,?,?,?,?,?,?,?,?,?,?) returning id_producto
 """,Long.class,i.codigo(),i.nombre().strip(),i.descripcion(),i.categoriaId(),i.unidadId(),i.admiteFracciones(),i.incrementoBase(),i.minimoVentaBase(),i.modoControl(),i.stockMinimo(),i.ubicacion()));}
 public void update(long id,ProductInput i){jdbc.update("update huaman.producto set codigo=?,nombre=?,descripcion=?,id_categoria=?,minimo_venta_base=?,stock_minimo=?,ubicacion=? where id_producto=?",i.codigo(),i.nombre().strip(),i.descripcion(),i.categoriaId(),i.minimoVentaBase(),i.stockMinimo(),i.ubicacion(),id);}
 public void state(long id,String state){jdbc.update("update huaman.producto set estado=? where id_producto=?",state,id);}
 private static final String PRESENTATION="select p.*,u.abreviatura unidad,coalesce(p.fecmod,p.feccre) version from huaman.presentacion_producto p left join huaman.unidad_medida u on u.id_unidad=p.id_unidad_venta";
 private Presentation presentation(ResultSet r,int n)throws SQLException{return new Presentation(r.getLong("id_presentacion"),r.getLong("id_producto"),r.getString("nombre"),r.getObject("id_unidad_venta",Long.class),r.getString("unidad"),decimal(r,"factor_base"),r.getBoolean("es_base"),r.getBoolean("permite_venta"),r.getBoolean("admite_fracciones"),decimal(r,"incremento_venta"),decimal(r,"minimo_venta"),decimal(r,"precio_normal"),r.getString("estado"),r.getObject("version",LocalDateTime.class));}
 public List<Presentation> presentations(long product){return jdbc.query(PRESENTATION+" where p.id_producto=? order by p.es_base desc,lower(p.nombre),p.id_presentacion",(r,n)->presentation(r,n),product);}
 public Optional<Presentation> presentation(long id,boolean lock){return jdbc.query(PRESENTATION+" where p.id_presentacion=?"+(lock?" for update of p":""),(r,n)->presentation(r,n),id).stream().findFirst();}
 public long createPresentation(long product,PresentationInput i,boolean base){return Objects.requireNonNull(jdbc.queryForObject("""
 insert into huaman.presentacion_producto(id_producto,nombre,id_unidad_venta,factor_base,es_base,permite_venta,admite_fracciones,incremento_venta,minimo_venta,precio_normal)
 values(?,?,?,?,?,?,?,?,?,?) returning id_presentacion
 """,Long.class,product,i.nombre().strip(),i.unidadVentaId(),i.factorBase(),base,i.permiteVenta(),i.admiteFracciones(),i.incrementoVenta(),i.minimoVenta(),i.precioNormal()));}
 public void updatePresentation(long id,PresentationInput i){jdbc.update("update huaman.presentacion_producto set nombre=?,permite_venta=?,admite_fracciones=?,incremento_venta=?,minimo_venta=?,precio_normal=? where id_presentacion=?",i.nombre().strip(),i.permiteVenta(),i.admiteFracciones(),i.incrementoVenta(),i.minimoVenta(),i.precioNormal(),id);}
 public void presentationState(long id,String state){jdbc.update("update huaman.presentacion_producto set estado=? where id_presentacion=?",state,id);}
 private Wholesale wholesale(ResultSet r,int n)throws SQLException{return new Wholesale(r.getLong("id_precio_mayorista"),r.getLong("id_presentacion"),decimal(r,"cantidad_minima"),decimal(r,"precio"),r.getString("estado"),r.getObject("version",LocalDateTime.class));}
 private static final String WHOLESALE="select w.*,coalesce(w.fecmod,w.feccre) version from huaman.precio_mayorista w";
 public List<Wholesale> wholesale(long product){return jdbc.query(WHOLESALE+" join huaman.presentacion_producto p on p.id_presentacion=w.id_presentacion where p.id_producto=? order by w.cantidad_minima",(r,n)->wholesale(r,n),product);}
 public Optional<Wholesale> wholesaleById(long id){return jdbc.query(WHOLESALE+" where w.id_precio_mayorista=? for update",(r,n)->wholesale(r,n),id).stream().findFirst();}
 public long createWholesale(long presentation,WholesaleInput i){return Objects.requireNonNull(jdbc.queryForObject("insert into huaman.precio_mayorista(id_presentacion,cantidad_minima,precio) values(?,?,?) returning id_precio_mayorista",Long.class,presentation,i.cantidadMinima(),i.precio()));}
 public void updateWholesale(long id,WholesaleInput i){jdbc.update("update huaman.precio_mayorista set cantidad_minima=?,precio=? where id_precio_mayorista=?",i.cantidadMinima(),i.precio(),id);}
 public void wholesaleState(long id,String state){jdbc.update("update huaman.precio_mayorista set estado=? where id_precio_mayorista=?",state,id);}
 private Barcode barcode(ResultSet r,int n)throws SQLException{return new Barcode(r.getLong("id_codigo"),r.getLong("id_presentacion"),r.getString("codigo"),r.getString("simbologia"),r.getString("estado"),r.getObject("version",LocalDateTime.class));}
 private static final String BARCODE="select b.*,coalesce(b.fecmod,b.feccre) version from huaman.codigo_presentacion b";
 public List<Barcode> barcodes(long product){return jdbc.query(BARCODE+" join huaman.presentacion_producto p on p.id_presentacion=b.id_presentacion where p.id_producto=? order by b.id_codigo",(r,n)->barcode(r,n),product);}
 public Optional<Barcode> barcode(long id){return jdbc.query(BARCODE+" where b.id_codigo=? for update",(r,n)->barcode(r,n),id).stream().findFirst();}
 public long createBarcode(long presentation,BarcodeInput i){return Objects.requireNonNull(jdbc.queryForObject("insert into huaman.codigo_presentacion(id_presentacion,codigo,simbologia) values(?,?,?) returning id_codigo",Long.class,presentation,i.codigo(),i.simbologia()));}
 public void barcodeState(long id,String state){jdbc.update("update huaman.codigo_presentacion set estado=? where id_codigo=?",state,id);}
 public boolean barcodeCollision(String code){return Boolean.TRUE.equals(jdbc.queryForObject("select exists(select 1 from huaman.producto where codigo=upper(?)) or exists(select 1 from huaman.codigo_presentacion where upper(codigo)=upper(?))",Boolean.class,code,code));}
 public void lockCodes(){jdbc.execute("select pg_advisory_xact_lock(73210,1)");}
}


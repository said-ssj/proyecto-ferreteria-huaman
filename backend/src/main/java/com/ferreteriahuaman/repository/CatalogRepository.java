package com.ferreteriahuaman.repository;

import com.ferreteriahuaman.dto.CatalogModels.*;
import java.sql.*;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository @Profile("db")
public class CatalogRepository {
    private final JdbcTemplate jdbc;
    public CatalogRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
    private static final String CATEGORY="select id_categoria,nombre,descripcion,estado,coalesce(fecmod,feccre) version from huaman.categoria";
    private static final String UNIT="select id_unidad,nombre,abreviatura,codigo_sunat,descripcion_comercial,admite_decimales,magnitud,factor_referencia,precision_cantidad,estado,coalesce(fecmod,feccre) version from huaman.unidad_medida";
    private Category category(ResultSet r,int row)throws SQLException{return new Category(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getObject(5,LocalDateTime.class));}
    private Unit unit(ResultSet r,int row)throws SQLException{return new Unit(r.getLong(1),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getBoolean(6),r.getString(7),r.getBigDecimal(8),r.getInt(9),r.getString(10),r.getObject(11,LocalDateTime.class));}
    private String pattern(String search){String escape=Character.toString(92);return "%"+search.replace(escape,escape+escape).replace("%",escape+"%").replace("_",escape+"_")+"%";}
    public Page<Category> categories(String search,String state,int page,int size){
        String filter=" where nombre ilike ? and (?='' or estado=?)";String q=pattern(search);
        long total=Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.categoria"+filter,Long.class,q,state,state));
        return new Page<>(jdbc.query(CATEGORY+filter+" order by lower(nombre),id_categoria limit ? offset ?",this::category,q,state,state,size,(long)page*size),total,page,size);
    }
    public Page<Unit> units(String search,String state,int page,int size){
        String filter=" where (nombre ilike ? or codigo_sunat ilike ? or abreviatura ilike ?) and (?='' or estado=?)";String q=pattern(search);
        long total=Objects.requireNonNull(jdbc.queryForObject("select count(*) from huaman.unidad_medida"+filter,Long.class,q,q,q,state,state));
        return new Page<>(jdbc.query(UNIT+filter+" order by lower(nombre),id_unidad limit ? offset ?",this::unit,q,q,q,state,state,size,(long)page*size),total,page,size);
    }
    public Optional<Category> category(long id,boolean lock){return jdbc.query(CATEGORY+" where id_categoria=?"+(lock?" for update":""),this::category,id).stream().findFirst();}
    public Optional<Unit> unit(long id,boolean lock){return jdbc.query(UNIT+" where id_unidad=?"+(lock?" for update":""),this::unit,id).stream().findFirst();}
    public long createCategory(CategoryInput input){return Objects.requireNonNull(jdbc.queryForObject("insert into huaman.categoria(nombre,descripcion) values(?,?) returning id_categoria",Long.class,input.nombre().strip(),input.descripcion()));}
    public void updateCategory(long id,CategoryInput input){jdbc.update("update huaman.categoria set nombre=?,descripcion=? where id_categoria=?",input.nombre().strip(),input.descripcion(),id);}
    public void categoryState(long id,String state){jdbc.update("update huaman.categoria set estado=? where id_categoria=?",state,id);}
    public boolean categoryInUse(long id){return Boolean.TRUE.equals(jdbc.queryForObject("select exists(select 1 from huaman.producto where id_categoria=? and estado='A')",Boolean.class,id));}
    public long createUnit(UnitInput i){return Objects.requireNonNull(jdbc.queryForObject("""
        insert into huaman.unidad_medida(nombre,abreviatura,codigo_sunat,descripcion_comercial,admite_decimales,magnitud,factor_referencia,precision_cantidad)
        values(?,?,?,?,?,?,?,?) returning id_unidad
        """,Long.class,i.nombre().strip(),i.abreviatura().strip(),i.codigoSunat(),i.descripcionComercial().strip(),i.admiteDecimales(),i.magnitud(),i.factorReferencia(),i.precisionCantidad()));}
    public void updateUnit(long id,UnitInput i){jdbc.update("""
        update huaman.unidad_medida set nombre=?,abreviatura=?,codigo_sunat=?,descripcion_comercial=?,admite_decimales=?,magnitud=?,factor_referencia=?,precision_cantidad=? where id_unidad=?
        """,i.nombre().strip(),i.abreviatura().strip(),i.codigoSunat(),i.descripcionComercial().strip(),i.admiteDecimales(),i.magnitud(),i.factorReferencia(),i.precisionCantidad(),id);}
    public void unitState(long id,String state){jdbc.update("update huaman.unidad_medida set estado=? where id_unidad=?",state,id);}
    public boolean unitInUse(long id){return Boolean.TRUE.equals(jdbc.queryForObject("select exists(select 1 from huaman.producto where id_unidad=?) or exists(select 1 from huaman.presentacion_producto where id_unidad_venta=?)",Boolean.class,id,id));}
    public void event(long actor,String action,String entity,long id,String before,String after){jdbc.update("insert into huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,valor_anterior,valor_nuevo) values(?,?,?,?,?::jsonb,?::jsonb)",actor,action,entity,id,before,after);}
}

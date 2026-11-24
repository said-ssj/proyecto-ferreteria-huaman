package com.ferreteriahuaman.repository;
import com.ferreteriahuaman.dto.AuditModels.*;import com.ferreteriahuaman.dto.CatalogModels.Page;
import java.sql.*;import java.time.LocalDateTime;import java.util.*;
import org.springframework.context.annotation.Profile;import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.stereotype.Repository;import org.springframework.transaction.annotation.Transactional;
@Repository @Profile("db")
public class AuditRepository {
 private final JdbcTemplate jdbc;public AuditRepository(JdbcTemplate jdbc){this.jdbc=jdbc;}
 private static final String FROM=" from huaman.bitacora_evento b left join huaman.usuario u on u.id_usuario=b.id_usuario ";
 private static final String COLUMNS="b.id_evento,b.feccre,coalesce(u.username,b.usucre) usuario,b.accion,b.entidad,b.id_entidad,b.pccre";
 private Event event(ResultSet r,int n)throws SQLException{return new Event(r.getLong("id_evento"),r.getObject("feccre",LocalDateTime.class),r.getString("usuario"),r.getString("accion"),r.getString("entidad"),r.getObject("id_entidad",Long.class),r.getString("pccre"));}
 @Transactional(readOnly=true,isolation=org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
 public Page<Event> list(Filter f){var args=new ArrayList<Object>();var where=new StringBuilder(" where true");
  if(f.desde()!=null){where.append(" and b.feccre>=?");args.add(f.desde().atStartOfDay());}
  if(f.hasta()!=null){where.append(" and b.feccre<?");args.add(f.hasta().plusDays(1).atStartOfDay());}
  if(!f.usuario().isEmpty()){where.append(" and position(lower(?) in lower(coalesce(u.username,b.usucre)))>0");args.add(f.usuario());}
  if(!f.accion().isEmpty()){where.append(" and b.accion=?");args.add(f.accion());}
  if(f.grupo().equals("SEGURIDAD"))where.append(" and b.accion like 'SEG.%'");
  if(f.grupo().equals("OPERACIONES"))where.append(" and b.accion not like 'SEG.%'");
  long total=Objects.requireNonNull(jdbc.queryForObject("select count(*)"+FROM+where,Long.class,args.toArray()));args.add(f.tamano());args.add((long)f.pagina()*f.tamano());
  return new Page<>(jdbc.query("select "+COLUMNS+FROM+where+" order by b.feccre desc,b.id_evento desc limit ? offset ?",this::event,args.toArray()),total,f.pagina(),f.tamano());
 }
 public Optional<Raw> detail(long id){return jdbc.query("select "+COLUMNS+",b.valor_anterior::text,b.valor_nuevo::text"+FROM+" where b.id_evento=?",(r,n)->new Raw(event(r,n),r.getString("valor_anterior"),r.getString("valor_nuevo")),id).stream().findFirst();}
 public List<String> actions(){return jdbc.queryForList("select distinct accion from huaman.bitacora_evento order by accion",String.class);}
}

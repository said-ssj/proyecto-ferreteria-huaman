package com.ferreteriahuaman.service;
import com.ferreteriahuaman.dto.InventoryModels.*;
import com.ferreteriahuaman.dto.CatalogModels.Page;
import com.ferreteriahuaman.repository.InventoryRepository;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.ferreteriahuaman.security.AuthFailure;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;
@Service @Profile("db")
public class InventoryService {
 private final InventoryRepository repo;private final BusinessTransactions tx;private final ObjectMapper mapper;
 public InventoryService(InventoryRepository repo,BusinessTransactions tx,ObjectMapper mapper){this.repo=repo;this.tx=tx;this.mapper=mapper;}
 private void page(String q,int page,int size){if(q.length()>100||page<0||page>1000000||size<1||size>100)throw new AuthFailure(400,"Revisa los filtros y la paginación");}
 private void state(String state,Set<String> allowed){if(!allowed.contains(state))throw new AuthFailure(400,"Estado no válido");}
 private String json(Object value){try{return mapper.writeValueAsString(value);}catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException("No se pudo preparar la operación");}}
 private String units(List<Physical> plan){var list=new ArrayList<Map<String,Object>>();for(var u:plan){var row=new LinkedHashMap<String,Object>();row.put("cantidad",u.cantidad());if(u.unidadId()!=null){if(u.unidadId()<1||u.condicion()!=null||u.presentacionId()!=null)throw new AuthFailure(400,"Una pieza existente solo requiere su identificación y cantidad");row.put("id_unidad",u.unidadId());}else{if(u.condicion()==null||u.presentacionId()!=null&&u.presentacionId()<1)throw new AuthFailure(400,"Indica la condición física del material nuevo");row.put("condicion",u.condicion());if(u.presentacionId()!=null)row.put("id_presentacion",u.presentacionId());}list.add(row);}return json(list);}
 public Page<Map<String,Object>> alerts(String q,String state,int page,int size){page(q,page,size);state(state,Set.of("","ABIERTA","CERRADA"));return repo.alerts(q.strip(),state,page,size);}
 public Page<Map<String,Object>> adjustments(Identity a,String q,String type,int page,int size){page(q,page,size);state(type,Set.of("","AUMENTO","DISMINUCION"));return repo.adjustments(q.strip(),type,page,size,a.permisos().contains("PRO.COSTOS"));}
 public List<Map<String,Object>> reasons(){return repo.reasons();}
 public Page<Map<String,Object>> takes(String q,String state,int page,int size){page(q,page,size);state(state,Set.of("","EN_CONTEO","CERRADA","APROBADA","ANULADA"));return repo.takes(q.strip(),state,page,size);}
 public Map<String,Object> take(long id){return repo.take(id).orElseThrow(()->new AuthFailure(404,"Toma de inventario no encontrada"));}
 public Page<Map<String,Object>> counts(Identity a,long id,String q,int page,int size){page(q,page,size);take(id);return repo.counts(id,q.strip(),page,size,a.permisos().contains("PRO.COSTOS"));}
 public Result adjust(Identity a,String equipo,Adjustment i){return tx.write(a,equipo,"INV.AJUSTAR",()->new Result(repo.adjust(i,units(i.unidades()))));}
 public Result transform(Identity a,String equipo,Transformation i){if(i.operacion().equals("ABRIR")&&!i.longitudes().isEmpty()||i.operacion().equals("CORTAR")&&i.longitudes().size()<2)throw new AuthFailure(400,"El corte requiere al menos dos longitudes, incluido el remanente; abrir un envase no lleva longitudes");return tx.write(a,equipo,"INV.TRANSFORMAR",()->new Result(repo.transform(i,json(i.longitudes()))));}
 public Result start(Identity a,String equipo,Start i){if(i.alcance().equals("TODO")&&i.categoriaId()!=null||i.alcance().equals("CATEGORIA")&&(i.categoriaId()==null||i.categoriaId()<1))throw new AuthFailure(400,"Selecciona el alcance y la categoría correctamente");return tx.write(a,equipo,"INV.TOMA_GESTIONAR",()->new Result(repo.start(i)));}
 public Result count(Identity a,String equipo,long id,Count i){return tx.write(a,equipo,"INV.TOMA_CONTAR",()->new Result(repo.count(id,i,units(i.unidades()))));}
 public Result transition(Identity a,String equipo,long id,String action,Transition i){if(!Set.of("cerrar","reabrir","anular","aprobar").contains(action))throw new AuthFailure(404,"Acción no encontrada");if(Set.of("reabrir","anular").contains(action)&&(i.motivo()==null||i.motivo().strip().length()<10||i.motivo().length()>200))throw new AuthFailure(400,"Indica un motivo de 10 a 200 caracteres");return tx.write(a,equipo,"INV.TOMA_GESTIONAR",()->new Result(repo.transition(id,action,i)));}
}

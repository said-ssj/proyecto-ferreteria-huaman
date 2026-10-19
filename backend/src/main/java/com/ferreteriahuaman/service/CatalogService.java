package com.ferreteriahuaman.service;

import com.ferreteriahuaman.dto.CatalogModels.*;
import com.ferreteriahuaman.repository.CatalogRepository;
import com.ferreteriahuaman.security.AuthFailure;
import com.ferreteriahuaman.security.AuthModels.Identity;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.LocalDateTime;
import java.util.Objects;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

@Service @Profile("db")
public class CatalogService {
    private final CatalogRepository repo;private final BusinessTransactions tx;private final ObjectMapper mapper;
    public CatalogService(CatalogRepository repo,BusinessTransactions tx,ObjectMapper mapper){this.repo=repo;this.tx=tx;this.mapper=mapper;}
    public Page<Category> categories(String q,String state,int page,int size){validatePage(q,state,page,size);return repo.categories(q.strip(),state,page,size);}
    public Page<Unit> units(String q,String state,int page,int size){validatePage(q,state,page,size);return repo.units(q.strip(),state,page,size);}
    public Category category(long id){return repo.category(id,false).orElseThrow(()->new AuthFailure(404,"Categoría no encontrada"));}
    public Unit unit(long id){return repo.unit(id,false).orElseThrow(()->new AuthFailure(404,"Unidad de medida no encontrada"));}
    private void validatePage(String q,String state,int page,int size){if(q.length()>100||!state.matches("A|I|^$")||page<0||page>1000000||size<1||size>100)throw new AuthFailure(400,"Revisa los filtros y el tamaño de página");}
    private void version(LocalDateTime expected,LocalDateTime current){if(expected==null)throw new AuthFailure(400,"Falta la versión del registro");if(!Objects.equals(expected,current))throw new AuthFailure(409,"El registro cambió. Vuelve a cargarlo antes de guardar");}
    private String json(Object value){if(value==null)return null;try{return mapper.writeValueAsString(value);}catch(JsonProcessingException e){throw new IllegalStateException("No se pudo registrar la auditoría");}}
    public Category createCategory(Identity actor,String equipo,CategoryInput input){return tx.write(actor,equipo,"CAT.GESTIONAR",()->{
        long id=repo.createCategory(input);Category result=category(id);repo.event(actor.id(),"CAT.CREAR","categoria",id,null,json(result));return result;
    });}
    public Category updateCategory(Identity actor,String equipo,long id,CategoryInput input){return tx.write(actor,equipo,"CAT.GESTIONAR",()->{
        Category before=repo.category(id,true).orElseThrow(()->new AuthFailure(404,"Categoría no encontrada"));version(input.version(),before.version());repo.updateCategory(id,input);Category result=category(id);repo.event(actor.id(),"CAT.EDITAR","categoria",id,json(before),json(result));return result;
    });}
    public Category categoryState(Identity actor,String equipo,long id,StateInput input){return tx.write(actor,equipo,"CAT.GESTIONAR",()->{
        Category before=repo.category(id,true).orElseThrow(()->new AuthFailure(404,"Categoría no encontrada"));version(input.version(),before.version());
        if(before.estado().equals(input.estado()))return before;
        if(input.estado().equals("I")&&repo.categoryInUse(id))throw new AuthFailure(409,"La categoría tiene productos activos y no puede desactivarse");
        repo.categoryState(id,input.estado());Category result=category(id);repo.event(actor.id(),"CAT.ESTADO","categoria",id,json(before),json(result));return result;
    });}
    private void validateUnit(UnitInput input){if(input.admiteDecimales()!=(input.precisionCantidad()>0))throw new AuthFailure(400,"La precisión debe ser cero si la unidad no admite decimales");}
    public Unit createUnit(Identity actor,String equipo,UnitInput input){validateUnit(input);return tx.write(actor,equipo,"UNI.GESTIONAR",()->{
        long id=repo.createUnit(input);Unit result=unit(id);repo.event(actor.id(),"UNI.CREAR","unidad_medida",id,null,json(result));return result;
    });}
    public Unit updateUnit(Identity actor,String equipo,long id,UnitInput input){validateUnit(input);return tx.write(actor,equipo,"UNI.GESTIONAR",()->{
        Unit before=repo.unit(id,true).orElseThrow(()->new AuthFailure(404,"Unidad no encontrada"));version(input.version(),before.version());
        boolean measurementChanged=!before.codigoSunat().equals(input.codigoSunat())||!before.magnitud().equals(input.magnitud())||before.factorReferencia().compareTo(input.factorReferencia())!=0||before.precisionCantidad()!=input.precisionCantidad()||before.admiteDecimales()!=input.admiteDecimales();
        if(measurementChanged&&repo.unitInUse(id))throw new AuthFailure(409,"La unidad está en uso. No se puede cambiar su código, magnitud, factor o precisión");
        repo.updateUnit(id,input);Unit result=unit(id);repo.event(actor.id(),"UNI.EDITAR","unidad_medida",id,json(before),json(result));return result;
    });}
    public Unit unitState(Identity actor,String equipo,long id,StateInput input){return tx.write(actor,equipo,"UNI.GESTIONAR",()->{
        Unit before=repo.unit(id,true).orElseThrow(()->new AuthFailure(404,"Unidad no encontrada"));version(input.version(),before.version());
        if(before.estado().equals(input.estado()))return before;
        if(input.estado().equals("I")&&repo.unitInUse(id))throw new AuthFailure(409,"La unidad está en uso y no puede desactivarse");
        repo.unitState(id,input.estado());Unit result=unit(id);repo.event(actor.id(),"UNI.ESTADO","unidad_medida",id,json(before),json(result));return result;
    });}
}

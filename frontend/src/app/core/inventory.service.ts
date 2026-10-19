import {inject,Injectable} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
import {CatalogPage} from './catalog.service';
export interface InventoryRow {[key:string]:any;id:number;}
export interface InventoryPhysical {unidadId:number|null;condicion:string|null;presentacionId:number|null;cantidad:string;}
@Injectable({providedIn:'root'})
export class InventoryService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/inventario';
 list(type:'alertas'|'ajustes'|'tomas',q:string,state:string,page:number){return this.http.get<CatalogPage<InventoryRow>>(this.base+'/'+type,{params:{buscar:q,estado:state,pagina:page,tamano:20}});}
 reasons(){return this.http.get<{id:number;nombre:string}[]>(this.base+'/motivos');}
 take(id:number){return this.http.get<InventoryRow>(this.base+'/tomas/'+id);}
 counts(id:number,q:string,page:number){return this.http.get<CatalogPage<InventoryRow>>(this.base+'/tomas/'+id+'/lineas',{params:{buscar:q,pagina:page,tamano:20}});}
 adjust(body:object){return this.http.post<{id:number}>(this.base+'/ajustes',body);}
 transform(body:object){return this.http.post<{id:number}>(this.base+'/transformaciones',body);}
 start(body:object){return this.http.post<{id:number}>(this.base+'/tomas',body);}
 count(id:number,body:object){return this.http.post<{id:number}>(this.base+'/tomas/'+id+'/conteos',body);}
 transition(id:number,action:string,body:object){return this.http.post<{id:number}>(this.base+'/tomas/'+id+'/acciones/'+action,body);}
}

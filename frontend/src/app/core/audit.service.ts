import {inject,Injectable} from '@angular/core';import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';
export interface AuditEvent{id:number;fecha:string;usuario:string;accion:string;entidad:string;registro:number|null;equipo:string;}
export interface AuditDetail{evento:AuditEvent;anterior:unknown;nuevo:unknown;}
export interface AuditFilters{desde:string;hasta:string;usuario:string;accion:string;grupo:string;}
@Injectable({providedIn:'root'}) export class AuditService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/bitacora';
 list(filters:AuditFilters,pagina:number){return this.http.get<{items:AuditEvent[];total:number;pagina:number;tamano:number}>(this.base,{params:new HttpParams({fromObject:{...filters,pagina,tamano:25}})});}
 options(){return this.http.get<{acciones:string[]}>(this.base+'/opciones');}
 detail(id:number){return this.http.get<AuditDetail>(this.base+'/'+id);}
}

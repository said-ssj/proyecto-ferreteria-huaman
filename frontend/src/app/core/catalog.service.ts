import {inject,Injectable} from '@angular/core';
import {HttpClient,HttpParams} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
export interface Category {id:number;nombre:string;descripcion:string|null;estado:'A'|'I';version:string;}
export interface Unit extends Category {abreviatura:string;codigoSunat:string;descripcionComercial:string;admiteDecimales:boolean;magnitud:string;factorReferencia:number|string;precisionCantidad:number;}
export interface CatalogPage<T>{items:T[];total:number;pagina:number;tamano:number;}
@Injectable({providedIn:'root'})
export class CatalogService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/catalogos';
 list(unit:boolean,search:string,state:string,page:number){return this.http.get<CatalogPage<Category|Unit>>(this.url(unit),{params:new HttpParams().set('buscar',search).set('estado',state).set('pagina',page).set('tamano',20)});}
 get(unit:boolean,id:number){return this.http.get<Category|Unit>(this.url(unit)+'/'+id);}
 save(unit:boolean,id:number|null,body:object){return id?this.http.put<Category|Unit>(this.url(unit)+'/'+id,body):this.http.post<Category|Unit>(this.url(unit),body);}
 state(unit:boolean,row:Category,state:'A'|'I'){return this.http.patch<Category|Unit>(this.url(unit)+'/'+row.id+'/estado',{estado:state,version:row.version});}
 private url(unit:boolean){return this.base+(unit?'/unidades':'/categorias');}
}

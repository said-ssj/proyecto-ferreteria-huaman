import {inject,Injectable} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
export interface SettingParameter{clave:string;grupo:string;valor:string;tipo:string;minimo:string|number|null;maximo:string|number|null;descripcion:string;editable:boolean;version:string|null;}
export interface DocumentSeries{id:number;tipo:string;serie:string;inicial:number;ultimo:number;estado:string;usada:boolean;version:string;}
export interface ProductLabel{producto:string;presentacion:string;codigo:string;simbologia:'EAN13'|'CODE128';precio:string;cantidad:number;}
@Injectable({providedIn:'root'})
export class SettingsService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/configuracion';
 parameters(printing:boolean){return this.http.get<SettingParameter[]>(this.base+(printing?'/impresion':'/parametros'));}
 saveParameters(printing:boolean,cambios:{clave:string;valor:string;version:string|null}[]){return this.http.put<SettingParameter[]>(this.base+(printing?'/impresion':'/parametros'),{cambios});}
 series(){return this.http.get<DocumentSeries[]>(this.base+'/series');}
 saveSeries(id:number|null,value:object){return id?this.http.put<DocumentSeries>(this.base+'/series/'+id,value):this.http.post<DocumentSeries>(this.base+'/series',value);}
 state(series:DocumentSeries){return this.http.patch<DocumentSeries>(this.base+'/series/'+series.id+'/estado',{estado:series.estado==='A'?'I':'A',version:series.version});}
 labels(input:{productoId:number;presentacionId:number;codigoId:number|null;cantidad:number}){return this.http.post<ProductLabel>(this.base+'/etiquetas',input);}
}

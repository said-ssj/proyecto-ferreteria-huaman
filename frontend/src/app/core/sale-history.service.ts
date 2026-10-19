import {inject,Injectable} from '@angular/core';import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {CatalogPage} from './catalog.service';import {SaleDetails} from './sale.service';
export interface SaleHistoryRow {id:number;fecha:string;cliente:string;documento:string|null;vendedor:string;tipo:string;total:string;estado:string;serie:string;numero:number;medios:string;}
export interface SaleHistoryFilter {buscar:string;desde:string;hasta:string;tipo:string;estado:string;vendedor:string|number;}
@Injectable({providedIn:'root'}) export class SaleHistoryService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/historial-ventas';
 list(filters:SaleHistoryFilter,pagina:number){let params=new HttpParams().set('pagina',pagina);for(const [key,value] of Object.entries(filters))if(value!=='')params=params.set(key,value);return this.http.get<CatalogPage<SaleHistoryRow>>(this.base,{params});}
 sellers(){return this.http.get<{id:number;nombre:string}[]>(this.base+'/vendedores');}
 get(id:number){return this.http.get<SaleDetails>(this.base+'/'+id);}
 action(id:number,action:'reimpresion'|'copia'|'anulacion',body:object){return this.http.post<SaleDetails>(this.base+'/'+id+'/'+action,body);}
}

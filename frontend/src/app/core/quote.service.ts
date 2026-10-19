import {inject,Injectable} from '@angular/core';import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {CatalogPage} from './catalog.service';
export interface QuoteHeader {id:number;numero:number;fecha:string;vigenteHasta:string;revision:number;vendedorId:number;vendedor:string;clienteId:number|null;cliente:string;documento:string|null;interesado:string|null;observacion:string|null;subtotal:string;descuento:string;total:string;estado:string;motivoAnulacion:string|null;emitidaEn:string|null;anuladaEn:string|null;version:string;ventaId:number|null;estadoVenta:string|null;ventaVendedorId:number|null;hoy:string;}
export interface QuoteLine {id:number;productoId:number;presentacionId:number;producto:string;presentacion:string;unidad:string;cantidad:string;cantidadBase:string;factor:string;precioLista:string;precio:string;origen:string;descuento:string;importe:string;}
export interface QuoteDetails {cotizacion:QuoteHeader;lineas:QuoteLine[];}
export interface QuoteFilter {buscar:string;estado:string;desde:string;hasta:string;}
@Injectable({providedIn:'root'}) export class QuoteService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/cotizaciones';
 options(){return this.http.get<{hoy:string;vigenciaDias:number;caja:{id:number;fecha:string;estado:string}|null}>(this.base+'/opciones');}
 list(filters:QuoteFilter,pagina:number){let params=new HttpParams().set('pagina',pagina);for(const [key,value] of Object.entries(filters))if(value)params=params.set(key,value);return this.http.get<CatalogPage<QuoteHeader>>(this.base,{params});}
 get(id:number){return this.http.get<QuoteDetails>(this.base+'/'+id);}
 save(id:number|null,body:object){return id?this.http.put<QuoteDetails>(this.base+'/'+id,body):this.http.post<QuoteDetails>(this.base,body);}
 action(id:number,action:string,body:object){return this.http.post<QuoteDetails>(this.base+'/'+id+'/acciones/'+action,body);}
 convert(id:number,body:object){return this.http.post<{ventaId:number}>(this.base+'/'+id+'/convertir',body);}
}

import {inject,Injectable} from '@angular/core';import {HttpClient} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {CatalogPage} from './catalog.service';
export interface SaleLine {id:number;productoId:number;presentacionId:number;producto:string;presentacion:string;unidad:string;cantidad:string;cantidadBase:string;factor:string;piezas:number;longitudPieza:string|null;precioLista:string;precio:string;origen:string;descuento:string;importe:string;modoControl:string;}
export interface SaleDetails {venta:{id:number;cajaId:number;cotizacionId?:number|null;cotizacionVigenteHasta?:string|null;entregaInmediata?:boolean;despachoEstado?:string|null;motivoAnulacion?:string|null;fechaAnulacion?:string|null;origenId?:number|null;vendedor:string;cliente:string;documento:string|null;direccion:string|null;tipo:string;estado:string;total:string;subtotal:string;descuento:string;base:string;igv:string;version:string;fecha:string};lineas:SaleLine[];pagos:{medio:string;monto:string;recibido:string|null;vuelto:string|null;operacion:string|null;marca:string|null;ultimosCuatro:string|null}[];comprobante:Record<string,any>|null;}
export interface SaleUnit {id:number;identificador:string;condicion:string;cantidad:string;presentacionId:number|null;}
@Injectable({providedIn:'root'}) export class SaleService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/ventas';
 options(){return this.http.get<{datosTributariosCompletos:boolean;fecha:string;caja:{id:number;fecha:string;estado:string}|null;series:{id:number;tipo:string;serie:string}[]}>(this.base+'/opciones');}
 drafts(){return this.http.get<{id:number;fecha:string;cliente:string;total:string}[]>(this.base+'/borradores');}
 get(id:number){return this.http.get<SaleDetails>(this.base+'/'+id);}
 create(body:object){return this.http.post<SaleDetails>(this.base+'/borradores',body);}
 confirm(id:number,body:object){return this.http.post<SaleDetails>(this.base+'/'+id+'/confirmar',body);}
 discard(id:number,body:object){return this.http.post<SaleDetails>(this.base+'/'+id+'/descartar',body);}
 units(id:number,linea:number,pagina:number){return this.http.get<CatalogPage<SaleUnit>>(this.base+'/'+id+'/existencias',{params:{linea,pagina}});}
}

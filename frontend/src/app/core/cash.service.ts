import {inject,Injectable} from '@angular/core';import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {CatalogPage} from './catalog.service';
export interface CashRegister {id:number;fecha:string;estado:'ABIERTA'|'CERRADA';fondo:string;apertura:string;cierre:string|null;fechaApertura:string;fechaCierre:string|null;observacionApertura:string|null;observacionCierre:string|null;efectivo:string;yape:string;debito:string;efectivoContado:string|null;yapeReportado:string|null;debitoReportado:string|null;diferenciaEfectivo:string|null;diferenciaYape:string|null;diferenciaDebito:string|null;ventasPendientes:number;}
export interface CashMovement {id:number;tipo:string;medio:string;sentido:string;importe:string;motivo:string|null;fecha:string;usuario:string;ventaId:number|null;}
@Injectable({providedIn:'root'}) export class CashService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/caja';
 current(){return this.http.get<{fechaServidor:string;caja:CashRegister|null}>(this.base+'/actual');}
 history(desde:string,hasta:string,estado:string,pagina:number){let params=new HttpParams().set('estado',estado).set('pagina',pagina);if(desde)params=params.set('desde',desde);if(hasta)params=params.set('hasta',hasta);return this.http.get<CatalogPage<CashRegister>>(this.base+'/historial',{params});}
 get(id:number){return this.http.get<CashRegister>(this.base+'/historial/'+id);}
 movements(id:number|null,pagina:number){return this.http.get<CatalogPage<CashMovement>>(this.base+(id===null?'/actual':'/historial/'+id)+'/movimientos',{params:{pagina}});}
 execute(action:'abrir'|'movimientos'|'cerrar',id:number|null,body:object){return this.http.post<{id:number}>(this.base+(action==='abrir'?'/abrir':'/'+id+'/'+action),body);}
}

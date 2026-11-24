import {inject,Injectable} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
export interface RucData {ruc:string;razonSocial:string;estadoTributario:string|null;condicion:string|null;direccion:string|null;ubigeo:string|null;departamento:string|null;provincia:string|null;distrito:string|null;}
@Injectable({providedIn:'root'}) export class DecolectaService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL);
 lookup(numero:string){return this.http.get<RucData>(this.base+'/consultas/ruc',{params:{numero}});}
}

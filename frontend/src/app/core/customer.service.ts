import {inject,Injectable} from '@angular/core';
import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {CatalogPage} from './catalog.service';
export interface Customer {id:number;tipoDocumento:'DNI'|'RUC';documento:string;nombre:string;telefono:string|null;correo:string|null;direccion:string|null;limiteCredito:string;saldoPendiente:string;estado:'A'|'I';version:string;}
@Injectable({providedIn:'root'}) export class CustomerService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/clientes';
 customers(buscar:string,estado:string,pagina:number){return this.http.get<CatalogPage<Customer>>(this.base,{params:new HttpParams().set('buscar',buscar).set('estado',estado).set('pagina',pagina).set('tamano',20)});}
 customer(id:number){return this.http.get<Customer>(this.base+'/'+id);}
 lookup(documento:string){return this.http.get<Customer>(this.base+'/buscar-documento',{params:{documento}});}
 saveCustomer(id:number|null,body:object){return id?this.http.put<Customer>(this.base+'/'+id,body):this.http.post<Customer>(this.base,body);}
 customerState(row:Customer){return this.http.patch<Customer>(this.base+'/'+row.id+'/estado',{estado:row.estado==='A'?'I':'A',version:row.version});}
 credit(row:Customer,limite:string){return this.http.patch<Customer>(this.base+'/'+row.id+'/credito',{limite,version:row.version});}
}

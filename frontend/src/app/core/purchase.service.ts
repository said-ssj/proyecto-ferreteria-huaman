import {inject,Injectable} from '@angular/core';
import {HttpClient,HttpParams} from '@angular/common/http';
import {EMPTY,expand,reduce} from 'rxjs';
import {API_BASE_URL} from './auth.service';
import {CatalogPage} from './catalog.service';
export interface Supplier {id:number;ruc:string;razonSocial:string;contacto:string|null;telefono:string|null;correo:string|null;direccion:string|null;estado:'A'|'I';version:string;}
export type PurchaseKind='ordenes'|'ingresos';
export interface PurchaseDocument {id:number;numero:number;proveedorId:number;proveedor:string;fecha:string;entregaEstimada:string|null;ordenId:number|null;guia:string|null;observacion:string|null;total:string;estado:string;version:string;}
export interface PurchaseLine {id:number;productoId:number;producto:string;presentacionId:number;presentacion:string;unidad:string;factorBase:string;cantidad:string;cantidadBase:string;recibidoBase:string|null;canceladoBase:string|null;costoUnitario:string;importe:string;detalleOrdenId:number|null;condicion:string|null;piezas:number|null;estado:'A'|'I';}
export interface PurchaseDetails {documento:PurchaseDocument;lineas:PurchaseLine[];}
export interface Movement {id:number;tipo:string;sentido:string;cantidad:string;saldoAnterior:string;saldo:string;costoUnitarioBase:string|null;fecha:string;}
export interface Existence {id:number;identificador:string;condicion:string;cantidadInicial:string;cantidadDisponible:string;presentacionId:number|null;estado:string;}
export interface PhysicalUnit {identificador:string;condicion:string;cantidad:string;presentacionId:number|null;}
@Injectable({providedIn:'root'})
export class PurchaseService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL);
 suppliers(search:string,state:string,page:number,size=20){return this.http.get<CatalogPage<Supplier>>(this.base+'/proveedores',{params:{buscar:search,estado:state,pagina:page,tamano:size}});}
 supplier(id:number){return this.http.get<Supplier>(this.base+'/proveedores/'+id);}
 saveSupplier(id:number|null,body:object){return id?this.http.put<Supplier>(this.base+'/proveedores/'+id,body):this.http.post<Supplier>(this.base+'/proveedores',body);}
 supplierState(row:Supplier){return this.http.patch<Supplier>(this.base+'/proveedores/'+row.id+'/estado',{estado:row.estado==='A'?'I':'A',version:row.version});}
 supplierOptions(){return this.suppliers('','',0,100).pipe(expand(r=>(r.pagina+1)*r.tamano<r.total?this.suppliers('','',r.pagina+1,100):EMPTY),reduce((all,r)=>[...all,...r.items],[] as Supplier[]));}
 list(kind:PurchaseKind,search:string,state:string,supplier:string,page:number,size=20){let params=new HttpParams().set('buscar',search).set('estado',state).set('pagina',page).set('tamano',size);if(supplier)params=params.set('proveedor',supplier);return this.http.get<CatalogPage<PurchaseDocument>>(this.url(kind),{params});}
 get(kind:PurchaseKind,id:number){return this.http.get<PurchaseDetails>(this.url(kind)+'/'+id);}
 save(kind:PurchaseKind,id:number|null,body:object){return id?this.http.put<PurchaseDetails>(this.url(kind)+'/'+id,body):this.http.post<PurchaseDetails>(this.url(kind),body);}
 line(kind:PurchaseKind,doc:number,id:number|null,body:object){const url=this.url(kind)+'/'+doc+'/lineas';return id?this.http.put<PurchaseDetails>(url+'/'+id,body):this.http.post<PurchaseDetails>(url,body);}
 lineState(kind:PurchaseKind,doc:PurchaseDocument,row:PurchaseLine){return this.http.patch<PurchaseDetails>(this.url(kind)+'/'+doc.id+'/lineas/'+row.id+'/estado',{estado:row.estado==='A'?'I':'A',version:doc.version});}
 process(kind:PurchaseKind,doc:PurchaseDocument,key:string,cancel:boolean,motive:string|null){return this.http.post<PurchaseDetails>(this.url(kind)+'/'+doc.id+(cancel?'/anular':'/procesar'),{clave:key,version:doc.version,motivo:motive});}
 orderOptions(supplier:number){const load=(state:string,n:number)=>this.list('ordenes','',state,''+supplier,n,100);const pages=(state:string)=>load(state,0).pipe(expand(r=>(r.pagina+1)*r.tamano<r.total?load(state,r.pagina+1):EMPTY),reduce((all,r)=>[...all,...r.items],[] as PurchaseDocument[]));return {issued:pages('EMITIDA'),partial:pages('PARCIAL')};}
 opening(body:object){return this.http.post<{movimientoId:number}>(this.base+'/inventario/apertura',body);}
 movements(product:number,page:number){return this.http.get<CatalogPage<Movement>>(this.base+'/inventario/'+product+'/movimientos',{params:{pagina:page,tamano:20}});}
 existences(product:number,page:number){return this.http.get<CatalogPage<Existence>>(this.base+'/inventario/'+product+'/existencias',{params:{pagina:page,tamano:20}});}
 private url(kind:PurchaseKind){return this.base+'/compras/'+kind;}
}

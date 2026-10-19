import {inject,Injectable} from '@angular/core';
import {HttpClient,HttpParams} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
import {CatalogPage,Category,Unit} from './catalog.service';
import {EMPTY,expand,reduce} from 'rxjs';
export interface Product {id:number;codigo:string;nombre:string;descripcion:string|null;categoriaId:number;categoria:string;unidadId:number;unidad:string;admiteFracciones:boolean;incrementoBase:string;minimoVentaBase:string;modoControl:string;stockMinimo:string;ubicacion:string|null;stockActual:string;precioBase:string|null;ultimoCostoCompra:string|null;costoPromedio:string|null;estado:'A'|'I';version:string;}
export interface Presentation {id:number;productoId:number;nombre:string;unidadVentaId:number|null;unidad:string|null;factorBase:string;esBase:boolean;permiteVenta:boolean;admiteFracciones:boolean;incrementoVenta:string;minimoVenta:string;precioNormal:string;estado:'A'|'I';version:string;}
export interface Wholesale {id:number;presentacionId:number;cantidadMinima:string;precio:string;estado:'A'|'I';version:string;}
export interface Barcode {id:number;presentacionId:number;codigo:string;simbologia:string;estado:'A'|'I';version:string;}
export interface ProductDetails {producto:Product;presentaciones:Presentation[];preciosMayoristas:Wholesale[];codigos:Barcode[];}
@Injectable({providedIn:'root'})
export class ProductService {
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL);
 list(search:string,state:string,category:string,page:number){let params=new HttpParams().set('buscar',search).set('estado',state).set('pagina',page).set('tamano',20);if(category)params=params.set('categoria',category);return this.http.get<CatalogPage<Product>>(this.base+'/productos',{params});}
 get(id:number){return this.http.get<ProductDetails>(this.base+'/productos/'+id);}
 save(id:number|null,body:object){return id?this.http.put<Product>(this.base+'/productos/'+id,body):this.http.post<Product>(this.base+'/productos',body);}
 presentation(product:number,id:number|null,body:object){const url=this.base+'/productos/'+product+'/presentaciones';return id?this.http.put<Presentation>(url+'/'+id,body):this.http.post<Presentation>(url,body);}
 wholesale(product:number,presentation:number,id:number|null,body:object){const url=this.base+'/productos/'+product+'/presentaciones/'+presentation+'/mayoristas';return id?this.http.put<Wholesale>(url+'/'+id,body):this.http.post<Wholesale>(url,body);}
 barcode(product:number,presentation:number,body:object){return this.http.post<Barcode>(this.base+'/productos/'+product+'/presentaciones/'+presentation+'/codigos',body);}
 state(product:number,kind:'producto'|'presentaciones'|'mayoristas'|'codigos',row:{id:number;estado:string;version:string}){return this.http.patch(this.base+'/productos/'+product+(kind==='producto'?'':'/'+kind+'/'+row.id)+'/estado',{estado:row.estado==='A'?'I':'A',version:row.version});}
 options<T extends Category|Unit>(kind:'categorias'|'unidades'){
  const page=(n:number)=>this.http.get<CatalogPage<T>>(this.base+'/catalogos/'+kind,{params:{pagina:n,tamano:100}});
  return page(0).pipe(expand(result=>(result.pagina+1)*result.tamano<result.total?page(result.pagina+1):EMPTY),reduce((all,result)=>[...all,...result.items],[] as T[]));
 }
}

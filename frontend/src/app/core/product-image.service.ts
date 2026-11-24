import {Injectable,Injector,inject} from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
export interface ProductImageMetadata {productoId:number;hash:string|null;version:string|null;}
@Injectable({providedIn:'root'})
export class ProductImageService {
 private readonly injector=inject(Injector);private readonly base=inject(API_BASE_URL);
 private get http(){return this.injector.get(HttpClient);}
 get(id:number){return this.http.get<ProductImageMetadata>(`${this.base}/productos/${id}/imagen`);}
 image(id:number,hash:string){return this.http.get(`${this.base}/productos/${id}/imagen/${hash}`,{responseType:'blob'});}
 save(id:number,body:{imagenBase64:string|null;quitarImagen:boolean;version:string|null}){return this.http.put<ProductImageMetadata>(`${this.base}/productos/${id}/imagen`,body);}
}

import {inject,Injectable} from '@angular/core';import {HttpClient} from '@angular/common/http';import {API_BASE_URL} from './auth.service';
export interface XmlPreview{modo:string;enviosHabilitados:boolean;validezTributaria:boolean;generable:boolean;comprobante:string;errores:string[];advertencias:string[];xml:string|null;}
@Injectable({providedIn:'root'}) export class XmlTrialService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/xml-pruebas';
 status(){return this.http.get<{modo:string;enviosHabilitados:boolean;firmaDigital:boolean;validezTributaria:boolean}>(this.base+'/estado');}
 example(tipo:string){return this.http.get<XmlPreview>(this.base+'/ejemplo',{params:{tipo}});}
 preview(id:number){return this.http.get<XmlPreview>(this.base+'/ventas/'+id);}
 download(id:number|null,tipo:string){return id===null?this.http.post(this.base+'/ejemplo/descarga',null,{params:{tipo},responseType:'blob'}):this.http.post(this.base+'/ventas/'+id+'/descarga',null,{responseType:'blob'});}
}

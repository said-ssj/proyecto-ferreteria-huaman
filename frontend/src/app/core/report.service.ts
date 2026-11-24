import {inject,Injectable} from '@angular/core';import {HttpClient,HttpParams} from '@angular/common/http';import {API_BASE_URL} from './auth.service';
export type ReportRow=Record<string,string|number|null>;
export interface ReportFilters{desde:string;hasta:string;producto:number|null;buscar:string;}
export interface SalesReport{desde:string;hasta:string;resumen:ReportRow;dias:ReportRow[];productos:ReportRow[];}
export interface TableReport{desde:string;hasta:string;resumen:ReportRow;registros:{items:ReportRow[];total:number;pagina:number;tamano:number};}
@Injectable({providedIn:'root'}) export class ReportService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/reportes';
 dates(){return this.http.get<{hoy:string}>(this.base+'/fechas');}
 private params(f:ReportFilters,pagina=0){let p=new HttpParams({fromObject:{desde:f.desde,hasta:f.hasta,buscar:f.buscar,pagina}});if(f.producto!==null)p=p.set('producto',f.producto);return p;}
 sales(type:string,f:ReportFilters){return this.http.get<SalesReport>(this.base+'/'+type,{params:this.params(f)});}
 table(type:string,f:ReportFilters,pagina:number){return this.http.get<TableReport>(this.base+'/'+type,{params:this.params(f,pagina)});}
 products(buscar:string,pagina:number){return this.http.get<ReportRow[]>(this.base+'/productos/opciones',{params:{buscar,pagina}});}
 export(type:string,f:ReportFilters){return this.http.get(this.base+'/'+type+'/csv',{params:this.params(f),responseType:'blob'});}
}

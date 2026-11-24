import {inject,Injectable} from '@angular/core';
import {HttpClient,HttpParams} from '@angular/common/http';
import {API_BASE_URL} from './auth.service';
export interface ManagedUser{id:number;usuario:string;nombres:string;apellidos:string;dni:string;telefono:string|null;correo:string|null;rolId:number;rol:string;rolNombre:string;estado:string;cambioClaveObligatorio:boolean;bloqueadoHasta:string|null;ultimoIngreso:string|null;version:string;}
export interface RolePermission{codigo:string;modulo:string;descripcion:string;}
export interface ManagedRole{id:number;codigo:string;nombre:string;descripcion:string;estado:string;permisos:RolePermission[];}
export interface UserPage{items:ManagedUser[];total:number;pagina:number;tamano:number;}
@Injectable({providedIn:'root'})
export class UserAdminService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL);
 list(buscar:string,estado:string,pagina:number){return this.http.get<UserPage>(this.base+'/usuarios',{params:new HttpParams().set('buscar',buscar).set('estado',estado).set('pagina',pagina).set('tamano',20)});}
 user(id:number){return this.http.get<ManagedUser>(this.base+'/usuarios/'+id);}
 roles(options=false){return this.http.get<ManagedRole[]>(this.base+(options?'/usuarios/opciones':'/roles'));}
 save(id:number|null,input:unknown){return id?this.http.put<ManagedUser>(this.base+'/usuarios/'+id,input):this.http.post<ManagedUser>(this.base+'/usuarios',input);}
 state(user:ManagedUser){return this.http.patch<ManagedUser>(this.base+'/usuarios/'+user.id+'/estado',{estado:user.estado==='A'?'I':'A',version:user.version});}
 reset(user:ManagedUser,claveTemporal:string){return this.http.post<ManagedUser>(this.base+'/usuarios/'+user.id+'/restablecer-clave',{claveTemporal,version:user.version});}
}

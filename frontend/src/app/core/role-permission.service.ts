import {inject,Injectable} from '@angular/core';import {HttpClient} from '@angular/common/http';import {API_BASE_URL} from './auth.service';import {RolePermission} from './user-admin.service';
export interface RoleEditor{id:number;codigo:string;nombre:string;descripcion:string;estado:string;editable:boolean;version:string;disponibles:RolePermission[];asignados:string[];obligatorios:string[];usuarios:number;}
@Injectable({providedIn:'root'}) export class RolePermissionService{
 private readonly http=inject(HttpClient);private readonly base=inject(API_BASE_URL)+'/roles';
 get(id:number){return this.http.get<RoleEditor>(this.base+'/'+id+'/permisos');}
 save(role:RoleEditor,permisos:string[]){return this.http.put<{rol:RoleEditor;sesionesCerradas:number}>(this.base+'/'+role.id+'/permisos',{version:role.version,permisos});}
}

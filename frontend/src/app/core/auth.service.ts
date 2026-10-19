import {DOCUMENT} from '@angular/common';
import {HttpClient,HttpErrorResponse,HttpInterceptorFn} from '@angular/common/http';
import {Injectable,InjectionToken,computed,inject,signal,DestroyRef} from '@angular/core';
import {Router,CanActivateFn,CanActivateChildFn} from '@angular/router';
import {catchError,finalize,tap,throwError} from 'rxjs';
export const API_BASE_URL=new InjectionToken<string>('API_BASE_URL',{providedIn:'root',factory:()=>'/api'});
export interface UserProfile {id:number;usuario:string;nombres:string;apellidos:string;rol:string;cambioClaveObligatorio:boolean;permisos:string[];expiraEn:string;}
export interface LoginResponse {accessToken:string;tokenType:string;usuario:UserProfile;}
const ROUTE_PERMISSIONS:Record<string,string[]>={
 inicio:['INI.VER'],usuarios:['SEG.USUARIOS'],roles:['SEG.PERMISOS'],bitacora:['SEG.BITACORA'],parametros:['CFG.PARAMETROS'],
 'comprobantes/series':['CFG.SERIES'],'configuracion/tickets':['CFG.TICKET','CFG.ETIQUETAS'],
 productos:['PRO.VER'],'productos/nuevo':['PRO.GESTIONAR'],'productos/presentaciones':['PRO.PRESENTACIONES','PRO.MAYORISTA'],'productos/medidas':['PRO.MEDIDAS'],
 categorias:['CAT.GESTIONAR','UNI.GESTIONAR'],'categorias/nueva':['CAT.GESTIONAR'],'categorias/unidades/nueva':['UNI.GESTIONAR'],
 proveedores:['PRV.GESTIONAR'],'inventario/apertura':['INV.APERTURA'],clientes:['CLI.VER'],'clientes/nuevo':['CLI.GESTIONAR'],
 'compras/ordenes':['COM.OC'],'compras/ingresos':['COM.INGRESO'],inventario:['INV.VER'],
 'inventario/alertas':['INV.ALERTAS'],'inventario/ajustes':['INV.AJUSTAR'],'inventario/tomas':['INV.TOMA_GESTIONAR','INV.TOMA_CONTAR'],
 'inventario/tomas/nueva':['INV.TOMA_GESTIONAR'],'inventario/fraccionamiento':['INV.TRANSFORMAR'],
 'ventas/punto-de-venta':['VEN.VENDER'],'ventas/historial':['VEN.HISTORIAL'],'ventas/comprobante':['VEN.REIMPRIMIR'],
 cotizaciones:['COC.COTIZAR'],ofertas:['COC.OFERTAS'],creditos:['CRE.VER'],devoluciones:['VEN.DEVOLVER'],
 caja:['CAJ.OPERAR'],'caja/historial':['CAJ.HISTORIAL'],despachos:['DES.VER'],reportes:['REP.CENTRO'],
 'reportes/ventas':['REP.VENTAS'],'reportes/productos':['REP.PRODUCTO'],'reportes/inventario':['REP.INVENTARIO'],'reportes/caja':['REP.CAJA'],componentes:['CFG.PARAMETROS']
};
@Injectable({providedIn:'root'})
export class AuthService {
 private readonly http=inject(HttpClient);private readonly router=inject(Router);private readonly base=inject(API_BASE_URL);
 private readonly document=inject(DOCUMENT);private readonly destroy=inject(DestroyRef);
 private readonly secret=signal<string|null>(null);readonly user=signal<UserProfile|null>(null);
 readonly message=signal('');readonly busy=signal(false);readonly remaining=signal(0);
 readonly authenticated=computed(()=>!!this.secret()&&!!this.user());
 readonly warning=computed(()=>this.authenticated()&&this.remaining()>0&&this.remaining()<=60000);
 readonly roleName=computed(()=>({ADM:'Administración',VEN:'Ventas',ALM:'Almacén',AYU:'Ayudante'}[this.user()?.rol||'']||this.user()?.rol||''));
 private lastPing=0;private pinging=false;
 constructor(){const timer=this.document.defaultView?.setInterval(()=>this.tick(),1000);this.destroy.onDestroy(()=>{if(timer)this.document.defaultView?.clearInterval(timer);});}
 token(){return this.secret();}
 canAction(path:string,label:string){
  const rules:Record<string,Record<string,string>>={
   productos:{'Editar producto':'PRO.GESTIONAR','Desactivar':'PRO.INACTIVAR','Imprimir etiquetas':'CFG.ETIQUETAS'},
   'ventas/historial':{'Imprimir comprobante':'VEN.REIMPRIMIR','Copiar datos de venta':'VEN.COPIAR','Descargar XML':'VEN.XML','Anular venta':'VEN.ANULAR'},
   'compras/ordenes':{'Anular orden':'COM.OC_ANULAR'},
   'inventario/tomas':{'Continuar conteo':'INV.TOMA_CONTAR','Guardar conteo':'INV.TOMA_CONTAR','Cerrar conteo':'INV.TOMA_GESTIONAR','Reabrir conteo':'INV.TOMA_GESTIONAR','Aprobar y ajustar':'INV.TOMA_GESTIONAR','Anular toma':'INV.TOMA_GESTIONAR'},
   creditos:{'Registrar abono':'CRE.ABONAR'},despachos:{'Marcar preparado':'DES.GESTIONAR','Confirmar entrega':'DES.GESTIONAR'},
   devoluciones:{'Autorizar':'VEN.DEVOLVER','Rechazar':'VEN.DEVOLVER','Nueva devolución':'VEN.DEVOLVER'},
   ofertas:{'Nueva oferta':'COC.OFERTAS','Editar':'COC.OFERTAS','Inactivar':'COC.OFERTAS','Reactivar':'COC.OFERTAS'}
  };
  const permission=rules[path]?.[label];return !permission||this.has(permission);
 }
 has(permission:string){return this.user()?.permisos.includes(permission)??false;}
 can(path:string){
  path=path.replace(/^\//,'');if(!this.authenticated())return false;
  if(this.user()?.cambioClaveObligatorio)return path==='perfil';
  if(['perfil','preferencias','acceso-denegado'].includes(path))return true;
  const key=Object.keys(ROUTE_PERMISSIONS).sort((a,b)=>b.length-a.length).find(k=>path===k||path.startsWith(k+'/'));
  return !!key&&ROUTE_PERMISSIONS[key].some(p=>this.has(p));
 }
 login(usuario:string,clave:string){this.message.set('');return this.http.post<LoginResponse>(this.base+'/auth/login',{usuario,clave}).pipe(tap(result=>{
  this.secret.set(result.accessToken);this.setProfile(result.usuario);
 }));}
 private setProfile(profile:UserProfile){this.user.set(profile);this.lastPing=Date.now();this.tick();}
 refresh(){return this.http.get<UserProfile>(this.base+'/auth/me').pipe(tap(profile=>this.setProfile(profile)));}
 continueSession(){return this.http.post<UserProfile>(this.base+'/auth/continuar',{}).pipe(tap(profile=>this.setProfile(profile)));}
 changePassword(actual:string,nueva:string,confirmacion:string){return this.http.put<void>(this.base+'/auth/clave',{actual,nueva,confirmacion});}
 logout(){if(this.busy())return;this.busy.set(true);let message='Sesión cerrada';this.http.post<void>(this.base+'/auth/logout',{}).pipe(finalize(()=>{this.busy.set(false);this.clear(message);})).subscribe({error:()=>{message='La sesión se cerró en este equipo. Si no hubo conexión, la sesión del servidor expirará por inactividad.';}});}
 clear(message=''){this.secret.set(null);this.user.set(null);this.remaining.set(0);this.message.set(message);void this.router.navigate(['/iniciar-sesion'],{replaceUrl:true});}
 tick(){const expires=Date.parse(this.user()?.expiraEn||'');const remaining=Number.isFinite(expires)?Math.max(0,expires-Date.now()):0;this.remaining.set(remaining);if(this.authenticated()&&remaining===0)this.clear('Tu sesión expiró. Inicia sesión nuevamente.');}
 activity(){if(!this.authenticated()||this.warning()||this.pinging||Date.now()-this.lastPing<60000)return;
  this.pinging=true;this.continueSession().pipe(finalize(()=>this.pinging=false)).subscribe({error:()=>{}});
 }
 continue(){if(this.pinging)return;this.pinging=true;this.continueSession().pipe(finalize(()=>this.pinging=false)).subscribe({error:()=>this.message.set('No se pudo renovar la sesión. Revisa la conexión.')});}
}
export const authInterceptor:HttpInterceptorFn=(request,next)=>{
 const auth=inject(AuthService);const base=inject(API_BASE_URL);
 const api=request.url.startsWith(base+'/');const login=request.url===base+'/auth/login';
 const sent=api&&!login&&auth.token()?request.clone({setHeaders:{Authorization:'Bearer '+auth.token()}}):request;
 const token=auth.token();return next(sent).pipe(catchError((error:HttpErrorResponse)=>{
  if(api&&!login&&error.status===401&&token===auth.token())auth.clear('Tu sesión expiró o fue cerrada. Inicia sesión nuevamente.');
  return throwError(()=>error);
 }));
};
export const sessionGuard:CanActivateChildFn=(_route,state)=>{
 const auth=inject(AuthService);const router=inject(Router);auth.tick();
 return auth.authenticated()?true:router.createUrlTree(['/iniciar-sesion'],{queryParams:{volver:state.url}});
};
export const permissionGuard:CanActivateFn=(route)=>{
 const auth=inject(AuthService);const router=inject(Router);const path=route.data['page']?.path;
 if(auth.user()?.cambioClaveObligatorio&&path!=='perfil')return router.createUrlTree(['/perfil']);
 if(path==='no-encontrada'||auth.can(path||''))return true;
 return router.createUrlTree(['/acceso-denegado']);
};
export function authError(error:HttpErrorResponse):string{
 if(error.status===0||error.status===502||error.status===504)return 'No se pudo conectar con el servidor. Intenta de nuevo.';
 if([400,401,403,404,409,423,503].includes(error.status)&&typeof error.error?.detail==='string')return error.error.detail;
 return 'No se pudo completar la solicitud. Intenta de nuevo.';
}



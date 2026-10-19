import {TestBed} from '@angular/core/testing';
import {HttpClient,provideHttpClient,withInterceptors} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {Router,ActivatedRouteSnapshot,RouterStateSnapshot} from '@angular/router';
import {AuthService,authInterceptor,permissionGuard,UserProfile} from './auth.service';

describe('Conexión de acceso',()=>{
 let auth:AuthService;let http:HttpTestingController;
 const router={navigate:vi.fn().mockResolvedValue(true),createUrlTree:(parts:string[])=>parts.join('/')};
 const profile=(permissions=['INI.VER','SEG.PERFIL']):UserProfile=>({id:1,usuario:'cuenta.prueba',nombres:'Nombre',apellidos:'Apellido',rol:'VEN',cambioClaveObligatorio:false,permisos:permissions,expiraEn:new Date(Date.now()+1800000).toISOString()});
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(withInterceptors([authInterceptor])),provideHttpClientTesting(),{provide:Router,useValue:router}]});auth=TestBed.inject(AuthService);http=TestBed.inject(HttpTestingController);router.navigate.mockClear();});
 afterEach(()=>http.verify());
 function login(permissions?:string[]){auth.login('cuenta.prueba','Clave1234').subscribe();const request=http.expectOne('/api/auth/login');expect(request.request.headers.has('Authorization')).toBe(false);request.flush({accessToken:'secreto-de-prueba',tokenType:'Bearer',usuario:profile(permissions)});}
 it('envía credenciales por POST y conserva únicamente una sesión en memoria',()=>{login();expect(auth.authenticated()).toBe(true);expect(auth.user()?.usuario).toBe('cuenta.prueba');expect(localStorage.getItem('accessToken')).toBeNull();expect(sessionStorage.getItem('accessToken')).toBeNull();});
 it('añade Bearer solo a la API propia',()=>{login();auth.refresh().subscribe();const request=http.expectOne('/api/auth/me');expect(request.request.headers.get('Authorization')).toBe('Bearer secreto-de-prueba');request.flush(profile());TestBed.inject(HttpClient).get('https://example.invalid/test').subscribe();const external=http.expectOne('https://example.invalid/test');expect(external.request.headers.has('Authorization')).toBe(false);external.flush({});});
 it('una respuesta 401 elimina la sesión y vuelve al ingreso',()=>{login();auth.refresh().subscribe({error:()=>{}});http.expectOne('/api/auth/me').flush({},{status:401,statusText:'Unauthorized'});expect(auth.authenticated()).toBe(false);expect(router.navigate).toHaveBeenCalled();});
 it('una respuesta 403 no elimina una sesión válida',()=>{login();auth.refresh().subscribe({error:()=>{}});http.expectOne('/api/auth/me').flush({},{status:403,statusText:'Forbidden'});expect(auth.authenticated()).toBe(true);});
 it('los permisos de ventas no abren administración ni reportes financieros',()=>{login(['VEN.VENDER','VEN.HISTORIAL','SEG.PERFIL']);expect(auth.can('ventas/punto-de-venta')).toBe(true);expect(auth.can('usuarios')).toBe(false);expect(auth.can('reportes/productos')).toBe(false);expect(auth.can('caja')).toBe(false);});
 it('la clave temporal limita el acceso al perfil',()=>{login(['VEN.VENDER','SEG.PERFIL']);auth.user.update(user=>({...user!,cambioClaveObligatorio:true}));expect(auth.can('perfil')).toBe(true);expect(auth.can('ventas/punto-de-venta')).toBe(false);const route={data:{page:{path:'inicio'}}} as unknown as ActivatedRouteSnapshot;expect(TestBed.runInInjectionContext(()=>permissionGuard(route,{} as RouterStateSnapshot))).toBe('/perfil');});
 it('redirige a acceso denegado cuando se escribe una ruta sin permiso',()=>{login(['INI.VER']);const route={data:{page:{path:'usuarios'}}} as unknown as ActivatedRouteSnapshot;expect(TestBed.runInInjectionContext(()=>permissionGuard(route,{} as RouterStateSnapshot))).toBe('/acceso-denegado');});
 it('expira sin consultar ni mantener viva la sesión automáticamente',()=>{login();auth.user.update(user=>({...user!,expiraEn:new Date(Date.now()-1000).toISOString()}));auth.tick();expect(auth.authenticated()).toBe(false);expect(auth.message()).toContain('expiró');});
 it('avisa al faltar un minuto y la renovación es explícita',()=>{login();auth.user.update(user=>({...user!,expiraEn:new Date(Date.now()+45000).toISOString()}));auth.tick();expect(auth.warning()).toBe(true);auth.activity();http.expectNone('/api/auth/continuar');auth.continueSession().subscribe();http.expectOne('/api/auth/continuar').flush(profile());expect(auth.warning()).toBe(false);});
 it('cierra la sesión en el servidor y borra el estado local',()=>{login();auth.logout();const request=http.expectOne('/api/auth/logout');expect(request.request.method).toBe('POST');request.flush(null,{status:204,statusText:'No Content'});expect(auth.token()).toBeNull();expect(auth.user()).toBeNull();});
});

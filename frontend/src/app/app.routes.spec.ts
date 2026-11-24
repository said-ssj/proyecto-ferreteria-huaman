import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {provideRouter,Router} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {AuthService} from './core/auth.service';
import {routes} from './app.routes';

describe('Navegación con rutas de negocio diferidas',()=>{
 beforeEach(()=>TestBed.configureTestingModule({providers:[provideRouter(routes),provideHttpClient(),provideHttpClientTesting()]}));
 afterEach(()=>TestBed.inject(HttpTestingController).verify());
 function signIn(){
  TestBed.inject(AuthService).login('usuario.prueba','ClaveDePrueba123').subscribe();
  TestBed.inject(HttpTestingController).expectOne('/api/auth/login').flush({accessToken:'token-local-prueba',tokenType:'Bearer',usuario:{id:1,usuario:'usuario.prueba',nombres:'Nombre',apellidos:'Apellido',rol:'VEN',cambioClaveObligatorio:false,permisos:['INI.VER','SEG.PERFIL'],expiraEn:new Date(Date.now()+1800000).toISOString()}});
 }
 it('mantiene el ingreso separado del catálogo de pantallas',()=>{
  expect(routes[0].path).toBe('iniciar-sesion');expect(routes[0].loadComponent).toBeDefined();expect(routes[1].loadChildren).toBeDefined();expect(routes[1].children).toBeUndefined();
 });
 it('redirige una entrada directa protegida y conserva la dirección solicitada',async()=>{
  const h=await RouterTestingHarness.create();await h.navigateByUrl('/inventario');
  expect(TestBed.inject(Router).url).toBe('/iniciar-sesion?volver=%2Finventario');expect(h.routeNativeElement?.textContent).toContain('Iniciar sesión');
 });
 it('carga la estructura y preferencias después de autenticarse',async()=>{
  signIn();const h=await RouterTestingHarness.create();await h.navigateByUrl('/preferencias');
  expect(TestBed.inject(Router).url).toBe('/preferencias');expect(h.routeNativeElement?.textContent).toContain('Apariencia y accesibilidad');
 });
 it('conserva la denegación de acceso a reportes administrativos',async()=>{
  signIn();const h=await RouterTestingHarness.create();await h.navigateByUrl('/reportes/ventas');
  expect(TestBed.inject(Router).url).toBe('/acceso-denegado');expect(h.routeNativeElement?.textContent).toContain('Acceso denegado');
 });
});

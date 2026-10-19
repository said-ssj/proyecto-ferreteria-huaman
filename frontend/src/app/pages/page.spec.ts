import {QuoteService} from '../core/quote.service';
import {SaleHistoryService} from '../core/sale-history.service';
import {InventoryService} from '../core/inventory.service';
import {of} from 'rxjs';
import {CatalogService} from '../core/catalog.service';
import {Catalog} from './catalog';
import {Products} from './products';
import {ProductService} from '../core/product.service';
import {PurchaseService} from '../core/purchase.service';
import {signal} from '@angular/core';
import {AuthService} from '../core/auth.service';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {Page} from './page';
import {SCREEN_CONTROLS} from '../core/screen-controls';
import {routes} from '../app.routes';
import {PAGES} from '../core/screens';
import {ThemeService,THEMES} from '../core/theme.service';

describe('Frontend sin datos',()=>{
 beforeEach(()=>TestBed.configureTestingModule({providers:[provideRouter(routes),{provide:QuoteService,useValue:{options:()=>of({hoy:'2026-10-18',vigenciaDias:7,caja:null}),list:()=>of({items:[],total:0,pagina:0,tamano:20})}},{provide:SaleHistoryService,useValue:{list:()=>of({items:[],total:0,pagina:0,tamano:20}),sellers:()=>of([])}},{provide:InventoryService,useValue:{list:()=>of({items:[],total:0,pagina:0,tamano:20}),reasons:()=>of([])}},{provide:PurchaseService,useValue:{list:()=>of({items:[],total:0,pagina:0,tamano:20}),suppliers:()=>of({items:[],total:0,pagina:0,tamano:20}),supplierOptions:()=>of([])}},{provide:ProductService,useValue:{list:()=>of({items:[],total:0,pagina:0,tamano:20}),options:()=>of([])}},{provide:CatalogService,useValue:{list:()=>of({items:[],total:0,pagina:0,tamano:20})}},{provide:AuthService,useValue:{
 authenticated:()=>true,token:()=>null,user:signal({id:1,usuario:'cuenta.prueba',nombres:'Nombre',apellidos:'Apellido',rol:'ADM',permisos:[],cambioClaveObligatorio:false,expiraEn:new Date(Date.now()+1800000).toISOString()}),
 has:()=>true,can:()=>true,canAction:()=>true,tick:()=>{},activity:()=>{},busy:()=>false,warning:()=>false,message:()=>'',roleName:()=> 'Administración'
 }}]}));
 it('renderiza todas las pantallas registradas con un encabezado y sin datos de entrada',async()=>{
 const harness=await RouterTestingHarness.create();
 for(const page of PAGES){
 await harness.navigateByUrl('/'+page.path);harness.detectChanges();
 const root=harness.routeNativeElement!;
 expect(root.querySelector('h1')?.textContent).toContain(page.title);
 for(const input of Array.from(root.querySelectorAll('input:not([type=checkbox]),textarea')) as HTMLInputElement[]){expect(input.value).toBe('');}
 for(const checkbox of Array.from(root.querySelectorAll('input[type=checkbox]')) as HTMLInputElement[]){expect(checkbox.checked).toBe(false);}
 expect(root.textContent).not.toMatch(/versión demo|plantilla|Carlos M\.|Juan Pérez|163\.90/i);
 }
 },20000);
 it('mantiene deshabilitada la confirmación de una venta vacía',async()=>{
 const h=await RouterTestingHarness.create('/ventas/punto-de-venta');
 const buttons=Array.from(h.routeNativeElement!.querySelectorAll('button'));
 expect(buttons.find(b=>b.textContent?.includes('Revisar venta'))?.disabled).toBe(true);
 expect(h.routeNativeElement!.querySelector('input[placeholder="00000000"]')?.getAttribute('placeholder')).toBe('00000000');
 });
 it('aplica los seis temas y descarta identificadores desconocidos',()=>{
 const theme=TestBed.inject(ThemeService);
 for(const item of THEMES){theme.set(item.id);expect(document.documentElement.dataset['theme']).toBe(item.id);}
 theme.set('desconocido');expect(theme.current()).toBe('noche-suave');theme.set('plomo');
 });
 it('muestra acceso denegado y página no encontrada',async()=>{
 const h=await RouterTestingHarness.create('/acceso-denegado');
 expect(h.routeNativeElement!.textContent).toContain('Acceso denegado');
 await h.navigateByUrl('/ruta-inexistente');expect(h.routeNativeElement!.textContent).toContain('Página no encontrada');
 });

 it('permite alternar categorías y unidades sin mostrar el mismo encabezado',async()=>{
 const h=await RouterTestingHarness.create('/categorias');
 const page=h.routeDebugElement!.query(By.directive(Catalog)).componentInstance as Catalog;
 page.selectTab(1);h.detectChanges();
 expect(page.isUnit()).toBe(true);expect(h.routeNativeElement!.textContent).toContain('Código SUNAT');
 expect(h.routeNativeElement!.querySelector('a[href="/categorias/unidades/nueva"]')).toBeTruthy();
 });
 it('limpia también los selectores Material y las casillas de los filtros',async()=>{
 const h=await RouterTestingHarness.create('/productos');
 const page=h.routeDebugElement!.query(By.directive(Products)).componentInstance as Products;
 page.searchForm.setValue({estado:'A',categoria:'1',buscar:'búsqueda'});page.apply();
 page.clear();h.detectChanges();
 expect(page.searchForm.getRawValue()).toEqual({estado:'',categoria:'',buscar:''});
 expect(page.filters()).toEqual({estado:'',categoria:'',buscar:''});
 });
 it('incluye los accesos y acciones documentadas sin inventar registros',()=>{
 expect(PAGES.some(p=>p.path==='reportes')).toBe(true);
 expect(SCREEN_CONTROLS['ventas/historial'].actions!.map(a=>a.label)).toContain('Copiar datos de venta');
 expect(SCREEN_CONTROLS['inventario/tomas'].actions!.map(a=>a.label)).toContain('Aprobar y ajustar');
 });
});



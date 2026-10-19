import {signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {ProductService,ProductDetails} from '../core/product.service';
import {Products} from './products';
describe('Formularios de productos conectados',()=>{
 const details:ProductDetails={producto:{id:3,codigo:'PRUEBA',nombre:'Producto de prueba',descripcion:null,categoriaId:1,categoria:'Categoría',unidadId:2,unidad:'kg',admiteFracciones:true,incrementoBase:'0.001000',minimoVentaBase:'0.001000',modoControl:'GRANEL',stockMinimo:'0.000000',ubicacion:null,stockActual:'0.000000',precioBase:'10.000000',ultimoCostoCompra:null,costoPromedio:null,estado:'A',version:'2026-10-17T12:00:00.123456'},presentaciones:[{id:4,productoId:3,nombre:'Kilogramo',unidadVentaId:2,unidad:'kg',factorBase:'1.000000',esBase:true,permiteVenta:true,admiteFracciones:true,incrementoVenta:'0.001000',minimoVenta:'0.001000',precioNormal:'10.000000',estado:'A',version:'2026-10-17T12:00:00.123456'}],preciosMayoristas:[],codigos:[]};
 const api={options:()=>of([]),list:()=>of({items:[],total:0,pagina:0,tamano:20}),get:()=>of(details),save:vi.fn((_id:number|null,_body:object)=>of(details.producto)),presentation:vi.fn((_product:number,_id:number|null,_body:object)=>of(details.presentaciones[0]))};
 const auth={authenticated:()=>true,token:()=>null,user:signal(null),has:vi.fn((_permission:string)=>true),can:()=>true,canAction:()=>true,tick:()=>{},activity:()=>{},busy:()=>false,warning:()=>false,message:()=>'',roleName:()=> 'Administración'};
 beforeEach(()=>{vi.clearAllMocks();auth.has.mockReturnValue(true);TestBed.configureTestingModule({providers:[provideRouter(routes),{provide:ProductService,useValue:api},{provide:AuthService,useValue:auth}]});});
 async function page(url:string){const harness=await RouterTestingHarness.create(url);harness.detectChanges();await TestBed.inject(ApplicationRef).whenStable();harness.detectChanges();return harness.routeDebugElement!.query(By.directive(Products)).componentInstance as Products;}
 it('crea producto y base sin enviar campos de stock o costo',async()=>{const p=await page('/productos/nuevo');p.productForm.setValue({codigo:'prueba',nombre:'Producto',categoriaId:1,descripcion:'',unidadId:2,modoControl:'GRANEL',admiteFracciones:true,incrementoBase:'0.001',minimoVentaBase:'0.001',stockMinimo:'0',ubicacion:'',nombreBase:'Kilogramo',precioBase:'10.123456'});p.saveProduct();const body=api.save.mock.calls[0][1] as any;expect(body.codigo).toBe('PRUEBA');expect(body.precioBase).toBe('10.123456');expect(body.stockActual).toBeUndefined();expect(body.costoPromedio).toBeUndefined();});
 it('edita metadatos conservando versión y medidas históricas',async()=>{const p=await page('/productos/editar/3');expect(p.productForm.controls['unidadId'].disabled).toBe(true);p.productForm.controls['nombre'].setValue('Nombre actualizado');p.saveProduct();expect(api.save).toHaveBeenCalledWith(3,expect.objectContaining({nombre:'Nombre actualizado',version:details.producto.version,incrementoBase:'0.001000'}));const body=api.save.mock.calls[0][1] as any;expect(body.precioBase).toBeUndefined();expect(body.nombreBase).toBeUndefined();});
 it('guarda una presentación comercial sin convertir el decimal a número',async()=>{const p=await page('/productos/presentaciones?producto=3');p.presentationForm.setValue({nombre:'Bolsa',unidadVentaId:'',factorBase:'5.000000',permiteVenta:true,admiteFracciones:false,incrementoVenta:'1',minimoVenta:'1',precioNormal:'45.123456'});p.savePresentation();expect(api.presentation).toHaveBeenCalledWith(3,null,expect.objectContaining({unidadVentaId:null,factorBase:'5.000000',precioNormal:'45.123456'}));});
 it('bloquea el campo de precio al editar sin permiso específico',async()=>{const p=await page('/productos/presentaciones?producto=3');auth.has.mockImplementation(permission=>permission!=='PRO.PRECIOS');p.editPresentation(details.presentaciones[0]);expect(p.presentationForm.controls['precioNormal'].disabled).toBe(true);expect(p.presentationForm.controls['factorBase'].disabled).toBe(true);});
});
import {ApplicationRef} from '@angular/core';


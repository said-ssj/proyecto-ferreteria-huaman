import {ApplicationRef,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {MatDialog} from '@angular/material/dialog';
import {of,throwError} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {ProductService,ProductDetails} from '../core/product.service';
import {PurchaseService} from '../core/purchase.service';
import {InventoryService} from '../core/inventory.service';
import {PhysicalPlan} from '../shared/physical-plan';
import {Inventory} from './inventory';
const product={producto:{id:3,codigo:'PRUEBA',nombre:'Producto de prueba',modoControl:'ENVASES',unidad:'kg'},presentaciones:[{id:4,nombre:'Bolsa',factorBase:'50',unidadVentaId:null,estado:'A'}]} as ProductDetails;
const physicalApi={existences:()=>of({items:[{id:9,identificador:'B-1',condicion:'ENVASE',cantidadInicial:'50',cantidadDisponible:'50',estado:'A'}],total:1,pagina:0,tamano:20})};
describe('Plan físico de inventario',()=>{
 beforeEach(()=>TestBed.configureTestingModule({providers:[{provide:PurchaseService,useValue:physicalApi}]}));
 function setup(){const f=TestBed.createComponent(PhysicalPlan);f.componentRef.setInput('product',product);f.componentRef.setInput('mode','count');f.detectChanges();return f;}
 it('conserva una pieza añadida después de actualizar la vista',()=>{const f=setup(),p=f.componentInstance;p.existingForm.setValue({unidadId:9,cantidad:'50.000000'});p.addExisting();f.detectChanges();expect(p.rows()).toHaveLength(1);expect(p.rows()[0].cantidad).toBe('50.000000');});
 it('evita repetir la misma pieza existente',()=>{const f=setup(),p=f.componentInstance;for(let i=0;i<2;i++){p.existingForm.setValue({unidadId:9,cantidad:'50'});p.addExisting();}f.detectChanges();expect(p.rows()).toHaveLength(1);expect(p.error()).toContain('ya está incluida');});
 it('conserva seis decimales del material nuevo sin convertirlos a número',()=>{const f=setup(),p=f.componentInstance;p.newForm.setValue({condicion:'SUELTO',cantidad:'2.500001',presentacionId:''});p.addNew();f.detectChanges();expect(p.rows()[0]).toEqual({unidadId:null,condicion:'SUELTO',presentacionId:null,cantidad:'2.500001'});});
});
describe('Flujos de inventario conectados',()=>{
 const line={id:6,productoId:3,producto:'Producto',cantidad:null,revision:4,plan:'[]'};
 const api={take:()=>of({id:1,numero:1,estado:'EN_CONTEO',revision:0,contados:0,productos:1}),counts:()=>of({items:[line],total:1,pagina:0,tamano:20}),list:()=>of({items:[],total:0,pagina:0,tamano:20}),count:vi.fn((_id:number,_body:object)=>throwError(()=>({status:503}))),start:vi.fn((_body:object)=>of({id:8})),transform:vi.fn((_body:object)=>of({id:4}))};
 beforeEach(()=>{vi.clearAllMocks();TestBed.configureTestingModule({providers:[provideRouter(routes),{provide:InventoryService,useValue:api},{provide:PurchaseService,useValue:physicalApi},{provide:ProductService,useValue:{get:()=>of({...product,producto:{...product.producto,modoControl:'GRANEL'}}),list:()=>of({items:[],total:0,pagina:0,tamano:20}),options:()=>of([])}},{provide:MatDialog,useValue:{open:()=>({afterClosed:()=>of(true)})}},{provide:AuthService,useValue:{authenticated:()=>true,token:()=>null,user:signal({rol:'ADM'}),has:()=>true,can:()=>true,canAction:()=>true,tick:()=>{},activity:()=>{},busy:()=>false,warning:()=>false,message:()=>'',roleName:()=> 'Administración'}}]});});
 async function page(url:string){const h=await RouterTestingHarness.create(url);h.detectChanges();await TestBed.inject(ApplicationRef).whenStable();h.detectChanges();return h.routeDebugElement!.query(By.directive(Inventory)).componentInstance as Inventory;}
 it('envía cero con la revisión de la línea y conserva la clave al reintentar',async()=>{const p=await page('/inventario/tomas/ver/1');p.selectCount(line);p.countQuantity.setValue('0');p.saveCount();p.saveCount();const a=api.count.mock.calls[0][1] as any,b=api.count.mock.calls[1][1] as any;expect(a.cantidad).toBe('0');expect(a.revision).toBe(4);expect(a.clave).toBe(b.clave);expect(a.stockActual).toBeUndefined();});
 it('abre directamente la toma devuelta por el servidor',async()=>{const p=await page('/inventario/tomas/nueva');p.start.setValue({alcance:'TODO',categoriaId:'',observacion:''});p.saveStart();expect(api.start).toHaveBeenCalledWith(expect.objectContaining({alcance:'TODO',categoriaId:null}));});
 it('rechaza un corte sin remanente antes de enviar la solicitud',async()=>{const p=await page('/inventario/fraccionamiento');p.choose(product);p.transform.patchValue({operacion:'CORTAR',origenId:9,motivo:'Preparar corte'});p.lengths.setValue('2.500000');p.saveTransform();expect(api.transform).not.toHaveBeenCalled();expect(p.error()).toContain('al menos dos');});
});

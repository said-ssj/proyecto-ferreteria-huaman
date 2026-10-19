import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {PurchaseService,PurchaseDocument} from './purchase.service';
describe('Compras e inventario HTTP',()=>{
 let service:PurchaseService;let http:HttpTestingController;
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});service=TestBed.inject(PurchaseService);http=TestBed.inject(HttpTestingController);});afterEach(()=>http.verify());
 it('filtra documentos por proveedor, estado y página',()=>{service.list('ingresos','guía','CONFIRMADO','3',2).subscribe();const r=http.expectOne(q=>q.url==='/api/compras/ingresos');expect(r.request.params.get('proveedor')).toBe('3');expect(r.request.params.get('pagina')).toBe('2');expect(r.request.params.get('estado')).toBe('CONFIRMADO');r.flush({items:[],total:0});});
 it('envía versión y estado al activar un proveedor',()=>{service.supplierState({id:1,estado:'I',version:'v'} as any).subscribe();const r=http.expectOne('/api/proveedores/1/estado');expect(r.request.body).toEqual({estado:'A',version:'v'});r.flush({});});
 it('conserva la clave del cliente al reintentar la confirmación',()=>{const doc={id:4,version:'v'} as PurchaseDocument;for(let i=0;i<2;i++){service.process('ingresos',doc,'misma-clave',false,null).subscribe();const r=http.expectOne('/api/compras/ingresos/4/procesar');expect(r.request.body).toEqual({clave:'misma-clave',version:'v',motivo:null});r.flush({});}});
 it('conserva decimales y datos físicos de una apertura',()=>{const body={productoId:2,cantidad:'12.500000',costoUnitarioBase:'4.123456',clave:'clave',unidades:[{identificador:'B-1',condicion:'SUELTO',cantidad:'12.500000',presentacionId:null}]};service.opening(body).subscribe();const r=http.expectOne('/api/inventario/apertura');expect(r.request.body).toEqual(body);r.flush({movimientoId:1});});
 it('edita una línea sin enviar importes ni equivalencias calculadas',()=>{service.line('ordenes',4,5,{cantidad:'10',costoUnitario:'8.123456',version:'v',productoId:2,presentacionId:3}).subscribe();const r=http.expectOne('/api/compras/ordenes/4/lineas/5');expect(r.request.method).toBe('PUT');expect(r.request.body.importe).toBeUndefined();expect(r.request.body.factorBase).toBeUndefined();r.flush({});});
 it('pagina el kardex desde el servidor',()=>{service.movements(3,2).subscribe();const r=http.expectOne(q=>q.url==='/api/inventario/3/movimientos');expect(r.request.params.get('pagina')).toBe('2');expect(r.request.params.get('tamano')).toBe('20');r.flush({items:[],total:0});});
});

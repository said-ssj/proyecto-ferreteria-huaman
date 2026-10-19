import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {ProductService} from './product.service';
import {Category} from './catalog.service';
describe('API de productos',()=>{
 let service:ProductService;let http:HttpTestingController;
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});service=TestBed.inject(ProductService);http=TestBed.inject(HttpTestingController);});
 afterEach(()=>http.verify());
 it('envía una búsqueda única para nombre, código y barras con filtros y página',()=>{service.list('7501234567890','A','7',2).subscribe();const r=http.expectOne(q=>q.url==='/api/productos');expect(r.request.params.get('buscar')).toBe('7501234567890');expect(r.request.params.get('categoria')).toBe('7');expect(r.request.params.get('pagina')).toBe('2');r.flush({items:[],total:0,pagina:2,tamano:20});});
 it('preserva los decimales al guardar presentaciones',()=>{service.presentation(3,null,{factorBase:'0.001000',precioNormal:'0.123456'}).subscribe();const r=http.expectOne('/api/productos/3/presentaciones');expect(r.request.method).toBe('POST');expect(r.request.body.factorBase).toBe('0.001000');r.flush({});});
 it('envía la versión al cambiar estado de una regla',()=>{const version='2026-10-17T12:00:00.123456';service.state(3,'mayoristas',{id:8,estado:'A',version}).subscribe();const r=http.expectOne('/api/productos/3/mayoristas/8/estado');expect(r.request.method).toBe('PATCH');expect(r.request.body).toEqual({estado:'I',version});r.flush({});});
 it('edita la regla de su presentación sin reasignarla',()=>{service.wholesale(3,4,8,{cantidadMinima:'100',precio:'8',version:'v'}).subscribe();const r=http.expectOne('/api/productos/3/presentaciones/4/mayoristas/8');expect(r.request.method).toBe('PUT');r.flush({});});
 it('carga todas las páginas de opciones sin truncarlas a cien',()=>{let count=0;service.options<Category>('categorias').subscribe(rows=>count=rows.length);const first=http.expectOne(q=>q.url==='/api/catalogos/categorias'&&q.params.get('pagina')==='0');first.flush({items:Array.from({length:100},(_,i)=>({id:i})),total:101,pagina:0,tamano:100});const second=http.expectOne(q=>q.url==='/api/catalogos/categorias'&&q.params.get('pagina')==='1');second.flush({items:[{id:100}],total:101,pagina:1,tamano:100});expect(count).toBe(101);});
});

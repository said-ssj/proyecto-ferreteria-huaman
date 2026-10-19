import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {CatalogService,Category} from './catalog.service';

describe('Catálogos HTTP',()=>{
 let api:CatalogService;let http:HttpTestingController;
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});api=TestBed.inject(CatalogService);http=TestBed.inject(HttpTestingController);});
 afterEach(()=>http.verify());
 it('envía filtros y paginación sin construir SQL en el navegador',()=>{api.list(false,'%_', 'A',2).subscribe();const request=http.expectOne(r=>r.url==='/api/catalogos/categorias');expect(request.request.params.get('buscar')).toBe('%_');expect(request.request.params.get('pagina')).toBe('2');expect(request.request.params.get('tamano')).toBe('20');request.flush({items:[],total:0,pagina:2,tamano:20});});
 it('envía la versión exacta al cambiar el estado',()=>{const row:Category={id:7,nombre:'Prueba',descripcion:null,estado:'A',version:'2026-10-17T12:00:00.123456'};api.state(true,row,'I').subscribe();const request=http.expectOne('/api/catalogos/unidades/7/estado');expect(request.request.method).toBe('PATCH');expect(request.request.body).toEqual({estado:'I',version:row.version});request.flush({...row,estado:'I'});});
 it('distingue alta y edición de categorías',()=>{api.save(false,null,{nombre:'Prueba'}).subscribe();const create=http.expectOne('/api/catalogos/categorias');expect(create.request.method).toBe('POST');create.flush({});api.save(false,7,{nombre:'Prueba',version:'v'}).subscribe();const edit=http.expectOne('/api/catalogos/categorias/7');expect(edit.request.method).toBe('PUT');edit.flush({});});
 it('permite conservar el factor decimal como texto sin redondearlo en JavaScript',()=>{api.save(true,null,{factorReferencia:'0.000001'}).subscribe();const request=http.expectOne('/api/catalogos/unidades');expect(request.request.body.factorReferencia).toBe('0.000001');request.flush({});});
});

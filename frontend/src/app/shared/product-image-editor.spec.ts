import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {MAT_DIALOG_DATA,MatDialogRef} from '@angular/material/dialog';
import {ProductImageEditor} from './product-image-editor';
describe('Imagen de producto',()=>{
 let http:HttpTestingController;const close=vi.fn();
 beforeEach(()=>{close.mockReset();TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting(),{provide:MAT_DIALOG_DATA,useValue:{id:7,nombre:'Producto'}},{provide:MatDialogRef,useValue:{close,disableClose:false}}]});http=TestBed.inject(HttpTestingController);});
 afterEach(()=>http.verify());
 it('quitar imagen exige guardar y conserva el archivo seleccionado si existe un conflicto',()=>{const f=TestBed.createComponent(ProductImageEditor);http.expectOne('/api/productos/7/imagen').flush({productoId:7,hash:null,version:'2026-10-26T01:00:00'});f.detectChanges();f.componentInstance.encoded.set('eA==');f.componentInstance.save();const save=http.expectOne('/api/productos/7/imagen');expect(save.request.body).toEqual({imagenBase64:'eA==',quitarImagen:false,version:'2026-10-26T01:00:00'});save.flush({detail:'La imagen cambió. Recarga antes de guardar'},{status:409,statusText:'Conflict'});expect(f.componentInstance.encoded()).toBe('eA==');expect(f.componentInstance.error()).toContain('Recarga');expect(close).not.toHaveBeenCalled();f.componentInstance.clear();f.componentInstance.save();const remove=http.expectOne('/api/productos/7/imagen');expect(remove.request.body.quitarImagen).toBe(true);remove.flush({productoId:7,hash:null,version:'2026-10-26T02:00:00'});expect(close).toHaveBeenCalled();});
 it('rechaza tipos no permitidos y archivos grandes antes de enviarlos',()=>{const f=TestBed.createComponent(ProductImageEditor);http.expectOne('/api/productos/7/imagen').flush({productoId:7,hash:null,version:null});for(const file of [new File(['<svg/>'],'x.svg',{type:'image/svg+xml'}),new File([new Uint8Array(2097153)],'x.png',{type:'image/png'})]){f.componentInstance.pick({target:{files:[file],value:''}} as unknown as Event);expect(f.componentInstance.error()).toContain('2 MB');}http.expectNone(r=>r.method==='PUT');});
});

import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {HttpTestingController,provideHttpClientTesting} from '@angular/common/http/testing';
import {ProductPhoto} from './product-photo';
describe('Miniatura privada',()=>{
 beforeEach(()=>{TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});vi.stubGlobal('URL',class extends URL {static override createObjectURL=vi.fn(()=> 'blob:photo');static override revokeObjectURL=vi.fn();});});
 afterEach(()=>{TestBed.inject(HttpTestingController).verify();vi.unstubAllGlobals();});
 it('no solicita imágenes ausentes y libera la miniatura al cambiar a otro producto',()=>{const http=TestBed.inject(HttpTestingController),f=TestBed.createComponent(ProductPhoto);f.componentRef.setInput('productId',7);f.detectChanges();http.expectNone(r=>true);f.componentRef.setInput('hash','a'.repeat(64));f.detectChanges();http.expectOne('/api/productos/7/imagen/'+'a'.repeat(64)).flush(new Blob(['image'],{type:'image/jpeg'}));expect(f.componentInstance.url()).toBe('blob:photo');f.componentRef.setInput('hash',null);f.detectChanges();expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:photo');expect(f.componentInstance.url()).toBe('');});
});

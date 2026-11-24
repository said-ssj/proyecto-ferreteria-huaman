import {TestBed} from '@angular/core/testing';
import {provideHttpClient} from '@angular/common/http';
import {provideHttpClientTesting,HttpTestingController} from '@angular/common/http/testing';
import {FormGroup,FormControl} from '@angular/forms';
import {RucLookup} from './ruc-lookup';
describe('Consulta RUC',()=>{
 beforeEach(()=>TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]}));
 afterEach(()=>TestBed.inject(HttpTestingController).verify());
 function setup(){const f=TestBed.createComponent(RucLookup);const form=new FormGroup({tipoDocumento:new FormControl('RUC'),documento:new FormControl('20601030013'),nombre:new FormControl('Nombre escrito'),direccion:new FormControl('Direccion escrita')});f.componentRef.setInput('group',form);f.detectChanges();return {f,form,c:f.componentInstance,http:TestBed.inject(HttpTestingController)};}
 it('habilita el boton al escribir un RUC en un formulario inicialmente vacio',async()=>{const {f,form}=setup();form.controls.documento.setValue('');f.detectChanges();expect(f.nativeElement.querySelector('button').disabled).toBe(true);form.controls.documento.setValue('20601030013');await f.whenStable();expect(f.nativeElement.querySelector('button').disabled).toBe(false);});
 it('no consulta DNI ni un documento incompleto',()=>{const {c,form,http}=setup();form.controls.tipoDocumento.setValue('DNI');c.lookup();http.expectNone('/api/consultas/ruc?numero=20601030013');});
 it('consulta sin guardar y aplica solamente al elegirlo',()=>{const {c,form,http}=setup();c.lookup();http.expectOne('/api/consultas/ruc?numero=20601030013').flush({ruc:'20601030013',razonSocial:'Empresa consultada',direccion:'Direccion fiscal'});expect(form.controls.nombre.value).toBe('Nombre escrito');c.apply(c.result()!);expect(form.controls.nombre.value).toBe('Empresa consultada');expect(form.controls.direccion.value).toBe('Direccion fiscal');});
 it('ignora respuestas de un documento que ya cambio',()=>{const {c,form,http}=setup();c.lookup();form.controls.documento.setValue('20100000000');http.expectOne('/api/consultas/ruc?numero=20601030013').flush({ruc:'20601030013',razonSocial:'Empresa consultada'});expect(c.result()).toBeNull();expect(form.controls.nombre.value).toBe('Nombre escrito');});
 it('permite ingreso manual cuando el proveedor falla',()=>{const {c,form,http}=setup();c.lookup();http.expectOne('/api/consultas/ruc?numero=20601030013').flush({detail:'Cuota agotada'},{status:429,statusText:'Too Many Requests'});expect(c.error()).toBe('Cuota agotada');expect(form.controls.nombre.enabled).toBe(true);expect(form.controls.nombre.value).toBe('Nombre escrito');});
});

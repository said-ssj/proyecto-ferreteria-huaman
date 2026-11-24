import {ApplicationRef} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {of} from 'rxjs';
import {Users} from './users';
import {AuthService} from '../core/auth.service';
import {UserAdminService,ManagedUser,ManagedRole} from '../core/user-admin.service';
const sample:ManagedUser={id:2,usuario:'ventas.prueba',nombres:'Nombre',apellidos:'Prueba',dni:'12345678',telefono:null,correo:null,rolId:2,rol:'VEN',rolNombre:'Ventas',estado:'A',cambioClaveObligatorio:false,bloqueadoHasta:null,ultimoIngreso:null,version:'2026-10-24T12:00:00'};
const roles:ManagedRole[]=[{id:2,codigo:'VEN',nombre:'Ventas',descripcion:'Ventas',estado:'A',permisos:[{codigo:'VEN.VENDER',modulo:'VEN',descripcion:'Registrar ventas'}]}];
describe('Administración de usuarios',()=>{
 let api:{list:ReturnType<typeof vi.fn>;roles:ReturnType<typeof vi.fn>;user:ReturnType<typeof vi.fn>;save:ReturnType<typeof vi.fn>;state:ReturnType<typeof vi.fn>;reset:ReturnType<typeof vi.fn>};
 beforeEach(()=>{api={list:vi.fn(()=>of({items:[sample],total:1,pagina:0,tamano:20})),roles:vi.fn(()=>of(roles)),user:vi.fn(()=>of(sample)),save:vi.fn(()=>of(sample)),state:vi.fn(()=>of(sample)),reset:vi.fn(()=>of(sample))};TestBed.configureTestingModule({providers:[provideRouter([{path:'usuarios',component:Users,data:{page:{path:'usuarios'}}},{path:'usuarios/nuevo',component:Users,data:{userForm:true,page:{path:'usuarios/nuevo'}}},{path:'usuarios/editar/:id',component:Users,data:{userForm:true,page:{path:'usuarios'}}},{path:'roles',component:Users,data:{page:{path:'roles'}}}]),{provide:UserAdminService,useValue:api},{provide:AuthService,useValue:{user:()=>({id:1}),has:()=>true}}]});});
 async function page(url:string){const h=await RouterTestingHarness.create();const p=await h.navigateByUrl(url,Users);await TestBed.inject(ApplicationRef).whenStable();h.detectChanges();return {p,h};}
 it('carga usuarios reales y permite filtrar',async()=>{const {p}=await page('/usuarios');expect(p.rows()).toEqual([sample]);p.filters.patchValue({buscar:'ventas',estado:'A'});p.apply();await TestBed.inject(ApplicationRef).whenStable();expect(api.list).toHaveBeenLastCalledWith('ventas','A',0);});
 it('no envía formularios incompletos ni contraseñas diferentes',async()=>{const {p}=await page('/usuarios/nuevo');p.save();expect(api.save).not.toHaveBeenCalled();p.form.patchValue({...sample,telefono:'',correo:'',claveTemporal:'Temporal123',confirmacion:'Diferente123'});p.save();expect(api.save).not.toHaveBeenCalled();});
 it('crea cuenta temporal y no envía confirmación al backend',async()=>{const {p}=await page('/usuarios/nuevo');p.form.patchValue({...sample,telefono:'',correo:'',claveTemporal:'Temporal123',confirmacion:'Temporal123'});p.save();expect(api.save).toHaveBeenCalledWith(null,expect.objectContaining({claveTemporal:'Temporal123',rolId:2}));expect(api.save.mock.calls[0][1]).not.toHaveProperty('confirmacion');expect(p.form.controls.claveTemporal.value).toBe('');});
 it('consulta permisos sin cargar ni modificar usuarios',async()=>{const {p,h}=await page('/roles');expect(api.roles).toHaveBeenCalledWith(false);expect(api.list).not.toHaveBeenCalled();expect(p.role()?.permisos[0].codigo).toBe('VEN.VENDER');expect(h.routeNativeElement?.textContent).toContain('Registrar ventas');});
 it('edita sin enviar contraseña y conserva versión',async()=>{const {p}=await page('/usuarios/editar/2');p.save();expect(api.save).toHaveBeenCalledWith(2,expect.objectContaining({version:sample.version,claveTemporal:null}));});
 it('restablecimiento requiere confirmación y limpia el secreto',async()=>{const {p}=await page('/usuarios');p.openReset(sample);p.passwordForm.patchValue({claveTemporal:'Temporal123',confirmacion:'Otra12345'});p.resetPassword();expect(api.reset).not.toHaveBeenCalled();p.passwordForm.controls.confirmacion.setValue('Temporal123');p.resetPassword();expect(api.reset).toHaveBeenCalledWith(sample,'Temporal123');expect(p.resetting()).toBeNull();expect(p.passwordForm.controls.claveTemporal.value).toBe('');});
 it('la propia cuenta no se desactiva desde la lista',async()=>{const {p}=await page('/usuarios');p.state({...sample,id:1});expect(api.state).not.toHaveBeenCalled();});
});

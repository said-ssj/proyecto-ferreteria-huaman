import {By} from '@angular/platform-browser';
import {CdkTrapFocus} from '@angular/cdk/a11y';
import {signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {Shell} from './shell';
import {AuthService} from '../core/auth.service';
import {ThemeService} from '../core/theme.service';
describe('Navegación móvil accesible',()=>{
 beforeEach(()=>TestBed.configureTestingModule({providers:[provideRouter([]),{provide:ThemeService,useValue:{current:signal('plomo')}},{provide:AuthService,useValue:{user:signal({usuario:'usuario'}),roleName:()=> 'Administración',can:()=>true,busy:()=>false,warning:()=>false,message:()=>'',activity:()=>{},logout:()=>{}}}]}));
 it('mantiene el foco dentro del menú y lo devuelve al botón al cerrar',async()=>{
  const f=TestBed.createComponent(Shell);f.componentInstance.mobile.set(true);f.detectChanges();
  const open=f.nativeElement.querySelector('.menu-toggle') as HTMLButtonElement;open.focus();open.click();f.detectChanges();await f.whenStable();
  const sidebar=f.nativeElement.querySelector('.sidebar') as HTMLElement;
  expect(sidebar.getAttribute('role')).toBe('dialog');
  const trap=f.debugElement.query(By.directive(CdkTrapFocus)).injector.get(CdkTrapFocus);
  expect(trap.enabled).toBe(true);expect(trap.autoCapture).toBe(true);
  expect(f.nativeElement.querySelector('.workspace').hasAttribute('inert')).toBe(true);
  f.componentInstance.closeMenu();f.detectChanges();await f.whenStable();f.detectChanges();
  expect(f.nativeElement.querySelector('.workspace').hasAttribute('inert')).toBe(false);expect(document.activeElement).toBe(open);
 });
 it('no aplica modalidad ni bloquea el contenido en escritorio',()=>{
  const f=TestBed.createComponent(Shell);f.componentInstance.mobile.set(false);f.detectChanges();
  expect(f.nativeElement.querySelector('.sidebar').hasAttribute('role')).toBe(false);
  expect(f.nativeElement.querySelector('.workspace').hasAttribute('inert')).toBe(false);
 });
});

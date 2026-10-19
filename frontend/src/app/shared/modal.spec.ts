import {Component,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {Modal} from './modal';
@Component({imports:[Modal],template:'<button id="opener">Abrir</button>@if(open()){<section appModal aria-label="Prueba" [modalLocked]="locked()" (modalClose)="open.set(false)"><button id="inside">Confirmar</button></section>}'})
class Host {open=signal(false);locked=signal(false);}
describe('Diálogos accesibles',()=>{
 it('enfoca el diálogo y devuelve el foco al cerrar con Escape',async()=>{
  const f=TestBed.createComponent(Host);f.detectChanges();
  const opener=f.nativeElement.querySelector('#opener') as HTMLButtonElement;opener.focus();
  f.componentInstance.open.set(true);f.detectChanges();await f.whenStable();
  const dialog=f.nativeElement.querySelector('[appModal]') as HTMLElement;
  expect(dialog.getAttribute('role')).toBe('dialog');expect(dialog.contains(document.activeElement)).toBe(true);
  dialog.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));f.detectChanges();
  expect(f.componentInstance.open()).toBe(false);expect(document.activeElement).toBe(opener);
 });
 it('mantiene abierto el diálogo cuando una operación está pendiente',async()=>{
  const f=TestBed.createComponent(Host);f.componentInstance.open.set(true);f.componentInstance.locked.set(true);f.detectChanges();await f.whenStable();
  const dialog=f.nativeElement.querySelector('[appModal]') as HTMLElement;
  dialog.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));f.detectChanges();
  expect(f.componentInstance.open()).toBe(true);
 });
});

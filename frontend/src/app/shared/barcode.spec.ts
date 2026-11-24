import {TestBed} from '@angular/core/testing';import {Barcode} from './barcode';
describe('Códigos de etiquetas',()=>{
 it('dibuja barras reales para Code 128',async()=>{const f=TestBed.createComponent(Barcode);f.componentRef.setInput('value','PRO-001');f.componentRef.setInput('format','CODE128');f.detectChanges();await f.whenStable();f.detectChanges();expect(f.nativeElement.querySelectorAll('svg rect').length).toBeGreaterThan(1);expect(f.componentInstance.error()).toBe('');});
 it('rechaza un EAN-13 con dígito verificador incorrecto',async()=>{const f=TestBed.createComponent(Barcode);f.componentRef.setInput('value','1234567890123');f.componentRef.setInput('format','EAN13');f.detectChanges();await f.whenStable();f.detectChanges();expect(f.componentInstance.error()).toContain('No se pudo representar');});
});

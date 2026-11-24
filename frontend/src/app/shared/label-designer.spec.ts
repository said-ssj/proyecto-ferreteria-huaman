import {TestBed} from '@angular/core/testing';
import {LabelDesigner} from './label-designer';
import {LABEL_FORMATS,barcodeModuleMm,labelPages} from './label-layout';

describe('Imposición de etiquetas',()=>{
 it('incluye los 13 formatos y respeta el área de A4',()=>{
  expect(LABEL_FORMATS).toHaveLength(13);
  for(const f of LABEL_FORMATS.filter(f=>f.kind==='sheet')){expect(f.width*f.columns).toBeLessThanOrEqual(210);expect(f.height*f.rows).toBeLessThanOrEqual(297);}
 });
 it('continúa en otra hoja sin repetir ni añadir etiquetas',()=>{
  const f=LABEL_FORMATS.find(f=>f.id==='a4-24')!;
  const pages=labelPages(25,f,24);
  expect(pages.map(p=>p.length)).toEqual([24,24]);
  expect(pages.flat().filter(c=>c!==null)).toEqual(Array.from({length:25},(_,i)=>i));
  expect(pages[0].slice(0,23).every(c=>c===null)).toBe(true);
 });
 it('rechaza posiciones fraccionarias, fuera de hoja y cantidades inválidas',()=>{
  const f=LABEL_FORMATS.find(f=>f.id==='a4-40')!;
  for(const start of [0,41,1.5,NaN])expect(labelPages(1,f,start)).toEqual([]);
  for(const qty of [0,201,1.5,NaN])expect(labelPages(qty,f)).toEqual([]);
 });
 it('produce una etiqueta por página de rollo',()=>{expect(labelPages(3,LABEL_FORMATS[3])).toEqual([[0],[1],[2]]);});
 it('reserva el centro del lazo y considera las zonas libres del código',()=>{
  expect(barcodeModuleMm(200,LABEL_FORMATS.find(f=>f.kind==='butterfly')!)).toBe(.2);
 });
});
describe('Diseñador de etiquetas',()=>{
 async function designer(code='PRO-001',quantity=2){const f=TestBed.createComponent(LabelDesigner);f.componentRef.setInput('label',{producto:'Producto <script>alert(1)</script>',presentacion:'Unidad',codigo:code,simbologia:'CODE128',precio:'12.50',cantidad:quantity});f.detectChanges();await f.whenStable();f.detectChanges();return f;}
 it('representa el nombre como texto y conserva códigos de barras reales',async()=>{
  const f=await designer();expect(f.nativeElement.querySelector('script')).toBeNull();expect(f.nativeElement.textContent).toContain('<script>');expect(f.nativeElement.querySelectorAll('svg rect').length).toBeGreaterThan(1);
 });
 it('bloquea códigos demasiado anchos para etiquetas pequeñas',async()=>{
  const f=await designer('PRODUCTO-CODIGO-MUY-LARGO-1234567890');f.componentInstance.changeFormat('25x15');f.detectChanges();expect(f.componentInstance.barcodeProblem()).toContain('más ancho');expect(f.nativeElement.querySelector('button').disabled).toBe(true);
 });
 it('recalcula páginas y reinicia la posición al cambiar de formato',async()=>{
  const f=await designer('1234',25),p=f.componentInstance;p.changeFormat('a4-24');p.start.set(24);f.detectChanges();expect(f.nativeElement.querySelectorAll('.label-page').length).toBe(2);expect(f.nativeElement.querySelectorAll('.product-label').length).toBe(25);p.changeFormat('50x30');expect(p.start()).toBe(1);expect(p.pages()).toHaveLength(25);
 });
 it('imprime en un documento aislado con papel exacto, sin controles ni scripts',async()=>{
  const f=await designer('1234'),p=f.componentInstance;p.changeFormat('a4-40');f.detectChanges();p.print();
  const frame=document.querySelector('iframe')!;expect(frame.srcdoc).toContain('@page{size:A4;margin:0}');expect(frame.srcdoc).not.toContain('<button');expect(new DOMParser().parseFromString(frame.srcdoc,'text/html').querySelector('script')).toBeNull();expect(frame.srcdoc).toContain('&lt;script&gt;');expect(frame.srcdoc).toContain('<svg');f.destroy();expect(document.querySelector('iframe')).toBeNull();
 });
});

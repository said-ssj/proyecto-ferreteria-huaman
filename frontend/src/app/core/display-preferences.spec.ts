import {TestBed} from '@angular/core/testing';
import {DisplayPreferences} from './display-preferences';
describe('Preferencias de visualización',()=>{
 beforeEach(()=>localStorage.removeItem('huaman.visualizacion'));
 afterEach(()=>{localStorage.removeItem('huaman.visualizacion');document.documentElement.style.removeProperty('--ui-scale');document.documentElement.style.removeProperty('--overlay-scale');});
 it('restaura tamaño e imágenes y conserva ambos al cambiar solo uno',()=>{localStorage.setItem('huaman.visualizacion',JSON.stringify({scale:95,photos:true}));const p=TestBed.inject(DisplayPreferences);expect(p.scale()).toBe(95);expect(p.photos()).toBe(true);p.setScale(90);expect(p.photos()).toBe(true);expect(JSON.parse(localStorage.getItem('huaman.visualizacion')!)).toEqual({scale:90,photos:true});expect(document.documentElement.style.getPropertyValue('--ui-scale')).toBe('0.9');expect(document.documentElement.style.getPropertyValue('--overlay-scale')).toBe(String(100/90));});
 it('rechaza tamaños ajenos a las opciones y datos guardados corruptos',()=>{localStorage.setItem('huaman.visualizacion','invalid');const p=TestBed.inject(DisplayPreferences);expect(p.scale()).toBe(100);expect(p.photos()).toBe(false);p.setScale(10);expect(p.scale()).toBe(100);});
});

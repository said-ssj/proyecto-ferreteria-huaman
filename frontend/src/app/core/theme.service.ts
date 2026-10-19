import { DOCUMENT } from '@angular/common';
import { Injectable, inject, signal } from '@angular/core';
export const THEMES=[{id:'plomo',name:'Plomo',description:'Neutro y equilibrado',colors:['#465458','#f4f5f5','#ffffff','#252c2e']},{id:'gris-suave',name:'Gris suave',description:'Superficies de gris claro',colors:['#465458','#e8ebeb','#f8f9f9','#252c2e']},{id:'pizarra-neutra',name:'Pizarra neutra',description:'Grises oscuros y texto claro',colors:['#d3dce0','#202629','#293135','#edf1f3']},{id:'alto-contraste',name:'Alto contraste',description:'Bordes definidos y mayor contraste',colors:['#0f3d6e','#f0f4f8','#ffffff','#0a1118']},{id:'lectura-calida',name:'Lectura cálida',description:'Superficies cálidas en tonos sepia',colors:['#7a4f1d','#f6efe6','#faf6f0','#231a12']},{id:'noche-suave',name:'Noche suave',description:'Pizarra y acentos ámbar',colors:['#5e9ed6','#1a202c','#222b38','#e2e8f0']}] as const;
@Injectable({providedIn:'root'})
export class ThemeService {private readonly document=inject(DOCUMENT);readonly current=signal('plomo');readonly themes=THEMES;
constructor(){let saved='plomo';try{saved=this.document.defaultView?.localStorage.getItem('huaman.apariencia')??saved;}catch{}this.set(saved);}
set(id:string){const theme=THEMES.find(t=>t.id===id);if(!theme)return;this.current.set(theme.id);this.document.documentElement.dataset['theme']=theme.id;try{this.document.defaultView?.localStorage.setItem('huaman.apariencia',theme.id);}catch{}}
}

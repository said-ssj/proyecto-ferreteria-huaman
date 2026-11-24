import {DOCUMENT} from '@angular/common';
import {Injectable,inject,signal} from '@angular/core';
@Injectable({providedIn:'root'})
export class DisplayPreferences {
 private readonly document=inject(DOCUMENT);
 readonly scale=signal(100);readonly photos=signal(false);
 constructor(){try{const saved=JSON.parse(this.document.defaultView?.localStorage.getItem('huaman.visualizacion')||'{}');this.setScale(saved.scale);this.setPhotos(saved.photos===true);}catch{this.setScale(100);}}
 setScale(value:number){const scale=[90,95,100].includes(value)?value:100;this.scale.set(scale);this.document.documentElement.style.setProperty('--ui-scale',String(scale/100));this.document.documentElement.style.setProperty('--overlay-scale',String(100/scale));this.persist();}
 setPhotos(value:boolean){this.photos.set(value===true);this.persist();}
 private persist(){try{this.document.defaultView?.localStorage.setItem('huaman.visualizacion',JSON.stringify({scale:this.scale(),photos:this.photos()}));}catch{}}
}

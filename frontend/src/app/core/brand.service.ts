import {DOCUMENT} from '@angular/common';
import {HttpBackend,HttpClient} from '@angular/common/http';
import {Injectable,Injector,computed,effect,inject,signal} from '@angular/core';
import {Subscription,tap} from 'rxjs';
import {API_BASE_URL} from './auth.service';
export interface BrandMetadata {nombre:string;logoRuta:string|null;usarLogoComoFavicon:boolean;version:string|null;}
export function businessInitial(name:string):string {
 const words=name.trim().split(/\s+/);const generic=/^(ferreteria|restaurante|cafeteria|panaderia|tienda|licoreria|minimarket)$/;
 const first=words.length>1&&generic.test(words[0].normalize('NFD').replace(/\p{M}/gu,'').toLowerCase())?words.slice(1).join(' '):name;
 return Array.from(first.toUpperCase()).find(c=>/[\p{L}\p{N}]/u.test(c))||'N';
}
@Injectable({providedIn:'root'})
export class BrandService {
 private readonly injector=inject(Injector);private readonly document=inject(DOCUMENT);private readonly base=inject(API_BASE_URL);
 readonly state=signal<BrandMetadata>({nombre:'Mi negocio',logoRuta:null,usarLogoComoFavicon:false,version:null});
 readonly ready=signal(false);readonly loadError=signal(false);private pending:Subscription|null=null;
 readonly initial=computed(()=>businessInitial(this.state().nombre));readonly failed=signal(false);
 readonly logoUrl=computed(()=>{const path=this.state().logoRuta;return !this.failed()&&path&&/^\/api\/identidad-visual\/logo\/[a-f0-9]{64}$/.test(path)?this.base+path.slice(4):null;});
 constructor(){effect(()=>{const image=this.logoUrl(),letter=this.initial();let link=this.document.querySelector<HTMLLinkElement>('link[rel="icon"]');if(!link){link=this.document.createElement('link');link.rel='icon';this.document.head.append(link);}link.type=image&&this.state().usarLogoComoFavicon?'image/png':'image/svg+xml';link.href=image&&this.state().usarLogoComoFavicon?image:'data:image/svg+xml,'+encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="4" fill="#465458"/><text x="32" y="45" text-anchor="middle" font-family="Arial,sans-serif" font-size="44" font-weight="700" fill="#fff">${letter}</text></svg>`);});}
 load(){this.ready.set(false);this.pending?.unsubscribe();this.loadError.set(false);this.pending=new HttpClient(this.injector.get(HttpBackend)).get<BrandMetadata>(this.base+'/identidad-visual').subscribe({next:value=>this.apply(value),error:()=>this.loadError.set(true)});}
 apply(value:BrandMetadata){this.failed.set(false);this.state.set({...value,nombre:value.nombre?.trim() || 'Mi negocio'});this.ready.set(true);this.loadError.set(false);}
 save(input:{imagenBase64:string|null;quitarLogo:boolean;usarLogoComoFavicon:boolean;version:string|null}){return this.injector.get(HttpClient).put<BrandMetadata>(this.base+'/identidad-visual',input).pipe(tap(value=>{this.pending?.unsubscribe();this.apply(value);}));}
}

import {Component,effect,inject,input,signal} from '@angular/core';
import {ProductImageService} from '../core/product-image.service';
import {Icon} from './icon';
@Component({selector:'app-product-photo',imports:[Icon],host:{'aria-hidden':'true'},template:`@if(url()&&!failed()){<img [src]="url()" alt="" (error)="failed.set(true)">}@else{<span class="product-photo-placeholder"><app-icon name="image"/></span>}`,styles:[`:host{display:inline-flex;flex:none;width:64px;height:64px;border:1px solid var(--control);border-radius:4px;overflow:hidden;background:var(--surface)}img{width:100%;height:100%;object-fit:contain}.product-photo-placeholder{display:grid;place-items:center;width:100%;height:100%;color:var(--muted)}`]})
export class ProductPhoto {
 readonly productId=input.required<number>();readonly hash=input<string|null|undefined>(null);readonly url=signal('');readonly failed=signal(false);private readonly api=inject(ProductImageService);
 constructor(){effect(cleanup=>{this.url.set('');this.failed.set(false);const id=this.productId(),hash=this.hash();if(!Number.isSafeInteger(id)||id<=0||!hash||! /^[0-9a-f]{64}$/.test(hash))return;let objectUrl='';const sub=this.api.image(id,hash).subscribe({next:blob=>{if(blob.type!=='image/jpeg'){this.failed.set(true);return;}objectUrl=URL.createObjectURL(blob);this.url.set(objectUrl);},error:()=>this.failed.set(true)});cleanup(()=>{sub.unsubscribe();if(objectUrl)URL.revokeObjectURL(objectUrl);});});}
}

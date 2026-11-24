import {Component,inject} from '@angular/core';
import {BrandService} from '../core/brand.service';
@Component({selector:'app-business-brand',template:`<span class="brand-mark" aria-hidden="true">@if(brand.logoUrl();as logo){<img [src]="logo" alt="" (error)="brand.failed.set(true)">}@else{ {{brand.initial()}} }</span><strong class="business-name">{{brand.state().nombre}}</strong>`,styles:`:host{display:flex;align-items:center;gap:13px;min-width:0}.brand-mark{flex:0 0 46px;overflow:hidden}.brand-mark:has(img){background:transparent;border:1px solid var(--line)}img{width:100%;height:100%;object-fit:contain}.business-name{font-size:1rem!important;overflow-wrap:anywhere;line-height:1.35}`})
export class BusinessBrand {readonly brand=inject(BrandService);}

import {Component,ElementRef,effect,input,signal,viewChild} from '@angular/core';
import JsBarcode from 'jsbarcode';
@Component({selector:'app-barcode',templateUrl:'./barcode.html',styles:[':host{display:block;background:#fff;color:#111}svg{max-width:100%;height:auto;display:block;margin:auto}.barcode-value{font-size:14px;overflow-wrap:anywhere;text-align:center;color:#111}']})
export class Barcode{
 readonly barHeight=input(55);readonly value=input.required<string>();readonly format=input.required<'EAN13'|'CODE128'>();readonly error=signal('');private readonly svg=viewChild<ElementRef<SVGElement>>('barcode');
 constructor(){effect(()=>{const element=this.svg();const value=this.value(),format=this.format(),height=this.barHeight();if(!element)return;this.error.set('');try{JsBarcode(element.nativeElement,value,{format,width:2,height,margin:22,marginTop:0,marginBottom:0,displayValue:false,fontSize:16,background:'#ffffff',lineColor:'#000000'});element.nativeElement.setAttribute('preserveAspectRatio','none');}catch{element.nativeElement.replaceChildren();this.error.set('No se pudo representar el código. Revisa el registro del producto.');}});}
}

import {DOCUMENT,DecimalPipe} from '@angular/common';
import {Component,DestroyRef,ElementRef,ViewEncapsulation,computed,inject,input,signal,viewChild} from '@angular/core';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatSelectModule} from '@angular/material/select';
import {MatInputModule} from '@angular/material/input';
import JsBarcode from 'jsbarcode';
import {ProductLabel} from '../core/settings.service';
import {Barcode} from './barcode';
import {LABEL_FORMATS,LABEL_CSS,LABEL_PRINT_CSS,barcodeModuleMm,labelPages} from './label-layout';

@Component({selector:'app-label-designer',imports:[DecimalPipe,MatButtonModule,MatFormFieldModule,MatSelectModule,MatInputModule,Barcode],templateUrl:'./label-designer.html',styleUrl:'./label-designer.css',encapsulation:ViewEncapsulation.None,
 styles:[LABEL_CSS]
})
export class LabelDesigner {
 readonly label=input.required<ProductLabel>();readonly formats=LABEL_FORMATS;readonly formatId=signal('50x30');readonly start=signal(1);readonly printing=signal(false);readonly printError=signal('');
 readonly format=computed(()=>LABEL_FORMATS.find(f=>f.id===this.formatId())||LABEL_FORMATS[3]);
 readonly capacity=computed(()=>this.format().columns*this.format().rows);
 readonly pages=computed(()=>labelPages(this.label().cantidad,this.format(),this.start()));
 readonly barcodeHeight=computed(()=>this.format().height<=20?24:this.format().height<=30?36:55);
 readonly barcodeMm=computed(()=>this.format().height<=20?5:this.format().height<=30?9:Math.min(25,this.format().height/3));
 private readonly doc=inject(DOCUMENT);private readonly area=viewChild<ElementRef<HTMLElement>>('pagesArea');private readonly destroy=inject(DestroyRef);private frame:HTMLIFrameElement|null=null;private timer:ReturnType<typeof setTimeout>|null=null;
 readonly barcodeProblem=computed(()=>{try{const svg=this.doc.createElementNS('http://www.w3.org/2000/svg','svg');JsBarcode(svg,this.label().codigo,{format:this.label().simbologia,width:2,height:55,margin:22,displayValue:false});const module=barcodeModuleMm(Number.parseFloat(svg.getAttribute('width')||''),this.format());return !Number.isFinite(module)||module<.25?'El código necesita más ancho para conservar barras legibles. Elige una etiqueta más grande o un código registrado más corto.':'';}catch{return 'El código no se puede representar. Revisa el código registrado del producto.';}});
 constructor(){this.destroy.onDestroy(()=>this.cleanup());}
 changeFormat(id:string){this.formatId.set(id);this.start.set(1);this.printError.set('');}
 setStart(value:string){this.start.set(Number(value));}
 private cleanup(){if(this.timer)clearTimeout(this.timer);this.timer=null;this.frame?.remove();this.frame=null;this.printing.set(false);}
 print(){
  if(this.printing()||this.barcodeProblem()||!this.pages().length||!this.area())return;
  this.cleanup();this.printError.set('');this.printing.set(true);
  const f=this.format(),frame=this.doc.createElement('iframe');this.frame=frame;
  frame.title='Impresión de etiquetas';frame.setAttribute('aria-hidden','true');frame.style.cssText='position:fixed;width:1px;height:1px;left:-10000px;top:0;border:0';
  frame.onload=()=>{try{const win=frame.contentWindow;if(!win)throw new Error();win.addEventListener('afterprint',()=>this.cleanup(),{once:true});win.focus();win.print();this.printing.set(false);}catch{this.printError.set('No se pudo abrir la impresión. Revisa los permisos del navegador e inténtalo otra vez.');this.cleanup();}};
  // Only Angular-rendered text and SVG are copied, never raw product strings interpolated into HTML.
  const size=f.kind==='sheet'?'A4':`${f.width}mm ${f.height}mm`;
  frame.srcdoc=`<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Etiquetas de productos</title><style>${LABEL_PRINT_CSS}@page{size:${size};margin:0}</style></head><body>${this.area()!.nativeElement.outerHTML}</body></html>`;
  this.doc.body.appendChild(frame);
  this.timer=setTimeout(()=>this.cleanup(),300000);
 }
}

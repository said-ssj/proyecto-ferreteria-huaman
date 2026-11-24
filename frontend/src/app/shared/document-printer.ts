import {DOCUMENT} from '@angular/common';
import {DestroyRef,Injectable,inject} from '@angular/core';

/** Print a rendered application document separately from the navigation and dialogs. */
@Injectable()
export class DocumentPrinter {
 private readonly doc=inject(DOCUMENT);private readonly destroy=inject(DestroyRef);
 private frame:HTMLIFrameElement|null=null;private timer:ReturnType<typeof setTimeout>|null=null;
 constructor(){this.destroy.onDestroy(()=>this.cleanup());}
 private cleanup(){if(this.timer)clearTimeout(this.timer);this.timer=null;this.frame?.remove();this.frame=null;}
 print(source:HTMLElement,css:string,onError:()=>void){
  this.cleanup();
  const copy=source.cloneNode(true) as HTMLElement;
  copy.querySelectorAll('.print-hidden,button,input,textarea,select,script').forEach(e=>e.remove());
  copy.removeAttribute('role');copy.removeAttribute('aria-modal');copy.removeAttribute('tabindex');
  const frame=this.doc.createElement('iframe');this.frame=frame;
  frame.title='Impresión de hoja de preparación';frame.setAttribute('aria-hidden','true');
  frame.style.cssText='position:fixed;width:1px;height:1px;left:-10000px;top:0;border:0';
  frame.onload=()=>{try{const win=frame.contentWindow;if(!win)throw new Error();win.addEventListener('afterprint',()=>this.cleanup(),{once:true});win.focus();win.print();}catch{this.cleanup();onError();}};
  // Data comes from Angular's escaped DOM, never from unescaped business strings.
  frame.srcdoc=`<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Hoja de preparación</title><style>${css}</style></head><body>${copy.outerHTML}</body></html>`;
  this.doc.body.appendChild(frame);this.timer=setTimeout(()=>this.cleanup(),300000);
 }
}

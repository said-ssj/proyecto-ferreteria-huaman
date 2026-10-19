import {AfterViewInit,Directive,ElementRef,OnDestroy,inject,input,output} from '@angular/core';
import {DOCUMENT} from '@angular/common';
import {FocusTrap,FocusTrapFactory} from '@angular/cdk/a11y';

@Directive({selector:'[appModal]',host:{role:'dialog','aria-modal':'true',tabindex:'-1','(keydown.escape)':'escape($event)'}})
export class Modal implements AfterViewInit,OnDestroy {
  readonly modalLocked=input(false);
  readonly modalClose=output<void>();
  private readonly element=inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly doc=inject(DOCUMENT);
  private readonly factory=inject(FocusTrapFactory);
  private readonly previous=this.doc.activeElement as HTMLElement|null;
  private trap:FocusTrap|null=null;
  private destroyed=false;
  ngAfterViewInit(){
    this.trap=this.factory.create(this.element.nativeElement);
    this.trap.focusInitialElementWhenReady().then(focused=>{if(!focused&&!this.destroyed)this.element.nativeElement.focus();});
  }
  escape(event:Event){event.stopPropagation();event.preventDefault();if(!this.modalLocked())this.modalClose.emit();}
  ngOnDestroy(){this.destroyed=true;this.trap?.destroy();if(this.previous?.isConnected)this.previous.focus();}
}

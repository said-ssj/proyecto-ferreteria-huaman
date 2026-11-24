import {Component,DestroyRef,effect,inject,input,signal} from '@angular/core';
import {FormGroup} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {finalize} from 'rxjs';
import {DecolectaService,RucData} from '../core/decolecta.service';
@Component({selector:'app-ruc-lookup',imports:[MatButtonModule],template:`
<div class="lookup"><button mat-stroked-button type="button" [disabled]="disabled()||busy()||!valid()" (click)="lookup()">{{busy()?'Consultando…':'Consultar RUC'}}</button><span>Completa el RUC en el formulario y consulta los datos fiscales.</span></div>
@if(error()){<p role="alert">{{error()}}</p>}
@if(result();as r){@if(current()===r.ruc){<section aria-label="Datos fiscales consultados" aria-live="polite"><p><strong>{{r.razonSocial}}</strong></p><p>Estado: {{r.estadoTributario||'No informado'}} · Condición: {{r.condicion||'No informada'}}</p><p>{{r.direccion||'Dirección no informada'}}</p><p>{{r.departamento||'—'}} / {{r.provincia||'—'}} / {{r.distrito||'—'}} · Ubigeo: {{r.ubigeo||'No informado'}}</p><p>Revisa estos datos antes de aplicarlos. Los datos fiscales adicionales se muestran para consulta.</p><button mat-stroked-button type="button" [disabled]="disabled()" (click)="apply(r)">Usar razón social y dirección</button>@if(applied()){<p role="status">Datos aplicados. Revisa el formulario y guarda el registro.</p>}</section>}}
`,styles:[`:host{display:block;margin-block:24px}.lookup{display:flex;align-items:center;flex-wrap:wrap;gap:12px}.lookup span,p{overflow-wrap:anywhere}section{margin-top:16px;padding:16px;border:1px solid var(--line);border-radius:4px;background:var(--surface-alt)}p{margin:8px 0}`]})
export class RucLookup {
 readonly group=input.required<FormGroup>();readonly supplier=input(false);readonly disabled=input(false);
 readonly busy=signal(false);readonly error=signal('');readonly result=signal<RucData|null>(null);readonly applied=signal(false);
 private readonly api=inject(DecolectaService);private readonly destroy=inject(DestroyRef);
 private readonly revision=signal(0);
 constructor(){effect(cleanup=>{const subscription=this.group().valueChanges.subscribe(()=>this.revision.update(n=>n+1));cleanup(()=>subscription.unsubscribe());});}
 current(){this.revision();return String(this.group().get(this.supplier()?'ruc':'documento')?.value||'').trim();}
 valid(){return (this.supplier()||this.group().get('tipoDocumento')?.value==='RUC')&&/^(10|15|16|17|20)[0-9]{9}$/.test(this.current());}
 lookup(){if(!this.valid()||this.busy()||this.disabled())return;const number=this.current();this.busy.set(true);this.error.set('');this.result.set(null);this.applied.set(false);this.api.lookup(number).pipe(takeUntilDestroyed(this.destroy),finalize(()=>this.busy.set(false))).subscribe({next:r=>{if(this.current()===number&&this.valid())this.result.set(r);},error:e=>{this.error.set(typeof e.error?.detail==='string'?e.error.detail:'No se pudo consultar el RUC. Puedes ingresar los datos manualmente.');}});}
 apply(r:RucData){if(this.disabled()||!this.valid()||this.current()!==r.ruc)return;const patch:Record<string,string>={[this.supplier()?'razonSocial':'nombre']:r.razonSocial};if(r.direccion)patch['direccion']=r.direccion;this.group().patchValue(patch);this.group().markAsDirty();this.applied.set(true);}
}

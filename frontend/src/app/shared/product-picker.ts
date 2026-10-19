import {Component,DestroyRef,effect,inject,input,output,signal} from '@angular/core';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {FormControl,ReactiveFormsModule} from '@angular/forms';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatButtonModule} from '@angular/material/button';
import {finalize} from 'rxjs';
import {ProductService,Product,ProductDetails} from '../core/product.service';
import {authError} from '../core/auth.service';
import {EmptyState} from './empty-state';
@Component({selector:'app-product-picker',imports:[ReactiveFormsModule,MatFormFieldModule,MatInputModule,MatButtonModule,EmptyState],template:`<form (submit)="$event.preventDefault();search()" class="filter-fields"><mat-form-field appearance="outline"><mat-label>Nombre o código del producto</mat-label><input matInput type="search" [formControl]="query" maxlength="100"><mat-hint>También acepta códigos de barras.</mat-hint></mat-form-field><button mat-stroked-button [disabled]="loading()">Buscar productos</button></form>@if(error()){<p class="notice danger" role="alert">{{error()}}</p>}@if(loading()){<p role="status">Cargando productos…</p>}@if(rows().length){<div class="table-scroll"><table aria-label="Seleccionar producto"><thead><tr><th>Código</th><th>Producto</th><th>Unidad</th><th>Stock actual</th><th>Acción</th></tr></thead><tbody>@for(p of rows();track p.id){<tr><td>{{p.codigo}}</td><td>{{p.nombre}}</td><td>{{p.unidad}}</td><td>{{p.stockActual}}</td><td><button mat-stroked-button type="button" [disabled]="loading()||disabled()" (click)="select(p)">Seleccionar</button></td></tr>}</tbody></table></div>}@else if(!loading()){<app-empty-state icon="inventory_2" title="No hay productos" description="No se encontraron productos para seleccionar."/>}<div class="catalog-pagination"><span>{{total()}} productos</span><div><button mat-stroked-button type="button" [disabled]="page()===0||loading()" (click)="page.set(page()-1)">Anterior</button><span>Página {{page()+1}}</span><button mat-stroked-button type="button" [disabled]="(page()+1)*20>=total()||loading()" (click)="page.set(page()+1)">Siguiente</button></div></div>`})
export class ProductPicker {
 private readonly api=inject(ProductService);private readonly destroy=inject(DestroyRef);readonly disabled=input(false);readonly activeOnly=input(true);readonly chosen=output<ProductDetails>();readonly query=new FormControl('',{nonNullable:true});readonly applied=signal('');readonly page=signal(0);readonly total=signal(0);readonly rows=signal<Product[]>([]);readonly loading=signal(false);readonly error=signal('');
 constructor(){effect(cleanup=>{this.loading.set(true);this.error.set('');const sub=this.api.list(this.applied(),this.activeOnly()?'A':'','',this.page()).pipe(finalize(()=>this.loading.set(false))).subscribe({next:r=>{this.rows.set(r.items);this.total.set(r.total);},error:e=>{this.rows.set([]);this.error.set(authError(e));}});cleanup(()=>sub.unsubscribe());});}
 search(){this.page.set(0);this.applied.set(this.query.value);}
 select(p:Product){if(this.disabled()||this.loading())return;this.loading.set(true);this.api.get(p.id).pipe(takeUntilDestroyed(this.destroy),finalize(()=>this.loading.set(false))).subscribe({next:d=>this.chosen.emit(d),error:e=>this.error.set(authError(e))});}
}

import {Component,DestroyRef,computed,effect,inject,signal} from '@angular/core';
import {NgTemplateOutlet} from '@angular/common';
import {ActivatedRoute,Router,RouterLink} from '@angular/router';
import {takeUntilDestroyed,toSignal} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatSelectModule} from '@angular/material/select';
import {MatCheckboxModule} from '@angular/material/checkbox';
import {MatDialog} from '@angular/material/dialog';
import {Observable,finalize,forkJoin} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {ProductService,Product,ProductDetails,Presentation,Wholesale} from '../core/product.service';
import {Category,Unit} from '../core/catalog.service';
import {EmptyState} from '../shared/empty-state';
import {Icon} from '../shared/icon';
import {Confirm} from '../shared/confirm';
interface Field {key:string;label:string;type?:'select'|'check'|'area'|'decimal';required?:boolean;max?:number;options?:{id:string|number;nombre:string}[];}
const decimal=[Validators.required,Validators.pattern(/^[0-9]{1,12}(?:\.[0-9]{1,6})?$/)];
function form(fields:Field[]){return new FormGroup<Record<string,FormControl<any>>>(Object.fromEntries(fields.map(f=>[f.key,new FormControl(f.type==='check'?false:'',{nonNullable:true,validators:[...(f.required?[Validators.required]:[]),...(f.max?[Validators.maxLength(f.max)]:[]),...(f.type==='decimal'?decimal:[])]})])));}
@Component({selector:'app-products',imports:[NgTemplateOutlet,RouterLink,ReactiveFormsModule,MatButtonModule,MatFormFieldModule,MatInputModule,MatSelectModule,MatCheckboxModule,EmptyState,Icon],templateUrl:'./products.html'})
export class Products {
 readonly auth=inject(AuthService);private readonly api=inject(ProductService);private readonly route=inject(ActivatedRoute);private readonly router=inject(Router);private readonly dialog=inject(MatDialog);private readonly destroy=inject(DestroyRef);
 private readonly data=toSignal(this.route.data);private readonly params=toSignal(this.route.paramMap);
 readonly mode=computed(()=>this.data()?.['productMode']||'list');readonly title=computed(()=>this.mode()==='form'?(this.editId()?'Editar producto':'Nuevo producto'):this.mode()==='presentations'?'Presentaciones y precios':this.mode()==='measures'?'Unidades y fraccionamiento':'Productos');
 readonly editId=computed(()=>Number(this.params()?.get('id'))||null);
 readonly categories=signal<Category[]>([]);readonly units=signal<Unit[]>([]);readonly rows=signal<Product[]>([]);readonly total=signal(0);readonly page=signal(0);readonly filters=signal({buscar:'',estado:'',categoria:''});
 readonly loading=signal(false);readonly optionsReady=signal(false);readonly saving=signal(false);readonly error=signal('');readonly message=signal('');readonly loaded=signal(false);readonly details=signal<ProductDetails|null>(null);readonly selected=signal(Number(this.route.snapshot.queryParamMap.get('producto'))||null);
 readonly editingPresentation=signal<Presentation|null>(null);readonly editingWholesale=signal<Wholesale|null>(null);readonly presentationId=signal<number|null>(null);
 readonly searchForm=new FormGroup({buscar:new FormControl('',{nonNullable:true}),estado:new FormControl('',{nonNullable:true}),categoria:new FormControl('',{nonNullable:true})});
 readonly productFields:Field[]=[{key:'codigo',label:'Código interno',required:true,max:30},{key:'nombre',label:'Nombre',required:true,max:120},{key:'categoriaId',label:'Categoría',type:'select',required:true},{key:'descripcion',label:'Descripción',type:'area',max:300},{key:'unidadId',label:'Unidad base',type:'select',required:true},{key:'modoControl',label:'Control de existencias',type:'select',required:true,options:[{id:'GRANEL',nombre:'Granel'},{id:'ENVASES',nombre:'Envases y contenido suelto'},{id:'TRAMOS',nombre:'Tramos'}]},{key:'admiteFracciones',label:'Admite cantidades fraccionadas',type:'check'},{key:'incrementoBase',label:'Incremento permitido en unidad base',type:'decimal'},{key:'minimoVentaBase',label:'Cantidad mínima en unidad base',type:'decimal'},{key:'stockMinimo',label:'Stock mínimo de alerta',type:'decimal'},{key:'ubicacion',label:'Ubicación',max:60}];
 readonly baseFields:Field[]=[{key:'nombreBase',label:'Nombre de la presentación base',required:true,max:60},{key:'precioBase',label:'Precio de venta base (S/, IGV incluido)',type:'decimal'}];
 readonly presentationFields:Field[]=[{key:'nombre',label:'Nombre de presentación',required:true,max:60},{key:'unidadVentaId',label:'Unidad de venta',type:'select'},{key:'factorBase',label:'Equivalencia en unidad base',type:'decimal'},{key:'permiteVenta',label:'Disponible para venta',type:'check'},{key:'admiteFracciones',label:'Admite cantidades fraccionadas',type:'check'},{key:'incrementoVenta',label:'Incremento permitido',type:'decimal'},{key:'minimoVenta',label:'Cantidad mínima de venta',type:'decimal'},{key:'precioNormal',label:'Precio normal (S/, IGV incluido)',type:'decimal'}];
 readonly wholesaleFields:Field[]=[{key:'cantidadMinima',label:'Cantidad mínima mayorista',type:'decimal'},{key:'precio',label:'Precio por presentación (S/)',type:'decimal'}];
 readonly barcodeFields:Field[]=[{key:'codigo',label:'Código de barras',required:true,max:80},{key:'simbologia',label:'Tipo de código',type:'select',required:true,options:[{id:'CODE128',nombre:'Code 128'},{id:'EAN13',nombre:'EAN-13'}]}];
 readonly productForm=form([...this.productFields,...this.baseFields]);readonly presentationForm=form(this.presentationFields);readonly wholesaleForm=form(this.wholesaleFields);readonly barcodeForm=form(this.barcodeFields);
 constructor(){
  forkJoin({categories:this.api.options<Category>('categorias'),units:this.api.options<Unit>('unidades')}).pipe(takeUntilDestroyed()).subscribe({next:r=>{this.categories.set(r.categories);this.units.set(r.units);this.optionsReady.set(true);},error:e=>this.error.set(authError(e))});
  effect(cleanup=>{const mode=this.mode(),id=this.editId(),selected=this.selected(),filter=this.filters(),page=this.page();this.error.set('');this.loaded.set(false);this.loading.set(true);
   if(mode==='form'&&!id){this.productForm.enable();this.productForm.reset();this.details.set(null);this.loaded.set(true);this.loading.set(false);return;}
   if(mode==='form'||mode!=='list'&&selected){const key=mode==='form'?id!:selected!;const sub=this.api.get(key).pipe(finalize(()=>this.loading.set(false))).subscribe({next:d=>{this.details.set(d);this.loaded.set(true);if(mode==='form'){this.productForm.reset();this.productForm.patchValue(d.producto);for(const field of ['unidadId','modoControl','admiteFracciones','incrementoBase','nombreBase','precioBase'])this.productForm.controls[field].disable();}},error:e=>this.error.set(authError(e))});cleanup(()=>sub.unsubscribe());}
   else{const sub=this.api.list(filter.buscar,filter.estado,filter.categoria,page).pipe(finalize(()=>this.loading.set(false))).subscribe({next:r=>{this.rows.set(r.items);this.total.set(r.total);this.loaded.set(true);},error:e=>{this.rows.set([]);this.error.set(authError(e));}});cleanup(()=>sub.unsubscribe());}
  });
 }
 options(field:Field){if(field.key==='categoriaId')return this.categories().filter(c=>c.estado==='A'||c.id===this.details()?.producto.categoriaId);if(field.key==='unidadId'||field.key==='unidadVentaId')return this.units().filter(u=>u.estado==='A'||u.id===this.details()?.producto.unidadId);return field.options||[];}
 apply(){this.page.set(0);this.filters.set(this.searchForm.getRawValue());}
 clear(){this.searchForm.reset();this.apply();}
 reload(){this.filters.update(f=>({...f}));}
 choose(row:Product){this.details.set(null);this.selected.set(row.id);this.resetPresentation();}
 changeProduct(){this.selected.set(null);this.details.set(null);this.presentationId.set(null);this.resetPresentation();}
 labelMode(code:string){return ({GRANEL:'Granel',ENVASES:'Envases y contenido suelto',TRAMOS:'Tramos'} as Record<string,string>)[code]||code;}
 presentationName(id:number){return this.details()?.presentaciones.find(p=>p.id===id)?.nombre||'';}
 private run<T>(request:Observable<T>,after:()=>void){this.saving.set(true);this.error.set('');this.message.set('');request.pipe(takeUntilDestroyed(this.destroy),finalize(()=>this.saving.set(false))).subscribe({next:()=>{this.message.set('Cambios guardados correctamente');after();},error:e=>this.error.set(authError(e))});}
 saveProduct(){if(this.productForm.invalid||this.saving()||!this.loaded()||!this.optionsReady())return;const {nombreBase,precioBase,...value}=this.productForm.getRawValue();value['codigo']=value['codigo'].trim().toUpperCase();const body=this.editId()?{...value,version:this.details()!.producto.version}:{...value,nombreBase,precioBase};this.run(this.api.save(this.editId(),body),()=>void this.router.navigate(['/productos']));}
 editPresentation(p:Presentation){this.editingPresentation.set(p);this.presentationForm.reset();this.presentationForm.enable();this.presentationForm.patchValue(p);for(const f of ['unidadVentaId','factorBase'])this.presentationForm.controls[f].disable();if(!this.auth.has('PRO.PRECIOS'))this.presentationForm.controls['precioNormal'].disable();}
 resetPresentation(){this.editingPresentation.set(null);this.presentationForm.enable();this.presentationForm.reset();}
 savePresentation(){if(this.presentationForm.invalid||this.saving()||!this.details())return;const value=this.presentationForm.getRawValue();value['unidadVentaId']=value['unidadVentaId']||null;this.run(this.api.presentation(this.details()!.producto.id,this.editingPresentation()?.id||null,{...value,version:this.editingPresentation()?.version||null}),()=>{this.resetPresentation();this.refreshDetails();});}
 selectPresentation(id:number){this.presentationId.set(id);this.editingWholesale.set(null);this.wholesaleForm.reset();this.barcodeForm.reset();}
 editWholesale(w:Wholesale){this.presentationId.set(w.presentacionId);this.editingWholesale.set(w);this.wholesaleForm.patchValue(w);}
 resetWholesale(){this.editingWholesale.set(null);this.wholesaleForm.reset();}
 saveWholesale(){if(this.wholesaleForm.invalid||this.saving()||!this.presentationId())return;this.run(this.api.wholesale(this.details()!.producto.id,this.presentationId()!,this.editingWholesale()?.id||null,{...this.wholesaleForm.getRawValue(),version:this.editingWholesale()?.version||null}),()=>{this.resetWholesale();this.refreshDetails();});}
 saveBarcode(){if(this.barcodeForm.invalid||this.saving()||!this.presentationId())return;this.run(this.api.barcode(this.details()!.producto.id,this.presentationId()!,this.barcodeForm.getRawValue()),()=>{this.barcodeForm.reset();this.refreshDetails();});}
 private refreshDetails(){const id=this.details()!.producto.id;this.api.get(id).pipe(takeUntilDestroyed(this.destroy)).subscribe({next:d=>this.details.set(d),error:e=>this.error.set(authError(e))});}
 state(kind:'producto'|'presentaciones'|'mayoristas'|'codigos',row:{id:number;estado:string;version:string}){if(this.saving())return;const product=kind==='producto'?row.id:this.details()!.producto.id;const action=row.estado==='A'?'Desactivar':'Activar';this.dialog.open(Confirm,{width:'460px',data:{title:action+' registro',message:action+' este registro para las próximas operaciones.',action}}).afterClosed().pipe(takeUntilDestroyed(this.destroy)).subscribe(ok=>{if(ok)this.run(this.api.state(product,kind,row),()=>kind==='producto'?this.reload():this.refreshDetails());});}
}


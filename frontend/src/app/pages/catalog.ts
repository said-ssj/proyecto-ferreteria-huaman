import {Component,computed,effect,inject,signal} from '@angular/core';
import {ActivatedRoute,Router,RouterLink} from '@angular/router';
import {toSignal} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatSelectModule} from '@angular/material/select';
import {MatCheckboxModule} from '@angular/material/checkbox';
import {MatTabsModule} from '@angular/material/tabs';
import {MatDialog} from '@angular/material/dialog';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {CatalogService,Category,Unit} from '../core/catalog.service';
import {EmptyState} from '../shared/empty-state';
import {Icon} from '../shared/icon';
import {Confirm} from '../shared/confirm';
@Component({selector:'app-catalog',imports:[RouterLink,ReactiveFormsModule,MatButtonModule,MatFormFieldModule,MatInputModule,MatSelectModule,MatCheckboxModule,MatTabsModule,EmptyState,Icon],templateUrl:'./catalog.html'})
export class Catalog {
 readonly auth=inject(AuthService);private readonly api=inject(CatalogService);private readonly route=inject(ActivatedRoute);private readonly router=inject(Router);private readonly dialog=inject(MatDialog);
 private readonly data=toSignal(this.route.data);private readonly params=toSignal(this.route.paramMap);
 readonly mode=computed(()=>this.data()?.['catalogMode']||'list');readonly selectedTab=signal(this.route.snapshot.queryParamMap.get('vista')==='unidades'?1:0);
 readonly isUnit=computed(()=>this.mode()==='unit-form'||(this.mode()==='list'&&this.selectedTab()===1));
 readonly isForm=computed(()=>this.mode()!=='list');readonly editId=computed(()=>this.params()?.get('id')?Number(this.params()!.get('id')):null);
 readonly title=computed(()=>!this.isForm()?'Categorías y unidades':(this.editId()?'Editar ':'Nueva ')+(this.isUnit()?'unidad de medida':'categoría'));
 readonly editable=computed(()=>this.auth.has(this.isUnit()?'UNI.GESTIONAR':'CAT.GESTIONAR'));
 readonly rows=signal<(Category|Unit)[]>([]);readonly total=signal(0);readonly page=signal(0);readonly applied=signal({buscar:'',estado:''});
 readonly loading=signal(false);readonly saving=signal(false);readonly error=signal('');readonly message=signal('');readonly version=signal<string|null>(null);readonly loaded=signal(false);
 readonly filters=new FormGroup({buscar:new FormControl('',{nonNullable:true}),estado:new FormControl('',{nonNullable:true})});
 readonly categoryForm=new FormGroup({nombre:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(60)]}),descripcion:new FormControl('',{nonNullable:true,validators:[Validators.maxLength(200)]})});
 readonly unitForm=new FormGroup({nombre:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(40)]}),abreviatura:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(8)]}),codigoSunat:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.pattern('[A-Z0-9]{2,3}')]}),descripcionComercial:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(80)]}),magnitud:new FormControl('',{nonNullable:true,validators:[Validators.required]}),factorReferencia:new FormControl<number|string>('',{nonNullable:true,validators:[Validators.required,Validators.min(0.000001),Validators.pattern(/^[0-9]{1,12}(?:\.[0-9]{1,6})?$/)]}),precisionCantidad:new FormControl<number|string>('',{nonNullable:true,validators:[Validators.required,Validators.min(0),Validators.max(6),Validators.pattern('[0-6]')]}),admiteDecimales:new FormControl(false,{nonNullable:true})});
 readonly attempted=signal(false);
 get form():FormGroup{return this.isUnit()?this.unitForm:this.categoryForm;}
 get decimalConflict(){const value=this.unitForm.getRawValue();return this.isUnit()&&this.unitForm.controls.precisionCantidad.valid&&value.admiteDecimales!==(Number(value.precisionCantidad)>0);}
 get formIssues():string[]{
  const labels:Record<string,string>={nombre:'Nombre',abreviatura:'Símbolo o abreviatura',codigoSunat:'Código SUNAT',descripcionComercial:'Descripción comercial',magnitud:'Magnitud',factorReferencia:'Factor respecto a la unidad de referencia',precisionCantidad:'Decimales permitidos',descripcion:'Descripción'};
  return Object.entries(this.form.controls).filter(([,control])=>control.invalid).map(([key,control])=>control.hasError('required')?'Completa «'+labels[key]+'».':'Revisa «'+labels[key]+'».');
 }
 constructor(){effect(cleanup=>{
  const unit=this.isUnit(),mode=this.mode(),id=this.editId(),page=this.page(),filter=this.applied();
  this.error.set('');this.loaded.set(false);this.attempted.set(false);
  if(mode!=='list'){
   this.categoryForm.reset();this.unitForm.reset();this.version.set(null);
   if(!id){this.loaded.set(true);return;}
   this.loading.set(true);const request=this.api.get(unit,id).pipe(finalize(()=>this.loading.set(false))).subscribe({next:row=>{this.version.set(row.version);this.form.patchValue(row);this.loaded.set(true);},error:error=>this.error.set(authError(error))});cleanup(()=>request.unsubscribe());
  }else{
   this.loading.set(true);const request=this.api.list(unit,filter.buscar,filter.estado,page).pipe(finalize(()=>this.loading.set(false))).subscribe({next:result=>{this.rows.set(result.items);this.total.set(result.total);this.loaded.set(true);},error:error=>{this.rows.set([]);this.error.set(authError(error));}});cleanup(()=>request.unsubscribe());
  }
 });}
 selectTab(index:number){this.page.set(0);this.selectedTab.set(index);this.filters.reset();this.applied.set({buscar:'',estado:''});this.message.set('');}
 apply(){this.page.set(0);this.applied.set(this.filters.getRawValue());}
 clear(){this.filters.reset();this.apply();}
 reload(){this.applied.update(value=>({...value}));}
 magnitude(code:string){return ({CONTEO:'Cantidad',PESO:'Peso',LONGITUD:'Longitud',VOLUMEN:'Volumen'} as Record<string,string>)[code]||code;}
 asUnit(row:Category|Unit){return row as Unit;}
 save(){
  if(this.saving()||!this.editable()||!this.loaded())return;
  this.attempted.set(true);this.form.markAllAsTouched();this.error.set('');
  if(this.form.invalid||this.decimalConflict)return;
  const value=this.form.getRawValue();
  if(!value.nombre.trim()){this.error.set('Escribe un nombre válido');return;}
  if(this.isUnit()&&value.admiteDecimales!==(Number(value.precisionCantidad)>0)){this.error.set('La precisión debe ser mayor que cero cuando la unidad admite decimales');return;}
  this.saving.set(true);this.error.set('');this.api.save(this.isUnit(),this.editId(),{...value,version:this.version()}).pipe(finalize(()=>this.saving.set(false))).subscribe({next:()=>void this.router.navigate(['/categorias'],{queryParams:{vista:this.isUnit()?'unidades':'categorias'}}),error:error=>this.error.set(authError(error))});
 }
 edit(row:Category){void this.router.navigate([this.isUnit()?'/categorias/unidades/editar':'/categorias/editar',row.id]);}
 changeState(row:Category){if(!this.editable()||this.saving())return;const state=row.estado==='A'?'I':'A';const action=state==='I'?'Desactivar':'Activar';const unit=this.isUnit();
  this.dialog.open(Confirm,{width:'460px',maxWidth:'calc(100vw - 32px)',data:{title:action+' registro',message:action+' «'+row.nombre+'»'+(state==='I'?' impedirá seleccionarlo en nuevas operaciones.':'.'),action}}).afterClosed().subscribe(confirmed=>{
   if(!confirmed)return;this.saving.set(true);this.error.set('');this.api.state(unit,row,state).pipe(finalize(()=>this.saving.set(false))).subscribe({next:()=>{this.message.set('Estado actualizado correctamente');this.reload();},error:error=>this.error.set(authError(error))});
  });
 }
}

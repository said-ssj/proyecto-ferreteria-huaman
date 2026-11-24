import {Component,computed,effect,inject,signal,DestroyRef} from '@angular/core';
import {ActivatedRoute,Router,RouterLink} from '@angular/router';
import {takeUntilDestroyed,toSignal} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatSelectModule} from '@angular/material/select';
import {MatDialog} from '@angular/material/dialog';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {UserAdminService,ManagedUser,ManagedRole} from '../core/user-admin.service';
import {EmptyState} from '../shared/empty-state';
import {Confirm} from '../shared/confirm';
import {Modal} from '../shared/modal';
@Component({selector:'app-users',imports:[RouterLink,ReactiveFormsModule,MatButtonModule,MatFormFieldModule,MatInputModule,MatSelectModule,EmptyState,Modal],templateUrl:'./users.html',styles:[
'.password-overlay{position:fixed;inset:0;z-index:1000;padding:16px;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center}.password-dialog{width:100%;max-width:520px;max-height:90vh;overflow:auto;border:1px solid var(--control);border-radius:4px;padding:24px;background:var(--surface)}.password-dialog mat-form-field{width:100%}.role-selector{width:100%;max-width:420px}.user-notes{color:var(--muted)}'
]})
export class Users{
 readonly auth=inject(AuthService);private readonly api=inject(UserAdminService);private readonly route=inject(ActivatedRoute);private readonly router=inject(Router);private readonly dialog=inject(MatDialog);private readonly destroy=inject(DestroyRef);
 private readonly data=toSignal(this.route.data);private readonly params=toSignal(this.route.paramMap);
 readonly roleView=computed(()=>this.data()?.['page']?.path==='roles');readonly isForm=computed(()=>this.data()?.['userForm']===true);readonly id=computed(()=>Number(this.params()?.get('id'))||null);
 readonly roles=signal<ManagedRole[]>([]);readonly selectedRole=signal<number|null>(null);readonly role=computed(()=>this.roles().find(r=>r.id===this.selectedRole()));
 readonly rows=signal<ManagedUser[]>([]);readonly page=signal(0);readonly total=signal(0);readonly loading=signal(false);readonly loaded=signal(false);readonly rolesLoaded=signal(false);readonly saving=signal(false);readonly error=signal('');readonly message=signal('');readonly attempted=signal(false);readonly resetting=signal<ManagedUser|null>(null);
 readonly filters=new FormGroup({buscar:new FormControl('',{nonNullable:true}),estado:new FormControl('',{nonNullable:true})});readonly applied=signal({buscar:'',estado:''});
 readonly form=new FormGroup({usuario:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.pattern('[A-Za-z0-9._-]{4,30}')]}),nombres:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(100),Validators.pattern(/.*\S.*/)]}),apellidos:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(100),Validators.pattern(/.*\S.*/)]}),dni:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.pattern('(?!00000000)[0-9]{8}')]}),telefono:new FormControl('',{nonNullable:true,validators:[Validators.maxLength(20)]}),correo:new FormControl('',{nonNullable:true,validators:[Validators.email,Validators.maxLength(100)]}),rolId:new FormControl<number|null>(null,{validators:[Validators.required]}),claveTemporal:new FormControl('',{nonNullable:true}),confirmacion:new FormControl('',{nonNullable:true})});
 readonly passwordForm=new FormGroup({claveTemporal:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.minLength(8),Validators.maxLength(72)]}),confirmacion:new FormControl('',{nonNullable:true,validators:[Validators.required]})});
 get passwordMismatch(){return this.form.controls.claveTemporal.value!==this.form.controls.confirmacion.value;}
 private version:string|null=null;
 constructor(){
  effect(cleanup=>{const options=!this.roleView();this.rolesLoaded.set(false);const sub=this.api.roles(options).subscribe({next:r=>{this.roles.set(r);this.selectedRole.set(r[0]?.id??null);this.rolesLoaded.set(true);},error:e=>this.error.set(authError(e))});cleanup(()=>sub.unsubscribe());});
  effect(cleanup=>{const form=this.isForm(),id=this.id(),filter=this.applied(),page=this.page();if(this.roleView())return;this.error.set('');this.loaded.set(false);this.attempted.set(false);if(form){this.form.reset();this.version=null;for(const key of ['claveTemporal','confirmacion'] as const){this.form.controls[key].setValidators(!id?[Validators.required,Validators.minLength(8),Validators.maxLength(72)]:[]);this.form.controls[key].updateValueAndValidity();}if(!id){this.loaded.set(true);return;}this.loading.set(true);const sub=this.api.user(id).pipe(finalize(()=>this.loading.set(false))).subscribe({next:r=>{this.form.patchValue({...r,telefono:r.telefono||'',correo:r.correo||''});this.version=r.version;this.loaded.set(true);},error:e=>this.error.set(authError(e))});cleanup(()=>sub.unsubscribe());}else{this.loading.set(true);const sub=this.api.list(filter.buscar,filter.estado,page).pipe(finalize(()=>this.loading.set(false))).subscribe({next:r=>{this.rows.set(r.items);this.total.set(r.total);this.loaded.set(true);},error:e=>{this.rows.set([]);this.error.set(authError(e));}});cleanup(()=>sub.unsubscribe());}});
 }
 apply(){this.page.set(0);this.applied.set(this.filters.getRawValue());}clear(){this.filters.reset();this.apply();}reload(){this.applied.update(v=>({...v}));}
 save(){if(this.saving()||!this.loaded()||!this.rolesLoaded())return;this.attempted.set(true);this.form.markAllAsTouched();if(this.form.invalid||(!this.id()&&this.passwordMismatch))return;const {confirmacion,...value}=this.form.getRawValue();this.saving.set(true);this.error.set('');this.api.save(this.id(),{...value,claveTemporal:this.id()?null:value.claveTemporal,version:this.version}).pipe(takeUntilDestroyed(this.destroy),finalize(()=>{this.saving.set(false);this.form.controls.claveTemporal.reset();this.form.controls.confirmacion.reset();})).subscribe({next:()=>void this.router.navigate(['/usuarios']),error:e=>this.error.set(authError(e))});}
 state(row:ManagedUser){if(this.saving()||row.id===this.auth.user()?.id)return;this.dialog.open(Confirm,{width:'460px',maxWidth:'calc(100vw - 32px)',data:{title:row.estado==='A'?'Desactivar usuario':'Activar usuario',message:row.estado==='A'?'Se impedirá el ingreso y se cerrarán las sesiones de '+row.usuario+'.':'Se habilitará el ingreso de '+row.usuario+'.',action:'Confirmar'}}).afterClosed().pipe(takeUntilDestroyed(this.destroy)).subscribe(ok=>{if(!ok||this.saving())return;this.saving.set(true);this.error.set('');this.api.state(row).pipe(takeUntilDestroyed(this.destroy),finalize(()=>this.saving.set(false))).subscribe({next:()=>{this.message.set('Estado actualizado.');this.reload();},error:e=>this.error.set(authError(e))});});}
 openReset(row:ManagedUser){this.passwordForm.reset();this.error.set('');this.resetting.set(row);}
 closeReset(){if(this.saving())return;this.passwordForm.reset();this.resetting.set(null);}
 resetPassword(){const row=this.resetting();if(!row||this.saving())return;this.passwordForm.markAllAsTouched();const value=this.passwordForm.getRawValue();if(this.passwordForm.invalid||value.claveTemporal!==value.confirmacion)return;this.saving.set(true);this.error.set('');this.api.reset(row,value.claveTemporal).pipe(takeUntilDestroyed(this.destroy),finalize(()=>{this.saving.set(false);this.passwordForm.reset();})).subscribe({next:()=>{this.resetting.set(null);this.message.set('Contraseña restablecida. La persona deberá cambiarla al ingresar.');this.reload();},error:e=>this.error.set(authError(e))});}
}

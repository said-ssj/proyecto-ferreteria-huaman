import {Component,inject,signal} from '@angular/core';
import {ReactiveFormsModule,FormControl,FormGroup,Validators} from '@angular/forms';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatButtonModule} from '@angular/material/button';
import {finalize,switchMap} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {Icon} from '../shared/icon';
@Component({selector:'app-profile',imports:[ReactiveFormsModule,MatFormFieldModule,MatInputModule,MatButtonModule,Icon],template:`
<div class="page-heading"><div><p class="eyebrow">Cuenta</p><h1>Mi perfil</h1><p>Datos de tu cuenta y seguridad.</p></div></div>
@if(auth.user();as user){<section class="panel"><h2>Datos personales</h2><dl class="profile-data"><div><dt>Usuario</dt><dd>{{user.usuario}}</dd></div><div><dt>Nombres</dt><dd>{{user.nombres}}</dd></div><div><dt>Apellidos</dt><dd>{{user.apellidos}}</dd></div><div><dt>Rol</dt><dd>{{auth.roleName()}}</dd></div></dl></section>}
@if(auth.user()?.cambioClaveObligatorio){<p class="notice warning" role="alert">Debes cambiar tu contraseña antes de continuar.</p>}
@if(auth.has('SEG.PERFIL')){<section class="panel"><h2>Cambiar contraseña</h2>
@if(error()){<p class="notice danger" role="alert">{{error()}}</p>}@if(success()){<p class="notice success" role="status">{{success()}}</p>}
<form [formGroup]="form" (ngSubmit)="submit()" [attr.aria-busy]="busy()"><div class="form-grid">
@for(field of passwordFields;track field.key){<mat-form-field appearance="outline"><mat-label>{{field.label}}</mat-label><input matInput [formControlName]="field.key" [type]="visible()?'text':'password'" [autocomplete]="field.key==='actual'?'current-password':'new-password'" maxlength="72" required></mat-form-field>}
</div><p class="field-note">Mínimo 8 caracteres con letras y números. Debe ser distinta de tu usuario y contraseña actual.</p><div class="related-links"><button mat-stroked-button type="button" (click)="visible.set(!visible())"><app-icon [name]="visible()?'visibility_off':'visibility'"/>{{visible()?'Ocultar contraseñas':'Mostrar contraseñas'}}</button><button mat-flat-button [disabled]="form.invalid||busy()">{{busy()?'Guardando…':'Cambiar contraseña'}}</button></div></form></section>}
`})
export class Profile {
 readonly auth=inject(AuthService);readonly busy=signal(false);readonly visible=signal(false);readonly error=signal('');readonly success=signal('');
 readonly passwordFields=[{key:'actual',label:'Contraseña actual'},{key:'nueva',label:'Nueva contraseña'},{key:'confirmacion',label:'Confirmar nueva contraseña'}];
 readonly form=new FormGroup({actual:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(72)]}),nueva:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.minLength(8),Validators.maxLength(72),Validators.pattern(/^(?=.*\p{L})(?=.*\p{N}).+$/u)]}),confirmacion:new FormControl('',{nonNullable:true,validators:[Validators.required]})},{validators:control=>control.get('nueva')?.value===control.get('confirmacion')?.value?null:{confirmacion:true}});
 submit(){if(this.form.invalid||this.busy())return;this.busy.set(true);this.error.set('');this.success.set('');const value=this.form.getRawValue();
 this.auth.changePassword(value.actual,value.nueva,value.confirmacion).pipe(switchMap(()=>this.auth.refresh()),finalize(()=>this.busy.set(false))).subscribe({next:()=>{this.form.reset();this.success.set('Contraseña actualizada correctamente. Las otras sesiones se cerraron.');},error:error=>this.error.set(authError(error))});
 }
}

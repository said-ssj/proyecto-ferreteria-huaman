import {Component,inject,signal} from '@angular/core';
import {ReactiveFormsModule,FormControl,FormGroup,Validators} from '@angular/forms';
import {ActivatedRoute,Router} from '@angular/router';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {Icon} from '../shared/icon';
@Component({selector:'app-login',imports:[ReactiveFormsModule,MatButtonModule,MatFormFieldModule,MatInputModule,Icon],template:`
<main class="login-page"><section class="panel login-panel"><div class="brand"><span class="brand-mark">H</span><span>Ferretería<strong>Huamán</strong></span></div><h1>Iniciar sesión</h1><p>Ingresa con tu cuenta de trabajo.</p>
@if(auth.message()){<p class="notice info" role="status">{{auth.message()}}</p>}
@if(error()){<p class="notice danger" role="alert">{{error()}}</p>}
<form [formGroup]="form" (ngSubmit)="submit()" [attr.aria-busy]="busy()">
<mat-form-field appearance="outline"><mat-label>Usuario</mat-label><input matInput formControlName="usuario" autocomplete="username" maxlength="30" required><mat-error>Escribe un usuario de 4 a 30 caracteres, sin espacios.</mat-error></mat-form-field>
<mat-form-field appearance="outline"><mat-label>Contraseña</mat-label><input matInput formControlName="clave" [type]="visible()?'text':'password'" autocomplete="current-password" maxlength="72" required><button mat-icon-button matIconSuffix type="button" [attr.aria-label]="visible()?'Ocultar contraseña':'Mostrar contraseña'" [attr.aria-pressed]="visible()" (click)="visible.set(!visible())"><app-icon [name]="visible()?'visibility_off':'visibility'"/></button><mat-error>Escribe tu contraseña.</mat-error></mat-form-field>
<button mat-flat-button class="full-width" [disabled]="form.invalid||busy()">{{busy()?'Ingresando…':'Ingresar'}}</button>
<button mat-button type="button" class="full-width" (click)="help.set(!help())">¿Olvidaste tu contraseña?</button>
@if(help()){<p role="status">Pídele a la persona administradora que restablezca tu contraseña.</p>}</form></section></main>`})
export class Login {
 readonly auth=inject(AuthService);private readonly router=inject(Router);private readonly route=inject(ActivatedRoute);
 readonly busy=signal(false);readonly visible=signal(false);readonly error=signal('');readonly help=signal(false);
 readonly form=new FormGroup({usuario:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.pattern('[A-Za-z0-9._-]{4,30}')]}),clave:new FormControl('',{nonNullable:true,validators:[Validators.required,Validators.maxLength(72)]})});
 submit(){if(this.form.invalid||this.busy())return;this.busy.set(true);this.error.set('');const {usuario,clave}=this.form.getRawValue();
 this.auth.login(usuario,clave).pipe(finalize(()=>this.busy.set(false))).subscribe({next:()=>{
  this.form.controls.clave.reset();const back=this.route.snapshot.queryParamMap.get('volver')||'/inicio';
  void this.router.navigateByUrl(this.auth.user()?.cambioClaveObligatorio?'/perfil':back.startsWith('/')&&!back.startsWith('//')&&!back.includes(':')&&!back.startsWith('/iniciar-sesion')?back:'/inicio',{replaceUrl:true});
 },error:error=>{this.form.controls.clave.reset();this.error.set(authError(error));}});
 }
}

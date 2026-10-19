import {CdkTrapFocus} from '@angular/cdk/a11y';
import {DOCUMENT} from '@angular/common';
import {Component,computed,signal,inject,Injector,afterNextRender} from '@angular/core';
import {RouterLink,RouterLinkActive,RouterOutlet} from '@angular/router';
import {MatButtonModule} from '@angular/material/button';
import {Icon} from '../shared/icon';
import {AuthService} from '../core/auth.service';
import {NAV_GROUPS} from '../core/screens';
import {ThemeService,THEMES} from '../core/theme.service';
@Component({selector:'app-shell',host:{'(document:pointerdown)':'auth.activity()', '(document:keydown)':'auth.activity()', '(window:resize)':'updateViewport()', '(document:keydown.escape)':'closeMenu()'},imports:[CdkTrapFocus,RouterLink,RouterLinkActive,RouterOutlet,MatButtonModule,Icon],template:`
<a class="skip-link" href="#content">Saltar al contenido</a>
@if(menuOpen()){<button class="scrim" aria-label="Cerrar menú" (click)="closeMenu()"></button>}
<aside [cdkTrapFocus]="mobile()&&menuOpen()" [cdkTrapFocusAutoCapture]="mobile()&&menuOpen()" [attr.role]="mobile()&&menuOpen()?'dialog':null" [attr.aria-modal]="mobile()&&menuOpen()?true:null" aria-label="Navegación principal" id="navigation-panel" class="sidebar" [class.is-open]="menuOpen()" [attr.inert]="mobile()&&!menuOpen()?'':null" [attr.aria-hidden]="mobile()&&!menuOpen()?true:null"><button mat-stroked-button class="close-menu" (click)="closeMenu()"><app-icon name="close"/>Cerrar menú</button><a class="brand" routerLink="/inicio"><span class="brand-mark">H</span><span>Ferretería<strong>Huamán</strong></span></a>
<nav aria-label="Menú principal">@for(group of groups();track group.label){<div class="nav-group"><p>{{group.label}}</p>@for(page of group.pages;track page.path){<a [routerLink]="'/'+page.path" routerLinkActive="active" ariaCurrentWhenActive="page" [routerLinkActiveOptions]="{exact:true}" (click)="closeMenu(true)"><app-icon [name]="page.icon"/><span>{{page.title}}</span></a>}</div>}</nav>
<button class="session-link logout-button" type="button" [disabled]="auth.busy()" (click)="auth.logout()"><app-icon name="logout"/>Cerrar sesión</button></aside>
<div class="workspace" [attr.inert]="mobile()&&menuOpen()?'':null"><header class="topbar"><button mat-icon-button class="menu-toggle" aria-label="Abrir menú" aria-controls="navigation-panel" [attr.aria-expanded]="menuOpen()" (click)="menuOpen.set(!menuOpen())"><app-icon name="menu"/></button><span class="topbar-title">{{auth.user()?.usuario}} · {{auth.roleName()}}</span><div class="topbar-actions"><a mat-stroked-button routerLink="/preferencias" [attr.aria-label]="'Cambiar apariencia. Tema actual: '+themeName()" class="theme-access"><app-icon name="contrast"/><span>{{themeName()}}</span></a><a mat-icon-button routerLink="/perfil" aria-label="Mi perfil"><app-icon name="account_circle"/></a></div></header>
@if(auth.warning()){<div class="session-warning notice warning" role="alert"><span>Tu sesión está por vencer.</span><button mat-stroked-button (click)="auth.continue()">Seguir conectado</button><button mat-button (click)="auth.logout()">Cerrar sesión</button></div>}@if(auth.message()){<p class="notice info" role="status">{{auth.message()}}</p>}<main id="content" tabindex="-1"><router-outlet/></main><footer class="page-footer">Ferretería Huamán · Ventas e inventario</footer></div>`})
export class Shell {
 private readonly injector=inject(Injector);
 closeMenu(toContent=false){
   if(!this.menuOpen()) return;
   this.menuOpen.set(false);
   afterNextRender(()=>this.document.querySelector<HTMLElement>(toContent?'#content':'.menu-toggle')?.focus(),{injector:this.injector});
 }
private readonly document=inject(DOCUMENT);readonly mobile=signal((this.document.defaultView?.innerWidth??1280)<=1000);updateViewport(){this.mobile.set((this.document.defaultView?.innerWidth??1280)<=1000);}readonly auth=inject(AuthService);readonly groups=computed(()=>NAV_GROUPS.map(g=>({...g,pages:g.pages.filter(p=>this.auth.can(p.path))})).filter(g=>g.pages.length));readonly menuOpen=signal(false);readonly theme=inject(ThemeService);readonly themeName=computed(()=>THEMES.find(t=>t.id===this.theme.current())!.name);}

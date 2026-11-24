import {Component,inject} from '@angular/core';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatSelectModule} from '@angular/material/select';
import {MatButtonModule} from '@angular/material/button';
import {DisplayPreferences} from '../core/display-preferences';
import {ProductViewOptions} from './product-view-options';
@Component({selector:'app-display-settings',imports:[MatFormFieldModule,MatSelectModule,MatButtonModule,ProductViewOptions],template:`<section class="panel"><h2>Tamaño y visualización</h2><p>Estas preferencias se guardan en este navegador. El tamaño de impresión de tickets y etiquetas se conserva.</p><div class="form-actions"><mat-form-field appearance="outline"><mat-label>Tamaño de la interfaz</mat-label><mat-select [value]="display.scale()" (selectionChange)="display.setScale($event.value)"><mat-option [value]="100">100 % · Normal</mat-option><mat-option [value]="95">95 % · Un poco más pequeño</mat-option><mat-option [value]="90">90 % · Más espacio</mat-option></mat-select></mat-form-field><button mat-stroked-button type="button" [disabled]="display.scale()===100" (click)="display.setScale(100)">Restablecer tamaño</button></div><app-product-view-options/><p>Se aplica al catálogo, al punto de venta y a la selección de productos. Puedes cambiarlo también desde esas pantallas.</p></section>`})
export class DisplaySettings {readonly display=inject(DisplayPreferences);}

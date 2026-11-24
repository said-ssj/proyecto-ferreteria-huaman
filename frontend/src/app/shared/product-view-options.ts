import {Component,inject} from '@angular/core';
import {MatButtonModule} from '@angular/material/button';
import {DisplayPreferences} from '../core/display-preferences';
@Component({selector:'app-product-view-options',imports:[MatButtonModule],template:`<div class="product-view-options" role="group" aria-label="Contenido de los productos"><span>Mostrar productos:</span><button mat-stroked-button type="button" [attr.aria-pressed]="!display.photos()" (click)="display.setPhotos(false)">Solo texto</button><button mat-stroked-button type="button" [attr.aria-pressed]="display.photos()" (click)="display.setPhotos(true)">Texto e imagen</button></div>`})
export class ProductViewOptions {readonly display=inject(DisplayPreferences);}

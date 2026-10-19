import {Component,inject} from '@angular/core';
import {MAT_DIALOG_DATA,MatDialogModule} from '@angular/material/dialog';
import {MatButtonModule} from '@angular/material/button';
@Component({selector:'app-confirm',imports:[MatDialogModule,MatButtonModule],template:`<h2 mat-dialog-title>{{data.title}}</h2><mat-dialog-content><p>{{data.message}}</p></mat-dialog-content><mat-dialog-actions align="end"><button mat-stroked-button [mat-dialog-close]="false" cdkFocusInitial>Cancelar</button><button mat-flat-button [mat-dialog-close]="true">{{data.action}}</button></mat-dialog-actions>`})
export class Confirm {readonly data=inject<{title:string;message:string;action:string}>(MAT_DIALOG_DATA);}

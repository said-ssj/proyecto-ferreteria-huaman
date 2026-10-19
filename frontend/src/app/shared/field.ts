import {Component,input,viewChild} from '@angular/core';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule,MatInput} from '@angular/material/input';
import {MatSelectModule,MatSelect} from '@angular/material/select';
import {MatDatepickerModule,MatDatepickerIntl,MatDatepickerInput} from '@angular/material/datepicker';
import {provideNativeDateAdapter} from '@angular/material/core';
import {Field as FieldDefinition} from '../core/screens';
@Component({selector:'app-field',imports:[MatFormFieldModule,MatInputModule,MatSelectModule,MatDatepickerModule],providers:[provideNativeDateAdapter(),{provide:MatDatepickerIntl,useFactory:()=>{
      const labels=new MatDatepickerIntl();
      labels.openCalendarLabel='Abrir calendario';labels.closeCalendarLabel='Cerrar calendario';
      labels.prevMonthLabel='Mes anterior';labels.nextMonthLabel='Mes siguiente';
      labels.prevYearLabel='Año anterior';labels.nextYearLabel='Año siguiente';
      labels.prevMultiYearLabel='Período anterior';labels.nextMultiYearLabel='Período siguiente';
      labels.switchToMonthViewLabel='Elegir fecha';labels.switchToMultiYearViewLabel='Elegir mes y año';
      return labels;
    }}],template:`
<mat-form-field appearance="outline"><mat-label>{{field().label}}</mat-label>
@switch(field().type){
@case('select'){<mat-select [required]="!!field().required" [disabled]="!field().options?.length">@for(option of field().options;track option){<mat-option [value]="option">{{option}}</mat-option>}</mat-select>}
@case('textarea'){<textarea matInput rows="3" [required]="!!field().required"></textarea>}
@case('date'){<input matInput [matDatepicker]="picker">}
@default{<input matInput [type]="field().type || 'text'" [required]="!!field().required" [attr.step]="field().type==='number'?'any':null" [attr.inputmode]="field().type==='number'?'decimal':null" [attr.min]="field().type==='number'?0:null">}}
@if(field().type === 'date'){<mat-datepicker-toggle matIconSuffix [for]="picker"/>}<mat-datepicker #picker/>@if(field().hint){<mat-hint>{{field().hint}}</mat-hint>}</mat-form-field>`})
export class Field {
 readonly field=input.required<FieldDefinition>();
 readonly select=viewChild(MatSelect);readonly input=viewChild(MatInput);readonly date=viewChild(MatDatepickerInput);
 reset(){const select=this.select();const input=this.input();const date=this.date();if(select)select.value=undefined;if(date)date.value=null;if(input)input.value='';}
}


import {Component,computed,input} from '@angular/core';import {DecimalPipe} from '@angular/common';import {ReportRow} from '../core/report.service';
@Component({selector:'app-report-chart',imports:[DecimalPipe],templateUrl:'./report-chart.html',styleUrl:'./report-chart.css'})
export class ReportChart{
 readonly rows=input.required<ReportRow[]>();readonly max=computed(()=>Math.max(1,...this.rows().flatMap(r=>[Number(r['neto']),Number(r['margen'])])));readonly min=computed(()=>Math.min(0,...this.rows().flatMap(r=>[Number(r['neto']),Number(r['margen'])])));
 y(value:number){return 210-(value-this.min())/(this.max()-this.min())*190;}
 zero(){return this.y(0);}points(key:string){return this.rows().map((r,i)=>(60+i*640/Math.max(1,this.rows().length-1))+','+this.y(Number(r[key]))).join(' ');}
}

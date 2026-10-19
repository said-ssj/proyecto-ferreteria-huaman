import {Component,input} from '@angular/core';import {DatePipe} from '@angular/common';import {SaleDetails} from '../core/sale.service';
@Component({selector:'app-sale-receipt',imports:[DatePipe],templateUrl:'./sale-receipt.html',styleUrl:'./sale-receipt.css'})
export class SaleReceipt {readonly detail=input.required<SaleDetails>();type(t:string){return ({B:'Boleta',F:'Factura',N:'Nota de venta'} as Record<string,string>)[t]||t;}paymentName(t:string){return ({EFECTIVO:'Efectivo',YAPE:'Yape',DEBITO:'Tarjeta de débito',CREDITO:'Fiado'} as Record<string,string>)[t]||t;}}

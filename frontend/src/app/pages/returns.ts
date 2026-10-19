import {Modal} from '../shared/modal';
import {Component,DestroyRef,computed,effect,inject,signal} from '@angular/core';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {ActivatedRoute,Router} from '@angular/router';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {
  ApproveRequest,
  CashOption,
  RejectRequest,
  ReturnDetail,
  ReturnItemRequest,
  ReturnRow,
  ReturnService,
  ReturnSummary,
  SaleDetailLookup,
  SaleLookup,
  SaleItemLookup,
  SolicitRequest
} from '../core/return.service';
import {EmptyState} from '../shared/empty-state';
import {Icon} from '../shared/icon';

@Component({
  selector: 'app-returns',
  imports: [
    Modal,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    EmptyState,
    Icon
  ],
  templateUrl: './returns.html',
  styleUrl: './returns.css'
})
export class Returns {
  readonly auth = inject(AuthService);
  private readonly api = inject(ReturnService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly destroy = inject(DestroyRef);

  readonly isAdmin = computed(() => this.auth.user()?.rol === 'ADM');
  readonly canDevolver = computed(() => this.auth.has('VEN.DEVOLVER'));

  readonly mode = signal<'list' | 'new'>('list');

  // Summary
  readonly summary = signal<ReturnSummary>({
    pendientes: 0,
    aprobadasHoy: 0,
    montoReintegradoHoy: '0.00'
  });

  // List view state
  readonly activeTab = signal<'TODAS' | 'PENDIENTE' | 'APROBADA' | 'RECHAZADA'>('TODAS');
  readonly rows = signal<ReturnRow[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly pageSize = signal(20);
  readonly loading = signal(false);
  readonly busy = signal(false);
  readonly pending = signal<{kind:'approve'|'reject'|'new'; id:number; body:ApproveRequest|RejectRequest|SolicitRequest} | null>(null);
  readonly error = signal('');
  readonly success = signal('');

  // Modals state
  readonly detailModal = signal<ReturnDetail | null>(null);
  readonly approveTarget = signal<ReturnRow | null>(null);
  readonly rejectTarget = signal<ReturnRow | null>(null);

  // New return state (P27)
  readonly searchingSales = signal(false);
  readonly foundSales = signal<SaleLookup[]>([]);
  readonly selectedSale = signal<SaleDetailLookup | null>(null);
  readonly lineQuantities = signal<Record<number, number>>({});
  readonly returnUnits = signal<Record<number, {condicion:'ENVASE'|'SUELTO'|'TRAMO';cantidad:string;presentacionId:number|null}[]>>({});
  readonly lineConditions = signal<Record<number, 'APTO' | 'DANADO'>>({});
  readonly todayCash = signal<CashOption | null>(null);

  // Filter form controls
  readonly searchControl = new FormControl('', {nonNullable: true});
  readonly desdeControl = new FormControl('', {nonNullable: true});
  readonly hastaControl = new FormControl('', {nonNullable: true});

  // Sale search control
  readonly saleSearchControl = new FormControl('', {nonNullable: true});

  // New return form
  readonly newReturnForm = new FormGroup({
    motivo: new FormControl('', [Validators.required, Validators.minLength(10), Validators.maxLength(200)]),
    forma: new FormControl<'EFECTIVO' | 'YAPE' | 'DEBITO' | 'DESCUENTO_DEUDA'>('EFECTIVO', [Validators.required]),
    autoAprobar: new FormControl(true),
    referencia: new FormControl(''),
    observacion: new FormControl('')
  });

  // Approve form
  readonly approveForm = new FormGroup({
    referencia: new FormControl(''),
    observacion: new FormControl('')
  });

  // Reject form
  readonly rejectForm = new FormGroup({
    motivo: new FormControl('', [Validators.required, Validators.minLength(10), Validators.maxLength(200)])
  });

  readonly calculatedRefundTotal = computed(() => {
    const sale = this.selectedSale();
    if (!sale) return 0;
    const quantities = this.lineQuantities();
    let sum = 0;
    for (const item of sale.items) {
      const q = quantities[item.idDetalleVenta] || 0;
      if (q > 0) {
        sum += q * +item.precioUnitario;
      }
    }
    return Math.round(sum * 100) / 100;
  });

  constructor() {
    const routeMode = this.route.snapshot.data['returnMode'];
    if (routeMode === 'new') {
      this.mode.set('new');
    }

    this.fetchData();
    this.loadTodayCash();
  }

  setMode(m: 'list' | 'new'): void {
    if (this.pending() || this.busy()) return;
    this.mode.set(m);
    this.error.set('');
    this.success.set('');
    if (m === 'list') {
      this.fetchData();
    } else {
      this.loadTodayCash();
      if (this.foundSales().length === 0) {
        this.searchSales();
      }
    }
  }

  setTab(tab: 'TODAS' | 'PENDIENTE' | 'APROBADA' | 'RECHAZADA'): void {
    this.activeTab.set(tab);
    this.page.set(0);
    this.fetchData();
  }

  applyFilters(): void {
    this.page.set(0);
    this.fetchData();
  }

  clearFilters(): void {
    this.searchControl.setValue('');
    this.desdeControl.setValue('');
    this.hastaControl.setValue('');
    this.page.set(0);
    this.fetchData();
  }

  fetchData(): void {
    this.loading.set(true);
    this.error.set('');

    this.api.getSummary().pipe(
      takeUntilDestroyed(this.destroy)
    ).subscribe({
      next: s => this.summary.set(s),
      error: () => {}
    });

    const estadoParam = this.activeTab() === 'TODAS' ? '' : this.activeTab();
    this.api.getReturns({
      estado: estadoParam,
      buscar: this.searchControl.value.trim() || undefined,
      desde: this.desdeControl.value || undefined,
      hasta: this.hastaControl.value || undefined,
      pagina: this.page(),
      tamano: this.pageSize()
    }).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: res => {
        this.rows.set(res.items);
        this.total.set(res.total);
      },
      error: err => {
        this.error.set(authError(err));
      }
    });
  }

  loadTodayCash(): void {
    this.api.getTodayCash().pipe(
      takeUntilDestroyed(this.destroy)
    ).subscribe({
      next: c => this.todayCash.set(c),
      error: () => {}
    });
  }

  openDetail(id: number): void {
    this.api.getReturnDetail(id).pipe(
      takeUntilDestroyed(this.destroy)
    ).subscribe({
      next: d => this.detailModal.set(d),
      error: err => this.error.set(authError(err))
    });
  }

  openApprove(row: ReturnRow): void {
    if (this.pending() || this.busy()) return;
    this.approveTarget.set(row);
    this.approveForm.reset();
    this.loadTodayCash();
  }

  confirmApprove(): void {
    if (this.busy()) return;
    if (this.pending()) { this.retry(); return; }
    const target = this.approveTarget();
    if (!target) return;

    const cash = this.todayCash();
    if (!cash || cash.estadoCaja !== 'ABIERTA') {
      this.error.set('Se requiere una caja abierta para autorizar la devolución');
      return;
    }

    this.busy.set(true);
    this.error.set('');

    const payload: ApproveRequest = {
      cajaId: cash.idCaja,
      clave: crypto.randomUUID(),
      referencia: this.approveForm.get('referencia')?.value?.trim() || undefined,
      observacion: this.approveForm.get('observacion')?.value?.trim() || undefined
    };

    this.pending.set({kind:'approve',id:target.id,body:payload});
    this.approveForm.disable({emitEvent:false});
    this.busy.set(false);
    this.retry();
  }

  openReject(row: ReturnRow): void {
    if (this.pending() || this.busy()) return;
    this.rejectTarget.set(row);
    this.rejectForm.reset();
  }

  confirmReject(): void {
    if (this.busy()) return;
    if (this.pending()) { this.retry(); return; }
    const target = this.rejectTarget();
    if (!target) return;

    if (this.rejectForm.invalid) {
      this.error.set('Indique el motivo del rechazo (entre 10 y 200 caracteres)');
      return;
    }

    this.busy.set(true);
    this.error.set('');

    const payload: RejectRequest = {
      clave: crypto.randomUUID(),
      motivo: this.rejectForm.get('motivo')!.value!.trim()
    };

    this.pending.set({kind:'reject',id:target.id,body:payload});
    this.rejectForm.disable({emitEvent:false});
    this.busy.set(false);
    this.retry();
  }

  searchSales(): void {
    this.searchingSales.set(true);
    this.error.set('');
    this.api.searchSales(this.saleSearchControl.value.trim()).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.searchingSales.set(false))
    ).subscribe({
      next: list => this.foundSales.set(list),
      error: err => this.error.set(authError(err))
    });
  }

  selectSale(idVenta: number): void {
    if (this.pending() || this.busy()) return;
    this.loading.set(true);
    this.error.set('');
    this.api.getSaleDetail(idVenta).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: sale => {
        this.selectedSale.set(sale);
        this.returnUnits.set({});
        const qtys: Record<number, number> = {};
        const conds: Record<number, 'APTO' | 'DANADO'> = {};
        for (const it of sale.items) {
          qtys[it.idDetalleVenta] = 0;
          conds[it.idDetalleVenta] = 'APTO';
        }
        this.lineQuantities.set(qtys);
        this.lineConditions.set(conds);
      },
      error: err => this.error.set(authError(err))
    });
  }

  unselectSale(): void {
    if (this.pending() || this.busy()) return;
    this.selectedSale.set(null);
    this.lineQuantities.set({});
    this.returnUnits.set({});
    this.lineConditions.set({});
  }

  updateLineQuantity(idDetalleVenta: number, event: Event): void {
    if (this.pending() || this.busy()) return;
    const val = parseFloat((event.target as HTMLInputElement).value) || 0;
    const sale = this.selectedSale();
    if (!sale) return;

    const item = sale.items.find(i => i.idDetalleVenta === idDetalleVenta);
    const max = item ? +item.disponibleDevolver : 0;
    const cleanVal = Math.min(Math.max(0, val), max);

    this.lineQuantities.update(q => ({...q, [idDetalleVenta]: cleanVal}));
  }

  updateLineCondition(idDetalleVenta: number, event: Event): void {
    if (this.pending() || this.busy()) return;
    const val = (event.target as HTMLSelectElement).value as 'APTO' | 'DANADO';
    this.lineConditions.update(c => ({...c, [idDetalleVenta]: val}));
  }

  devolverTodo(): void {
    if (this.pending() || this.busy()) return;
    const sale = this.selectedSale();
    if (!sale) return;
    const qtys: Record<number, number> = {};
    for (const it of sale.items) {
      qtys[it.idDetalleVenta] = +it.disponibleDevolver;
    }
    this.lineQuantities.set(qtys);
  }

  submitNewReturn(): void {
    if (this.busy()) return;
    if (this.pending()) { this.retry(); return; }
    const sale = this.selectedSale();
    if (!sale) return;

    if (this.newReturnForm.invalid) {
      this.error.set('Complete todos los campos obligatorios del formulario.');
      return;
    }

    const lines: ReturnItemRequest[] = [];
    const quantities = this.lineQuantities();
    const conditions = this.lineConditions();

    for (const it of sale.items) {
      const q = quantities[it.idDetalleVenta] || 0;
      if (q > 0) {
        const estado = conditions[it.idDetalleVenta] || 'APTO';
        let unidades: NonNullable<ReturnItemRequest['unidades']> = [];
        const base = q * Number(it.factorBase);
        if (!Number.isFinite(q) || q > Number(it.disponibleDevolver) || !this.multiple(base,Number(it.incrementoBase))) {
          this.error.set('Revisa la cantidad y el incremento permitido de '+it.nombreProducto); return;
        }
        if (estado==='APTO' && it.modoControl!=='GRANEL') {
          const drafts = this.returnUnits()[it.idDetalleVenta] || [];
          if (!drafts.length || drafts.length>1000) { this.error.set('Detalla las unidades físicas que retornan de '+it.nombreProducto); return; }
          for (const unit of drafts) {
            const n=Number(unit.cantidad);
            if (!unit.cantidad.trim() || !/^\d{1,12}(?:\.\d{1,6})?$/.test(unit.cantidad) || !Number.isFinite(n) || n<=0 || !this.multiple(n,Number(it.incrementoBase))) {
              this.error.set('Cada unidad retornada requiere una cantidad válida en '+it.unidadBaseSimbolo); return;
            }
            if (unit.condicion==='ENVASE') {
              const pres=it.presentacionesRetorno?.find(p=>p.id===unit.presentacionId);
              if (!pres || Math.abs(Number(pres.factorBase)-n)>0.0000001) { this.error.set('Selecciona la presentación íntegra de cada envase.'); return; }
              unidades.push({condicion:'ENVASE',cantidad:n,id_presentacion:pres.id});
            } else unidades.push({condicion:it.modoControl==='TRAMOS'?'TRAMO':'SUELTO',cantidad:n});
          }
          if (Math.abs(unidades.reduce((sum,u)=>sum+u.cantidad,0)-base)>0.0000001) { this.error.set('La suma de las unidades retornadas debe ser '+base.toFixed(6)+' '+it.unidadBaseSimbolo); return; }
        }
        lines.push({idDetalleVenta:it.idDetalleVenta,cantidad:q,estadoProducto:estado,unidades});
      }
    }

    if (lines.length === 0) {
      this.error.set('Indique al menos un producto con cantidad a devolver mayor a cero.');
      return;
    }

    const autoAprobar = this.isAdmin() && !!this.newReturnForm.get('autoAprobar')?.value;
    const cash = this.todayCash();

    if (autoAprobar && (!cash || cash.estadoCaja !== 'ABIERTA')) {
      this.error.set('Abra la caja para autorizar el reintegro de inmediato.');
      return;
    }

    this.busy.set(true);
    this.error.set('');

    const payload: SolicitRequest = {
      ventaId: sale.venta.idVenta,
      forma: this.newReturnForm.get('forma')!.value!,
      motivo: this.newReturnForm.get('motivo')!.value!.trim(),
      lineas: lines,
      clave: crypto.randomUUID(),
      autoAprobar,
      cajaId: autoAprobar && cash ? cash.idCaja : undefined,
      referencia: this.newReturnForm.get('referencia')?.value?.trim() || undefined,
      observacion: this.newReturnForm.get('observacion')?.value?.trim() || undefined
    };

    this.pending.set({kind:'new',id:sale.venta.idVenta,body:payload});
    this.newReturnForm.disable({emitEvent:false});
    this.busy.set(false);
    this.retry();
  }

  private multiple(n:number,step:number):boolean {
    return step>0 && Math.abs(n/step-Math.round(n/step))<0.000001;
  }

  addReturnUnit(item:SaleItemLookup) {
    if (this.busy() || this.pending()) return;
    this.returnUnits.update(v=>({...v,[item.idDetalleVenta]:[...(v[item.idDetalleVenta]||[]),{condicion:item.modoControl==='TRAMOS'?'TRAMO':'SUELTO',cantidad:'',presentacionId:null}]}));
  }

  removeReturnUnit(id:number,index:number) {
    if (this.busy() || this.pending()) return;
    this.returnUnits.update(v=>({...v,[id]:(v[id]||[]).filter((_,i)=>i!==index)}));
  }

  updateReturnUnit(item:SaleItemLookup,index:number,key:'condicion'|'cantidad'|'presentacionId',event:Event) {
    if (this.busy() || this.pending()) return;
    const value=(event.target as HTMLInputElement).value;
    this.returnUnits.update(v=>({...v,[item.idDetalleVenta]:(v[item.idDetalleVenta]||[]).map((u,i)=>{
      if(i!==index) return u;
      const next={...u};
      if(key==='cantidad') next.cantidad=value;
      if(key==='condicion') { next.condicion=value as typeof u.condicion;next.presentacionId=null;next.cantidad=''; }
      if(key==='presentacionId') { next.presentacionId=Number(value)||null;next.cantidad=item.presentacionesRetorno?.find(p=>p.id===next.presentacionId)?.factorBase||''; }
      return next;
    })}));
  }

  retry(): void {
    const p=this.pending();
    if (!p || this.busy()) return;
    this.busy.set(true); this.error.set('');
    const call = p.kind==='approve' ? this.api.aprobarDevolucion(p.id,p.body as ApproveRequest)
      : p.kind==='reject' ? this.api.rechazarDevolucion(p.id,p.body as RejectRequest)
      : this.api.solicitarDevolucion(p.body as SolicitRequest);
    call.pipe(takeUntilDestroyed(this.destroy),finalize(()=>this.busy.set(false))).subscribe({
      next: res=>{
        this.pending.set(null); this.busy.set(false); this.enableForms();
        this.approveTarget.set(null); this.rejectTarget.set(null);
        if (p.kind==='new') { this.unselectSale(); this.mode.set('list'); }
        this.success.set('Devolución '+res.cabecera.codigo+': operación registrada correctamente.');
        this.fetchData();
      },
      error: e=>{
        if ([400,401,403,404,409].includes(e.status)) { this.pending.set(null); this.enableForms(); }
        this.error.set(authError(e));
      }
    });
  }

  private enableForms() {
    this.approveForm.enable({emitEvent:false}); this.rejectForm.enable({emitEvent:false}); this.newReturnForm.enable({emitEvent:false});
  }

  formatForma(forma: string): string {
    switch (forma) {
      case 'EFECTIVO': return 'Efectivo';
      case 'YAPE': return 'Yape';
      case 'DEBITO': return 'Tarjeta débito';
      case 'DESCUENTO_DEUDA': return 'Descuento de deuda';
      default: return forma;
    }
  }
}

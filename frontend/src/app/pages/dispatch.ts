import {Modal} from '../shared/modal';
import {Component,DestroyRef,computed,inject,signal,ElementRef,viewChild} from '@angular/core';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {finalize,Subscription} from 'rxjs';
import {DocumentPrinter} from '../shared/document-printer';
import {DISPATCH_PRINT_CSS} from '../shared/dispatch-print';
import {AuthService,authError} from '../core/auth.service';
import {
  PrepareDispatchRequest,DeliverDispatchRequest,
  DispatchDetail,
  DispatchFilter,
  DispatchItem,
  DispatchRow,
  DispatchService,
  DispatchSummary
} from '../core/dispatch.service';
import {EmptyState} from '../shared/empty-state';
import {Icon} from '../shared/icon';

@Component({
  selector: 'app-dispatch',
  imports: [
    Modal,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    EmptyState,
    Icon
  ],
  providers:[DocumentPrinter],
  templateUrl: './dispatch.html',
  styleUrl: './dispatch.css'
})
export class Dispatch {
  readonly auth = inject(AuthService);
  private readonly api = inject(DispatchService);
  private readonly destroy = inject(DestroyRef);

  private readonly printer=inject(DocumentPrinter);
  private readonly sheet=viewChild<ElementRef<HTMLElement>>('sheet');
  private listRequest?:Subscription;private summaryRequest?:Subscription;
  readonly summaryReady=signal(false);readonly summaryError=signal('');
  readonly prepareOperation=signal<PrepareDispatchRequest|null>(null);
  readonly deliverOperation=signal<DeliverDispatchRequest|null>(null);
  readonly canManage = computed(() => this.auth.has('DES.GESTIONAR'));

  readonly summary = signal<DispatchSummary>({
    pendientes: 0,
    preparados: 0,
    entregados: 0,
    anulados: 0
  });

  readonly activeTab = signal<'PENDIENTE' | 'PREPARADO' | 'ENTREGADO' | 'ANULADO'>('PENDIENTE');
  readonly rows = signal<DispatchRow[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly pageSize = signal(20);
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly busy = signal(false);
  readonly error = signal('');
  readonly success = signal('');

  // Modals state
  readonly sheetDetail = signal<DispatchDetail | null>(null);
  readonly prepareTarget = signal<DispatchRow | null>(null);
  readonly deliverTarget = signal<DispatchRow | null>(null);

  // Forms
  readonly filters = new FormGroup({
    buscar: new FormControl('', {nonNullable: true,validators:[Validators.maxLength(100)]}),
    desde: new FormControl('', {nonNullable: true}),
    hasta: new FormControl('', {nonNullable: true})
  });
  readonly applied = signal<DispatchFilter>({
    estado: 'PENDIENTE',
    buscar: '',
    desde: '',
    hasta: ''
  });

  readonly prepareForm = new FormGroup({
    observacion: new FormControl('', {
      nonNullable: true,
      validators: [Validators.maxLength(300), Validators.pattern(/^[^<>]*$/)]
    })
  });

  readonly deliverForm = new FormGroup({
    recibe: new FormControl('', {
      nonNullable: true,
      validators: [Validators.maxLength(100), Validators.pattern(/^[^<>]*$/)]
    }),
    observacion: new FormControl('', {
      nonNullable: true,
      validators: [Validators.maxLength(300), Validators.pattern(/^[^<>]*$/)]
    })
  });

  constructor() {
    this.fetchData(this.applied(), this.page());
    this.loadSummary();
  }

  fetchData(f: DispatchFilter, p: number) {
    this.listRequest?.unsubscribe();
    this.error.set('');
    this.loaded.set(false);
    this.loading.set(true);

    this.listRequest=this.api.list(f, p, this.pageSize()).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: res => {
        this.rows.set(res.items);
        this.total.set(res.total);
        this.loaded.set(true);
      },
      error: e => {
        this.rows.set([]);this.total.set(0);
        this.error.set(authError(e));
      }
    });
  }

  loadSummary() {
    this.summaryRequest?.unsubscribe();this.summaryError.set('');
    this.summaryRequest=this.api.summary().pipe(takeUntilDestroyed(this.destroy)).subscribe({
      next: s => {this.summary.set(s);this.summaryReady.set(true);},
      error: () => {this.summaryReady.set(false);this.summaryError.set('No se pudo cargar el resumen de estados.');}
    });
  }

  setTab(tab: 'PENDIENTE' | 'PREPARADO' | 'ENTREGADO' | 'ANULADO') {
    if(this.busy())return;
    this.activeTab.set(tab);
    this.page.set(0);
    const updated: DispatchFilter = {
      ...this.applied(),
      estado: tab
    };
    this.applied.set(updated);
    this.fetchData(updated, 0);
  }

  applyFilters() {
    if(this.busy())return;
    const val = this.filters.getRawValue();
    if(this.filters.invalid||(val.desde&&val.hasta&&val.desde>val.hasta)){this.error.set('Revisa la búsqueda (máximo 100 caracteres) y el orden de las fechas.');return;}
    this.page.set(0);
    const updated: DispatchFilter = {
      estado: this.activeTab(),
      buscar: val.buscar.trim(),
      desde: val.desde,
      hasta: val.hasta
    };
    this.applied.set(updated);
    this.fetchData(updated, 0);
    this.loadSummary();
  }

  clearFilters() {
    this.filters.reset();
    this.applyFilters();
  }

  nextPage(delta:number){const next=this.page()+delta;if(this.loading()||this.busy()||next<0||next*this.pageSize()>=this.total())return;this.page.set(next);this.fetchData(this.applied(),next);}

  reload() {
    if(this.busy())return;
    this.fetchData(this.applied(), this.page());
    this.loadSummary();
  }

  // Preparation Sheet Modal
  openSheet(despachoId: number) {
    if(this.busy()||this.sheetDetail()||this.prepareTarget()||this.deliverTarget())return;
    this.busy.set(true);
    this.error.set('');
    this.api.get(despachoId).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.busy.set(false))
    ).subscribe({
      next: detail => this.sheetDetail.set(detail),
      error: e => this.error.set(authError(e))
    });
  }

  closeSheet() {
    if(this.busy())return;
    this.sheetDetail.set(null);
  }

  printSheet() {
    const sheet=this.sheet();if(!sheet||!this.sheetDetail()||this.busy())return;
    this.printer.print(sheet.nativeElement,DISPATCH_PRINT_CSS,()=>this.error.set('No se pudo abrir la impresión. Inténtalo otra vez.'));
  }

  // Prepare Action
  openPrepareModal(row: DispatchRow) {
    if (!this.canManage()||this.busy()||row.estado!=='PENDIENTE'||this.sheetDetail()||this.deliverTarget()) return;
    this.error.set('');this.prepareOperation.set(null);
    this.prepareTarget.set(row);
    this.prepareForm.reset({observacion: ''});
  }

  closePrepareModal() {
    if (this.busy()) return;
    this.prepareTarget.set(null);
  }

  submitPrepare() {
    const target = this.prepareTarget();
    if (!target || !this.canManage() || target.estado!=='PENDIENTE' || this.prepareForm.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set('');
    this.success.set('');

    const val = this.prepareForm.getRawValue();
    const operation=this.prepareOperation()||{clave:crypto.randomUUID(),observacion:val.observacion.trim()||null};
    this.prepareOperation.set(operation);
    this.api.prepare(target.id, operation).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.busy.set(false))
    ).subscribe({
      next: () => {
        this.busy.set(false);
        this.closePrepareModal();
        this.success.set(`Pedido ${target.numeroFormateado} marcado como preparado.`);
        this.reload();
      },
      error: e => {if(e.status>=400&&e.status<500)this.prepareOperation.set(null);this.error.set(authError(e));}
    });
  }

  // Deliver Action
  openDeliverModal(row: DispatchRow) {
    if (!this.canManage()||this.busy()||row.estado!=='PREPARADO'||this.sheetDetail()||this.prepareTarget()) return;
    this.error.set('');this.deliverOperation.set(null);
    this.deliverTarget.set(row);
    this.deliverForm.reset({recibe: '', observacion: ''});
  }

  closeDeliverModal() {
    if (this.busy()) return;
    this.deliverTarget.set(null);
  }

  submitDeliver() {
    const target = this.deliverTarget();
    if (!target || !this.canManage() || target.estado!=='PREPARADO' || this.deliverForm.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set('');
    this.success.set('');

    const val = this.deliverForm.getRawValue();
    const operation=this.deliverOperation()||{clave:crypto.randomUUID(),recibe:val.recibe.trim()||null,observacion:val.observacion.trim()||null};
    this.deliverOperation.set(operation);
    this.api.deliver(target.id, operation).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.busy.set(false))
    ).subscribe({
      next: () => {
        this.busy.set(false);
        this.closeDeliverModal();
        this.success.set(`Pedido ${target.numeroFormateado} entregado con éxito.`);
        this.reload();
      },
      error: e => {if(e.status>=400&&e.status<500)this.deliverOperation.set(null);this.error.set(authError(e));}
    });
  }

  timeAgo(dateStr: string): string {
    if (!dateStr) return '';
    const iso=dateStr.replace(' ','T');
    const date = new Date(/(?:Z|[+-]\d{2}:?\d{2})$/.test(iso)?iso:iso+'-05:00');
    if(!Number.isFinite(date.getTime()))return 'Fecha no disponible';
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    if (diffMs < 0) return 'Reciente';
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 60) return `Hace ${diffMins} min`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `Hace ${diffHours} h`;
    const diffDays = Math.floor(diffHours / 24);
    return `Hace ${diffDays} d`;
  }
}

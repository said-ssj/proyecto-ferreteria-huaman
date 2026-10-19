import {Modal} from '../shared/modal';
import {Component,DestroyRef,computed,effect,inject,signal} from '@angular/core';
import {takeUntilDestroyed} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {
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
  templateUrl: './dispatch.html',
  styleUrl: './dispatch.css'
})
export class Dispatch {
  readonly auth = inject(AuthService);
  private readonly api = inject(DispatchService);
  private readonly destroy = inject(DestroyRef);

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
    buscar: new FormControl('', {nonNullable: true}),
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
    this.error.set('');
    this.loaded.set(false);
    this.loading.set(true);

    this.api.list(f, p, this.pageSize()).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: res => {
        this.rows.set(res.items);
        this.total.set(res.total);
        this.loaded.set(true);
      },
      error: e => {
        this.rows.set([]);
        this.error.set(authError(e));
      }
    });
  }

  loadSummary() {
    this.api.summary().pipe(takeUntilDestroyed(this.destroy)).subscribe({
      next: s => this.summary.set(s),
      error: () => {}
    });
  }

  setTab(tab: 'PENDIENTE' | 'PREPARADO' | 'ENTREGADO' | 'ANULADO') {
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
    this.page.set(0);
    const val = this.filters.getRawValue();
    const updated: DispatchFilter = {
      estado: this.activeTab(),
      buscar: val.buscar,
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

  reload() {
    this.fetchData(this.applied(), this.page());
    this.loadSummary();
  }

  // Preparation Sheet Modal
  openSheet(despachoId: number) {
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
    this.sheetDetail.set(null);
  }

  printSheet() {
    window.print();
  }

  // Prepare Action
  openPrepareModal(row: DispatchRow) {
    if (!this.canManage()) return;
    this.prepareTarget.set(row);
    this.prepareForm.reset({observacion: ''});
  }

  closePrepareModal() {
    if (this.busy()) return;
    this.prepareTarget.set(null);
  }

  submitPrepare() {
    const target = this.prepareTarget();
    if (!target || this.prepareForm.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set('');
    this.success.set('');

    const val = this.prepareForm.getRawValue();
    this.api.prepare(target.id, {
      clave: crypto.randomUUID(),
      observacion: val.observacion || null
    }).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.busy.set(false))
    ).subscribe({
      next: () => {
        this.busy.set(false);
        this.closePrepareModal();
        this.success.set(`Pedido ${target.numeroFormateado} marcado como preparado.`);
        this.reload();
      },
      error: e => this.error.set(authError(e))
    });
  }

  // Deliver Action
  openDeliverModal(row: DispatchRow) {
    if (!this.canManage()) return;
    this.deliverTarget.set(row);
    this.deliverForm.reset({recibe: '', observacion: ''});
  }

  closeDeliverModal() {
    if (this.busy()) return;
    this.deliverTarget.set(null);
  }

  submitDeliver() {
    const target = this.deliverTarget();
    if (!target || this.deliverForm.invalid || this.busy()) return;

    this.busy.set(true);
    this.error.set('');
    this.success.set('');

    const val = this.deliverForm.getRawValue();
    this.api.deliver(target.id, {
      clave: crypto.randomUUID(),
      recibe: val.recibe || null,
      observacion: val.observacion || null
    }).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.busy.set(false))
    ).subscribe({
      next: () => {
        this.busy.set(false);
        this.closeDeliverModal();
        this.success.set(`Pedido ${target.numeroFormateado} entregado con éxito.`);
        this.reload();
      },
      error: e => this.error.set(authError(e))
    });
  }

  timeAgo(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr.replace(' ', 'T'));
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

import {Modal} from '../shared/modal';
import {Component,Injector,afterNextRender,DestroyRef,computed,effect,inject,signal} from '@angular/core';
import {ActivatedRoute,Router,RouterLink} from '@angular/router';
import {takeUntilDestroyed,toSignal} from '@angular/core/rxjs-interop';
import {FormControl,FormGroup,ReactiveFormsModule,Validators} from '@angular/forms';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {MatSelectModule} from '@angular/material/select';
import {MatCheckboxModule} from '@angular/material/checkbox';
import {finalize} from 'rxjs';
import {AuthService,authError} from '../core/auth.service';
import {
  CreditService,
  PaymentInput,
  CreditSummary,
  CreditAccountRow,
  CustomerStatement,
  CreditOptions,
  PaymentReceipt,
  CreditAccountDetail,
  CreditFilter
} from '../core/credit.service';
import {EmptyState} from '../shared/empty-state';

interface PaymentTarget {
  cuentaId: number;
  clienteId: number;
  clienteNombre: string;
  comprobante: string;
  saldo: string;
}

@Component({
  selector: 'app-credits',
  imports: [
    Modal,
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatCheckboxModule,
    EmptyState
  ],
  templateUrl: './credits.html',
  styleUrl: './credits.css'
})
export class Credits {
  readonly auth = inject(AuthService);
  private readonly injector=inject(Injector);
  readonly printingStatement=signal(false);
  private readonly api = inject(CreditService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroy = inject(DestroyRef);
  private readonly queryParams = toSignal(this.route.queryParamMap);

  readonly summary = signal<CreditSummary | null>(null);
  readonly options = signal<CreditOptions | null>(null);
  readonly rows = signal<CreditAccountRow[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly loading = signal(false);
  readonly loaded = signal(false);
  readonly error = signal('');
  readonly success = signal('');

  readonly selectedCustomer = signal<number | null>(null);
  readonly statement = signal<CustomerStatement | null>(null);

  readonly paymentTarget = signal<PaymentTarget | null>(null);
  readonly savingPayment = signal(false);
  readonly pendingPayment = signal<PaymentInput | null>(null);
  readonly activeReceipt = signal<PaymentReceipt | null>(null);

  readonly filters = new FormGroup({
    buscar: new FormControl('', {nonNullable: true}),
    estado: new FormControl('', {nonNullable: true}),
    soloVencidas: new FormControl(false, {nonNullable: true}),
    desde: new FormControl('', {nonNullable: true}),
    hasta: new FormControl('', {nonNullable: true})
  });
  readonly applied = signal<CreditFilter>(this.filters.getRawValue());

  readonly paymentForm = new FormGroup({
    monto: new FormControl('', {
      nonNullable: true,
      validators: [
        Validators.required,
        Validators.pattern(/^[0-9]{1,16}(?:\.[0-9]{1,2})?$/),
        Validators.min(0.01)
      ]
    }),
    medio: new FormControl<'EFECTIVO' | 'YAPE' | 'DEBITO'>('EFECTIVO', {nonNullable: true}),
    operacion: new FormControl('', {nonNullable: true}),
    marca: new FormControl('', {nonNullable: true}),
    ultimosCuatro: new FormControl('', {nonNullable: true}),
    observacion: new FormControl('', {nonNullable: true, validators: [Validators.maxLength(300)]})
  });

  constructor() {
    this.setupPaymentValidation();

    // Check query params for specific client
    effect(() => {
      const qp = this.queryParams();
      const cliParam = qp?.get('cliente');
      if (cliParam) {
        const id = Number(cliParam);
        if (id && !Number.isNaN(id)) {
          this.openStatement(id);
        }
      }
    });

    // Reactive data loading
    effect(cleanup => {
      const f = this.applied();
      const p = this.page();
      const custId = this.selectedCustomer();

      if (custId) {
        return;
      }

      this.error.set('');
      this.loaded.set(false);
      this.loading.set(true);

      const sub = this.api.list(f, p).pipe(
        finalize(() => this.loading.set(false))
      ).subscribe({
        next: r => {
          this.rows.set(r.items);
          this.total.set(r.total);
          this.loaded.set(true);
        },
        error: e => {
          this.rows.set([]);
          this.error.set(authError(e));
        }
      });
      cleanup(() => sub.unsubscribe());
    });

    this.loadGeneralData();
  }

  private setupPaymentValidation() {
    this.paymentForm.controls.medio.valueChanges.pipe(
      takeUntilDestroyed(this.destroy)
    ).subscribe(m => {
      const op = this.paymentForm.controls.operacion;
      const u4 = this.paymentForm.controls.ultimosCuatro;

      if (m === 'YAPE') {
        op.setValidators([Validators.required, Validators.pattern(/^[0-9]{6,20}$/)]);
        u4.clearValidators();
      } else if (m === 'DEBITO') {
        op.setValidators([Validators.required, Validators.maxLength(40)]);
        u4.setValidators([Validators.pattern(/^[0-9]{4}$/)]);
      } else {
        op.clearValidators();
        u4.clearValidators();
      }
      op.updateValueAndValidity();
      u4.updateValueAndValidity();
    });
  }

  loadGeneralData() {
    this.api.summary().pipe(takeUntilDestroyed(this.destroy)).subscribe({
      next: s => this.summary.set(s),
      error: () => {}
    });
    this.api.options().pipe(takeUntilDestroyed(this.destroy)).subscribe({
      next: opt => this.options.set(opt),
      error: () => {}
    });
  }

  isCashOpen(): boolean {
    const o = this.options();
    return !!o?.caja && o.caja.estado === 'ABIERTA' && o.caja.fecha === o.fecha;
  }

  hasPendingDebt(cuentas?: CreditAccountDetail[]): boolean {
    return (cuentas || []).some(c => c.saldo !== '0.00' && c.estadoCuenta !== 'ANULADA');
  }

  formatMedio(medio: string): string {
    return ({EFECTIVO: 'Efectivo', YAPE: 'Yape', DEBITO: 'Tarjeta de débito'} as Record<string, string>)[medio] || medio;
  }

  apply() {
    this.page.set(0);
    this.applied.set(this.filters.getRawValue());
  }

  clear() {
    this.filters.reset();
    this.apply();
  }

  reload() {
    this.applied.update(f => ({...f}));
    this.loadGeneralData();
    const custId = this.selectedCustomer();
    if (custId) {
      this.api.statement(custId).pipe(takeUntilDestroyed(this.destroy)).subscribe({
        next: st => this.statement.set(st),
        error: e => this.error.set(authError(e))
      });
    }
  }

  openStatement(clienteId: number) {
    this.error.set('');
    this.success.set('');
    this.selectedCustomer.set(clienteId);
    this.loading.set(true);
    this.api.statement(clienteId).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: st => {
        this.statement.set(st);
        this.loaded.set(true);
      },
      error: e => this.error.set(authError(e))
    });
  }

  closeStatement() {
    this.selectedCustomer.set(null);
    this.statement.set(null);
    void this.router.navigate(['/creditos']);
  }

  openPayment(row: CreditAccountRow) {
    if (this.pendingPayment()) return;
    this.paymentTarget.set({
      cuentaId: row.id,
      clienteId: row.clienteId,
      clienteNombre: row.cliente,
      comprobante: row.comprobante,
      saldo: row.saldo
    });
    this.resetPaymentForm(row.saldo);
  }

  openPaymentForAccount(acc: CreditAccountDetail) {
    if (this.pendingPayment()) return;
    const st = this.statement();
    if (!st) return;
    this.paymentTarget.set({
      cuentaId: acc.id,
      clienteId: st.cliente.id,
      clienteNombre: st.cliente.nombre,
      comprobante: acc.comprobante,
      saldo: acc.saldo
    });
    this.resetPaymentForm(acc.saldo);
  }

  openPaymentFromStatement() {
    const st = this.statement();
    if (!st) return;
    const target = st.cuentas.find(c => c.saldo !== '0.00' && c.estadoCuenta !== 'ANULADA');
    if (target) {
      this.openPaymentForAccount(target);
    }
  }

  private resetPaymentForm(saldo: string) {
    this.paymentForm.reset({
      monto: saldo,
      medio: 'EFECTIVO',
      operacion: '',
      marca: '',
      ultimosCuatro: '',
      observacion: ''
    });
    const maxSaldo = Number(saldo);
    this.paymentForm.controls.monto.setValidators([
      Validators.required,
      Validators.pattern(/^[0-9]{1,16}(?:\.[0-9]{1,2})?$/),
      Validators.min(0.01),
      Validators.max(maxSaldo)
    ]);
    this.paymentForm.controls.monto.updateValueAndValidity();
  }

  setPayAll(saldo: string) {
    this.paymentForm.patchValue({monto: saldo});
  }

  closePaymentModal() {
    if (this.pendingPayment() || this.savingPayment()) return;
    this.paymentTarget.set(null);
  }

  submitPayment() {
    const target = this.paymentTarget();
    if (!target || this.savingPayment() || (!this.pendingPayment() && (this.paymentForm.invalid || !this.isCashOpen()))) return;

    this.savingPayment.set(true);
    this.error.set('');
    this.success.set('');

    const val = this.paymentForm.getRawValue();
    const payload = this.pendingPayment() || {
      cuentaId: target.cuentaId,
      monto: val.monto,
      medio: val.medio,
      clave: crypto.randomUUID(),
      operacion: val.medio === 'EFECTIVO' ? null : val.operacion || null,
      marca: val.medio === 'DEBITO' ? val.marca || null : null,
      ultimosCuatro: val.medio === 'DEBITO' ? val.ultimosCuatro || null : null,
      observacion: val.observacion || null
    };
    this.pendingPayment.set(payload);
    this.paymentForm.disable({emitEvent:false});
    this.api.registerPayment(payload).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.savingPayment.set(false))
    ).subscribe({
      next: receipt => {
        this.pendingPayment.set(null);
        this.paymentForm.enable({emitEvent:false});
        this.paymentTarget.set(null);
        this.activeReceipt.set(receipt);
        this.success.set('Abono registrado con éxito por S/ ' + receipt.monto);
        this.reload();
      },
      error: e => {
        if ([400,401,403,404,409].includes(e.status)) {
          this.pendingPayment.set(null);
          this.paymentForm.enable({emitEvent:false});
        }
        this.error.set(authError(e));
      }
    });
  }

  viewReceipt(abonoId: number) {
    this.api.receipt(abonoId).pipe(
      takeUntilDestroyed(this.destroy)
    ).subscribe({
      next: r => this.activeReceipt.set(r),
      error: e => this.error.set(authError(e))
    });
  }

  closeReceipt() {
    this.activeReceipt.set(null);
  }

  printReceipt() {
    window.print();
  }

  printStatement() {
    this.printingStatement.set(true);
    afterNextRender(()=>{try{window.print();}finally{this.printingStatement.set(false);}},{injector:this.injector});
  }
}

import {Modal} from '../shared/modal';
import {Component, DestroyRef, computed, inject, signal} from '@angular/core';
import {takeUntilDestroyed, toSignal} from '@angular/core/rxjs-interop';
import {FormControl, FormGroup, ReactiveFormsModule, Validators} from '@angular/forms';
import {ActivatedRoute, Router} from '@angular/router';
import {MatButtonModule} from '@angular/material/button';
import {MatFormFieldModule} from '@angular/material/form-field';
import {MatInputModule} from '@angular/material/input';
import {finalize} from 'rxjs';
import {AuthService, authError} from '../core/auth.service';
import {
  OfferCreateRequest,
  OfferRow,
  OfferService,
  OfferStateRequest,
  OfferSummary,
  OfferUpdateRequest,
  ProductPresentationOption
} from '../core/offer.service';
import {EmptyState} from '../shared/empty-state';
import {Icon} from '../shared/icon';

@Component({
  selector: 'app-offers',
  imports: [
    Modal,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    EmptyState,
    Icon
  ],
  templateUrl: './offers.html',
  styleUrl: './offers.css'
})
export class Offers {
  readonly auth = inject(AuthService);
  private readonly api = inject(OfferService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly destroy = inject(DestroyRef);

  readonly isAdmin = computed(() => this.auth.user()?.rol === 'ADM');
  readonly canManage = computed(() => this.auth.has('COC.OFERTAS'));

  readonly mode = signal<'list' | 'new'>('list');

  // Summary
  readonly summary = signal<OfferSummary>({
    vigentes: 0,
    programadas: 0,
    vencidas: 0,
    inactivas: 0
  });

  // List view state
  readonly activeTab = signal<'TODAS' | 'VIGENTE' | 'PROGRAMADA' | 'VENCIDA' | 'INACTIVA'>('TODAS');
  readonly rows = signal<OfferRow[]>([]);
  readonly total = signal(0);
  readonly page = signal(0);
  readonly pageSize = 20;

  readonly searchControl = new FormControl('', {nonNullable: true});
  readonly loading = signal(false);
  readonly busy = signal(false);
  readonly error = signal('');
  readonly success = signal('');

  // Creation state
  readonly productSearchControl = new FormControl('', {nonNullable: true});
  readonly searchingProducts = signal(false);
  readonly availableProducts = signal<ProductPresentationOption[]>([]);
  readonly selectedProduct = signal<ProductPresentationOption | null>(null);

  readonly newOfferForm = new FormGroup({
    nombre: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(3), Validators.maxLength(80), Validators.pattern(/^[^<>]*$/)]
    }),
    precioOferta: new FormControl<number | null>(null, [Validators.required, Validators.min(0.01)]),
    fechaInicio: new FormControl('', {nonNullable: true, validators: [Validators.required]}),
    fechaFin: new FormControl('', {nonNullable: true, validators: [Validators.required]})
  });

  readonly newOfferPrice = toSignal(this.newOfferForm.controls.precioOferta.valueChanges, {initialValue: null});
  readonly newCalculatedDiscount = computed(() => {
    const prod = this.selectedProduct();
    const price = this.newOfferPrice();
    if (!prod || price == null || price <= 0) return null;
    const reg = parseFloat(prod.precioRegular);
    if (reg <= 0 || price >= reg) return 0;
    return Math.round(((reg - price) / reg) * 10000) / 100;
  });

  // Edit state
  readonly editingTarget = signal<OfferRow | null>(null);
  readonly editOfferForm = new FormGroup({
    nombre: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(3), Validators.maxLength(80), Validators.pattern(/^[^<>]*$/)]
    }),
    precioOferta: new FormControl<number | null>(null, [Validators.required, Validators.min(0.01)]),
    fechaInicio: new FormControl('', {nonNullable: true}),
    fechaFin: new FormControl('', {nonNullable: true, validators: [Validators.required]})
  });

  readonly editOfferPrice = toSignal(this.editOfferForm.controls.precioOferta.valueChanges, {initialValue: null});
  readonly editCalculatedDiscount = computed(() => {
    const row = this.editingTarget();
    const price = this.editOfferPrice();
    if (!row || price == null || price <= 0) return null;
    const reg = parseFloat(row.precioRegular);
    if (reg <= 0 || price >= reg) return 0;
    return Math.round(((reg - price) / reg) * 10000) / 100;
  });

  // State change (Inactivate / Reactivate)
  readonly stateTarget = signal<{row: OfferRow; nextState: 'A' | 'I'} | null>(null);

  constructor() {
    // Check initial route mode
    const routeMode = this.route.snapshot.data['offerMode'];
    if (routeMode === 'new') {
      this.mode.set('new');
    }

    this.loadSummary();
    this.loadOffers();
  }

  todayString(): string {
    const d = new Date();
    return d.toISOString().split('T')[0];
  }

  plusDaysString(days: number): string {
    const d = new Date();
    d.setDate(d.getDate() + days);
    return d.toISOString().split('T')[0];
  }

  initNewOfferDates() {
    const hoy = this.todayString();
    const fin = this.plusDaysString(7);
    this.newOfferForm.patchValue({
      fechaInicio: hoy,
      fechaFin: fin
    });
  }

  loadSummary() {
    this.api.getSummary()
      .pipe(takeUntilDestroyed(this.destroy))
      .subscribe({
        next: s => this.summary.set(s),
        error: () => {}
      });
  }

  loadOffers() {
    this.loading.set(true);
    this.error.set('');
    const estado = this.activeTab() === 'TODAS' ? '' : this.activeTab();
    const buscar = this.searchControl.value.trim();

    this.api.getOffers({
      buscar,
      estado,
      pagina: this.page(),
      tamano: this.pageSize
    }).pipe(
      takeUntilDestroyed(this.destroy),
      finalize(() => this.loading.set(false))
    ).subscribe({
      next: res => {
        this.rows.set(res.items);
        this.total.set(res.total);
      },
      error: err => this.error.set(authError(err))
    });
  }

  selectTab(tab: 'TODAS' | 'VIGENTE' | 'PROGRAMADA' | 'VENCIDA' | 'INACTIVA') {
    if (this.activeTab() !== tab) {
      this.activeTab.set(tab);
      this.page.set(0);
      this.loadOffers();
    }
  }

  searchOffers() {
    this.page.set(0);
    this.loadOffers();
  }

  clearSearch() {
    this.searchControl.reset();
    this.searchOffers();
  }

  openNewOffer() {
    this.mode.set('new');
    this.selectedProduct.set(null);
    this.newOfferForm.reset();
    this.initNewOfferDates();
    this.error.set('');
    this.success.set('');
    this.searchProducts();
  }

  cancelNewOffer() {
    this.mode.set('list');
    this.selectedProduct.set(null);
    this.newOfferForm.reset();
    this.error.set('');
    if (this.route.snapshot.data['offerMode'] === 'new') {
      void this.router.navigate(['/ofertas']);
    }
  }

  searchProducts() {
    this.searchingProducts.set(true);
    const q = this.productSearchControl.value.trim();
    this.api.getAvailableProducts(q)
      .pipe(
        takeUntilDestroyed(this.destroy),
        finalize(() => this.searchingProducts.set(false))
      ).subscribe({
        next: list => this.availableProducts.set(list),
        error: err => this.error.set(authError(err))
      });
  }

  selectProduct(opt: ProductPresentationOption) {
    this.selectedProduct.set(opt);
    this.newOfferForm.patchValue({
      nombre: `Oferta ${opt.nombreProducto} - ${opt.presentacionNombre}`.substring(0, 80)
    });
  }

  submitNewOffer() {
    if (this.newOfferForm.invalid || !this.selectedProduct() || this.busy()) return;
    const prod = this.selectedProduct()!;
    const val = this.newOfferForm.getRawValue();

    if (val.precioOferta == null || val.precioOferta <= 0) {
      this.error.set('El precio de oferta debe ser mayor a cero');
      return;
    }
    const regular = parseFloat(prod.precioRegular);
    if (val.precioOferta >= regular) {
      this.error.set(`El precio de oferta (S/ ${val.precioOferta.toFixed(2)}) debe ser menor al regular (S/ ${prod.precioRegular})`);
      return;
    }
    const costo = parseFloat(prod.costoReferencial);
    if (costo > 0 && val.precioOferta < costo) {
      this.error.set(`El precio de oferta (S/ ${val.precioOferta.toFixed(2)}) no puede ser menor al costo (S/ ${prod.costoReferencial})`);
      return;
    }
    if (val.fechaFin < val.fechaInicio) {
      this.error.set('La fecha de fin no puede ser anterior a la fecha de inicio');
      return;
    }
    if (val.fechaInicio < this.todayString()) {
      this.error.set('La fecha de inicio de la oferta no puede ser anterior a hoy');
      return;
    }

    const req: OfferCreateRequest = {
      productoId: prod.productoId,
      presentacionId: prod.presentacionId,
      nombre: val.nombre.trim(),
      precioOferta: val.precioOferta,
      fechaInicio: val.fechaInicio,
      fechaFin: val.fechaFin
    };

    this.busy.set(true);
    this.error.set('');
    this.api.createOffer(req)
      .pipe(
        takeUntilDestroyed(this.destroy),
        finalize(() => this.busy.set(false))
      ).subscribe({
        next: created => {
          this.success.set(`Oferta "${created.nombre}" registrada correctamente.`);
          this.mode.set('list');
          this.loadSummary();
          this.loadOffers();
          if (this.route.snapshot.data['offerMode'] === 'new') {
            void this.router.navigate(['/ofertas']);
          }
        },
        error: err => this.error.set(authError(err))
      });
  }

  openEdit(row: OfferRow) {
    if (row.estadoOperativo === 'VENCIDA' || row.estadoOperativo === 'INACTIVA') return;
    this.editingTarget.set(row);
    this.error.set('');
    this.success.set('');
    this.editOfferForm.patchValue({
      nombre: row.nombre,
      precioOferta: parseFloat(row.precioOferta),
      fechaInicio: row.fechaInicio,
      fechaFin: row.fechaFin
    });
  }

  closeEdit() {
    if (this.busy()) return;
    this.editingTarget.set(null);
    this.editOfferForm.reset();
  }

  submitEdit() {
    const target = this.editingTarget();
    if (!target || this.editOfferForm.invalid || this.busy()) return;
    const val = this.editOfferForm.getRawValue();

    if (val.precioOferta == null || val.precioOferta <= 0) {
      this.error.set('El precio de oferta debe ser mayor a cero');
      return;
    }
    const regular = parseFloat(target.precioRegular);
    if (val.precioOferta >= regular) {
      this.error.set(`El precio de oferta debe ser menor al precio regular (S/ ${target.precioRegular})`);
      return;
    }
    const costo = parseFloat(target.costoReferencial);
    if (costo > 0 && val.precioOferta < costo) {
      this.error.set(`El precio de oferta no puede ser menor al costo (S/ ${target.costoReferencial})`);
      return;
    }
    if (val.fechaFin < (target.estadoOperativo === 'VIGENTE' ? target.fechaInicio : val.fechaInicio)) {
      this.error.set('La fecha de fin no puede ser anterior a la fecha de inicio');
      return;
    }
    if (val.fechaFin < this.todayString()) {
      this.error.set('La fecha de fin no puede ser anterior a hoy');
      return;
    }

    const req: OfferUpdateRequest = {
      nombre: val.nombre.trim(),
      precioOferta: val.precioOferta,
      fechaInicio: target.estadoOperativo === 'VIGENTE' ? target.fechaInicio : val.fechaInicio,
      fechaFin: val.fechaFin,
      version: target.version
    };

    this.busy.set(true);
    this.error.set('');
    this.api.updateOffer(target.id, req)
      .pipe(
        takeUntilDestroyed(this.destroy),
        finalize(() => this.busy.set(false))
      ).subscribe({
        next: updated => {
          this.success.set(`Oferta "${updated.nombre}" actualizada correctamente.`);
          this.editingTarget.set(null);
          this.loadSummary();
          this.loadOffers();
        },
        error: err => this.error.set(authError(err))
      });
  }

  openStateModal(row: OfferRow, nextState: 'A' | 'I') {
    this.stateTarget.set({row, nextState});
    this.error.set('');
  }

  closeStateModal() {
    if (this.busy()) return;
    this.stateTarget.set(null);
  }

  confirmStateChange() {
    const target = this.stateTarget();
    if (!target || this.busy()) return;

    const req: OfferStateRequest = {
      estado: target.nextState,
      version: target.row.version
    };

    this.busy.set(true);
    this.error.set('');
    this.api.changeState(target.row.id, req)
      .pipe(
        takeUntilDestroyed(this.destroy),
        finalize(() => this.busy.set(false))
      ).subscribe({
        next: updated => {
          const accion = target.nextState === 'I' ? 'inactivada' : 'reactivada';
          this.success.set(`Oferta "${updated.nombre}" ${accion} correctamente.`);
          this.stateTarget.set(null);
          this.loadSummary();
          this.loadOffers();
        },
        error: err => this.error.set(authError(err))
      });
  }
}

import {ApplicationRef, signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {
  OfferCreateRequest,
  OfferListResponse,
  OfferRow,
  OfferService,
  OfferStateRequest,
  OfferSummary,
  OfferUpdateRequest,
  ProductPresentationOption
} from '../core/offer.service';
import {Offers} from './offers';

describe('Administración de ofertas conectada', () => {
  const summary: OfferSummary = {
    vigentes: 3,
    programadas: 1,
    vencidas: 2,
    inactivas: 1
  };

  const sampleRow: OfferRow = {
    id: 1,
    nombre: 'Super Oferta Taladro',
    productoId: 10,
    codigoProducto: 'TAL-001',
    nombreProducto: 'Taladro Percutor 650W',
    categoriaId: 2,
    categoriaNombre: 'Herramientas Eléctricas',
    presentacionId: 101,
    presentacionNombre: 'Unidad',
    unidadBase: 'NIU',
    precioRegular: '100.00',
    precioOferta: '80.00',
    descuentoPorcentaje: '20.00',
    costoReferencial: '50.00',
    fechaInicio: '2026-10-18',
    fechaFin: '2026-10-25',
    estadoLogico: 'A',
    estadoOperativo: 'VIGENTE',
    version: '2026-10-18T10:00:00'
  };

  const sampleProductOption: ProductPresentationOption = {
    productoId: 10,
    codigoProducto: 'TAL-001',
    nombreProducto: 'Taladro Percutor 650W',
    presentacionId: 101,
    presentacionNombre: 'Unidad',
    unidadBase: 'NIU',
    precioRegular: '100.00',
    costoReferencial: '50.00',
    permiteVenta: true
  };

  const userProfile = signal<{id: number; rol: string; permisos: string[]; cambioClaveObligatorio: boolean}>({
    id: 1,
    rol: 'ADM',
    permisos: ['COC.OFERTAS'],
    cambioClaveObligatorio: false
  });

  const api = {
    getSummary: vi.fn(() => of(summary)),
    getOffers: vi.fn((_p: any) => of({items: [sampleRow], total: 1, pagina: 0, tamano: 20} as OfferListResponse)),
    getOffer: vi.fn((_id: number) => of(sampleRow)),
    getAvailableProducts: vi.fn((_q: string) => of([sampleProductOption])),
    createOffer: vi.fn((_req: OfferCreateRequest) => of(sampleRow)),
    updateOffer: vi.fn((_id: number, _req: OfferUpdateRequest) => of(sampleRow)),
    changeState: vi.fn((_id: number, _req: OfferStateRequest) => of(sampleRow))
  };

  beforeEach(() => {
    vi.clearAllMocks();
    userProfile.set({id: 1, rol: 'ADM', permisos: ['COC.OFERTAS'], cambioClaveObligatorio: false});
    api.getSummary.mockImplementation(() => of(summary));
    api.getOffers.mockImplementation(() => of({items: [sampleRow], total: 1, pagina: 0, tamano: 20}));
    api.getOffer.mockImplementation((_id: number) => of(sampleRow));
    api.getAvailableProducts.mockImplementation(() => of([sampleProductOption]));
    api.createOffer.mockImplementation((_req: OfferCreateRequest) => of(sampleRow));
    api.updateOffer.mockImplementation((_id: number, _req: OfferUpdateRequest) => of(sampleRow));
    api.changeState.mockImplementation((_id: number, _req: OfferStateRequest) => of(sampleRow));

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        {provide: OfferService, useValue: api},
        {
          provide: AuthService,
          useValue: {
            authenticated: () => true,
            token: () => 'token',
            user: userProfile,
            profile: () => userProfile(),
            has: (perm: string) => userProfile().permisos.includes(perm),
            can: () => true,
            canAction: () => true,
            tick: () => {},
            activity: () => {},
            busy: () => false,
            warning: () => false,
            message: () => '',
            roleName: () => 'Administrador'
          }
        }
      ]
    });
  });

  async function createPage(url: string) {
    const harness = await RouterTestingHarness.create(url);
    harness.detectChanges();
    await TestBed.inject(ApplicationRef).whenStable();
    harness.detectChanges();
    return harness.routeDebugElement!.query(By.directive(Offers)).componentInstance as Offers;
  }

  it('consulta el resumen y la lista de ofertas al cargar', async () => {
    const p = await createPage('/ofertas');
    expect(api.getSummary).toHaveBeenCalled();
    expect(api.getOffers).toHaveBeenCalledWith(expect.objectContaining({
      estado: '',
      pagina: 0,
      tamano: 20
    }));
    expect(p.summary().vigentes).toBe(3);
    expect(p.rows()).toHaveLength(1);
    expect(p.rows()[0].nombre).toBe('Super Oferta Taladro');
  });

  it('cambia de pestaña y actualiza el filtro de estado', async () => {
    const p = await createPage('/ofertas');
    p.selectTab('PROGRAMADA');
    expect(p.activeTab()).toBe('PROGRAMADA');
    expect(api.getOffers).toHaveBeenCalledWith(expect.objectContaining({
      estado: 'PROGRAMADA'
    }));

    p.selectTab('VENCIDA');
    expect(p.activeTab()).toBe('VENCIDA');
    expect(api.getOffers).toHaveBeenCalledWith(expect.objectContaining({
      estado: 'VENCIDA'
    }));
  });

  it('abre la vista de nueva oferta y valida el cálculo de descuento', async () => {
    const p = await createPage('/ofertas');
    p.openNewOffer();
    expect(p.mode()).toBe('new');
    expect(api.getAvailableProducts).toHaveBeenCalled();

    p.selectProduct(sampleProductOption);
    expect(p.selectedProduct()).toEqual(sampleProductOption);

    // Enter offer price: 80.00 on regular 100.00 -> 20% discount
    p.newOfferForm.patchValue({precioOferta: 80.00});
    expect(p.newCalculatedDiscount()).toBe(20.00);

    // Higher than regular -> 0
    p.newOfferForm.patchValue({precioOferta: 110.00});
    expect(p.newCalculatedDiscount()).toBe(0);
  });

  it('registra una nueva oferta correctamente', async () => {
    const p = await createPage('/ofertas/nueva');
    expect(p.mode()).toBe('new');

    p.selectProduct(sampleProductOption);
    p.newOfferForm.patchValue({
      nombre: 'Gran Oferta Fin de Año',
      precioOferta: 85.00,
      fechaInicio: '2026-10-18',
      fechaFin: '2026-10-31'
    });

    p.submitNewOffer();
    expect(api.createOffer).toHaveBeenCalledWith(expect.objectContaining({
      productoId: 10,
      presentacionId: 101,
      nombre: 'Gran Oferta Fin de Año',
      precioOferta: 85.00,
      fechaInicio: '2026-10-18',
      fechaFin: '2026-10-31'
    }));
    expect(p.mode()).toBe('list');
  });

  it('abre el modal de edición y actualiza la oferta', async () => {
    const p = await createPage('/ofertas');
    p.openEdit(sampleRow);
    expect(p.editingTarget()).toEqual(sampleRow);
    expect(p.editOfferForm.value.nombre).toBe('Super Oferta Taladro');
    expect(p.editOfferForm.value.precioOferta).toBe(80.00);

    p.editOfferForm.patchValue({
      nombre: 'Super Oferta Taladro Editada',
      precioOferta: 75.00,
      fechaFin: '2026-10-30'
    });
    expect(p.editCalculatedDiscount()).toBe(25.00);

    p.submitEdit();
    expect(api.updateOffer).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        nombre: 'Super Oferta Taladro Editada',
        precioOferta: 75.00,
        fechaFin: '2026-10-30'
      })
    );
    expect(p.editingTarget()).toBeNull();
  });

  it('inactiva y reactiva una oferta', async () => {
    const p = await createPage('/ofertas');

    // Inactivate
    p.openStateModal(sampleRow, 'I');
    expect(p.stateTarget()).toEqual({row: sampleRow, nextState: 'I'});

    p.confirmStateChange();
    expect(api.changeState).toHaveBeenCalledWith(1, {
      estado: 'I',
      version: sampleRow.version
    });
    expect(p.stateTarget()).toBeNull();

    // Reactivate
    const inactiveRow: OfferRow = {...sampleRow, estadoLogico: 'I', estadoOperativo: 'INACTIVA'};
    p.openStateModal(inactiveRow, 'A');
    expect(p.stateTarget()).toEqual({row: inactiveRow, nextState: 'A'});

    p.confirmStateChange();
    expect(api.changeState).toHaveBeenCalledWith(1, {
      estado: 'A',
      version: inactiveRow.version
    });
    expect(p.stateTarget()).toBeNull();
  });
});

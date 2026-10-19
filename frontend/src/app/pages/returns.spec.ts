import {ApplicationRef,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of,throwError} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {
  CashOption,
  ReturnDetail,
  ReturnRow,
  ReturnService,
  ReturnSummary,
  SaleDetailLookup,
  SaleLookup
} from '../core/return.service';
import {Returns} from './returns';

describe('Devoluciones conectadas', () => {
  const summary: ReturnSummary = {
    pendientes: 1,
    aprobadasHoy: 2,
    montoReintegradoHoy: '150.00'
  };

  const sampleRow: ReturnRow = {
    id: 1,
    codigo: 'DV-000001',
    ventaId: 10,
    comprobante: 'B001-00000050',
    tipoComprobante: 'BOLETA',
    clienteNombre: 'Carlos Mendez',
    clienteDocumento: '87654321',
    fechaSolicitud: '2026-10-18 11:00:00',
    estadoDevolucion: 'PENDIENTE',
    formaReintegro: 'EFECTIVO',
    montoReintegro: '50.00',
    motivo: 'Producto con falla de fábrica detectado al abrir',
    solicitanteId: 2,
    solicitanteNombre: 'Vendedor Turno',
    autorizadorId: null,
    autorizadorNombre: null,
    fechaDecision: null,
    motivoRechazo: null,
    cajaId: null,
    observacionAprobacion: null,
    totalItems: 1
  };

  const sampleDetail: ReturnDetail = {
    cabecera: sampleRow,
    items: [
      {
        id: 1,
        idDetalleVenta: 101,
        productoId: 5,
        codigoProducto: 'TAL-001',
        nombreProducto: 'Taladro percutor 650W',
        presentacionId: 1,
        presentacionNombre: 'Unidad',
        unidadBaseSimbolo: 'NIU',
        factorBase: '1.000000',
        cantidad: '1.000000',
        estadoProducto: 'DANADO',
        importe: '50.00',
        unidadesRetorno: '[]'
      }
    ]
  };

  const sampleSaleLookup: SaleLookup = {
    idVenta: 10,
    codigoVenta: 'VTA-00010',
    tipoComprobante: 'BOLETA',
    serie: 'B001',
    correlativo: 50,
    comprobante: 'B001-00000050',
    fechaVenta: '2026-10-15 14:00:00',
    diasTranscurridos: 3,
    clienteNombre: 'Carlos Mendez',
    clienteDocumento: '87654321',
    total: '100.00',
    saldoDeuda: '0.00',
    mediosPago: 'EFECTIVO'
  };

  const sampleSaleDetail: SaleDetailLookup = {
    venta: sampleSaleLookup,
    items: [
      {
        idDetalleVenta: 101,
        productoId: 5,
        codigoProducto: 'TAL-001',
        nombreProducto: 'Taladro percutor 650W',
        modoControl: 'GRANEL',
        incrementoBase: '1.000000',
        presentacionId: 1,
        presentacionNombre: 'Unidad',
        unidadBaseSimbolo: 'NIU',
        factorBase: '1.000000',
        cantidadVendida: '2.000000',
        precioUnitario: '50.00',
        importeOriginal: '100.00',
        yaDevuelto: '0.000000',
        disponibleDevolver: '2.000000'
      }
    ],
    cobradoEfectivoDisponible: '100.00',
    cobradoYapeDisponible: '0.00',
    cobradoDebitoDisponible: '0.00',
    totalMonetarioDisponible: '100.00',
    saldoDeuda: '0.00'
  };

  const sampleCash: CashOption = {
    idCaja: 1,
    fecha: '2026-10-18',
    estadoCaja: 'ABIERTA',
    efectivoDisponible: '500.00'
  };

  const userProfile = signal<{id: number; rol: string; permisos: string[]; cambioClaveObligatorio: boolean}>({
    id: 1,
    rol: 'ADM',
    permisos: ['VEN.DEVOLVER', 'CAJ.OPERAR'],
    cambioClaveObligatorio: false
  });

  const api = {
    getSummary: vi.fn(() => of(summary)),
    getReturns: vi.fn((_p: any) => of({items: [sampleRow], total: 1, page: 0, size: 20})),
    getReturnDetail: vi.fn((_id: number) => of(sampleDetail)),
    searchSales: vi.fn((_q: string) => of([sampleSaleLookup])),
    getSaleDetail: vi.fn((_id: number) => of(sampleSaleDetail)),
    getTodayCash: vi.fn(() => of(sampleCash)),
    solicitarDevolucion: vi.fn((_p: any) => of(sampleDetail)),
    aprobarDevolucion: vi.fn((_id: number, _p: any) => of(sampleDetail)),
    rechazarDevolucion: vi.fn((_id: number, _p: any) => of(sampleDetail))
  };

  beforeEach(() => {
    vi.clearAllMocks();
    userProfile.set({id: 1, rol: 'ADM', permisos: ['VEN.DEVOLVER', 'CAJ.OPERAR'], cambioClaveObligatorio: false});
    api.getSummary.mockImplementation(() => of(summary));
    api.getReturns.mockImplementation(() => of({items: [sampleRow], total: 1, page: 0, size: 20}));
    api.getReturnDetail.mockImplementation(() => of(sampleDetail));
    api.searchSales.mockImplementation(() => of([sampleSaleLookup]));
    api.getSaleDetail.mockImplementation(() => of(sampleSaleDetail));
    api.getTodayCash.mockImplementation(() => of(sampleCash));
    api.solicitarDevolucion.mockImplementation(() => of(sampleDetail));
    api.aprobarDevolucion.mockImplementation(() => of(sampleDetail));
    api.rechazarDevolucion.mockImplementation(() => of(sampleDetail));

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        {provide: ReturnService, useValue: api},
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
    return harness.routeDebugElement!.query(By.directive(Returns)).componentInstance as Returns;
  }

  it('consulta el resumen y la lista de devoluciones al cargar', async () => {
    const p = await createPage('/devoluciones');
    expect(api.getSummary).toHaveBeenCalled();
    expect(api.getReturns).toHaveBeenCalled();
    expect(p.rows()).toHaveLength(1);
    expect(p.rows()[0].codigo).toBe('DV-000001');
    expect(p.summary().pendientes).toBe(1);
  });

  it('cambia de pestaña y actualiza el filtro de estado', async () => {
    const p = await createPage('/devoluciones');
    p.setTab('PENDIENTE');
    expect(p.activeTab()).toBe('PENDIENTE');
    expect(api.getReturns).toHaveBeenCalledWith(
      expect.objectContaining({estado: 'PENDIENTE'})
    );
  });

  it('abre el modal de detalle con los productos de la devolución', async () => {
    const p = await createPage('/devoluciones');
    p.openDetail(1);
    expect(api.getReturnDetail).toHaveBeenCalledWith(1);
    expect(p.detailModal()).toEqual(sampleDetail);
    expect(p.detailModal()!.items[0].codigoProducto).toBe('TAL-001');
  });

  it('autoriza una devolución pendiente cuando el administrador confirma', async () => {
    const p = await createPage('/devoluciones');
    p.openApprove(sampleRow);
    expect(p.approveTarget()).toEqual(sampleRow);

    p.approveForm.patchValue({observacion: 'Aprobación autorizada en tienda'});
    p.confirmApprove();

    expect(api.aprobarDevolucion).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        cajaId: 1,
        observacion: 'Aprobación autorizada en tienda'
      })
    );
    expect(p.approveTarget()).toBeNull();
  });

  it('rechaza una devolución con motivo obligatorio', async () => {
    const p = await createPage('/devoluciones');
    p.openReject(sampleRow);
    expect(p.rejectTarget()).toEqual(sampleRow);

    p.rejectForm.patchValue({motivo: 'El producto muestra desgaste por mal uso y no falla de origen'});
    p.confirmReject();

    expect(api.rechazarDevolucion).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        motivo: 'El producto muestra desgaste por mal uso y no falla de origen'
      })
    );
    expect(p.rejectTarget()).toBeNull();
  });

  it('busca ventas y permite registrar una devolución en modo nueva', async () => {
    const p = await createPage('/devoluciones/nueva');
    expect(p.mode()).toBe('new');

    p.saleSearchControl.setValue('B001-00000050');
    p.searchSales();
    expect(api.searchSales).toHaveBeenCalledWith('B001-00000050');
    expect(p.foundSales()).toHaveLength(1);

    p.selectSale(10);
    expect(api.getSaleDetail).toHaveBeenCalledWith(10);
    expect(p.selectedSale()).toEqual(sampleSaleDetail);

    // Set quantity
    p.lineQuantities.set({101: 1});
    expect(p.calculatedRefundTotal()).toBe(50.00);

    p.newReturnForm.patchValue({
      motivo: 'Falla eléctrica comprobada en mostrador',
      forma: 'EFECTIVO',
      autoAprobar: false
    });

    p.submitNewReturn();
    expect(api.solicitarDevolucion).toHaveBeenCalledWith(
      expect.objectContaining({
        ventaId: 10,
        forma: 'EFECTIVO',
        motivo: 'Falla eléctrica comprobada en mostrador',
        autoAprobar: false,
        lineas: [
          expect.objectContaining({
            idDetalleVenta: 101,
            cantidad: 1,
            estadoProducto: 'APTO'
          })
        ]
      })
    );
    expect(p.mode()).toBe('list');
  });
  it('conserva la clave y el cuerpo al reintentar una autorización',async()=>{
    const p=await createPage('/devoluciones');p.openApprove(sampleRow);
    api.aprobarDevolucion.mockImplementationOnce(()=>throwError(()=>({status:503})));
    p.confirmApprove();const first=api.aprobarDevolucion.mock.calls[0][1];
    expect(p.pending()).not.toBeNull();expect(p.approveForm.disabled).toBe(true);
    p.confirmApprove();expect(api.aprobarDevolucion.mock.calls[1][1]).toEqual(first);expect(p.pending()).toBeNull();
  });
  it('exige el detalle de cada tramo y valida su suma antes de solicitar',async()=>{
    const p=await createPage('/devoluciones/nueva');
    const item={...sampleSaleDetail.items[0],modoControl:'TRAMOS',factorBase:'1',incrementoBase:'0.001'};
    p.selectedSale.set({...sampleSaleDetail,items:[item]});p.lineQuantities.set({101:1});
    p.newReturnForm.patchValue({motivo:'Producto retornado en buen estado',autoAprobar:false});
    p.submitNewReturn();expect(api.solicitarDevolucion).not.toHaveBeenCalled();
    p.returnUnits.set({101:[{condicion:'TRAMO',cantidad:'0.4',presentacionId:null}]});
    p.submitNewReturn();expect(api.solicitarDevolucion).not.toHaveBeenCalled();
    p.returnUnits.set({101:[{condicion:'TRAMO',cantidad:'0.4',presentacionId:null},{condicion:'TRAMO',cantidad:'0.6',presentacionId:null}]});
    p.submitNewReturn();expect(api.solicitarDevolucion).toHaveBeenCalledWith(expect.objectContaining({lineas:[expect.objectContaining({unidades:[{condicion:'TRAMO',cantidad:0.4},{condicion:'TRAMO',cantidad:0.6}]})]}));
    expect(p.selectedSale()).toBeNull();
  });

});

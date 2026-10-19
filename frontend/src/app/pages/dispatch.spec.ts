import {ApplicationRef,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {
  DispatchDetail,
  DispatchRow,
  DispatchService,
  DispatchSummary
} from '../core/dispatch.service';
import {Dispatch} from './dispatch';

describe('Despachos de pedidos conectados', () => {
  const summary: DispatchSummary = {
    pendientes: 2,
    preparados: 1,
    entregados: 5,
    anulados: 0
  };

  const sampleRow: DispatchRow = {
    id: 1,
    numero: 1,
    numeroFormateado: 'DP-000001',
    ventaId: 101,
    comprobante: 'B001-00000045',
    tipoComprobante: 'B',
    clienteNombre: 'Juan Perez',
    clienteDocumento: '12345678',
    fechaVenta: '2026-10-18 10:00:00',
    estado: 'PENDIENTE',
    totalItems: 2,
    preparadoPor: null,
    fechaPreparacion: null,
    observacionPreparacion: null,
    entregadoPor: null,
    fechaEntrega: null,
    recibeNombre: null,
    observacionEntrega: null,
    version: '2026-10-18T10:00:00'
  };

  const sampleDetail: DispatchDetail = {
    despacho: sampleRow,
    items: [
      {
        id: 1,
        productoId: 10,
        codigoProducto: 'HERR-001',
        productoNombre: 'Martillo de uña',
        presentacionNombre: 'Unidad',
        unidadBase: 'NIU',
        cantidad: '2.000000',
        factorBase: '1.000000',
        cantidadBase: '2.000000',
        ubicacion: 'PASILLO 3',
        modoControl: 'GRANEL'
      }
    ],
    vendedor: 'Vendedor Demo',
    totalVenta: '50.00',
    observacionVenta: 'Pedido para recoger'
  };

  const userPermissions = signal(['DES.VER', 'DES.GESTIONAR']);

  const api = {
    summary: vi.fn(() => of(summary)),
    list: vi.fn(() => of({items: [sampleRow], total: 1, pagina: 0, tamano: 20})),
    get: vi.fn((_id: number) => of(sampleDetail)),
    prepare: vi.fn((_id: number, _body: any) => of(sampleDetail)),
    deliver: vi.fn((_id: number, _body: any) => of(sampleDetail))
  };

  beforeEach(() => {
    vi.clearAllMocks();
    userPermissions.set(['DES.VER', 'DES.GESTIONAR']);
    api.summary.mockImplementation(() => of(summary));
    api.list.mockImplementation(() => of({items: [sampleRow], total: 1, pagina: 0, tamano: 20}));
    api.get.mockImplementation((_id: number) => of(sampleDetail));
    api.prepare.mockImplementation((_id: number, _body: any) => of(sampleDetail));
    api.deliver.mockImplementation((_id: number, _body: any) => of(sampleDetail));

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        {provide: DispatchService, useValue: api},
        {
          provide: AuthService,
          useValue: {
            authenticated: () => true,
            token: () => 'token',
            user: signal({id: 1, rol: 'ALM'}),
            has: (perm: string) => userPermissions().includes(perm),
            can: () => true,
            canAction: () => true,
            tick: () => {},
            activity: () => {},
            busy: () => false,
            warning: () => false,
            message: () => '',
            roleName: () => 'Almacén'
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
    return harness.routeDebugElement!.query(By.directive(Dispatch)).componentInstance as Dispatch;
  }

  it('consulta la lista de despachos y el resumen al cargar', async () => {
    const p = await createPage('/despachos');
    expect(api.list).toHaveBeenCalled();
    expect(api.summary).toHaveBeenCalled();
    expect(p.loaded()).toBe(true);
    expect(p.rows()).toHaveLength(1);
    expect(p.rows()[0].numeroFormateado).toBe('DP-000001');
    expect(p.summary().pendientes).toBe(2);
  });

  it('cambia de pestaña y actualiza el filtro de estado', async () => {
    const p = await createPage('/despachos');
    p.setTab('PREPARADO');
    expect(p.activeTab()).toBe('PREPARADO');
    expect(api.list).toHaveBeenCalledWith(
      expect.objectContaining({estado: 'PREPARADO'}),
      0,
      20
    );
  });

  it('abre la hoja de preparación con los datos de detalle', async () => {
    const p = await createPage('/despachos');
    p.openSheet(1);
    expect(api.get).toHaveBeenCalledWith(1);
    expect(p.sheetDetail()).toEqual(sampleDetail);
    expect(p.sheetDetail()!.items[0].ubicacion).toBe('PASILLO 3');
    p.closeSheet();
    expect(p.sheetDetail()).toBeNull();
  });

  it('prepara un despacho con UUID y muestra mensaje de éxito', async () => {
    const p = await createPage('/despachos');
    p.openPrepareModal(sampleRow);
    expect(p.prepareTarget()).toEqual(sampleRow);

    p.prepareForm.controls.observacion.setValue('2 cajas embaladas');
    p.submitPrepare();

    expect(api.prepare).toHaveBeenCalled();
    const callArgs = api.prepare.mock.calls[0];
    expect(callArgs[0]).toBe(1);
    expect(callArgs[1].clave).toBeDefined();
    expect(callArgs[1].observacion).toBe('2 cajas embaladas');
    expect(p.prepareTarget()).toBeNull();
    expect(p.success()).toContain('marcado como preparado');
  });

  it('confirma entrega con nombre de quien retira y UUID', async () => {
    const p = await createPage('/despachos');
    p.openDeliverModal(sampleRow);
    expect(p.deliverTarget()).toEqual(sampleRow);

    p.deliverForm.controls.recibe.setValue('Carlos Ruiz');
    p.deliverForm.controls.observacion.setValue('Entregado conforme');
    p.submitDeliver();

    expect(api.deliver).toHaveBeenCalled();
    const callArgs = api.deliver.mock.calls[0];
    expect(callArgs[0]).toBe(1);
    expect(callArgs[1].clave).toBeDefined();
    expect(callArgs[1].recibe).toBe('Carlos Ruiz');
    expect(callArgs[1].observacion).toBe('Entregado conforme');
    expect(p.deliverTarget()).toBeNull();
    expect(p.success()).toContain('entregado con éxito');
  });

  it('bloquea acciones operativas si el usuario solo tiene DES.VER (vendedor)', async () => {
    userPermissions.set(['DES.VER']);
    const p = await createPage('/despachos');
    expect(p.canManage()).toBe(false);

    p.openPrepareModal(sampleRow);
    expect(p.prepareTarget()).toBeNull();

    p.openDeliverModal(sampleRow);
    expect(p.deliverTarget()).toBeNull();
  });
});

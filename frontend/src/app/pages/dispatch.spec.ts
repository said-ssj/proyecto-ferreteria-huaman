import {ApplicationRef,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of,Subject,throwError} from 'rxjs';
import {CatalogPage} from '../core/catalog.service';
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
  let currentHarness:RouterTestingHarness;
  afterEach(()=>vi.useRealTimers());
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
    const harness = await RouterTestingHarness.create(url);currentHarness=harness;
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
    const prepared={...sampleRow,estado:'PREPARADO' as const};
    p.openDeliverModal(prepared);
    expect(p.deliverTarget()).toEqual(prepared);

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
  it('pagina y conserva el filtro aplicado',async()=>{
    const p=await createPage('/despachos');p.setTab('PREPARADO');p.total.set(41);p.nextPage(1);
    expect(api.list).toHaveBeenLastCalledWith(expect.objectContaining({estado:'PREPARADO'}),1,20);
    p.total.set(41);p.nextPage(1);p.total.set(41);api.list.mockClear();p.nextPage(1);
    expect(p.page()).toBe(2);expect(api.list).not.toHaveBeenCalled();
  });
  it('rechaza fechas invertidas antes de consultar',async()=>{
    const p=await createPage('/despachos');api.list.mockClear();p.filters.patchValue({desde:'2026-10-25',hasta:'2026-10-01'});p.applyFilters();
    expect(api.list).not.toHaveBeenCalled();expect(p.error()).toContain('fechas');
  });
  it('no permite entregar un pendiente ni preparar un entregado',async()=>{
    const p=await createPage('/despachos');p.openDeliverModal(sampleRow);p.openPrepareModal({...sampleRow,estado:'ENTREGADO'});
    expect(p.deliverTarget()).toBeNull();expect(p.prepareTarget()).toBeNull();expect(api.deliver).not.toHaveBeenCalled();
  });
  it('ignora respuestas anteriores al cambiar de estado',async()=>{
    const p=await createPage('/despachos');const old=new Subject<CatalogPage<DispatchRow>>(),latest=new Subject<CatalogPage<DispatchRow>>();
    api.list.mockImplementationOnce(()=>old).mockImplementationOnce(()=>latest);p.reload();p.setTab('ENTREGADO');
    old.next({items:[sampleRow],total:99,pagina:0,tamano:20});latest.next({items:[],total:0,pagina:0,tamano:20});latest.complete();
    expect(p.total()).toBe(0);expect(p.rows()).toEqual([]);expect(p.loading()).toBe(false);
  });
  it('distingue el fallo del resumen de un contador en cero',async()=>{
    api.summary.mockImplementationOnce(()=>throwError(()=>({status:0})));const p=await createPage('/despachos');
    expect(p.summaryReady()).toBe(false);expect(p.summaryError()).toContain('No se pudo');expect(currentHarness.routeNativeElement?.textContent).toContain('—');
  });
  it('reutiliza clave y datos de preparación tras una respuesta incierta',async()=>{
    const p=await createPage('/despachos');p.openPrepareModal(sampleRow);p.prepareForm.controls.observacion.setValue('Dos cajas');
    api.prepare.mockImplementationOnce(()=>throwError(()=>({status:0})));p.submitPrepare();const first=api.prepare.mock.calls[0][1];
    p.prepareForm.controls.observacion.setValue('Otro dato');p.submitPrepare();expect(api.prepare.mock.calls[1][1]).toEqual(first);
  });
  it('reutiliza clave y receptor de entrega después de un error del servidor',async()=>{
    const p=await createPage('/despachos');p.openDeliverModal({...sampleRow,estado:'PREPARADO'});p.deliverForm.controls.recibe.setValue('Persona que retira');
    api.deliver.mockImplementationOnce(()=>throwError(()=>({status:503})));p.submitDeliver();const first=api.deliver.mock.calls[0][1];
    p.deliverForm.controls.recibe.setValue('Otro nombre');p.submitDeliver();expect(api.deliver.mock.calls[1][1]).toEqual(first);
  });
  it('muestra el error dentro del diálogo y permite corregir un rechazo conocido',async()=>{
    const p=await createPage('/despachos');p.openPrepareModal(sampleRow);
    api.prepare.mockImplementationOnce(()=>throwError(()=>({status:409,error:{detail:'El pedido cambió en otra sesión.'}})));p.submitPrepare();currentHarness.detectChanges();
    expect(currentHarness.routeNativeElement?.querySelector('[aria-label="Preparar despacho"] [role="alert"]')?.textContent).toContain('otra sesión');
    expect(p.prepareOperation()).toBeNull();
  });
  it('no cierra ni abre otras operaciones mientras se prepara',async()=>{
    const p=await createPage('/despachos');const pending=new Subject<DispatchDetail>();api.prepare.mockImplementationOnce(()=>pending);p.openPrepareModal(sampleRow);p.submitPrepare();
    p.closePrepareModal();p.openSheet(1);p.openDeliverModal({...sampleRow,estado:'PREPARADO'});
    expect(p.prepareTarget()).toEqual(sampleRow);expect(p.deliverTarget()).toBeNull();expect(api.get).not.toHaveBeenCalled();pending.complete();
  });
  it('interpreta las fechas de negocio en Lima y evita tiempos inválidos',async()=>{
    vi.useFakeTimers({toFake:['Date']});vi.setSystemTime(new Date('2026-10-25T17:00:00Z'));const p=await createPage('/despachos');
    expect(p.timeAgo('2026-10-25 11:00:00')).toBe('Hace 1 h');expect(p.timeAgo('fecha rota')).toBe('Fecha no disponible');
  });
  it('prepara un documento A4 completo y aislado con muchas líneas',async()=>{
    const p=await createPage('/despachos');api.get.mockImplementationOnce(()=>of({...sampleDetail,items:Array.from({length:125},(_,i)=>({...sampleDetail.items[0],id:i+1,productoNombre:'Producto <script>alert(1)</script> '+i}))}));
    p.openSheet(1);currentHarness.detectChanges();p.printSheet();const frame=document.querySelector('iframe')!;
    expect(frame.srcdoc).toContain('@page{size:A4');expect(frame.srcdoc).toContain('max-height:none');
    const parsed=new DOMParser().parseFromString(frame.srcdoc,'text/html');expect(parsed.querySelectorAll('tbody tr')).toHaveLength(125);
    expect(parsed.querySelector('script')).toBeNull();expect(parsed.querySelector('button,input')).toBeNull();expect(parsed.querySelector('.sheet-signatures')).not.toBeNull();
  });




});

import {ApplicationRef,signal} from '@angular/core';
import {TestBed} from '@angular/core/testing';
import {provideRouter} from '@angular/router';
import {RouterTestingHarness} from '@angular/router/testing';
import {By} from '@angular/platform-browser';
import {of,throwError} from 'rxjs';
import {routes} from '../app.routes';
import {AuthService} from '../core/auth.service';
import {CreditOptions,CreditService,CreditSummary,CustomerStatement,PaymentReceipt} from '../core/credit.service';
import {Credits} from './credits';

describe('Créditos y abonos conectados', () => {
  const summary: CreditSummary = {
    totalPorCobrar: '120.00',
    totalVencido: '50.00',
    clientesDeudores: 2
  };

  const statement: CustomerStatement = {
    cliente: {
      id: 10,
      nombre: 'Juan Perez',
      tipoDocumento: 'DNI',
      documento: '12345678',
      telefono: '999888777',
      correo: null,
      direccion: null,
      limiteCredito: '500.00',
      deudaTotal: '120.00',
      creditoDisponible: '380.00'
    },
    cuentas: [
      {
        id: 1,
        ventaId: 101,
        fechaVenta: '2026-10-10',
        comprobante: 'B001-00000045',
        tipoComprobante: 'B',
        montoOriginal: '120.00',
        montoAbonado: '0.00',
        saldo: '120.00',
        fechaVencimiento: '2026-11-10',
        situacion: 'AL_DIA',
        estadoCuenta: 'PENDIENTE',
        version: '2026-10-10T10:00:00'
      }
    ],
    abonos: []
  };

  const receipt: PaymentReceipt = {
    id: 1,
    cuentaId: 1,
    monto: '50.00',
    medio: 'EFECTIVO',
    operacion: null,
    marca: null,
    ultimosCuatro: null,
    observacion: 'Pago a cuenta',
    fecha: '2026-10-18 12:00:00',
    registradoPor: 'admin',
    montoOriginalCuenta: '120.00',
    saldoActualCuenta: '70.00',
    saldoAnteriorCuenta: '120.00',
    comprobante: 'B001-00000045',
    clienteId: 10,
    cliente: 'Juan Perez',
    tipoDocumento: 'DNI',
    documento: '12345678',
    negocioNombre: 'Ferretería Huamán',
    negocioRuc: '20123456789',
    negocioDireccion: 'Av. Principal 123',
    negocioTelefono: '01-2345678'
  };

  const api = {
    summary: vi.fn(() => of(summary)),
    options: vi.fn(() => of<CreditOptions>({fecha: '2026-10-18', caja: {id: 1, fecha: '2026-10-18', estado: 'ABIERTA'}})),
    list: vi.fn(() => of({items: [], total: 0, pagina: 0, tamano: 20})),
    statement: vi.fn((_id: number) => of(statement)),
    receipt: vi.fn((_id: number) => of(receipt)),
    registerPayment: vi.fn((_input: any) => of(receipt))
  };

  beforeEach(() => {
    vi.clearAllMocks();
    api.summary.mockImplementation(() => of(summary));
    api.options.mockImplementation(() => of<CreditOptions>({fecha: '2026-10-18', caja: {id: 1, fecha: '2026-10-18', estado: 'ABIERTA'}}));
    api.list.mockImplementation(() => of({items: [], total: 0, pagina: 0, tamano: 20}));
    api.statement.mockImplementation((_id: number) => of(statement));
    api.receipt.mockImplementation((_id: number) => of(receipt));
    api.registerPayment.mockImplementation((_input: any) => of(receipt));
    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        {provide: CreditService, useValue: api},
        {
          provide: AuthService,
          useValue: {
            authenticated: () => true,
            token: () => 'token',
            user: signal({id: 1, rol: 'ADM'}),
            has: (perm: string) => ['CRE.VER', 'CRE.ABONAR', 'VEN.VENDER'].includes(perm),
            can: () => true,
            canAction: () => true,
            tick: () => {},
            activity: () => {},
            busy: () => false,
            warning: () => false,
            message: () => '',
            roleName: () => 'Administración'
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
    return harness.routeDebugElement!.query(By.directive(Credits)).componentInstance as Credits;
  }

  it('consulta la lista real y el resumen sin registrar abonos ni deudas', async () => {
    const p = await createPage('/creditos');
    expect(api.list).toHaveBeenCalled();
    expect(api.summary).toHaveBeenCalled();
    expect(p.loaded()).toBe(true);
    expect(p.rows()).toEqual([]);
    expect(api.registerPayment).not.toHaveBeenCalled();
  });

  it('muestra el estado de cuenta y sus tablas al seleccionar un cliente', async () => {
    const p = await createPage('/creditos');
    p.openStatement(10);
    expect(api.statement).toHaveBeenCalledWith(10);
    expect(p.selectedCustomer()).toBe(10);
    expect(p.statement()).toEqual(statement);
  });

  it('bloquea el abono si la caja está cerrada', async () => {
    api.options.mockReturnValue(of<CreditOptions>({fecha: '2026-10-18', caja: null}));
    const p = await createPage('/creditos');
    p.openPayment({
      id: 1,
      ventaId: 101,
      clienteId: 10,
      cliente: 'Juan Perez',
      documento: '12345678',
      tipoComprobante: 'B',
      serie: 'B001',
      numero: 45,
      comprobante: 'B001-00000045',
      fechaVenta: '2026-10-10',
      montoOriginal: '120.00',
      montoAbonado: '0.00',
      saldo: '120.00',
      fechaVencimiento: '2026-11-10',
      situacion: 'AL_DIA',
      estadoCuenta: 'PENDIENTE',
      version: '2026-10-10T10:00:00'
    });
    expect(p.isCashOpen()).toBe(false);
  });

  it('valida el monto del abono sin superar el saldo de la cuenta', async () => {
    const p = await createPage('/creditos');
    p.openPayment({
      id: 1,
      ventaId: 101,
      clienteId: 10,
      cliente: 'Juan Perez',
      documento: '12345678',
      tipoComprobante: 'B',
      serie: 'B001',
      numero: 45,
      comprobante: 'B001-00000045',
      fechaVenta: '2026-10-10',
      montoOriginal: '120.00',
      montoAbonado: '0.00',
      saldo: '120.00',
      fechaVencimiento: '2026-11-10',
      situacion: 'AL_DIA',
      estadoCuenta: 'PENDIENTE',
      version: '2026-10-10T10:00:00'
    });

    p.paymentForm.controls.monto.setValue('150.00');
    expect(p.paymentForm.controls.monto.invalid).toBe(true);

    p.paymentForm.controls.monto.setValue('50.00');
    expect(p.paymentForm.controls.monto.valid).toBe(true);
  });

  it('registra un abono válido enviando una clave UUID y actualiza la constancia', async () => {
    const p = await createPage('/creditos');
    p.openPayment({
      id: 1,
      ventaId: 101,
      clienteId: 10,
      cliente: 'Juan Perez',
      documento: '12345678',
      tipoComprobante: 'B',
      serie: 'B001',
      numero: 45,
      comprobante: 'B001-00000045',
      fechaVenta: '2026-10-10',
      montoOriginal: '120.00',
      montoAbonado: '0.00',
      saldo: '120.00',
      fechaVencimiento: '2026-11-10',
      situacion: 'AL_DIA',
      estadoCuenta: 'PENDIENTE',
      version: '2026-10-10T10:00:00'
    });

    p.paymentForm.controls.monto.setValue('50.00');
    p.paymentForm.controls.medio.setValue('EFECTIVO');
    p.submitPayment();

    expect(api.registerPayment).toHaveBeenCalled();
    const callArg = api.registerPayment.mock.calls[0][0];
    expect(callArg.cuentaId).toBe(1);
    expect(callArg.monto).toBe('50.00');
    expect(callArg.medio).toBe('EFECTIVO');
    expect(callArg.clave).toBeDefined();
    expect(p.activeReceipt()).toEqual(receipt);
  });
  it('reintenta el mismo abono y bloquea cambios cuando la respuesta es incierta',async()=>{
    const p=await createPage('/creditos');p.openStatement(10);p.openPaymentForAccount(statement.cuentas[0]);
    p.paymentForm.patchValue({monto:'20.00'});
    api.registerPayment.mockImplementationOnce(()=>throwError(()=>({status:0})));
    p.submitPayment();const first=api.registerPayment.mock.calls[0][0];
    expect(p.pendingPayment()?.clave).toBe(first.clave);expect(p.paymentForm.disabled).toBe(true);
    p.closePaymentModal();expect(p.paymentTarget()).not.toBeNull();
    p.submitPayment();expect(api.registerPayment.mock.calls[1][0]).toEqual(first);
    expect(p.pendingPayment()).toBeNull();expect(p.paymentForm.enabled).toBe(true);
  });

});

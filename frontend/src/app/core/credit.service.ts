import {HttpClient,HttpParams} from '@angular/common/http';
import {Injectable,inject} from '@angular/core';
import {API_BASE_URL} from './auth.service';
import {CatalogPage} from './catalog.service';

export interface CreditSummary {
  totalPorCobrar: string;
  totalVencido: string;
  clientesDeudores: number;
}

export interface CreditAccountRow {
  id: number;
  ventaId: number;
  clienteId: number;
  cliente: string;
  documento: string;
  tipoComprobante: string;
  serie: string | null;
  numero: number | null;
  comprobante: string;
  fechaVenta: string;
  montoOriginal: string;
  montoAbonado: string;
  saldo: string;
  fechaVencimiento: string;
  situacion: 'AL_DIA' | 'POR_VENCER' | 'VENCIDA' | 'CANCELADA';
  estadoCuenta: 'PENDIENTE' | 'VENCIDA' | 'CANCELADA' | 'ANULADA';
  version: string;
}

export interface CustomerCreditInfo {
  id: number;
  nombre: string;
  tipoDocumento: string;
  documento: string;
  telefono: string | null;
  correo: string | null;
  direccion: string | null;
  limiteCredito: string;
  deudaTotal: string;
  creditoDisponible: string;
}

export interface CreditAccountDetail {
  id: number;
  ventaId: number;
  fechaVenta: string;
  comprobante: string;
  tipoComprobante: string;
  montoOriginal: string;
  montoAbonado: string;
  saldo: string;
  fechaVencimiento: string;
  situacion: string;
  estadoCuenta: string;
  version: string;
}

export interface PaymentItem {
  id: number;
  cuentaId: number;
  fecha: string;
  monto: string;
  medio: string;
  operacion: string | null;
  marca: string | null;
  ultimosCuatro: string | null;
  observacion: string | null;
  registradoPor: string;
  comprobante: string;
}

export interface CustomerStatement {
  cliente: CustomerCreditInfo;
  cuentas: CreditAccountDetail[];
  abonos: PaymentItem[];
}

export interface PaymentReceipt {
  id: number;
  cuentaId: number;
  monto: string;
  medio: string;
  operacion: string | null;
  marca: string | null;
  ultimosCuatro: string | null;
  observacion: string | null;
  fecha: string;
  registradoPor: string;
  montoOriginalCuenta: string;
  saldoActualCuenta: string;
  saldoAnteriorCuenta: string;
  comprobante: string;
  clienteId: number;
  cliente: string;
  tipoDocumento: string;
  documento: string;
  negocioNombre: string;
  negocioRuc: string;
  negocioDireccion: string;
  negocioTelefono: string;
}

export interface CreditOptions {
  fecha: string;
  caja: {id: number; fecha: string; estado: string} | null;
}

export interface PaymentInput {
  cuentaId: number;
  monto: string;
  medio: string;
  clave: string;
  operacion?: string | null;
  marca?: string | null;
  ultimosCuatro?: string | null;
  observacion?: string | null;
}

export interface CreditFilter {
  buscar: string;
  estado: string;
  soloVencidas: boolean;
  desde: string;
  hasta: string;
}

@Injectable({providedIn:'root'})
export class CreditService {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  summary() {
    return this.http.get<CreditSummary>(this.base + '/creditos/resumen');
  }

  list(filter: CreditFilter, page = 0, size = 20) {
    let params = new HttpParams()
      .set('buscar', filter.buscar)
      .set('estado', filter.estado)
      .set('soloVencidas', filter.soloVencidas ? 'true' : 'false')
      .set('pagina', page)
      .set('tamano', size);

    if (filter.desde) params = params.set('desde', filter.desde);
    if (filter.hasta) params = params.set('hasta', filter.hasta);

    return this.http.get<CatalogPage<CreditAccountRow>>(this.base + '/creditos', {params});
  }

  options() {
    return this.http.get<CreditOptions>(this.base + '/creditos/opciones');
  }

  statement(clienteId: number) {
    return this.http.get<CustomerStatement>(`${this.base}/creditos/clientes/${clienteId}/estado-cuenta`);
  }

  receipt(abonoId: number) {
    return this.http.get<PaymentReceipt>(`${this.base}/creditos/abonos/${abonoId}/constancia`);
  }

  registerPayment(input: PaymentInput) {
    return this.http.post<PaymentReceipt>(this.base + '/creditos/abonos', input);
  }
}

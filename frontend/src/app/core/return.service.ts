import {Injectable} from '@angular/core';
import {HttpClient, HttpParams} from '@angular/common/http';
import {Observable} from 'rxjs';

export interface ReturnSummary {
  pendientes: number;
  aprobadasHoy: number;
  montoReintegradoHoy: string;
}

export interface ReturnRow {
  id: number;
  codigo: string;
  ventaId: number;
  comprobante: string;
  tipoComprobante: string;
  clienteNombre: string;
  clienteDocumento: string;
  fechaSolicitud: string;
  estadoDevolucion: 'PENDIENTE' | 'APROBADA' | 'RECHAZADA';
  formaReintegro: 'EFECTIVO' | 'YAPE' | 'DEBITO' | 'DESCUENTO_DEUDA';
  montoReintegro: string;
  motivo: string;
  solicitanteId: number;
  solicitanteNombre: string;
  autorizadorId: number | null;
  autorizadorNombre: string | null;
  fechaDecision: string | null;
  motivoRechazo: string | null;
  cajaId: number | null;
  observacionAprobacion: string | null;
  totalItems: number;
}

export interface ReturnItem {
  id: number;
  idDetalleVenta: number;
  productoId: number;
  codigoProducto: string;
  nombreProducto: string;
  presentacionId: number;
  presentacionNombre: string;
  unidadBaseSimbolo: string;
  factorBase: string;
  cantidad: string;
  estadoProducto: 'APTO' | 'DANADO';
  importe: string;
  unidadesRetorno: string;
}

export interface ReturnDetail {
  cabecera: ReturnRow;
  items: ReturnItem[];
}

export interface SaleLookup {
  idVenta: number;
  codigoVenta: string;
  tipoComprobante: string;
  serie: string | null;
  correlativo: number | null;
  comprobante: string;
  fechaVenta: string;
  diasTranscurridos: number;
  clienteNombre: string;
  clienteDocumento: string;
  total: string;
  saldoDeuda: string | null;
  mediosPago: string;
}

export interface SaleItemLookup {
  idDetalleVenta: number;
  productoId: number;
  codigoProducto: string;
  nombreProducto: string;
  modoControl: string;
  incrementoBase: string;
  presentacionId: number;
  presentacionNombre: string;
  unidadBaseSimbolo: string;
  factorBase: string;
  cantidadVendida: string;
  precioUnitario: string;
  importeOriginal: string;
  yaDevuelto: string;
  disponibleDevolver: string;
  presentacionesRetorno?: {id:number;nombre:string;factorBase:string}[];
}

export interface SaleDetailLookup {
  venta: SaleLookup;
  items: SaleItemLookup[];
  cobradoEfectivoDisponible: string;
  cobradoYapeDisponible: string;
  cobradoDebitoDisponible: string;
  totalMonetarioDisponible: string;
  saldoDeuda: string;
}

export interface CashOption {
  idCaja: number;
  fecha: string;
  estadoCaja: 'ABIERTA' | 'CERRADA';
  efectivoDisponible: string;
}

export interface ReturnItemRequest {
  idDetalleVenta: number;
  cantidad: number;
  estadoProducto: 'APTO' | 'DANADO';
  unidades?: {condicion:'ENVASE'|'SUELTO'|'TRAMO';cantidad:number;id_presentacion?:number}[];
}

export interface SolicitRequest {
  ventaId: number;
  forma: 'EFECTIVO' | 'YAPE' | 'DEBITO' | 'DESCUENTO_DEUDA';
  motivo: string;
  lineas: ReturnItemRequest[];
  clave: string;
  autoAprobar?: boolean;
  cajaId?: number;
  referencia?: string;
  observacion?: string;
}

export interface ApproveRequest {
  cajaId: number;
  clave: string;
  referencia?: string;
  observacion?: string;
}

export interface RejectRequest {
  clave: string;
  motivo: string;
}

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  size: number;
}

@Injectable({
  providedIn: 'root'
})
export class ReturnService {
  private readonly baseUrl = '/api/devoluciones';

  constructor(private http: HttpClient) {}

  getSummary(): Observable<ReturnSummary> {
    return this.http.get<ReturnSummary>(`${this.baseUrl}/resumen`);
  }

  getReturns(params: {
    estado?: string;
    buscar?: string;
    desde?: string;
    hasta?: string;
    pagina?: number;
    tamano?: number;
  }): Observable<Page<ReturnRow>> {
    let httpParams = new HttpParams();
    if (params.estado) httpParams = httpParams.set('estado', params.estado);
    if (params.buscar) httpParams = httpParams.set('buscar', params.buscar);
    if (params.desde) httpParams = httpParams.set('desde', params.desde);
    if (params.hasta) httpParams = httpParams.set('hasta', params.hasta);
    if (params.pagina !== undefined) httpParams = httpParams.set('pagina', params.pagina.toString());
    if (params.tamano !== undefined) httpParams = httpParams.set('tamano', params.tamano.toString());

    return this.http.get<Page<ReturnRow>>(this.baseUrl, {params: httpParams});
  }

  getReturnDetail(id: number): Observable<ReturnDetail> {
    return this.http.get<ReturnDetail>(`${this.baseUrl}/${id}`);
  }

  searchSales(termino: string = ''): Observable<SaleLookup[]> {
    let params = new HttpParams();
    if (termino) params = params.set('termino', termino);
    return this.http.get<SaleLookup[]>(`${this.baseUrl}/ventas/buscar`, {params});
  }

  getSaleDetail(idVenta: number): Observable<SaleDetailLookup> {
    return this.http.get<SaleDetailLookup>(`${this.baseUrl}/ventas/${idVenta}/items`);
  }

  getTodayCash(): Observable<CashOption | null> {
    return this.http.get<CashOption | null>(`${this.baseUrl}/opciones-caja`);
  }

  solicitarDevolucion(payload: SolicitRequest): Observable<ReturnDetail> {
    return this.http.post<ReturnDetail>(`${this.baseUrl}/solicitar`, payload);
  }

  aprobarDevolucion(id: number, payload: ApproveRequest): Observable<ReturnDetail> {
    return this.http.post<ReturnDetail>(`${this.baseUrl}/${id}/aprobar`, payload);
  }

  rechazarDevolucion(id: number, payload: RejectRequest): Observable<ReturnDetail> {
    return this.http.post<ReturnDetail>(`${this.baseUrl}/${id}/rechazar`, payload);
  }
}

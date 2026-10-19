import {HttpClient,HttpParams} from '@angular/common/http';
import {Injectable,inject} from '@angular/core';
import {API_BASE_URL} from './auth.service';
import {CatalogPage} from './catalog.service';

export interface DispatchSummary {
  pendientes: number;
  preparados: number;
  entregados: number;
  anulados: number;
}

export interface DispatchRow {
  id: number;
  numero: number;
  numeroFormateado: string;
  ventaId: number;
  comprobante: string | null;
  tipoComprobante: string;
  clienteNombre: string;
  clienteDocumento: string;
  fechaVenta: string;
  estado: 'PENDIENTE' | 'PREPARADO' | 'ENTREGADO' | 'ANULADO';
  totalItems: number;
  preparadoPor: string | null;
  fechaPreparacion: string | null;
  observacionPreparacion: string | null;
  entregadoPor: string | null;
  fechaEntrega: string | null;
  recibeNombre: string | null;
  observacionEntrega: string | null;
  version: string;
}

export interface DispatchItem {
  id: number;
  productoId: number;
  codigoProducto: string;
  productoNombre: string;
  presentacionNombre: string;
  unidadBase: string;
  cantidad: string;
  factorBase: string;
  cantidadBase: string;
  ubicacion: string | null;
  modoControl: string;
}

export interface DispatchDetail {
  despacho: DispatchRow;
  items: DispatchItem[];
  vendedor: string | null;
  totalVenta: string;
  observacionVenta: string | null;
}

export interface PrepareDispatchRequest {
  clave: string;
  observacion?: string | null;
}

export interface DeliverDispatchRequest {
  clave: string;
  recibe?: string | null;
  observacion?: string | null;
}

export interface DispatchFilter {
  estado: string;
  buscar: string;
  desde: string;
  hasta: string;
}

@Injectable({providedIn: 'root'})
export class DispatchService {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  summary() {
    return this.http.get<DispatchSummary>(this.base + '/despachos/resumen');
  }

  list(filter: DispatchFilter, page = 0, size = 20) {
    let params = new HttpParams()
      .set('estado', filter.estado)
      .set('buscar', filter.buscar)
      .set('pagina', page)
      .set('tamano', size);

    if (filter.desde) params = params.set('desde', filter.desde);
    if (filter.hasta) params = params.set('hasta', filter.hasta);

    return this.http.get<CatalogPage<DispatchRow>>(this.base + '/despachos', {params});
  }

  get(id: number) {
    return this.http.get<DispatchDetail>(`${this.base}/despachos/${id}`);
  }

  prepare(id: number, body: PrepareDispatchRequest) {
    return this.http.post<DispatchDetail>(`${this.base}/despachos/${id}/preparar`, body);
  }

  deliver(id: number, body: DeliverDispatchRequest) {
    return this.http.post<DispatchDetail>(`${this.base}/despachos/${id}/entregar`, body);
  }
}

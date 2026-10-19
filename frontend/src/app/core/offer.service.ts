import {inject, Injectable} from '@angular/core';
import {HttpClient, HttpParams} from '@angular/common/http';
import {Observable} from 'rxjs';
import {API_BASE_URL} from './auth.service';

export interface OfferSummary {
  vigentes: number;
  programadas: number;
  vencidas: number;
  inactivas: number;
}

export interface OfferRow {
  id: number;
  nombre: string;
  productoId: number;
  codigoProducto: string;
  nombreProducto: string;
  categoriaId: number;
  categoriaNombre: string;
  presentacionId: number;
  presentacionNombre: string;
  unidadBase: string;
  precioRegular: string;
  precioOferta: string;
  descuentoPorcentaje: string;
  costoReferencial: string;
  fechaInicio: string;
  fechaFin: string;
  estadoLogico: 'A' | 'I';
  estadoOperativo: 'PROGRAMADA' | 'VIGENTE' | 'VENCIDA' | 'INACTIVA';
  version: string;
}

export interface ProductPresentationOption {
  productoId: number;
  codigoProducto: string;
  nombreProducto: string;
  presentacionId: number;
  presentacionNombre: string;
  unidadBase: string;
  precioRegular: string;
  costoReferencial: string;
  permiteVenta: boolean;
}

export interface OfferListResponse {
  items: OfferRow[];
  total: number;
  pagina: number;
  tamano: number;
}

export interface OfferCreateRequest {
  productoId: number;
  presentacionId: number;
  nombre: string;
  precioOferta: number;
  fechaInicio: string;
  fechaFin: string;
}

export interface OfferUpdateRequest {
  nombre: string;
  precioOferta: number;
  fechaInicio?: string | null;
  fechaFin: string;
  version?: string | null;
}

export interface OfferStateRequest {
  estado: 'A' | 'I';
  version?: string | null;
}

@Injectable({providedIn: 'root'})
export class OfferService {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL) + '/ofertas';

  getSummary(): Observable<OfferSummary> {
    return this.http.get<OfferSummary>(`${this.base}/resumen`);
  }

  getOffers(params: {
    buscar?: string;
    estado?: string;
    categoriaId?: number | null;
    pagina?: number;
    tamano?: number;
  }): Observable<OfferListResponse> {
    let httpParams = new HttpParams();
    if (params.buscar) httpParams = httpParams.set('buscar', params.buscar);
    if (params.estado) httpParams = httpParams.set('estado', params.estado);
    if (params.categoriaId != null && params.categoriaId > 0) {
      httpParams = httpParams.set('categoriaId', params.categoriaId.toString());
    }
    if (params.pagina != null) httpParams = httpParams.set('pagina', params.pagina.toString());
    if (params.tamano != null) httpParams = httpParams.set('tamano', params.tamano.toString());

    return this.http.get<OfferListResponse>(this.base, {params: httpParams});
  }

  getOffer(id: number): Observable<OfferRow> {
    return this.http.get<OfferRow>(`${this.base}/${id}`);
  }

  getAvailableProducts(buscar?: string): Observable<ProductPresentationOption[]> {
    let httpParams = new HttpParams();
    if (buscar) httpParams = httpParams.set('buscar', buscar);
    return this.http.get<ProductPresentationOption[]>(`${this.base}/productos-disponibles`, {params: httpParams});
  }

  createOffer(req: OfferCreateRequest): Observable<OfferRow> {
    return this.http.post<OfferRow>(this.base, req);
  }

  updateOffer(id: number, req: OfferUpdateRequest): Observable<OfferRow> {
    return this.http.put<OfferRow>(`${this.base}/${id}`, req);
  }

  changeState(id: number, req: OfferStateRequest): Observable<OfferRow> {
    return this.http.patch<OfferRow>(`${this.base}/${id}/estado`, req);
  }
}

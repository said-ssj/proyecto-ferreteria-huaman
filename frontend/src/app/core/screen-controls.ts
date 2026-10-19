import {Field} from './screens';
export interface ScreenAction {label:string;icon:string;}
export interface ScreenControls {filters?:Field[];checks?:string[];actions?:ScreenAction[];}
const status=(options:string[]):Field=>({label:'Estado',type:'select',options:['Todos',...options]});
const lookup=(label:string):Field=>({label,type:'select'});
const dates:Field[]=[{label:'Desde',type:'date'},{label:'Hasta',type:'date'}];
const active=status(['Activos','Inactivos']);
const action=(label:string,icon='visibility'):ScreenAction=>({label,icon});
export const SCREEN_CONTROLS:Record<string,ScreenControls>={
 usuarios:{filters:[lookup('Rol'),status(['Activos','Inactivos','Bloqueados'])],actions:[action('Ver usuario'),action('Editar usuario','edit'),action('Desbloquear','lock_open')]},
 roles:{actions:[action('Ver permisos','admin_panel_settings'),action('Editar permisos','edit')]},
 bitacora:{filters:[...dates,lookup('Usuario'),lookup('Acción')],actions:[action('Ver detalle')]},
 'comprobantes/series':{filters:[{label:'Tipo de documento',type:'select',options:['Boleta','Factura','Nota de venta']},active],actions:[action('Ver serie'),action('Editar serie','edit')]},
 productos:{filters:[lookup('Categoría'),lookup('Unidad de medida'),active],checks:['Solo stock bajo','Con oferta'],actions:[action('Ver producto'),action('Editar producto','edit'),action('Desactivar','block'),action('Imprimir etiquetas','print')]},
 categorias:{filters:[active],actions:[action('Editar','edit'),action('Desactivar','block')]},
 proveedores:{filters:[active],actions:[action('Ver proveedor'),action('Editar proveedor','edit')]},
 clientes:{filters:[{label:'Tipo de documento',type:'select',options:['DNI','RUC']},active],actions:[action('Ver cliente'),action('Editar cliente','edit'),action('Estado de cuenta','account_balance_wallet')]},
 'compras/ordenes':{filters:[...dates,lookup('Proveedor'),status(['Borrador','Emitida','Parcial','Completa','Anulada'])],actions:[action('Ver documento'),action('Editar borrador','edit'),action('Emitir orden','check'),action('Anular orden','block')]},
 'compras/ingresos':{filters:[...dates,lookup('Proveedor'),status(['Borrador','Confirmado','Anulado'])],actions:[action('Ver ingreso'),action('Confirmar ingreso','check'),action('Anular borrador','block')]},
 inventario:{filters:[lookup('Categoría'),lookup('Producto'),lookup('Unidad de medida')],checks:['Solo stock bajo'],actions:[action('Ver kardex','history')]},
 'inventario/alertas':{filters:[lookup('Categoría'),status(['Abiertas','Cerradas'])]},
 'inventario/ajustes':{filters:[...dates,lookup('Producto'),{label:'Tipo de ajuste',type:'select',options:['Aumento','Disminución']}],actions:[action('Ver ajuste')]},
 'inventario/tomas':{filters:[...dates,status(['En conteo','Cerrada','Aprobada','Anulada'])],actions:[action('Continuar conteo','edit_note'),action('Guardar conteo','save'),action('Cerrar conteo','check'),action('Reabrir conteo','restart_alt'),action('Aprobar y ajustar','fact_check'),action('Anular toma','block')]},
 'ventas/historial':{filters:[...dates,lookup('Vendedor'),{label:'Comprobante',type:'select',options:['Boleta','Factura','Nota de venta']},status(['Confirmada','Anulada'])],actions:[action('Ver venta'),action('Imprimir comprobante','print'),action('Copiar datos de venta','content_copy'),action('Descargar XML','download'),action('Anular venta','block')]},
 cotizaciones:{filters:[...dates,status(['Borrador','Vigente','Vencida','Convertida','Anulada'])],actions:[action('Ver cotización'),action('Editar borrador','edit'),action('Recalcular','calculate'),action('Convertir a venta','point_of_sale'),action('Anular cotización','block')]},
 ofertas:{filters:[...dates,lookup('Producto'),status(['Programada','Vigente','Finalizada','Inactiva'])],actions:[action('Editar oferta','edit'),action('Desactivar oferta','block')]},
 creditos:{filters:[lookup('Cliente'),status(['Pendiente','Vencida','Cancelada'])],actions:[action('Estado de cuenta','account_balance_wallet'),action('Registrar abono','payments'),action('Imprimir estado','print')]},
 devoluciones:{filters:[...dates,status(['Pendiente','Aprobada','Rechazada'])],actions:[action('Revisar solicitud'),action('Aprobar devolución','check'),action('Rechazar devolución','close')]},
 'caja/historial':{filters:[...dates,lookup('Responsable'),status(['Abierta','Cerrada'])],actions:[action('Ver cuadre','fact_check'),action('Imprimir cuadre','print')]},
 despachos:{filters:[...dates,status(['Pendiente','Preparado','Entregado','Anulado'])],actions:[action('Hoja de preparación','description'),action('Marcar preparado','inventory_2'),action('Confirmar entrega','local_shipping')]},
};
export const DOCUMENT_ACTIONS:Record<string,ScreenAction[]>={
 'compras/ordenes/nueva':[action('Guardar borrador','save'),action('Emitir orden','check')],
 'compras/ingresos/nuevo':[action('Guardar borrador','save'),action('Confirmar ingreso','check')],
 'cotizaciones/nueva':[action('Guardar borrador','save'),action('Emitir cotización','request_quote')],
 'devoluciones/nueva':[action('Solicitar devolución','assignment_return')],
 'inventario/fraccionamiento':[action('Confirmar apertura de envase','inventory'),action('Confirmar corte','content_cut')],
 'configuracion/tickets':[action('Guardar configuración','save'),action('Generar etiquetas','print')],
};

-- FERRETERIA HUAMAN - BLOQUE23 - anular venta interna
-- Requiere01 a22. Solo instala; no anula ventas reales.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.aprobar_devolucion(bigint,bigint,uuid,text,text)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque22'; END IF;
IF to_regprocedure('huaman.anular_venta(bigint,uuid,text,boolean,jsonb,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque23 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE venta ADD COLUMN clave_anulacion uuid UNIQUE;
ALTER TABLE venta ADD COLUMN retorno_confirmado boolean NOT NULL DEFAULT false;
ALTER TABLE venta ADD COLUMN referencias_anulacion jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(referencias_anulacion)='object');
ALTER TABLE unidad_existencia ADD COLUMN id_detalle_anulacion bigint;
ALTER TABLE unidad_existencia ADD CONSTRAINT fk_unidad_anulacion FOREIGN KEY(id_detalle_anulacion,id_producto) REFERENCES detalle_venta(id_detalle_venta,id_producto) ON DELETE RESTRICT;
ALTER TABLE unidad_existencia DROP CONSTRAINT ck_unidad_origen_unico;
ALTER TABLE unidad_existencia ADD CONSTRAINT ck_unidad_origen_unico CHECK(num_nonnulls(id_detalle_ingreso,id_transformacion_origen,referencia_apertura,id_ajuste_origen,id_toma_origen,id_detalle_devolucion,id_detalle_anulacion)=1);
CREATE UNIQUE INDEX ux_mov_anulacion_medio ON movimiento_caja(id_venta,medio) WHERE tipo_movimiento='ANULACION';
CREATE UNIQUE INDEX ux_anular_venta_evento ON bitacora_evento(referencia) WHERE accion='VEN.ANULAR';
CREATE UNIQUE INDEX ux_anulacion_yape_dia ON venta((fecha_anulacion::date),(referencias_anulacion->>'YAPE')) WHERE estado_venta='ANULADA' AND referencias_anulacion?'YAPE';
CREATE FUNCTION huaman.validar_yape_reintegro_cruzado() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE dia date;ref text;
BEGIN
IF TG_TABLE_NAME='venta' THEN
IF NEW.estado_venta<>'ANULADA' OR OLD.estado_venta='ANULADA' OR NOT (NEW.referencias_anulacion?'YAPE') THEN RETURN NEW; END IF;
dia:=NEW.fecha_anulacion::date;ref:=NEW.referencias_anulacion->>'YAPE';
ELSE
IF NEW.estado_devolucion<>'APROBADA' OR OLD.estado_devolucion='APROBADA' OR NEW.forma_reintegro<>'YAPE' THEN RETURN NEW; END IF;
dia:=NEW.fecha_decision::date;ref:=NEW.referencia_reintegro;
END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('YAPE_REINTEGRO:'||dia::text||':'||ref,0));
IF TG_TABLE_NAME='venta' THEN
IF EXISTS(SELECT 1 FROM huaman.devolucion WHERE estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='YAPE' AND fecha_decision::date=dia AND referencia_reintegro=ref) THEN RAISE EXCEPTION 'Referencia de salida Yape ya usada en devolucion'; END IF;
ELSE
IF EXISTS(SELECT 1 FROM huaman.venta WHERE estado_venta='ANULADA' AND fecha_anulacion::date=dia AND referencias_anulacion->>'YAPE'=ref) THEN RAISE EXCEPTION 'Referencia de salida Yape ya usada en anulacion'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER yape_reintegro_cruzado BEFORE UPDATE ON venta FOR EACH ROW EXECUTE FUNCTION huaman.validar_yape_reintegro_cruzado();
CREATE TRIGGER yape_reintegro_cruzado BEFORE UPDATE ON devolucion FOR EACH ROW EXECUTE FUNCTION huaman.validar_yape_reintegro_cruzado();

CREATE FUNCTION huaman._anulacion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'')='ANULAR_VENTA'
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA','TRANSFORMAR_EXISTENCIA','REGISTRAR_AJUSTE','APROBAR_TOMA','APROBAR_DEVOLUCION','ANULAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._caja_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('ABRIR_CAJA','MOVIMIENTO_MANUAL_CAJA','CERRAR_CAJA','CONFIRMAR_VENTA','REGISTRAR_ABONO','APROBAR_DEVOLUCION','ANULAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_venta_borrador() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cli huaman.cliente%ROWTYPE; caj huaman.caja_diaria%ROWTYPE;
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._anulacion_en_curso(),false) THEN
IF OLD.estado_venta<>'CONFIRMADA' OR NEW.estado_venta<>'ANULADA' OR NEW.clave_anulacion IS NULL OR NEW.id_usuario_anula IS NULL OR NEW.fecha_anulacion IS NULL OR length(btrim(coalesce(NEW.motivo_anulacion,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['base_imponible','igv','estado_venta','clave_anulacion','id_usuario_anula','fecha_anulacion','motivo_anulacion','retorno_confirmado','referencias_anulacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['base_imponible','igv','estado_venta','clave_anulacion','id_usuario_anula','fecha_anulacion','motivo_anulacion','retorno_confirmado','referencias_anulacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion altera datos no autorizados'; END IF;
RETURN NEW;
END IF;
IF TG_OP='UPDATE' AND NEW.id_cotizacion IS DISTINCT FROM OLD.id_cotizacion THEN RAISE EXCEPTION 'Vinculo de cotizacion inmutable'; END IF;
IF TG_OP='UPDATE' AND OLD.estado_venta<>'BORRADOR' THEN RAISE EXCEPTION 'Venta confirmada/anulada inmutable fuera de proceso de reversa'; END IF;
IF TG_OP='UPDATE' AND coalesce(huaman._venta_en_curso(),false) THEN
  IF current_setting('app.proceso',true)='DESCARTAR_VENTA' THEN
    IF (to_jsonb(NEW)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado','subtotal','descuento_total','total','base_imponible','igv','clave_descarte','motivo_descarte'])
      IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado','subtotal','descuento_total','total','base_imponible','igv','clave_descarte','motivo_descarte']) THEN RAISE EXCEPTION 'Descarte altera identidad de venta'; END IF;
    RETURN NEW;
  ELSIF NEW.estado_venta='CONFIRMADA' THEN
    IF (to_jsonb(NEW)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado_venta','base_imponible','igv'])
      IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado_venta','base_imponible','igv']) THEN RAISE EXCEPTION 'Confirmacion altera datos pendientes'; END IF;
    RETURN NEW;
  END IF;
END IF;
IF TG_OP='UPDATE' AND NEW.estado<>OLD.estado THEN RAISE EXCEPTION 'Descartar mediante proceso autorizado'; END IF;
IF NEW.clave_descarte IS NOT NULL OR NEW.motivo_descarte IS NOT NULL THEN RAISE EXCEPTION 'Descarte solo mediante proceso'; END IF;
IF NEW.estado_venta<>'BORRADOR' THEN RAISE EXCEPTION 'Confirmacion/anulacion pendiente de movimientos de inventario, caja y credito'; END IF;
SELECT * INTO caj FROM huaman.caja_diaria WHERE id_caja=NEW.id_caja FOR UPDATE;
IF NOT FOUND OR caj.estado_caja<>'ABIERTA' OR caj.estado<>'A' OR caj.fecha<>NEW.fecha_venta::date THEN RAISE EXCEPTION 'Venta requiere caja abierta de la fecha indicada'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_vendedor AND estado='A') THEN RAISE EXCEPTION 'Vendedor inexistente o inactivo'; END IF;
IF NEW.id_cliente IS NULL THEN
NEW.cliente_tipo_doc:=NULL;NEW.cliente_nro_doc:=NULL;NEW.cliente_nombre:='CLIENTE VARIOS';NEW.cliente_direccion:=NULL;
ELSE
SELECT * INTO cli FROM huaman.cliente WHERE id_cliente=NEW.id_cliente AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Cliente inexistente o inactivo'; END IF;
NEW.cliente_tipo_doc:=cli.tipo_documento;NEW.cliente_nro_doc:=cli.nro_documento;NEW.cliente_nombre:=cli.nombre_razon_social;NEW.cliente_direccion:=cli.direccion;
END IF;
IF NEW.tipo_comprobante='F' AND (NEW.id_cliente IS NULL OR NEW.cliente_tipo_doc<>'RUC') THEN RAISE EXCEPTION 'Factura requiere cliente con RUC, razon social y direccion'; END IF;
IF NEW.id_venta_origen IS NOT NULL AND NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta_origen AND estado_venta='CONFIRMADA') THEN RAISE EXCEPTION 'Venta origen no confirmada'; END IF;
IF NEW.id_cotizacion IS NOT NULL AND TG_OP='INSERT' AND (NOT coalesce(huaman._cotizacion_en_curso(),false) OR current_setting('app.proceso',true)<>'CONVERTIR_COTIZACION') THEN RAISE EXCEPTION 'Vincular cotizacion mediante conversion'; END IF;
IF TG_OP='INSERT' AND (NEW.subtotal<>0 OR NEW.descuento_total<>0 OR NEW.total<>0) THEN RAISE EXCEPTION 'Totales se calculan desde detalles'; END IF;
IF TG_OP='UPDATE' THEN
IF (NEW.subtotal,NEW.descuento_total,NEW.total) IS DISTINCT FROM (OLD.subtotal,OLD.descuento_total,OLD.total) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar totales manualmente'; END IF;
IF (NEW.id_caja,NEW.id_vendedor,NEW.fecha_venta,NEW.clave_idempotencia,NEW.igv_porcentaje,NEW.id_venta_origen) IS DISTINCT FROM (OLD.id_caja,OLD.id_vendedor,OLD.fecha_venta,OLD.clave_idempotencia,OLD.igv_porcentaje,OLD.id_venta_origen) THEN RAISE EXCEPTION 'Identidad y base fiscal del borrador inmutables'; END IF;
IF EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' GROUP BY id_venta HAVING sum(monto)>NEW.total) THEN RAISE EXCEPTION 'Reducir pagos provisionales antes de reducir el total'; END IF;
IF NEW.id_cliente IS NULL AND EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' AND medio='CREDITO') THEN RAISE EXCEPTION 'Fiado requiere cliente identificado'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.bloquear_emision_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;s huaman.serie_comprobante%ROWTYPE;
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._anulacion_en_curso(),false) THEN
IF OLD.estado_comprobante<>'EMITIDO' OR OLD.estado_tributario NOT IN ('NO_INTEGRADO','NO_APLICA') OR NEW.estado_comprobante<>'ANULADO' OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta AND estado_venta='ANULADA') OR (to_jsonb(NEW)-ARRAY['estado_comprobante','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_comprobante','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion interna no modifica documento fiscal ni numeracion'; END IF;
RETURN NEW;
END IF;
IF TG_OP<>'INSERT' OR NOT coalesce(huaman._venta_en_curso(),false) OR current_setting('app.proceso',true)<>'CONFIRMAR_VENTA' THEN RAISE EXCEPTION 'Comprobante solo mediante confirmacion autorizada'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;SELECT * INTO s FROM huaman.serie_comprobante WHERE id_serie=NEW.id_serie;
IF v.estado_venta<>'CONFIRMADA' OR s.estado<>'A' OR NEW.tipo_comprobante<>v.tipo_comprobante OR NEW.tipo_comprobante<>s.tipo_comprobante OR NEW.serie<>s.serie OR NEW.numero<>s.ultimo_correlativo OR (NEW.base_imponible,NEW.igv,NEW.total) IS DISTINCT FROM (v.base_imponible,v.igv,v.total) THEN RAISE EXCEPTION 'Comprobante incompatible con venta o serie'; END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_despacho_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;modo text:=current_setting('app.proceso',true);
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._anulacion_en_curso(),false) THEN
IF OLD.estado_despacho='ANULADO' OR NEW.estado_despacho<>'ANULADO' OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta AND estado_venta='ANULADA') OR (to_jsonb(NEW)-ARRAY['estado_despacho','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_despacho','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion conserva historial del despacho'; END IF;
RETURN NEW;
END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' OR v.entrega_inmediata THEN RAISE EXCEPTION 'Despacho requiere venta confirmada con entrega pendiente'; END IF;
IF TG_OP='INSERT' THEN
IF NOT coalesce(huaman._venta_en_curso(),false) OR modo<>'CONFIRMAR_VENTA' OR NEW.estado_despacho<>'PENDIENTE' OR NEW.estado<>'A' OR num_nonnulls(NEW.id_prepara,NEW.fecha_preparacion,NEW.id_entrega,NEW.fecha_entrega,NEW.recibe_nombre,NEW.clave_preparacion,NEW.clave_entrega,NEW.observacion_preparacion,NEW.observacion_entrega)>0 THEN RAISE EXCEPTION 'Despacho solo se crea pendiente mediante confirmacion de venta'; END IF;
RETURN NEW;
END IF;
IF NOT coalesce(huaman._despacho_en_curso(),false) OR OLD.estado<>'A' OR NEW.estado<>'A' THEN RAISE EXCEPTION 'Modificar despacho solo mediante proceso habilitado'; END IF;
IF modo='PREPARAR_DESPACHO' THEN
IF OLD.estado_despacho<>'PENDIENTE' OR NEW.estado_despacho<>'PREPARADO' OR NEW.id_prepara IS NULL OR NEW.fecha_preparacion IS NULL OR NEW.clave_preparacion IS NULL OR (to_jsonb(NEW)-ARRAY['estado_despacho','id_prepara','fecha_preparacion','clave_preparacion','observacion_preparacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_despacho','id_prepara','fecha_preparacion','clave_preparacion','observacion_preparacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Transicion de preparacion invalida'; END IF;
ELSIF modo='ENTREGAR_DESPACHO' THEN
IF OLD.estado_despacho<>'PREPARADO' OR NEW.estado_despacho<>'ENTREGADO' OR NEW.id_prepara IS NULL OR NEW.fecha_preparacion IS NULL OR NEW.id_entrega IS NULL OR NEW.fecha_entrega IS NULL OR NEW.fecha_entrega<NEW.fecha_preparacion OR NEW.clave_entrega IS NULL OR (to_jsonb(NEW)-ARRAY['estado_despacho','id_entrega','fecha_entrega','clave_entrega','recibe_nombre','observacion_entrega','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_despacho','id_entrega','fecha_entrega','clave_entrega','recibe_nombre','observacion_entrega','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Transicion de entrega invalida'; END IF;
ELSE RAISE EXCEPTION 'Operacion de despacho no habilitada'; END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.bloquear_credito_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
IF coalesce(huaman._anulacion_en_curso(),false) THEN
IF TG_OP<>'UPDATE' OR TG_TABLE_NAME<>'cuenta_por_cobrar' THEN RAISE EXCEPTION 'Anulacion solo cierra deuda existente'; END IF;
IF NEW.saldo<>0 OR NEW.estado_cuenta<>'ANULADA' OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta AND estado_venta='ANULADA') OR EXISTS(SELECT 1 FROM huaman.abono_credito WHERE id_cuenta=NEW.id_cuenta AND estado='A') OR (to_jsonb(NEW)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'No anular deuda con abonos ni alterar monto original'; END IF;
RETURN NEW;
END IF;
IF coalesce(huaman._devolucion_en_curso(),false) AND current_setting('app.proceso',true)='APROBAR_DEVOLUCION' THEN
IF TG_TABLE_NAME<>'cuenta_por_cobrar' OR TG_OP<>'UPDATE' THEN RAISE EXCEPTION 'Devolucion solo reduce deuda existente'; END IF;
IF (to_jsonb(NEW)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) OR NEW.saldo>=OLD.saldo OR NEW.saldo<0 OR NEW.saldo<>NEW.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=NEW.id_cuenta AND estado='A')-(SELECT coalesce(sum(monto_reintegro),0) FROM huaman.devolucion WHERE id_venta=NEW.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DESCUENTO_DEUDA') OR NEW.estado_cuenta<>(CASE WHEN NEW.saldo=0 THEN 'CANCELADA' WHEN NEW.fecha_vencimiento<timezone('America/Lima',now())::date THEN 'VENCIDA' ELSE 'PENDIENTE' END) THEN RAISE EXCEPTION 'Saldo no concilia con devolucion aprobada'; END IF;
RETURN NEW;
END IF;
IF coalesce(huaman._abono_en_curso(),false) THEN
IF TG_TABLE_NAME='abono_credito' AND TG_OP='INSERT' THEN
IF NEW.estado<>'A' OR NEW.fecha_abono::date<>timezone('America/Lima',now())::date OR NOT EXISTS(SELECT 1 FROM huaman.caja_diaria WHERE id_caja=NEW.id_caja AND estado='A' AND estado_caja='ABIERTA' AND fecha=NEW.fecha_abono::date) OR NOT EXISTS(SELECT 1 FROM huaman.cuenta_por_cobrar WHERE id_cuenta=NEW.id_cuenta AND estado='A' AND estado_cuenta IN ('PENDIENTE','VENCIDA') AND saldo>=NEW.monto) THEN RAISE EXCEPTION 'Abono incompatible con deuda o caja'; END IF;
RETURN NEW;
ELSIF TG_TABLE_NAME='cuenta_por_cobrar' AND TG_OP='UPDATE' THEN
IF (to_jsonb(NEW)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) OR NEW.saldo>=OLD.saldo OR NEW.saldo<0 OR NEW.saldo<>NEW.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=NEW.id_cuenta AND estado='A')-(SELECT coalesce(sum(monto_reintegro),0) FROM huaman.devolucion WHERE id_venta=NEW.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DESCUENTO_DEUDA') OR NEW.estado_cuenta<>(CASE WHEN NEW.saldo=0 THEN 'CANCELADA' WHEN NEW.fecha_vencimiento<timezone('America/Lima',now())::date THEN 'VENCIDA' ELSE 'PENDIENTE' END) THEN RAISE EXCEPTION 'Actualizacion de deuda incompatible con abonos'; END IF;
RETURN NEW;
END IF;
RAISE EXCEPTION 'Operacion de credito no habilitada';
END IF;
IF TG_TABLE_NAME<>'cuenta_por_cobrar' OR TG_OP<>'INSERT' OR NOT coalesce(huaman._venta_en_curso(),false) OR current_setting('app.proceso',true)<>'CONFIRMAR_VENTA' THEN RAISE EXCEPTION 'Credito solo mediante proceso habilitado'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado_venta<>'CONFIRMADA' OR v.id_cliente IS DISTINCT FROM NEW.id_cliente OR NEW.monto_original<>v.total OR NEW.saldo<>v.total OR NEW.estado_cuenta<>'PENDIENTE' OR NEW.fecha_vencimiento<v.fecha_venta::date OR NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=v.id_venta AND medio='CREDITO' AND monto=v.total AND estado='A') THEN RAISE EXCEPTION 'Cuenta no coincide con fiado confirmado'; END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_movimiento_monetario() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE c huaman.caja_diaria%ROWTYPE;disponible numeric;modo text;
BEGIN
IF NOT coalesce(huaman._caja_en_curso(),false) THEN RAISE EXCEPTION 'Movimiento sin proceso autorizado'; END IF;
modo:=current_setting('app.proceso',true);
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=NEW.id_caja FOR UPDATE;
IF NOT FOUND OR c.estado_caja<>'ABIERTA' OR c.estado<>'A' THEN RAISE EXCEPTION 'Caja no disponible'; END IF;
IF NEW.tipo_movimiento='APERTURA' THEN
IF modo<>'ABRIR_CAJA' OR NEW.medio<>'EFECTIVO' OR NEW.sentido<>'I' OR NEW.importe<>c.monto_inicial OR NEW.clave_idempotencia IS DISTINCT FROM c.clave_apertura THEN RAISE EXCEPTION 'Movimiento de apertura incompatible'; END IF;
ELSIF NEW.tipo_movimiento IN ('INGRESO_MANUAL','EGRESO_MANUAL') THEN
IF modo<>'MOVIMIENTO_MANUAL_CAJA' OR NEW.medio<>'EFECTIVO' THEN RAISE EXCEPTION 'Movimiento manual solo de efectivo'; END IF;
ELSIF NEW.tipo_movimiento='VENTA' THEN
IF modo<>'CONFIRMAR_VENTA' OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta AND id_caja=NEW.id_caja AND estado_venta='CONFIRMADA') OR NEW.importe<>(SELECT coalesce(sum(monto),0) FROM huaman.pago WHERE id_venta=NEW.id_venta AND medio=NEW.medio AND estado='A') THEN RAISE EXCEPTION 'Cobro no coincide con venta/pago'; END IF;
ELSIF NEW.tipo_movimiento='ABONO' THEN
IF modo<>'REGISTRAR_ABONO' OR NOT EXISTS(SELECT 1 FROM huaman.abono_credito WHERE id_abono=NEW.id_abono AND id_caja=NEW.id_caja AND medio=NEW.medio AND monto=NEW.importe AND clave_idempotencia=NEW.clave_idempotencia AND estado='A') THEN RAISE EXCEPTION 'Movimiento incompatible con abono'; END IF;
ELSIF NEW.tipo_movimiento='DEVOLUCION' THEN
IF modo<>'APROBAR_DEVOLUCION' OR NOT EXISTS(SELECT 1 FROM huaman.devolucion WHERE id_devolucion=NEW.id_devolucion AND id_caja=NEW.id_caja AND forma_reintegro=NEW.medio AND monto_reintegro=NEW.importe AND clave_aprobacion=NEW.clave_idempotencia AND estado='A' AND estado_devolucion='APROBADA') THEN RAISE EXCEPTION 'Egreso no coincide con devolucion aprobada'; END IF;
ELSIF NEW.tipo_movimiento='ANULACION' THEN
IF modo<>'ANULAR_VENTA' OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta AND id_caja=NEW.id_caja AND estado_venta='ANULADA') OR NEW.importe<>(SELECT coalesce(sum(monto),0) FROM huaman.pago WHERE id_venta=NEW.id_venta AND medio=NEW.medio AND estado='A') THEN RAISE EXCEPTION 'Reversa no coincide con pago original'; END IF;
ELSE RAISE EXCEPTION 'Reintegro no habilitado'; END IF;
SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) INTO disponible FROM huaman.movimiento_caja WHERE id_caja=NEW.id_caja AND medio=NEW.medio;
IF disponible+(CASE WHEN NEW.sentido='I' THEN NEW.importe ELSE -NEW.importe END)<0 THEN RAISE EXCEPTION 'Egreso supera saldo disponible'; END IF;
RETURN NEW;
END $$;
CREATE FUNCTION huaman.anular_venta(p_venta bigint,p_clave uuid,p_motivo text,p_confirmar_retorno boolean DEFAULT false,p_unidades jsonb DEFAULT '[]'::jsonb,p_referencias jsonb DEFAULT '{}'::jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;c huaman.caja_diaria%ROWTYPE;comp huaman.comprobante_venta%ROWTYPE;cc huaman.cuenta_por_cobrar%ROWTYPE;ds huaman.despacho%ROWTYPE;d huaman.detalle_venta%ROWTYPE;prod huaman.producto%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;
sol jsonb;motivo text:=nullif(btrim(p_motivo),'');previo text;item jsonb;pieza jsonb;plan jsonb;ids bigint[]:='{}';lid bigint;cantidad numeric;saldo_nuevo numeric;promedio numeric;mov bigint;pres_base bigint;numero integer;condicion text;pa record;ref text;
BEGIN
actor:=huaman._actor_con_permiso('VEN.ANULAR');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador anula ventas'; END IF;
IF p_venta IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' OR p_confirmar_retorno IS NULL OR p_unidades IS NULL OR jsonb_typeof(p_unidades)<>'array' OR jsonb_array_length(p_unidades)>1000 OR p_referencias IS NULL OR jsonb_typeof(p_referencias)<>'object' OR p_referencias-ARRAY['YAPE','DEBITO']<>'{}'::jsonb THEN RAISE EXCEPTION 'Datos de anulacion invalidos'; END IF;
sol:=jsonb_build_object('venta',p_venta,'motivo',motivo,'retorno_confirmado',p_confirmar_retorno,'unidades',p_unidades,'referencias',p_referencias);
PERFORM pg_advisory_xact_lock(hashtextextended('ANULAR_VENTA:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE accion='VEN.ANULAR' AND referencia=p_clave::text;
IF FOUND THEN IF b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra anulacion'; END IF;RETURN b.id_entidad;END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta;
IF NOT FOUND THEN RAISE EXCEPTION 'Venta inexistente'; END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=v.id_caja FOR UPDATE;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta FOR UPDATE;
IF c.estado<>'A' OR c.estado_caja<>'ABIERTA' OR c.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'La caja original debe seguir abierta y ser del dia'; END IF;
IF v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' THEN RAISE EXCEPTION 'Venta no confirmada o ya anulada'; END IF;
IF EXISTS(SELECT 1 FROM huaman.devolucion WHERE id_venta=p_venta AND estado='A' AND estado_devolucion IN ('PENDIENTE','APROBADA')) THEN RAISE EXCEPTION 'Venta con devolucion aprobada o pendiente; resolver solicitud antes de anular'; END IF;
IF v.id_cliente IS NOT NULL THEN PERFORM 1 FROM huaman.cliente WHERE id_cliente=v.id_cliente FOR UPDATE; END IF;
SELECT * INTO cc FROM huaman.cuenta_por_cobrar WHERE id_venta=p_venta FOR UPDATE;
IF cc.id_cuenta IS NOT NULL THEN
IF EXISTS(SELECT 1 FROM huaman.abono_credito WHERE id_cuenta=cc.id_cuenta AND estado='A') THEN RAISE EXCEPTION 'Venta al credito con abonos no se anula'; END IF;
IF cc.estado<>'A' OR cc.saldo<>cc.monto_original OR cc.estado_cuenta NOT IN ('PENDIENTE','VENCIDA') THEN RAISE EXCEPTION 'Cuenta requiere revision antes de anular'; END IF;
END IF;
SELECT * INTO ds FROM huaman.despacho WHERE id_venta=p_venta FOR UPDATE;
IF (v.entrega_inmediata OR ds.estado_despacho='ENTREGADO') AND NOT p_confirmar_retorno THEN RAISE EXCEPTION 'Confirmar retorno completo y apto de productos entregados; si hay danados usar devolucion'; END IF;
IF NOT v.entrega_inmediata AND (ds.id_despacho IS NULL OR ds.estado='I' OR ds.estado_despacho='ANULADO') THEN RAISE EXCEPTION 'Despacho inconsistente'; END IF;
SELECT * INTO comp FROM huaman.comprobante_venta WHERE id_venta=p_venta FOR UPDATE;
IF NOT FOUND OR comp.estado<>'A' OR comp.estado_comprobante<>'EMITIDO' OR comp.estado_tributario NOT IN ('NO_INTEGRADO','NO_APLICA') OR EXISTS(SELECT 1 FROM huaman.archivo_comprobante WHERE id_comprobante=comp.id_comprobante AND estado='A') THEN RAISE EXCEPTION 'Solo anulacion de comprobante interno no integrado; documento fiscal requiere otro flujo'; END IF;
FOR pa IN SELECT medio,sum(monto) monto FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio<>'CREDITO' GROUP BY medio LOOP
IF pa.medio='YAPE' THEN
IF jsonb_typeof(p_referencias->'YAPE') IS DISTINCT FROM 'string' OR coalesce(p_referencias->>'YAPE','') !~ '^[0-9]{6,20}$' THEN RAISE EXCEPTION 'Referencia de reintegro Yape requerida'; END IF;
ELSIF pa.medio='DEBITO' THEN
IF jsonb_typeof(p_referencias->'DEBITO') IS DISTINCT FROM 'string' OR length(btrim(coalesce(p_referencias->>'DEBITO',''))) NOT BETWEEN 1 AND 40 THEN RAISE EXCEPTION 'Referencia de reintegro debito requerida'; END IF;
END IF;
END LOOP;
IF (p_referencias?'YAPE' AND NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio='YAPE')) OR (p_referencias?'DEBITO' AND NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio='DEBITO')) THEN RAISE EXCEPTION 'Referencia sin medio de pago original'; END IF;
IF (SELECT coalesce(sum(monto),0) FROM huaman.pago WHERE id_venta=p_venta AND estado='A')<>v.total OR (EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio='CREDITO'))<>(cc.id_cuenta IS NOT NULL) THEN RAISE EXCEPTION 'Pagos o cuenta no conciliados con venta'; END IF;
-- Validate every physical line and prohibit extra/duplicate plans.
FOR item IN SELECT value FROM jsonb_array_elements(p_unidades) LOOP
IF jsonb_typeof(item)<>'object' OR item-ARRAY['id_detalle_venta','unidades']<>'{}'::jsonb OR jsonb_typeof(item->'id_detalle_venta') IS DISTINCT FROM 'number' OR (item->>'id_detalle_venta')::numeric<>trunc((item->>'id_detalle_venta')::numeric) THEN RAISE EXCEPTION 'Plan de retorno por linea invalido'; END IF;
lid:=(item->>'id_detalle_venta')::bigint;IF lid=ANY(ids) THEN RAISE EXCEPTION 'Linea fisica repetida'; END IF;ids:=array_append(ids,lid);
SELECT * INTO d FROM huaman.detalle_venta WHERE id_detalle_venta=lid AND id_venta=p_venta AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Plan de linea ajena'; END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=d.id_producto;
IF prod.modo_control='GRANEL' THEN RAISE EXCEPTION 'Granel no requiere plan fisico'; END IF;
PERFORM huaman.validar_plan_retorno(d.id_producto,d.cantidad_base,'APTO',item->'unidades');
END LOOP;
PERFORM 1 FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') ORDER BY id_producto FOR UPDATE;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') THEN RAISE EXCEPTION 'Venta sin lineas'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','ANULAR_VENTA',true);
FOR d IN SELECT * FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A' ORDER BY id_producto,id_detalle_venta LOOP
SELECT * INTO prod FROM huaman.producto WHERE id_producto=d.id_producto;
IF prod.estado<>'A' OR EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto inactivo o bloqueado por conteo'; END IF;
IF prod.modo_control<>'GRANEL' AND prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=prod.id_producto AND estado='A') THEN RAISE EXCEPTION 'Stock fisico no conciliado'; END IF;
cantidad:=d.cantidad_base;saldo_nuevo:=prod.stock_actual+cantidad;promedio:=round((prod.stock_actual*prod.costo_promedio+cantidad*d.costo_unitario_base)/saldo_nuevo,6);
IF promedio<=0 THEN RAISE EXCEPTION 'Costo historico invalido'; END IF;
IF prod.modo_control<>'GRANEL' THEN
SELECT value->'unidades' INTO plan FROM jsonb_array_elements(p_unidades) WHERE (value->>'id_detalle_venta')::bigint=d.id_detalle_venta;
IF plan IS NULL THEN RAISE EXCEPTION 'Falta plan fisico para linea'; END IF;
PERFORM huaman.validar_plan_retorno(d.id_producto,cantidad,'APTO',plan);
SELECT id_presentacion INTO pres_base FROM huaman.presentacion_producto WHERE id_producto=d.id_producto AND es_base AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Sin presentacion base activa'; END IF;
numero:=0;
FOR pieza IN SELECT value FROM jsonb_array_elements(plan) LOOP
numero:=numero+1;condicion:=pieza->>'condicion';
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_detalle_anulacion)
VALUES(d.id_producto,CASE WHEN condicion='ENVASE' THEN (pieza->>'id_presentacion')::bigint ELSE pres_base END,'AV-'||p_venta||'-'||d.id_detalle_venta||'-'||numero,condicion,(pieza->>'cantidad')::numeric,(pieza->>'cantidad')::numeric,d.id_detalle_venta);
END LOOP;
IF saldo_nuevo<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=d.id_producto AND estado='A') THEN RAISE EXCEPTION 'Retorno fisico no coincide con saldo'; END IF;
END IF;
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_venta,clave_idempotencia)
VALUES(d.id_producto,'ANULACION_VENTA','E',cantidad,prod.stock_actual,saldo_nuevo,d.costo_unitario_base,p_venta,gen_random_uuid()) RETURNING id_movimiento INTO mov;
UPDATE huaman.producto SET stock_actual=saldo_nuevo,costo_promedio=promedio WHERE id_producto=d.id_producto;
INSERT INTO huaman.historial_costo(id_producto,id_movimiento,motivo,referencia,stock_anterior,stock_nuevo,costo_promedio_anterior,costo_promedio_nuevo,ultimo_costo_anterior,ultimo_costo_nuevo)
VALUES(d.id_producto,mov,'Anulacion al costo historico','ANULACION:'||p_venta,prod.stock_actual,saldo_nuevo,prod.costo_promedio,promedio,prod.ultimo_costo_compra,prod.ultimo_costo_compra);
IF saldo_nuevo>prod.stock_minimo OR prod.stock_minimo=0 THEN
UPDATE huaman.alerta_stock SET estado_alerta='CERRADA',fecha_cierre=timezone('America/Lima',now()) WHERE id_producto=d.id_producto AND estado='A' AND estado_alerta='ABIERTA';
ELSIF NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=d.id_producto AND estado='A' AND estado_alerta='ABIERTA') THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(d.id_producto,saldo_nuevo,prod.stock_minimo);
END IF;
END LOOP;
UPDATE huaman.venta SET estado_venta='ANULADA',clave_anulacion=p_clave,motivo_anulacion=btrim(p_motivo),fecha_anulacion=timezone('America/Lima',now()),id_usuario_anula=actor,retorno_confirmado=p_confirmar_retorno,referencias_anulacion=p_referencias WHERE id_venta=p_venta;
UPDATE huaman.comprobante_venta SET estado_comprobante='ANULADO' WHERE id_comprobante=comp.id_comprobante;
IF cc.id_cuenta IS NOT NULL THEN
UPDATE huaman.cuenta_por_cobrar SET saldo=0,estado_cuenta='ANULADA' WHERE id_cuenta=cc.id_cuenta;
END IF;
FOR pa IN SELECT medio,sum(monto) monto FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio<>'CREDITO' GROUP BY medio LOOP
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,id_venta,clave_idempotencia) VALUES(v.id_caja,'ANULACION',pa.medio,'E',pa.monto,p_venta,gen_random_uuid());
END LOOP;
IF ds.id_despacho IS NOT NULL THEN UPDATE huaman.despacho SET estado_despacho='ANULADO' WHERE id_despacho=ds.id_despacho; END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'VEN.ANULAR','venta',p_venta,p_clave::text,jsonb_build_object('solicitud',sol,'comprobante',comp.id_comprobante,'serie',comp.serie,'numero',comp.numero,'total',v.total));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_venta;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'anular_venta' AS proceso,to_regprocedure('huaman.anular_venta(bigint,uuid,text,boolean,jsonb,jsonb)') IS NOT NULL AS instalado;

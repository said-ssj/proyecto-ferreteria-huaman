-- FERRETERIA HUAMAN - BLOQUE 12 - confirmar y descartar venta
-- Requiere 01 a 11, incluido 09B. Ejecutar completo una vez.
-- Solo instala. No crea ventas reales ni emite XML/aceptacion SUNAT.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.cerrar_caja(bigint,numeric,numeric,numeric,text,uuid)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 11'; END IF;
IF to_regprocedure('huaman.confirmar_venta(bigint,bigint,uuid,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 12 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE venta ADD COLUMN clave_descarte uuid UNIQUE;
ALTER TABLE venta ADD COLUMN motivo_descarte varchar(200);
ALTER TABLE presentacion_producto ADD COLUMN codigo_sunat varchar(3) CHECK (codigo_sunat ~ '^[A-Z0-9]{2,3}$');
ALTER TABLE detalle_venta ADD COLUMN codigo_unidad_sunat varchar(3) CHECK (codigo_unidad_sunat ~ '^[A-Z0-9]{2,3}$');
ALTER TABLE detalle_venta ADD COLUMN piezas_solicitadas integer NOT NULL DEFAULT 1 CHECK(piezas_solicitadas>0);
ALTER TABLE detalle_venta ADD COLUMN longitud_pieza_base numeric(18,6) CHECK(longitud_pieza_base>0);
ALTER TABLE detalle_venta ADD COLUMN base_imponible_linea numeric(18,2) CHECK(base_imponible_linea>=0);
ALTER TABLE detalle_venta ADD COLUMN igv_linea numeric(18,2) CHECK(igv_linea>=0);
ALTER TABLE detalle_venta ADD CONSTRAINT ck_linea_impuestos CHECK ((base_imponible_linea IS NULL AND igv_linea IS NULL) OR (base_imponible_linea IS NOT NULL AND igv_linea IS NOT NULL AND base_imponible_linea+igv_linea=importe));

CREATE FUNCTION huaman._venta_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('CONFIRMAR_VENTA','DESCARTAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._caja_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('ABRIR_CAJA','MOVIMIENTO_MANUAL_CAJA','CERRAR_CAJA','CONFIRMAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_venta_borrador() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cli huaman.cliente%ROWTYPE; caj huaman.caja_diaria%ROWTYPE;
BEGIN
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
IF NEW.id_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Conversion de cotizacion pendiente del bloque de procesos'; END IF;
IF TG_OP='INSERT' AND (NEW.subtotal<>0 OR NEW.descuento_total<>0 OR NEW.total<>0) THEN RAISE EXCEPTION 'Totales se calculan desde detalles'; END IF;
IF TG_OP='UPDATE' THEN
IF (NEW.subtotal,NEW.descuento_total,NEW.total) IS DISTINCT FROM (OLD.subtotal,OLD.descuento_total,OLD.total) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar totales manualmente'; END IF;
IF (NEW.id_caja,NEW.id_vendedor,NEW.fecha_venta,NEW.clave_idempotencia,NEW.igv_porcentaje,NEW.id_venta_origen) IS DISTINCT FROM (OLD.id_caja,OLD.id_vendedor,OLD.fecha_venta,OLD.clave_idempotencia,OLD.igv_porcentaje,OLD.id_venta_origen) THEN RAISE EXCEPTION 'Identidad y base fiscal del borrador inmutables'; END IF;
IF EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' GROUP BY id_venta HAVING sum(monto)>NEW.total) THEN RAISE EXCEPTION 'Reducir pagos provisionales antes de reducir el total'; END IF;
IF NEW.id_cliente IS NULL AND EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' AND medio='CREDITO') THEN RAISE EXCEPTION 'Fiado requiere cliente identificado'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_detalle_venta() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE c huaman.venta%ROWTYPE;p huaman.presentacion_producto%ROWTYPE;prod huaman.producto%ROWTYPE;
        mayor huaman.precio_mayorista%ROWTYPE;promo huaman.oferta%ROWTYPE;
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._venta_en_curso(),false) THEN
  IF current_setting('app.proceso',true)='CONFIRMAR_VENTA' THEN
    IF (to_jsonb(NEW)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','costo_unitario_base','base_imponible_linea','igv_linea','codigo_unidad_sunat','cantidad_base','importe','descuento_monto'])
      IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','costo_unitario_base','base_imponible_linea','igv_linea','codigo_unidad_sunat','cantidad_base','importe','descuento_monto']) THEN RAISE EXCEPTION 'Confirmacion no cambia cantidades o precios'; END IF;
  ELSE
    IF (to_jsonb(NEW)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado','cantidad_base','importe','descuento_monto'])
      IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['usucre','pccre','feccre','usmod','pcmod','fecmod','estado','cantidad_base','importe','descuento_monto']) THEN RAISE EXCEPTION 'Descarte no altera linea'; END IF;
  END IF;
  RETURN NEW;
END IF;
  SELECT * INTO c FROM huaman.venta WHERE id_venta=NEW.id_venta FOR UPDATE;
  IF NOT FOUND OR c.estado_venta<>'BORRADOR' OR c.estado<>'A' THEN RAISE EXCEPTION 'Cotizacion no editable'; END IF;
  IF TG_OP='UPDATE' AND NEW.id_venta<>OLD.id_venta THEN RAISE EXCEPTION 'No mover detalle a otra venta'; END IF;
  SELECT * INTO prod FROM huaman.producto WHERE id_producto=NEW.id_producto;
  IF NOT FOUND OR prod.estado<>'A' THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion FOR SHARE;
  IF NOT FOUND OR p.id_producto<>NEW.id_producto OR p.estado<>'A' OR NOT p.permite_venta THEN RAISE EXCEPTION 'Presentacion no disponible'; END IF;
  IF NEW.cantidad<p.minimo_venta OR mod(NEW.cantidad,p.incremento_venta)<>0 OR
     NEW.cantidad*p.factor_base<prod.minimo_venta_base OR mod(NEW.cantidad*p.factor_base,prod.incremento_base)<>0 THEN
    RAISE EXCEPTION 'Cantidad incompatible con minimo o incremento';
  END IF;
  NEW.producto_nombre:=prod.nombre;NEW.presentacion_nombre:=p.nombre;NEW.factor_base:=p.factor_base;
  SELECT abreviatura INTO NEW.unidad_base_simbolo FROM huaman.unidad_medida WHERE id_unidad=prod.id_unidad;
  NEW.costo_unitario_base:=prod.costo_promedio;NEW.precio_lista:=p.precio_normal;NEW.precio_unitario:=p.precio_normal;NEW.origen_precio:='NORMAL';NEW.id_oferta:=NULL;NEW.id_precio_mayorista:=NULL;
  SELECT * INTO mayor FROM huaman.precio_mayorista WHERE id_presentacion=p.id_presentacion AND estado='A' AND cantidad_minima<=NEW.cantidad ORDER BY cantidad_minima DESC LIMIT 1;
  IF FOUND AND mayor.precio<NEW.precio_unitario THEN NEW.precio_unitario:=mayor.precio;NEW.origen_precio:='MAYORISTA';NEW.id_precio_mayorista:=mayor.id_precio_mayorista; END IF;
  SELECT * INTO promo FROM huaman.oferta WHERE id_presentacion=p.id_presentacion AND estado='A' AND c.fecha_venta::date BETWEEN fecha_inicio AND fecha_fin;
  IF FOUND AND promo.precio_oferta<NEW.precio_unitario THEN NEW.precio_unitario:=promo.precio_oferta;NEW.origen_precio:='OFERTA';NEW.id_oferta:=promo.id_oferta;NEW.id_precio_mayorista:=NULL; END IF;
  RETURN NEW;
END $$;
CREATE FUNCTION huaman.validar_piezas_venta() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE p huaman.producto%ROWTYPE;pr huaman.presentacion_producto%ROWTYPE;cod text;
BEGIN
IF coalesce(huaman._venta_en_curso(),false) THEN RETURN NEW; END IF;
SELECT * INTO p FROM huaman.producto WHERE id_producto=NEW.id_producto;
SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion;
IF pr.id_unidad_venta IS NOT NULL THEN SELECT codigo_sunat INTO cod FROM huaman.unidad_medida WHERE id_unidad=pr.id_unidad_venta; END IF;
IF cod IS NOT NULL AND pr.codigo_sunat IS NOT NULL AND cod<>pr.codigo_sunat THEN RAISE EXCEPTION 'Codigo SUNAT incompatible con unidad fisica'; END IF;
NEW.codigo_unidad_sunat:=coalesce(cod,pr.codigo_sunat);
IF NEW.piezas_solicitadas IS NULL OR NEW.piezas_solicitadas<=0 THEN RAISE EXCEPTION 'Numero de piezas invalido'; END IF;
IF p.modo_control='TRAMOS' THEN
NEW.longitud_pieza_base:=NEW.cantidad*pr.factor_base/NEW.piezas_solicitadas;
IF mod(NEW.cantidad*pr.factor_base/NEW.piezas_solicitadas,p.incremento_base)<>0 THEN RAISE EXCEPTION 'Longitud por pieza incompatible'; END IF;
ELSE
IF NEW.piezas_solicitadas<>1 THEN RAISE EXCEPTION 'Piezas continuas solo para productos por tramos'; END IF;
NEW.longitud_pieza_base:=NULL;
END IF;
NEW.base_imponible_linea:=NULL;NEW.igv_linea:=NULL;
RETURN NEW;
END $$;
CREATE TRIGGER validar_piezas BEFORE INSERT OR UPDATE ON detalle_venta FOR EACH ROW EXECUTE FUNCTION huaman.validar_piezas_venta();
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
ELSE RAISE EXCEPTION 'Cobros y reintegros pendientes de sus procesos de venta/credito'; END IF;
SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) INTO disponible FROM huaman.movimiento_caja WHERE id_caja=NEW.id_caja AND medio=NEW.medio;
IF disponible+(CASE WHEN NEW.sentido='I' THEN NEW.importe ELSE -NEW.importe END)<0 THEN RAISE EXCEPTION 'Egreso supera saldo disponible'; END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.bloquear_credito_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
IF TG_TABLE_NAME<>'cuenta_por_cobrar' OR TG_OP<>'INSERT' OR NOT coalesce(huaman._venta_en_curso(),false) OR current_setting('app.proceso',true)<>'CONFIRMAR_VENTA' THEN RAISE EXCEPTION 'Credito solo mediante proceso habilitado'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado_venta<>'CONFIRMADA' OR v.id_cliente IS DISTINCT FROM NEW.id_cliente OR NEW.monto_original<>v.total OR NEW.saldo<>v.total OR NEW.estado_cuenta<>'PENDIENTE' OR NEW.fecha_vencimiento<v.fecha_venta::date OR NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=v.id_venta AND medio='CREDITO' AND monto=v.total AND estado='A') THEN RAISE EXCEPTION 'Cuenta no coincide con fiado confirmado'; END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.bloquear_emision_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;s huaman.serie_comprobante%ROWTYPE;
BEGIN
IF TG_OP<>'INSERT' OR NOT coalesce(huaman._venta_en_curso(),false) OR current_setting('app.proceso',true)<>'CONFIRMAR_VENTA' THEN RAISE EXCEPTION 'Comprobante solo mediante confirmacion autorizada'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;SELECT * INTO s FROM huaman.serie_comprobante WHERE id_serie=NEW.id_serie;
IF v.estado_venta<>'CONFIRMADA' OR s.estado<>'A' OR NEW.tipo_comprobante<>v.tipo_comprobante OR NEW.tipo_comprobante<>s.tipo_comprobante OR NEW.serie<>s.serie OR NEW.numero<>s.ultimo_correlativo OR (NEW.base_imponible,NEW.igv,NEW.total) IS DISTINCT FROM (v.base_imponible,v.igv,v.total) THEN RAISE EXCEPTION 'Comprobante incompatible con venta o serie'; END IF;
RETURN NEW;
END $$;

CREATE FUNCTION huaman.confirmar_venta(p_venta bigint,p_serie bigint,p_clave uuid,p_asignaciones jsonb DEFAULT '[]'::jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;c huaman.caja_diaria%ROWTYPE;s huaman.serie_comprobante%ROWTYPE;prod huaman.producto%ROWTYPE;
pr huaman.presentacion_producto%ROWTYPE;cli huaman.cliente%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;dv huaman.detalle_venta%ROWTYPE;
d record;pa record;item jsonb;previo text;precio numeric;origen text;oid bigint;mid bigint;cod text;saldo numeric;suma numeric;
comp bigint;numero integer;fid boolean;plazo integer;umbral numeric;igv_config numeric;negocio text;ruc text;direccion text;telefono text;formato text;version_plantilla integer;mensaje text;bit jsonb;
lid bigint;uid bigint;np integer;qty numeric;
BEGIN
actor:=huaman._actor_con_permiso('VEN.VENDER');
IF p_venta IS NULL OR p_serie IS NULL OR p_clave IS NULL OR p_asignaciones IS NULL OR jsonb_typeof(p_asignaciones)<>'array' THEN RAISE EXCEPTION 'Parametros incompletos'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta;
IF NOT FOUND THEN RAISE EXCEPTION 'Venta inexistente'; END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=v.id_caja FOR UPDATE;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta FOR UPDATE;
IF p_clave<>v.clave_idempotencia THEN RAISE EXCEPTION 'Usar la clave de idempotencia del borrador'; END IF;
IF v.estado_venta='CONFIRMADA' THEN
SELECT id_comprobante INTO comp FROM huaman.comprobante_venta WHERE id_venta=p_venta AND id_serie=p_serie;
SELECT valor_nuevo INTO bit FROM huaman.bitacora_evento WHERE accion='VEN.CONFIRMAR' AND entidad='venta' AND id_entidad=p_venta AND referencia=p_clave::text;
IF comp IS NULL OR bit->'asignaciones' IS DISTINCT FROM p_asignaciones THEN RAISE EXCEPTION 'Reintento con serie/asignaciones distintas'; END IF;
RETURN comp;
END IF;
IF v.estado_venta<>'BORRADOR' OR v.estado<>'A' OR c.estado_caja<>'ABIERTA' OR c.estado<>'A' OR c.fecha<>timezone('America/Lima',now())::date OR v.fecha_venta::date<>c.fecha OR v.total<=0 THEN RAISE EXCEPTION 'Venta o caja no disponibles'; END IF;
SELECT valor::numeric INTO igv_config FROM huaman.parametro_sistema WHERE clave='VENTAS.IGV_PORC' AND estado='A';
IF igv_config IS NULL OR v.igv_porcentaje<>igv_config THEN RAISE EXCEPTION 'IGV del borrador difiere de configuracion vigente; revisar venta'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=v.id_vendedor AND estado='A') THEN RAISE EXCEPTION 'Vendedor del borrador inactivo'; END IF;
IF v.id_cliente IS NOT NULL THEN SELECT * INTO cli FROM huaman.cliente WHERE id_cliente=v.id_cliente AND estado='A' FOR UPDATE;IF NOT FOUND THEN RAISE EXCEPTION 'Cliente inactivo'; END IF; END IF;
SELECT valor::numeric INTO umbral FROM huaman.parametro_sistema WHERE clave='VENTAS.BOLETA_DNI_DESDE' AND estado='A';
IF v.tipo_comprobante='B' AND umbral IS NOT NULL AND v.total>=umbral AND v.id_cliente IS NULL THEN RAISE EXCEPTION 'Identificar cliente segun umbral configurado del negocio'; END IF;
SELECT * INTO s FROM huaman.serie_comprobante WHERE id_serie=p_serie AND estado='A' FOR UPDATE;
IF NOT FOUND OR s.tipo_comprobante<>v.tipo_comprobante THEN RAISE EXCEPTION 'Serie incompatible'; END IF;
SELECT coalesce(sum(monto),0),coalesce(bool_or(medio='CREDITO'),false) INTO suma,fid FROM huaman.pago WHERE id_venta=p_venta AND estado='A';
IF suma<>v.total THEN RAISE EXCEPTION 'Pagos deben cubrir exactamente la venta'; END IF;
IF fid THEN
IF v.id_cliente IS NULL OR (SELECT count(*) FROM huaman.pago WHERE id_venta=p_venta AND estado='A')<>1 THEN RAISE EXCEPTION 'Fiado exige cliente y un unico medio'; END IF;
IF EXISTS(SELECT 1 FROM huaman.cuenta_por_cobrar cc WHERE cc.id_cliente=v.id_cliente AND cc.estado='A' AND cc.saldo>0 AND cc.fecha_vencimiento<c.fecha) THEN RAISE EXCEPTION 'Cliente con deuda vencida'; END IF;
SELECT coalesce(sum(cc.saldo),0) INTO suma FROM huaman.cuenta_por_cobrar cc WHERE cc.id_cliente=v.id_cliente AND cc.estado='A';
IF suma+v.total>cli.limite_credito THEN RAISE EXCEPTION 'Limite de credito insuficiente'; END IF;
SELECT valor::integer INTO plazo FROM huaman.parametro_sistema WHERE clave='VENTAS.PLAZO_CREDITO_DIAS' AND estado='A';
IF plazo IS NULL OR plazo<1 THEN RAISE EXCEPTION 'Configurar plazo de credito'; END IF;
END IF;
SELECT coalesce(nullif((SELECT valor FROM huaman.parametro_sistema WHERE clave='NEGOCIO.RAZON_SOCIAL' AND estado='A'),''),(SELECT valor FROM huaman.parametro_sistema WHERE clave='NEGOCIO.NOMBRE_COMERCIAL' AND estado='A')) INTO negocio;
SELECT valor INTO ruc FROM huaman.parametro_sistema WHERE clave='NEGOCIO.RUC' AND estado='A';SELECT valor INTO direccion FROM huaman.parametro_sistema WHERE clave='NEGOCIO.DIRECCION' AND estado='A';SELECT valor INTO telefono FROM huaman.parametro_sistema WHERE clave='NEGOCIO.TELEFONO' AND estado='A';
SELECT valor INTO formato FROM huaman.parametro_sistema WHERE clave='COMPROBANTE.FORMATO' AND estado='A';SELECT valor::integer INTO version_plantilla FROM huaman.parametro_sistema WHERE clave='COMPROBANTE.VERSION_PLANTILLA' AND estado='A';SELECT valor INTO mensaje FROM huaman.parametro_sistema WHERE clave='COMPROBANTE.PIE' AND estado='A';
IF negocio IS NULL OR length(btrim(negocio))<3 OR formato NOT IN ('A4','TICKET_80') OR formato IS NULL OR version_plantilla IS NULL THEN RAISE EXCEPTION 'Completar configuracion del negocio y plantilla'; END IF;
IF v.tipo_comprobante IN ('B','F') AND (coalesce(ruc,'') !~ '^[0-9]{11}$' OR ruc='00000000000' OR length(btrim(coalesce(direccion,'')))<5) THEN RAISE EXCEPTION 'Completar RUC y direccion del negocio; emision electronica sigue no integrada'; END IF;
PERFORM p.id_producto FROM huaman.producto p WHERE p.id_producto IN (SELECT id_producto FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') ORDER BY p.id_producto FOR UPDATE;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') THEN RAISE EXCEPTION 'Venta sin lineas'; END IF;
FOR prod IN SELECT * FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') ORDER BY id_producto LOOP
IF prod.estado<>'A' OR prod.costo_promedio<=0 THEN RAISE EXCEPTION 'Producto inactivo o sin costo valido'; END IF;
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto bloqueado por conteo'; END IF;
SELECT sum(cantidad_base) INTO suma FROM huaman.detalle_venta WHERE id_venta=p_venta AND id_producto=prod.id_producto AND estado='A';
IF suma>prod.stock_actual THEN RAISE EXCEPTION 'Existencias insuficientes para producto %',prod.codigo; END IF;
IF prod.modo_control<>'GRANEL' AND prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=prod.id_producto AND estado='A') THEN RAISE EXCEPTION 'Stock fisico no conciliado'; END IF;
END LOOP;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','CONFIRMAR_VENTA',true);
-- Cada asignacion corresponde a una pieza fisica. No se empalman retazos implicitamente.
FOR item IN SELECT value FROM jsonb_array_elements(p_asignaciones) ORDER BY (value->>'id_unidad_existencia')::bigint LOOP
IF jsonb_typeof(item)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(item) k WHERE k NOT IN ('id_detalle_venta','id_unidad_existencia','numero_pieza','cantidad_base')) THEN RAISE EXCEPTION 'Asignacion invalida'; END IF;
lid:=(item->>'id_detalle_venta')::bigint;uid:=(item->>'id_unidad_existencia')::bigint;np:=(item->>'numero_pieza')::integer;qty:=(item->>'cantidad_base')::numeric;
IF lid IS NULL OR uid IS NULL OR np IS NULL OR np<=0 OR qty IS NULL OR qty::text IN ('NaN','Infinity','-Infinity') OR qty<=0 OR qty<>round(qty,6) THEN RAISE EXCEPTION 'Datos fisicos incompletos'; END IF;
SELECT * INTO dv FROM huaman.detalle_venta WHERE id_detalle_venta=lid AND id_venta=p_venta AND estado='A';IF NOT FOUND THEN RAISE EXCEPTION 'Linea de asignacion ajena'; END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=dv.id_producto;SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=dv.id_presentacion;
SELECT * INTO u FROM huaman.unidad_existencia WHERE id_unidad_existencia=uid FOR UPDATE;
IF NOT FOUND OR u.estado<>'A' OR u.id_producto<>dv.id_producto OR qty>u.cantidad_disponible_base OR mod(qty,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Unidad fisica incompatible o insuficiente'; END IF;
IF prod.modo_control='GRANEL' THEN RAISE EXCEPTION 'Granel simple no requiere asignaciones'; END IF;
IF prod.modo_control='ENVASES' THEN
IF pr.id_unidad_venta IS NULL THEN
IF u.condicion_fisica<>'ENVASE' OR u.id_presentacion IS DISTINCT FROM dv.id_presentacion OR qty<>pr.factor_base THEN RAISE EXCEPTION 'Seleccionar un envase integro de la presentacion'; END IF;
ELSIF u.condicion_fisica<>'SUELTO' THEN RAISE EXCEPTION 'Venta por medida requiere contenido suelto; abrir envase con proceso autorizado'; END IF;
ELSE
IF u.condicion_fisica<>'TRAMO' OR dv.longitud_pieza_base IS NULL OR qty<>dv.longitud_pieza_base OR np>dv.piezas_solicitadas THEN RAISE EXCEPTION 'No hay un tramo continuo suficiente para la pieza solicitada'; END IF;
END IF;
INSERT INTO huaman.asignacion_existencia_venta(id_detalle_venta,id_producto,id_unidad_existencia,numero_pieza,cantidad_base) VALUES(lid,dv.id_producto,uid,np,qty);
UPDATE huaman.unidad_existencia SET cantidad_disponible_base=cantidad_disponible_base-qty WHERE id_unidad_existencia=uid;
END LOOP;
-- Se reparten centavos de base por restos mayores; las lineas suman la base de cabecera.
FOR d IN WITH bases AS (SELECT ln.*,trunc(ln.importe/(1+v.igv_porcentaje/100),2) piso FROM huaman.detalle_venta ln WHERE id_venta=p_venta AND estado='A'),
distribucion AS (SELECT bases.*,row_number() OVER(ORDER BY importe/(1+v.igv_porcentaje/100)-piso DESC,id_detalle_venta) orden_resto,sum(piso) OVER() piso_total FROM bases)
SELECT distribucion.*,piso+CASE WHEN orden_resto<=round((v.base_imponible-piso_total)*100)::integer THEN 0.01 ELSE 0 END base_calculada FROM distribucion ORDER BY id_producto,id_detalle_venta LOOP
SELECT * INTO prod FROM huaman.producto WHERE id_producto=d.id_producto;SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=d.id_presentacion FOR SHARE;
IF pr.estado<>'A' OR NOT pr.permite_venta OR pr.factor_base<>d.factor_base OR d.cantidad<pr.minimo_venta OR mod(d.cantidad,pr.incremento_venta)<>0 THEN RAISE EXCEPTION 'Presentacion o cantidad no disponible'; END IF;
precio:=pr.precio_normal;origen:='NORMAL';oid:=NULL;mid:=NULL;
SELECT id_precio_mayorista,pm.precio INTO mid,suma FROM huaman.precio_mayorista pm WHERE id_presentacion=d.id_presentacion AND estado='A' AND cantidad_minima<=d.cantidad ORDER BY cantidad_minima DESC LIMIT 1;
IF FOUND AND suma<precio THEN precio:=suma;origen:='MAYORISTA';ELSE mid:=NULL;END IF;
SELECT id_oferta,precio_oferta INTO oid,suma FROM huaman.oferta WHERE id_presentacion=d.id_presentacion AND estado='A' AND c.fecha BETWEEN fecha_inicio AND fecha_fin;
IF FOUND AND suma<precio THEN precio:=suma;origen:='OFERTA';mid:=NULL;ELSE oid:=NULL;END IF;
IF (d.precio_lista,d.precio_unitario,d.origen_precio,d.id_oferta,d.id_precio_mayorista) IS DISTINCT FROM (pr.precio_normal,precio,origen,oid,mid) THEN RAISE EXCEPTION 'Precios cambiaron: revisar borrador y pagos antes de confirmar'; END IF;
IF d.base_calculada<round(d.cantidad_base*prod.costo_promedio,2) THEN RAISE EXCEPTION 'Venta por debajo del costo comparable'; END IF;
cod:=NULL;IF pr.id_unidad_venta IS NOT NULL THEN SELECT codigo_sunat INTO cod FROM huaman.unidad_medida WHERE id_unidad=pr.id_unidad_venta; END IF;
IF cod IS NOT NULL AND pr.codigo_sunat IS NOT NULL AND cod<>pr.codigo_sunat THEN RAISE EXCEPTION 'Unidad SUNAT incompatible'; END IF;cod:=coalesce(cod,pr.codigo_sunat);
IF v.tipo_comprobante IN ('B','F') AND cod IS NULL THEN RAISE EXCEPTION 'Configurar codigo SUNAT de la presentacion comercial'; END IF;
IF prod.modo_control<>'GRANEL' THEN
SELECT coalesce(sum(cantidad_base),0) INTO suma FROM huaman.asignacion_existencia_venta WHERE id_detalle_venta=d.id_detalle_venta AND estado='A';
IF suma<>d.cantidad_base THEN RAISE EXCEPTION 'Asignaciones no cubren cantidad de la linea'; END IF;
IF prod.modo_control='TRAMOS' AND (SELECT count(*) FROM huaman.asignacion_existencia_venta WHERE id_detalle_venta=d.id_detalle_venta AND estado='A')<>d.piezas_solicitadas THEN RAISE EXCEPTION 'Numero de piezas no coincide'; END IF;
END IF;
UPDATE huaman.detalle_venta SET costo_unitario_base=prod.costo_promedio,base_imponible_linea=d.base_calculada,igv_linea=d.importe-d.base_calculada,codigo_unidad_sunat=cod WHERE id_detalle_venta=d.id_detalle_venta;
saldo:=prod.stock_actual-d.cantidad_base;
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_venta,clave_idempotencia)
VALUES(prod.id_producto,'SALIDA_VENTA','S',d.cantidad_base,prod.stock_actual,saldo,prod.costo_promedio,p_venta,gen_random_uuid());
UPDATE huaman.producto SET stock_actual=saldo WHERE id_producto=prod.id_producto;
IF saldo<=prod.stock_minimo AND NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=prod.id_producto AND estado_alerta='ABIERTA' AND estado='A') THEN INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(prod.id_producto,saldo,prod.stock_minimo); END IF;
END LOOP;
FOR prod IN SELECT * FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_venta WHERE id_venta=p_venta AND estado='A') LOOP
IF prod.modo_control<>'GRANEL' AND prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=prod.id_producto AND estado='A') THEN RAISE EXCEPTION 'Descuadre fisico despues de asignar'; END IF;
END LOOP;
UPDATE huaman.venta SET estado_venta='CONFIRMADA' WHERE id_venta=p_venta;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta;
FOR pa IN SELECT * FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio<>'CREDITO' LOOP
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,id_venta,clave_idempotencia) VALUES(v.id_caja,'VENTA',pa.medio,'I',pa.monto,p_venta,gen_random_uuid());
END LOOP;
IF fid THEN INSERT INTO huaman.cuenta_por_cobrar(id_venta,id_cliente,monto_original,saldo,fecha_vencimiento) VALUES(p_venta,v.id_cliente,v.total,v.total,c.fecha+plazo);END IF;
numero:=greatest(s.ultimo_correlativo+1,s.correlativo_inicial);
UPDATE huaman.serie_comprobante SET ultimo_correlativo=numero WHERE id_serie=p_serie;
INSERT INTO huaman.comprobante_venta(id_venta,id_serie,tipo_comprobante,serie,numero,cliente_tipo_doc,cliente_nro_doc,cliente_nombre,cliente_direccion,negocio_nombre,negocio_ruc,negocio_direccion,negocio_telefono,formato,version_plantilla,mensaje_final,base_imponible,igv,total,estado_tributario)
VALUES(p_venta,p_serie,v.tipo_comprobante,s.serie,numero,v.cliente_tipo_doc,v.cliente_nro_doc,v.cliente_nombre,v.cliente_direccion,negocio,ruc,direccion,telefono,formato,version_plantilla,mensaje,v.base_imponible,v.igv,v.total,CASE WHEN v.tipo_comprobante='N' THEN 'NO_APLICA' ELSE 'NO_INTEGRADO' END) RETURNING id_comprobante INTO comp;
IF NOT v.entrega_inmediata THEN INSERT INTO huaman.despacho(id_venta) VALUES(p_venta); END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'VEN.CONFIRMAR','venta',p_venta,p_clave::text,jsonb_build_object('comprobante',comp,'serie',p_serie,'total',v.total,'asignaciones',p_asignaciones));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN comp;
END $$;

CREATE FUNCTION huaman.descartar_venta(p_venta bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;previo text;motivo text:=btrim(p_motivo);
BEGIN
actor:=huaman._actor_con_permiso('VEN.VENDER');
IF p_venta IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 5 AND 200 THEN RAISE EXCEPTION 'Datos de descarte invalidos'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta;IF NOT FOUND THEN RAISE EXCEPTION 'Venta inexistente'; END IF;
PERFORM 1 FROM huaman.caja_diaria WHERE id_caja=v.id_caja FOR UPDATE;SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta FOR UPDATE;
IF v.estado='I' AND v.clave_descarte=p_clave AND v.motivo_descarte=motivo THEN RETURN p_venta; END IF;
IF v.estado_venta<>'BORRADOR' OR v.estado<>'A' THEN RAISE EXCEPTION 'Solo descartar borradores activos; no anular ventas confirmadas'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','DESCARTAR_VENTA',true);
UPDATE huaman.pago SET estado='I' WHERE id_venta=p_venta AND estado='A';
UPDATE huaman.detalle_venta SET estado='I' WHERE id_venta=p_venta AND estado='A';
UPDATE huaman.venta SET estado='I',clave_descarte=p_clave,motivo_descarte=motivo WHERE id_venta=p_venta;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'VEN.DESCARTAR','venta',p_venta,p_clave::text,jsonb_build_object('motivo',motivo));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_venta;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'confirmar_venta' AS proceso,to_regprocedure('huaman.confirmar_venta(bigint,bigint,uuid,jsonb)') IS NOT NULL AS instalado
UNION ALL SELECT 'descartar_venta',to_regprocedure('huaman.descartar_venta(bigint,uuid,text)') IS NOT NULL;

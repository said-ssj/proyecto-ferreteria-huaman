-- FERRETERIA HUAMAN - BLOQUE20 - convertir cotizacion y recalcular vencida
-- Requiere01 a19. Solo instala. No crea ventas reales ni confirma cobros.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.emitir_cotizacion(bigint,uuid)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque19'; END IF;
IF to_regprocedure('huaman.convertir_cotizacion(bigint,bigint,text,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque20 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE cotizacion ADD COLUMN revision integer NOT NULL DEFAULT 1 CHECK(revision>0);
ALTER TABLE detalle_venta ADD COLUMN id_detalle_cotizacion bigint REFERENCES detalle_cotizacion(id_detalle_cotizacion) ON DELETE RESTRICT;
-- Una venta activa por cotizacion; descartes conservan vinculo historico sin bloquear nuevo intento.
ALTER TABLE venta DROP CONSTRAINT venta_id_cotizacion_key;
CREATE UNIQUE INDEX ux_venta_cotizacion_activa ON venta(id_cotizacion) WHERE id_cotizacion IS NOT NULL AND estado='A';
CREATE UNIQUE INDEX ux_recalculo_clave ON bitacora_evento(referencia) WHERE accion='COC.RECALCULAR';
CREATE UNIQUE INDEX ux_conversion_clave ON bitacora_evento(referencia) WHERE accion='COC.CONVERTIR';
CREATE OR REPLACE FUNCTION huaman._cotizacion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('EMITIR_COTIZACION','ANULAR_COTIZACION','CONVERTIR_COTIZACION','RECALCULAR_COTIZACION','CONFIRMAR_VENTA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_cabecera_cotizacion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE modo text:=current_setting('app.proceso',true);
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._cotizacion_en_curso(),false) THEN
IF modo='RECALCULAR_COTIZACION' THEN
IF OLD.estado_cotizacion NOT IN ('VIGENTE','VENCIDA','BORRADOR') OR NEW.estado_cotizacion NOT IN ('BORRADOR','VIGENTE') OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','fecha','vigente_hasta','subtotal','descuento_total','total','revision','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','fecha','vigente_hasta','subtotal','descuento_total','total','revision','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Recalculo altera datos ajenos a precio y vigencia'; END IF;
RETURN NEW;
ELSIF modo='CONFIRMAR_VENTA' AND NEW.estado_cotizacion='CONVERTIDA' THEN
IF OLD.estado_cotizacion<>'VIGENTE' OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','usmod','pcmod','fecmod']) OR NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_cotizacion=NEW.id_cotizacion AND estado='A' AND estado_venta='CONFIRMADA') THEN RAISE EXCEPTION 'Conversion exige venta confirmada'; END IF;
RETURN NEW;
END IF;
IF modo='EMITIR_COTIZACION' AND OLD.estado_cotizacion='BORRADOR' AND NEW.estado_cotizacion='VIGENTE' THEN
IF NEW.clave_emision IS NULL OR NEW.emitida_en IS NULL OR NEW.id_emite IS NULL OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','vigente_hasta','clave_emision','emitida_en','id_emite','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','vigente_hasta','clave_emision','emitida_en','id_emite','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Emision altera datos no autorizados'; END IF;
RETURN NEW;
ELSIF modo='ANULAR_COTIZACION' AND OLD.estado_cotizacion IN ('BORRADOR','VIGENTE','VENCIDA') AND NEW.estado_cotizacion='ANULADA' THEN
IF NEW.clave_anulacion IS NULL OR NEW.anulada_en IS NULL OR NEW.id_anula IS NULL OR length(btrim(coalesce(NEW.motivo_anulacion,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','clave_anulacion','anulada_en','id_anula','motivo_anulacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','clave_anulacion','anulada_en','id_anula','motivo_anulacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion altera datos no autorizados'; END IF;
RETURN NEW;
END IF;
END IF;
IF (TG_OP='UPDATE' AND NEW.revision<>OLD.revision) OR (TG_OP='INSERT' AND NEW.revision<>1) THEN RAISE EXCEPTION 'Revision solo cambia mediante recalculo'; END IF;
IF NEW.estado_cotizacion<>'BORRADOR' OR NEW.estado<>'A' OR (TG_OP='UPDATE' AND OLD.estado_cotizacion<>'BORRADOR') THEN RAISE EXCEPTION 'Cotizacion emitida o finalizada no editable'; END IF;
IF num_nonnulls(NEW.clave_emision,NEW.emitida_en,NEW.id_emite,NEW.clave_anulacion,NEW.anulada_en,NEW.id_anula,NEW.motivo_anulacion)>0 THEN RAISE EXCEPTION 'Estado y responsables solo mediante proceso'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_vendedor AND estado='A') THEN RAISE EXCEPTION 'Vendedor inexistente o inactivo'; END IF;
IF NEW.id_cliente IS NOT NULL AND NOT EXISTS(SELECT 1 FROM huaman.cliente WHERE id_cliente=NEW.id_cliente AND estado='A') THEN RAISE EXCEPTION 'Cliente inexistente o inactivo'; END IF;
IF length(coalesce(NEW.observacion,''))>300 OR coalesce(NEW.observacion,'') ~ '[<>]' OR coalesce(NEW.nombre_interesado,'') ~ '[<>]' THEN RAISE EXCEPTION 'Ingresar texto simple sin etiquetas'; END IF;
IF TG_OP='INSERT' THEN
IF NEW.subtotal<>0 OR NEW.descuento_total<>0 OR NEW.total<>0 THEN RAISE EXCEPTION 'Totales se calculan desde detalles'; END IF;
ELSE
IF (NEW.id_vendedor,NEW.fecha,NEW.estado) IS DISTINCT FROM (OLD.id_vendedor,OLD.fecha,OLD.estado) THEN RAISE EXCEPTION 'Identidad y fecha de cotizacion inmutables'; END IF;
IF (NEW.subtotal,NEW.descuento_total,NEW.total) IS DISTINCT FROM (OLD.subtotal,OLD.descuento_total,OLD.total) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar totales manualmente'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_venta_borrador() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cli huaman.cliente%ROWTYPE; caj huaman.caja_diaria%ROWTYPE;
BEGIN
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
CREATE OR REPLACE FUNCTION huaman.validar_detalle_venta() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE c huaman.venta%ROWTYPE;p huaman.presentacion_producto%ROWTYPE;prod huaman.producto%ROWTYPE;
        mayor huaman.precio_mayorista%ROWTYPE;promo huaman.oferta%ROWTYPE;cot huaman.cotizacion%ROWTYPE;dc huaman.detalle_cotizacion%ROWTYPE;
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
  IF NOT FOUND OR (prod.estado<>'A' AND c.id_cotizacion IS NULL) THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion FOR SHARE;
  IF NOT FOUND OR p.id_producto<>NEW.id_producto OR ((p.estado<>'A' OR NOT p.permite_venta) AND c.id_cotizacion IS NULL) THEN RAISE EXCEPTION 'Presentacion no disponible'; END IF;
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
 
NEW.id_detalle_cotizacion:=NULL;
IF c.id_cotizacion IS NOT NULL THEN
SELECT * INTO cot FROM huaman.cotizacion WHERE id_cotizacion=c.id_cotizacion;
IF cot.estado<>'A' OR cot.estado_cotizacion<>'VIGENTE' OR cot.vigente_hasta<timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Cotizacion no vigente; descarte borrador y recalcule antes de convertir'; END IF;
SELECT * INTO dc FROM huaman.detalle_cotizacion WHERE id_cotizacion=c.id_cotizacion AND id_presentacion=NEW.id_presentacion AND id_producto=NEW.id_producto AND cantidad=NEW.cantidad AND estado='A';
IF FOUND THEN
NEW.id_detalle_cotizacion:=dc.id_detalle_cotizacion;NEW.producto_nombre:=dc.producto_nombre;NEW.presentacion_nombre:=dc.presentacion_nombre;NEW.factor_base:=dc.factor_base;NEW.unidad_base_simbolo:=dc.unidad_base_simbolo;
NEW.precio_lista:=dc.precio_lista;NEW.precio_unitario:=dc.precio_unitario;NEW.origen_precio:=dc.origen_precio;NEW.id_oferta:=dc.id_oferta;NEW.id_precio_mayorista:=dc.id_precio_mayorista;
END IF;
END IF;
  RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.confirmar_venta(p_venta bigint,p_serie bigint,p_clave uuid,p_asignaciones jsonb DEFAULT '[]'::jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;c huaman.caja_diaria%ROWTYPE;s huaman.serie_comprobante%ROWTYPE;prod huaman.producto%ROWTYPE;
pr huaman.presentacion_producto%ROWTYPE;cli huaman.cliente%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;dv huaman.detalle_venta%ROWTYPE;
d record;pa record;item jsonb;previo text;precio numeric;origen text;oid bigint;mid bigint;cod text;saldo numeric;suma numeric;
comp bigint;numero integer;fid boolean;plazo integer;umbral numeric;igv_config numeric;negocio text;ruc text;direccion text;telefono text;formato text;version_plantilla integer;mensaje text;bit jsonb;
lid bigint;uid bigint;np integer;qty numeric;cot huaman.cotizacion%ROWTYPE;dc huaman.detalle_cotizacion%ROWTYPE;
BEGIN
actor:=huaman._actor_con_permiso('VEN.VENDER');
IF p_venta IS NULL OR p_serie IS NULL OR p_clave IS NULL OR p_asignaciones IS NULL OR jsonb_typeof(p_asignaciones)<>'array' THEN RAISE EXCEPTION 'Parametros incompletos'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta;
IF NOT FOUND THEN RAISE EXCEPTION 'Venta inexistente'; END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=v.id_caja FOR UPDATE;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta FOR UPDATE;
IF p_clave<>v.clave_idempotencia THEN RAISE EXCEPTION 'Usar la clave de idempotencia del borrador'; END IF;
IF v.id_cotizacion IS NOT NULL AND v.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo confirmar borrador propio'; END IF;
IF v.estado_venta='CONFIRMADA' THEN
SELECT id_comprobante INTO comp FROM huaman.comprobante_venta WHERE id_venta=p_venta AND id_serie=p_serie;
SELECT valor_nuevo INTO bit FROM huaman.bitacora_evento WHERE accion='VEN.CONFIRMAR' AND entidad='venta' AND id_entidad=p_venta AND referencia=p_clave::text;
IF comp IS NULL OR bit->'asignaciones' IS DISTINCT FROM p_asignaciones THEN RAISE EXCEPTION 'Reintento con serie/asignaciones distintas'; END IF;
RETURN comp;
END IF;
IF v.id_cotizacion IS NOT NULL AND v.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo confirmar borrador propio'; END IF;
IF v.id_cotizacion IS NOT NULL THEN
SELECT * INTO cot FROM huaman.cotizacion WHERE id_cotizacion=v.id_cotizacion FOR UPDATE;
IF NOT FOUND OR cot.estado<>'A' OR cot.estado_cotizacion<>'VIGENTE' OR cot.vigente_hasta<timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Cotizacion vencida o finalizada; descarte borrador y recalcule'; END IF;
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
IF d.id_detalle_cotizacion IS NOT NULL THEN
SELECT * INTO dc FROM huaman.detalle_cotizacion WHERE id_detalle_cotizacion=d.id_detalle_cotizacion;
IF v.id_cotizacion IS NULL OR dc.id_cotizacion<>v.id_cotizacion OR dc.estado<>'A' OR (d.id_producto,d.id_presentacion,d.cantidad,d.factor_base,d.precio_lista,d.precio_unitario,d.origen_precio,d.id_oferta,d.id_precio_mayorista) IS DISTINCT FROM (dc.id_producto,dc.id_presentacion,dc.cantidad,dc.factor_base,dc.precio_lista,dc.precio_unitario,dc.origen_precio,dc.id_oferta,dc.id_precio_mayorista) THEN RAISE EXCEPTION 'Linea no coincide con precio cotizado'; END IF;
ELSE
precio:=pr.precio_normal;origen:='NORMAL';oid:=NULL;mid:=NULL;
SELECT id_precio_mayorista,pm.precio INTO mid,suma FROM huaman.precio_mayorista pm WHERE id_presentacion=d.id_presentacion AND estado='A' AND cantidad_minima<=d.cantidad ORDER BY cantidad_minima DESC LIMIT 1;
IF FOUND AND suma<precio THEN precio:=suma;origen:='MAYORISTA';ELSE mid:=NULL;END IF;
SELECT id_oferta,precio_oferta INTO oid,suma FROM huaman.oferta WHERE id_presentacion=d.id_presentacion AND estado='A' AND c.fecha BETWEEN fecha_inicio AND fecha_fin;
IF FOUND AND suma<precio THEN precio:=suma;origen:='OFERTA';mid:=NULL;ELSE oid:=NULL;END IF;
IF (d.precio_lista,d.precio_unitario,d.origen_precio,d.id_oferta,d.id_precio_mayorista) IS DISTINCT FROM (pr.precio_normal,precio,origen,oid,mid) THEN RAISE EXCEPTION 'Precios cambiaron: revisar borrador y pagos antes de confirmar'; END IF;
END IF;
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
IF v.id_cotizacion IS NOT NULL THEN
UPDATE huaman.cotizacion SET estado_cotizacion='CONVERTIDA' WHERE id_cotizacion=v.id_cotizacion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COC.VENTA_CONFIRMADA','cotizacion',v.id_cotizacion,p_clave::text,jsonb_build_object('venta',p_venta,'comprobante',comp));
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'VEN.CONFIRMAR','venta',p_venta,p_clave::text,jsonb_build_object('comprobante',comp,'serie',p_serie,'total',v.total,'asignaciones',p_asignaciones));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN comp;
END $$;

CREATE FUNCTION huaman.convertir_cotizacion(p_cotizacion bigint,p_caja bigint,p_tipo text,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.cotizacion%ROWTYPE;caja huaman.caja_diaria%ROWTYPE;v huaman.venta%ROWTYPE;previo text;sol jsonb;b huaman.bitacora_evento%ROWTYPE;nuevo bigint;igv_config numeric;
BEGIN
actor:=huaman._actor_con_permiso('COC.COTIZAR');PERFORM huaman._actor_con_permiso('VEN.VENDER');
IF p_cotizacion IS NULL OR p_caja IS NULL OR p_tipo IS NULL OR p_tipo NOT IN ('B','F','N') OR p_clave IS NULL THEN RAISE EXCEPTION 'Datos de conversion invalidos'; END IF;
sol:=jsonb_build_object('cotizacion',p_cotizacion,'caja',p_caja,'tipo',p_tipo);
PERFORM pg_advisory_xact_lock(hashtextextended('CONVERTIR_COTIZACION:'||p_clave::text,0));
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion;
IF NOT FOUND THEN RAISE EXCEPTION 'Cotizacion inexistente'; END IF;
IF c.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo convertir cotizaciones propias'; END IF;
SELECT * INTO b FROM huaman.bitacora_evento WHERE accion='COC.CONVERTIR' AND referencia=p_clave::text;
IF FOUND THEN IF b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra conversion'; END IF;RETURN (b.valor_nuevo->>'venta')::bigint;END IF;
SELECT * INTO caja FROM huaman.caja_diaria WHERE id_caja=p_caja FOR UPDATE;
IF NOT FOUND OR caja.estado<>'A' OR caja.estado_caja<>'ABIERTA' OR caja.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Caja abierta del dia requerida'; END IF;
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion FOR UPDATE;
IF c.estado<>'A' OR c.estado_cotizacion<>'VIGENTE' OR c.vigente_hasta<caja.fecha THEN RAISE EXCEPTION 'Cotizacion vencida o finalizada; recalcular antes de convertir'; END IF;
IF EXISTS(SELECT 1 FROM huaman.venta WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Cotizacion ya tiene una venta activa; continue o descarte ese borrador'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_cotizacion WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Cotizacion sin lineas'; END IF;
SELECT valor::numeric INTO igv_config FROM huaman.parametro_sistema WHERE clave='VENTAS.IGV_PORC' AND estado='A';
IF igv_config IS NULL THEN RAISE EXCEPTION 'IGV no configurado'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','CONVERTIR_COTIZACION',true);
INSERT INTO huaman.venta(id_caja,id_cliente,id_vendedor,id_cotizacion,tipo_comprobante,clave_idempotencia,igv_porcentaje)
VALUES(p_caja,c.id_cliente,actor,p_cotizacion,p_tipo,p_clave,igv_config) RETURNING id_venta INTO nuevo;
-- Sin copiar pagos ni asignaciones fisicas. Lo indisponible se revisa antes de cobrar.
INSERT INTO huaman.detalle_venta(id_venta,id_producto,id_presentacion,cantidad)
SELECT nuevo,id_producto,id_presentacion,cantidad FROM huaman.detalle_cotizacion WHERE id_cotizacion=p_cotizacion AND estado='A' ORDER BY id_detalle_cotizacion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COC.CONVERTIR','cotizacion',p_cotizacion,p_clave::text,jsonb_build_object('solicitud',sol,'venta',nuevo,'revision',c.revision));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
END $$;
CREATE FUNCTION huaman.recalcular_cotizacion(p_cotizacion bigint,p_revision integer,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.cotizacion%ROWTYPE;previo text;sol jsonb;b huaman.bitacora_evento%ROWTYPE;dias integer;antes jsonb;
BEGIN
actor:=huaman._actor_con_permiso('COC.COTIZAR');
IF p_cotizacion IS NULL OR p_revision IS NULL OR p_revision<1 OR p_clave IS NULL THEN RAISE EXCEPTION 'Datos de recalculo invalidos'; END IF;
sol:=jsonb_build_object('cotizacion',p_cotizacion,'revision',p_revision);
PERFORM pg_advisory_xact_lock(hashtextextended('RECALCULAR_COTIZACION:'||p_clave::text,0));
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Cotizacion inexistente'; END IF;
IF c.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo recalcular cotizaciones propias'; END IF;
SELECT * INTO b FROM huaman.bitacora_evento WHERE accion='COC.RECALCULAR' AND referencia=p_clave::text;
IF FOUND THEN IF b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otro recalculo'; END IF;RETURN p_cotizacion;END IF;
IF c.estado<>'A' OR c.estado_cotizacion NOT IN ('VIGENTE','VENCIDA') OR c.vigente_hasta>=timezone('America/Lima',now())::date OR c.revision<>p_revision THEN RAISE EXCEPTION 'Solo recalcular cotizacion vencida con revision concordante'; END IF;
IF EXISTS(SELECT 1 FROM huaman.venta WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Descarte borrador vinculado antes de recalcular'; END IF;
SELECT valor::integer INTO dias FROM huaman.parametro_sistema WHERE clave='COTIZACION.VIGENCIA_DIAS' AND estado='A';
IF dias IS NULL OR dias NOT BETWEEN 1 AND 90 THEN RAISE EXCEPTION 'Vigencia no configurada'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_cotizacion WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Sin lineas activas'; END IF;
SELECT jsonb_build_object('cabecera',to_jsonb(c),'lineas',jsonb_agg(to_jsonb(dc) ORDER BY dc.id_detalle_cotizacion)) INTO antes FROM huaman.detalle_cotizacion dc WHERE id_cotizacion=p_cotizacion;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','RECALCULAR_COTIZACION',true);
UPDATE huaman.cotizacion SET estado_cotizacion='BORRADOR',fecha=timezone('America/Lima',now())::date,vigente_hasta=timezone('America/Lima',now())::date+dias WHERE id_cotizacion=p_cotizacion;
UPDATE huaman.detalle_cotizacion SET cantidad=cantidad WHERE id_cotizacion=p_cotizacion AND estado='A';
UPDATE huaman.cotizacion SET estado_cotizacion='VIGENTE',revision=revision+1 WHERE id_cotizacion=p_cotizacion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo) VALUES(actor,'COC.RECALCULAR','cotizacion',p_cotizacion,p_clave::text,antes,jsonb_build_object('solicitud',sol,'revision',c.revision+1,'total_anterior',c.total,'total_nuevo',(SELECT total FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion)));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_cotizacion;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'convertir_cotizacion' AS proceso,to_regprocedure('huaman.convertir_cotizacion(bigint,bigint,text,uuid)') IS NOT NULL AS instalado
UNION ALL SELECT 'recalcular_cotizacion',to_regprocedure('huaman.recalcular_cotizacion(bigint,integer,uuid)') IS NOT NULL;

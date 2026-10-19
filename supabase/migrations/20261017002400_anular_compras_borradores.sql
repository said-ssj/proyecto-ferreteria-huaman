-- FERRETERIA HUAMAN - BLOQUE24 - anular orden y descartar ingreso borrador
-- Requiere01 a23. Solo instala. No revierte compras confirmadas ni mueve stock.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.anular_venta(bigint,uuid,text,boolean,jsonb,jsonb)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque23'; END IF;
IF to_regprocedure('huaman.anular_orden_compra(bigint,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque24 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE orden_compra ADD COLUMN clave_anulacion uuid UNIQUE;
ALTER TABLE orden_compra ADD COLUMN fecha_anulacion timestamp;
ALTER TABLE orden_compra ADD COLUMN id_anula bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE ingreso_mercaderia ADD COLUMN clave_anulacion uuid UNIQUE;
ALTER TABLE ingreso_mercaderia ADD COLUMN fecha_anulacion timestamp;
ALTER TABLE ingreso_mercaderia ADD COLUMN id_anula bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE detalle_orden_compra ADD COLUMN cantidad_cancelada_base numeric(24,12) NOT NULL DEFAULT 0 CHECK(cantidad_cancelada_base>=0);
ALTER TABLE detalle_orden_compra ADD CONSTRAINT ck_pedido_recibido_cancelado CHECK(cantidad_recibida_base+cantidad_cancelada_base<=cantidad_pedida*factor_base);
CREATE UNIQUE INDEX ux_compra_anulacion_clave ON bitacora_evento(referencia) WHERE accion IN ('COM.OC_ANULAR','COM.INGRESO_DESCARTAR');
CREATE FUNCTION huaman._compra_anulacion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('ANULAR_ORDEN_COMPRA','ANULAR_INGRESO_BORRADOR')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_cabecera_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE oc huaman.orden_compra%ROWTYPE;
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._compra_anulacion_en_curso(),false) THEN
IF TG_TABLE_NAME='orden_compra' AND current_setting('app.proceso',true)='ANULAR_ORDEN_COMPRA' THEN
IF pg_trigger_depth()>=2 AND (to_jsonb(NEW)-ARRAY['usmod','pcmod','fecmod']) IS NOT DISTINCT FROM (to_jsonb(OLD)-ARRAY['usmod','pcmod','fecmod']) THEN RETURN NEW; END IF;
IF OLD.estado_orden NOT IN ('BORRADOR','EMITIDA','PARCIAL') OR NEW.estado_orden<>'ANULADA' OR NEW.clave_anulacion IS NULL OR NEW.id_anula IS NULL OR NEW.fecha_anulacion IS NULL OR length(btrim(coalesce(NEW.motivo_anulacion,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['estado_orden','motivo_anulacion','clave_anulacion','fecha_anulacion','id_anula','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_orden','motivo_anulacion','clave_anulacion','fecha_anulacion','id_anula','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion de orden altera historial'; END IF;
RETURN NEW;
ELSIF TG_TABLE_NAME='ingreso_mercaderia' AND current_setting('app.proceso',true)='ANULAR_INGRESO_BORRADOR' THEN
IF OLD.estado_ingreso<>'BORRADOR' OR NEW.estado_ingreso<>'ANULADO' OR NEW.clave_anulacion IS NULL OR NEW.id_anula IS NULL OR NEW.fecha_anulacion IS NULL OR length(btrim(coalesce(NEW.motivo_anulacion,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['estado_ingreso','motivo_anulacion','clave_anulacion','fecha_anulacion','id_anula','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_ingreso','motivo_anulacion','clave_anulacion','fecha_anulacion','id_anula','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Solo descartar ingreso borrador sin alterar importes'; END IF;
RETURN NEW;
END IF;
RAISE EXCEPTION 'Operacion de anulacion incompatible';
END IF;
IF TG_OP='INSERT' THEN
IF num_nonnulls(NEW.clave_anulacion,NEW.fecha_anulacion,NEW.id_anula,NEW.motivo_anulacion)>0 THEN RAISE EXCEPTION 'Identidad de anulacion solo mediante proceso'; END IF;
ELSE
IF (NEW.clave_anulacion,NEW.fecha_anulacion,NEW.id_anula,NEW.motivo_anulacion) IS DISTINCT FROM (OLD.clave_anulacion,OLD.fecha_anulacion,OLD.id_anula,OLD.motivo_anulacion) THEN RAISE EXCEPTION 'Identidad de anulacion inmutable'; END IF;
END IF;
  IF NOT EXISTS(SELECT 1 FROM huaman.proveedor WHERE id_proveedor=NEW.id_proveedor AND estado='A') THEN RAISE EXCEPTION 'Proveedor inexistente o inactivo'; END IF;
  IF TG_TABLE_NAME='orden_compra' THEN
    IF TG_OP='UPDATE' AND OLD.estado_orden<>'BORRADOR' AND NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Orden emitida no editable fuera de proceso'; END IF;
    IF NEW.clave_emision IS NOT NULL AND NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Identidad de emision solo mediante proceso'; END IF;
    IF NEW.estado_orden<>'BORRADOR' AND NOT (coalesce(huaman._apertura_en_curso(),false) AND current_setting('app.proceso',true) IN ('EMITIR_ORDEN','CONFIRMAR_INGRESO')) THEN RAISE EXCEPTION 'Emision de orden pendiente del bloque de procesos'; END IF;
    IF TG_OP='INSERT' AND NEW.total_estimado<>0 THEN RAISE EXCEPTION 'El total se obtiene de los detalles'; END IF;
    IF TG_OP='UPDATE' AND NEW.total_estimado<>OLD.total_estimado AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar el total manualmente'; END IF;
  ELSE
    IF TG_OP='UPDATE' AND OLD.estado_ingreso<>'BORRADOR' AND NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Ingreso confirmado no editable fuera de proceso'; END IF;
    IF NEW.clave_confirmacion IS NOT NULL AND NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Identidad de confirmacion solo mediante proceso'; END IF;
    IF NEW.estado_ingreso<>'BORRADOR' AND NOT (coalesce(huaman._apertura_en_curso(),false) AND current_setting('app.proceso',true)='CONFIRMAR_INGRESO') THEN RAISE EXCEPTION 'Confirmacion/anulacion pendiente del bloque de movimientos; no ajustar stock manualmente'; END IF;
    IF NEW.id_orden_compra IS NOT NULL THEN
      SELECT * INTO oc FROM huaman.orden_compra WHERE id_orden_compra=NEW.id_orden_compra FOR UPDATE;
      IF NOT FOUND OR oc.id_proveedor<>NEW.id_proveedor THEN RAISE EXCEPTION 'Proveedor incompatible con orden de compra'; END IF;
IF NEW.estado_ingreso='BORRADOR' AND (oc.estado<>'A' OR oc.estado_orden NOT IN ('EMITIDA','PARCIAL')) THEN RAISE EXCEPTION 'Preparar ingreso solo contra orden emitida o parcial'; END IF;
    END IF;
    IF TG_OP='INSERT' AND NEW.total<>0 THEN RAISE EXCEPTION 'El total se obtiene de los detalles'; END IF;
    IF TG_OP='UPDATE' AND NEW.total<>OLD.total AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar el total manualmente'; END IF;
  END IF;
  IF TG_OP='UPDATE' THEN
    IF TG_TABLE_NAME='orden_compra' THEN
      IF NEW.id_proveedor<>OLD.id_proveedor AND EXISTS(SELECT 1 FROM huaman.detalle_orden_compra WHERE id_orden_compra=NEW.id_orden_compra) THEN RAISE EXCEPTION 'Orden con detalles: no cambiar proveedor'; END IF;
    ELSE
      IF (NEW.id_proveedor,NEW.id_orden_compra) IS DISTINCT FROM (OLD.id_proveedor,OLD.id_orden_compra) AND EXISTS(SELECT 1 FROM huaman.detalle_ingreso WHERE id_ingreso=NEW.id_ingreso) THEN RAISE EXCEPTION 'Ingreso con detalles: no cambiar proveedor u orden'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_detalle_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE p huaman.presentacion_producto%ROWTYPE; prod huaman.producto%ROWTYPE;
        ing huaman.ingreso_mercaderia%ROWTYPE; oc huaman.orden_compra%ROWTYPE; d huaman.detalle_orden_compra%ROWTYPE;
        cantidad numeric; unidad text;
BEGIN
IF TG_TABLE_NAME='detalle_orden_compra' THEN
IF TG_OP='UPDATE' AND coalesce(huaman._compra_anulacion_en_curso(),false) AND current_setting('app.proceso',true)='ANULAR_ORDEN_COMPRA' THEN
IF NEW.cantidad_cancelada_base<>OLD.cantidad_base-OLD.cantidad_recibida_base OR (to_jsonb(NEW)-ARRAY['cantidad_cancelada_base','cantidad_base','importe_adquisicion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['cantidad_cancelada_base','cantidad_base','importe_adquisicion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Cancelar solo el saldo pendiente de orden'; END IF;
RETURN NEW;
END IF;
IF (TG_OP='INSERT' AND NEW.cantidad_cancelada_base<>0) OR (TG_OP='UPDATE' AND NEW.cantidad_cancelada_base<>OLD.cantidad_cancelada_base) THEN RAISE EXCEPTION 'Cantidad cancelada solo por anulacion'; END IF;
END IF;
  IF TG_TABLE_NAME='detalle_orden_compra' AND TG_OP='UPDATE' AND coalesce(huaman._apertura_en_curso(),false) AND current_setting('app.proceso',true)='CONFIRMAR_INGRESO' THEN
    IF (NEW.id_orden_compra,NEW.id_producto,NEW.id_presentacion,NEW.presentacion_nombre,NEW.unidad_base_simbolo,NEW.factor_base,NEW.cantidad_pedida,NEW.costo_unitario,NEW.estado)
      IS DISTINCT FROM (OLD.id_orden_compra,OLD.id_producto,OLD.id_presentacion,OLD.presentacion_nombre,OLD.unidad_base_simbolo,OLD.factor_base,OLD.cantidad_pedida,OLD.costo_unitario,OLD.estado)
      OR NEW.cantidad_recibida_base<OLD.cantidad_recibida_base OR NEW.cantidad_recibida_base>OLD.cantidad_base THEN RAISE EXCEPTION 'Actualizacion de recepcion invalida'; END IF;
    RETURN NEW;
  END IF;
  SELECT * INTO prod FROM huaman.producto WHERE id_producto=NEW.id_producto;
  IF NOT FOUND OR prod.estado<>'A' THEN RAISE EXCEPTION 'Producto inexistente o inactivo'; END IF;
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion;
  IF NOT FOUND OR p.id_producto<>NEW.id_producto OR p.estado<>'A' THEN RAISE EXCEPTION 'Presentacion incompatible o inactiva'; END IF;
  SELECT abreviatura INTO unidad FROM huaman.unidad_medida WHERE id_unidad=prod.id_unidad;
  IF TG_TABLE_NAME='detalle_orden_compra' THEN
    SELECT * INTO oc FROM huaman.orden_compra WHERE id_orden_compra=NEW.id_orden_compra FOR UPDATE;
    IF NOT FOUND OR oc.estado_orden<>'BORRADOR' OR oc.estado<>'A' THEN RAISE EXCEPTION 'Orden no editable'; END IF;
    cantidad:=NEW.cantidad_pedida;
    IF NEW.cantidad_recibida_base<>0 THEN RAISE EXCEPTION 'Recepcion se registra al confirmar ingresos, no manualmente'; END IF;
    IF TG_OP='UPDATE' AND NEW.id_orden_compra<>OLD.id_orden_compra THEN RAISE EXCEPTION 'No mover linea a otra orden'; END IF;
  ELSE
    SELECT * INTO ing FROM huaman.ingreso_mercaderia WHERE id_ingreso=NEW.id_ingreso FOR UPDATE;
    IF NOT FOUND OR ing.estado_ingreso<>'BORRADOR' OR ing.estado<>'A' THEN RAISE EXCEPTION 'Ingreso no editable'; END IF;
    cantidad:=NEW.cantidad_recibida;
    IF ing.id_orden_compra IS NULL AND NEW.id_detalle_oc IS NOT NULL THEN RAISE EXCEPTION 'Ingreso sin orden no puede referenciar linea de orden'; END IF;
    IF ing.id_orden_compra IS NOT NULL THEN
      SELECT * INTO d FROM huaman.detalle_orden_compra WHERE id_detalle_oc=NEW.id_detalle_oc;
      IF NOT FOUND OR d.id_orden_compra<>ing.id_orden_compra OR d.id_producto<>NEW.id_producto OR d.id_presentacion<>NEW.id_presentacion THEN RAISE EXCEPTION 'Linea de orden incompatible con ingreso'; END IF;
      IF cantidad*p.factor_base>d.cantidad_base-d.cantidad_recibida_base THEN RAISE EXCEPTION 'Recepcion supera pendiente de orden'; END IF;
    END IF;
    IF TG_OP='UPDATE' AND NEW.id_ingreso<>OLD.id_ingreso THEN RAISE EXCEPTION 'No mover linea a otro ingreso'; END IF;
    IF prod.modo_control='GRANEL' AND NEW.condicion_fisica<>'GRANEL' THEN RAISE EXCEPTION 'Producto usa granel sin envases/tramos'; END IF;
    IF prod.modo_control='ENVASES' AND NEW.condicion_fisica NOT IN ('GRANEL','ENVASE') THEN RAISE EXCEPTION 'Producto usa envases o contenido suelto'; END IF;
    IF prod.modo_control='TRAMOS' AND NEW.condicion_fisica<>'TRAMO' THEN RAISE EXCEPTION 'Producto requiere identificar tramos'; END IF;
    IF NEW.condicion_fisica='ENVASE' AND (p.id_unidad_venta IS NOT NULL OR NEW.piezas<>cantidad) THEN RAISE EXCEPTION 'Envases completos requieren presentacion comercial y piezas coincidentes'; END IF;
    IF NEW.condicion_fisica='TRAMO' AND mod(cantidad*p.factor_base/NEW.piezas,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Longitud por pieza incompatible con incremento'; END IF;
  END IF;
  IF NOT p.admite_fracciones AND cantidad<>trunc(cantidad) THEN RAISE EXCEPTION 'Presentacion de compra indivisible'; END IF;
  IF mod(cantidad*p.factor_base,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad base incompatible con precision del producto'; END IF;
  NEW.factor_base:=p.factor_base;NEW.presentacion_nombre:=p.nombre;NEW.unidad_base_simbolo:=unidad;
  RETURN NEW;
END $$;
CREATE FUNCTION huaman.anular_orden_compra(p_orden bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;oc huaman.orden_compra%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;sol jsonb;motivo text:=nullif(btrim(p_motivo),'');previo text;cancelado jsonb;
BEGIN
actor:=huaman._actor_con_permiso('COM.OC_ANULAR');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador anula ordenes'; END IF;
IF p_orden IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' THEN RAISE EXCEPTION 'Datos de anulacion invalidos'; END IF;
sol:=jsonb_build_object('orden',p_orden,'motivo',motivo);
PERFORM pg_advisory_xact_lock(hashtextextended('COMPRA_ANULACION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('COM.OC_ANULAR','COM.INGRESO_DESCARTAR');
IF FOUND THEN IF b.accion<>'COM.OC_ANULAR' OR b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra operacion'; END IF;RETURN b.id_entidad;END IF;
SELECT * INTO oc FROM huaman.orden_compra WHERE id_orden_compra=p_orden FOR UPDATE;
IF NOT FOUND OR oc.estado<>'A' OR oc.estado_orden NOT IN ('BORRADOR','EMITIDA','PARCIAL') THEN RAISE EXCEPTION 'Orden completa, anulada o inexistente'; END IF;
-- No bloquear ingresos aqui: confirmar ingreso ya bloquea ingreso -> orden.
IF EXISTS(SELECT 1 FROM huaman.ingreso_mercaderia WHERE id_orden_compra=p_orden AND estado='A' AND estado_ingreso='BORRADOR') THEN RAISE EXCEPTION 'Hay ingreso en preparacion; confirmar o descartar su borrador primero'; END IF;
IF EXISTS(SELECT 1 FROM huaman.detalle_orden_compra d WHERE d.id_orden_compra=p_orden AND d.cantidad_recibida_base<>(SELECT coalesce(sum(di.cantidad_base),0) FROM huaman.detalle_ingreso di JOIN huaman.ingreso_mercaderia i USING(id_ingreso) WHERE di.id_detalle_oc=d.id_detalle_oc AND di.estado='A' AND i.estado='A' AND i.estado_ingreso='CONFIRMADO')) THEN RAISE EXCEPTION 'Cantidades recibidas requieren conciliacion con ingresos'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','ANULAR_ORDEN_COMPRA',true);
UPDATE huaman.detalle_orden_compra SET cantidad_cancelada_base=cantidad_base-cantidad_recibida_base WHERE id_orden_compra=p_orden AND estado='A';
SELECT coalesce(jsonb_agg(jsonb_build_object('detalle',id_detalle_oc,'producto',id_producto,'recibido_base',cantidad_recibida_base,'cancelado_base',cantidad_cancelada_base) ORDER BY id_detalle_oc),'[]'::jsonb) INTO cancelado FROM huaman.detalle_orden_compra WHERE id_orden_compra=p_orden AND estado='A';
UPDATE huaman.orden_compra SET estado_orden='ANULADA',motivo_anulacion=btrim(p_motivo),clave_anulacion=p_clave,fecha_anulacion=timezone('America/Lima',now()),id_anula=actor WHERE id_orden_compra=p_orden;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COM.OC_ANULAR','orden_compra',p_orden,p_clave::text,jsonb_build_object('solicitud',sol,'estado_anterior',oc.estado_orden,'lineas',cancelado));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_orden;
END $$;
CREATE FUNCTION huaman.anular_ingreso_borrador(p_ingreso bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;i huaman.ingreso_mercaderia%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;sol jsonb;motivo text:=nullif(btrim(p_motivo),'');previo text;
BEGIN
actor:=huaman._actor_con_permiso('COM.INGRESO');
IF p_ingreso IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' THEN RAISE EXCEPTION 'Datos de descarte invalidos'; END IF;
sol:=jsonb_build_object('ingreso',p_ingreso,'motivo',motivo);
PERFORM pg_advisory_xact_lock(hashtextextended('COMPRA_ANULACION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('COM.OC_ANULAR','COM.INGRESO_DESCARTAR');
IF FOUND THEN IF b.accion<>'COM.INGRESO_DESCARTAR' OR b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra operacion'; END IF;RETURN b.id_entidad;END IF;
SELECT * INTO i FROM huaman.ingreso_mercaderia WHERE id_ingreso=p_ingreso FOR UPDATE;
IF NOT FOUND OR i.estado<>'A' OR i.estado_ingreso<>'BORRADOR' THEN RAISE EXCEPTION 'Solo descartar ingresos borrador; confirmado no se revierte aqui'; END IF;
IF EXISTS(SELECT 1 FROM huaman.movimiento_inventario WHERE id_ingreso=p_ingreso) OR EXISTS(SELECT 1 FROM huaman.unidad_existencia u JOIN huaman.detalle_ingreso di USING(id_detalle_ingreso) WHERE di.id_ingreso=p_ingreso) THEN RAISE EXCEPTION 'Borrador con efectos requiere revision'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','ANULAR_INGRESO_BORRADOR',true);
UPDATE huaman.ingreso_mercaderia SET estado_ingreso='ANULADO',motivo_anulacion=btrim(p_motivo),clave_anulacion=p_clave,fecha_anulacion=timezone('America/Lima',now()),id_anula=actor WHERE id_ingreso=p_ingreso;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COM.INGRESO_DESCARTAR','ingreso_mercaderia',p_ingreso,p_clave::text,jsonb_build_object('solicitud',sol,'total_borrador',i.total));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_ingreso;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'anular_orden_compra' AS proceso,to_regprocedure('huaman.anular_orden_compra(bigint,uuid,text)') IS NOT NULL AS instalado
UNION ALL SELECT 'anular_ingreso_borrador',to_regprocedure('huaman.anular_ingreso_borrador(bigint,uuid,text)') IS NOT NULL;

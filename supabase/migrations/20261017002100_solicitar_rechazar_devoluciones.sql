-- FERRETERIA HUAMAN - BLOQUE21 - solicitar y rechazar devoluciones
-- Requiere01 a20. Solo instala. Aprobacion/reintegro fisico y monetario en bloque siguiente.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.convertir_cotizacion(bigint,bigint,text,uuid)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque20'; END IF;
IF to_regprocedure('huaman.solicitar_devolucion(bigint,text,text,jsonb,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque21 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE devolucion ADD COLUMN clave_solicitud uuid UNIQUE;
ALTER TABLE devolucion ADD COLUMN clave_rechazo uuid UNIQUE;
ALTER TABLE detalle_devolucion ADD COLUMN unidades_retorno jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(unidades_retorno)='array');
CREATE UNIQUE INDEX ux_devolucion_clave_evento ON bitacora_evento(referencia) WHERE accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR');
CREATE FUNCTION huaman._devolucion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('SOLICITAR_DEVOLUCION','RECHAZAR_DEVOLUCION')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_solicitud_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;modo text:=current_setting('app.proceso',true);
BEGIN
IF NOT coalesce(huaman._devolucion_en_curso(),false) THEN RAISE EXCEPTION 'Devoluciones solo mediante procesos'; END IF;
IF TG_OP='UPDATE' AND modo='RECHAZAR_DEVOLUCION' THEN
IF OLD.estado_devolucion<>'PENDIENTE' OR NEW.estado_devolucion<>'RECHAZADA' OR NEW.id_autoriza IS NULL OR NEW.fecha_decision IS NULL OR NEW.clave_rechazo IS NULL OR length(btrim(coalesce(NEW.motivo_rechazo,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['estado_devolucion','id_autoriza','fecha_decision','clave_rechazo','motivo_rechazo','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_devolucion','id_autoriza','fecha_decision','clave_rechazo','motivo_rechazo','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Rechazo altera datos no autorizados'; END IF;
RETURN NEW;
END IF;
IF modo<>'SOLICITAR_DEVOLUCION' OR NEW.estado_devolucion<>'PENDIENTE' OR NEW.estado<>'A' THEN RAISE EXCEPTION 'Decision y reintegro pendientes de aprobacion'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' THEN RAISE EXCEPTION 'Venta no confirmada'; END IF;
IF TG_OP='INSERT' THEN
IF NEW.monto_reintegro<>0 OR NEW.clave_solicitud IS NULL OR num_nonnulls(NEW.id_autoriza,NEW.fecha_decision,NEW.motivo_rechazo,NEW.id_caja,NEW.referencia_reintegro,NEW.clave_rechazo)>0 THEN RAISE EXCEPTION 'Solicitud inicial sin reintegro ejecutado'; END IF;
ELSE
IF pg_trigger_depth()<2 OR (to_jsonb(NEW)-ARRAY['monto_reintegro','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['monto_reintegro','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Solicitud inmutable; total solo desde lineas'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE FUNCTION huaman.validar_plan_retorno(p_producto bigint,p_cantidad_base numeric,p_estado text,p_plan jsonb) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE prod huaman.producto%ROWTYPE;pr huaman.presentacion_producto%ROWTYPE;item jsonb;qty numeric;suma numeric:=0;condicion text;
BEGIN
IF p_plan IS NULL OR jsonb_typeof(p_plan)<>'array' OR jsonb_array_length(p_plan)>1000 THEN RAISE EXCEPTION 'Plan fisico invalido'; END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=p_producto;
IF p_estado='DANADO' OR prod.modo_control='GRANEL' THEN
IF p_plan<>'[]'::jsonb THEN RAISE EXCEPTION 'Danado no vuelve a stock; granel no identifica piezas'; END IF;
RETURN;
END IF;
FOR item IN SELECT value FROM jsonb_array_elements(p_plan) LOOP
IF jsonb_typeof(item)<>'object' OR item-ARRAY['condicion','cantidad','id_presentacion']<>'{}'::jsonb OR jsonb_typeof(item->'cantidad') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Retorno requiere piezas nuevas con cantidad numerica'; END IF;
qty:=(item->>'cantidad')::numeric;condicion:=item->>'condicion';
IF qty<=0 OR qty<>round(qty,6) OR mod(qty,prod.incremento_base)<>0 OR condicion IS NULL OR (prod.modo_control='ENVASES' AND condicion NOT IN ('ENVASE','SUELTO')) OR (prod.modo_control='TRAMOS' AND condicion<>'TRAMO') THEN RAISE EXCEPTION 'Cantidad o condicion fisica incompatible'; END IF;
IF condicion='ENVASE' THEN
IF jsonb_typeof(item->'id_presentacion') IS DISTINCT FROM 'number' OR (item->>'id_presentacion')::numeric<>trunc((item->>'id_presentacion')::numeric) THEN RAISE EXCEPTION 'Envase requiere presentacion integra'; END IF;
SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=(item->>'id_presentacion')::bigint;
IF NOT FOUND OR pr.id_producto<>p_producto OR pr.estado<>'A' OR pr.id_unidad_venta IS NOT NULL OR pr.factor_base<>qty THEN RAISE EXCEPTION 'Envase devuelto debe comprobarse integro'; END IF;
ELSIF item?'id_presentacion' THEN RAISE EXCEPTION 'Solo envase declara presentacion'; END IF;
suma:=suma+qty;
END LOOP;
IF suma<>p_cantidad_base THEN RAISE EXCEPTION 'Piezas devueltas deben sumar cantidad base historica'; END IF;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_detalle_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE dev huaman.devolucion%ROWTYPE;det huaman.detalle_venta%ROWTYPE;aprobado numeric;importe_aprobado numeric;incremento numeric;
BEGIN
IF TG_OP<>'INSERT' OR NOT coalesce(huaman._devolucion_en_curso(),false) OR current_setting('app.proceso',true)<>'SOLICITAR_DEVOLUCION' OR NEW.estado<>'A' THEN RAISE EXCEPTION 'Detalle solo mediante solicitud; no editar'; END IF;
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=NEW.id_devolucion FOR UPDATE;
IF NOT FOUND OR dev.estado_devolucion<>'PENDIENTE' OR dev.estado<>'A' THEN RAISE EXCEPTION 'Solicitud no editable'; END IF;
SELECT * INTO det FROM huaman.detalle_venta WHERE id_detalle_venta=NEW.id_detalle_venta FOR UPDATE;
IF NOT FOUND OR det.id_venta<>dev.id_venta OR det.estado<>'A' THEN RAISE EXCEPTION 'Linea no pertenece a la venta'; END IF;
IF TG_OP='UPDATE' AND (NEW.id_devolucion,NEW.id_detalle_venta) IS DISTINCT FROM (OLD.id_devolucion,OLD.id_detalle_venta) THEN RAISE EXCEPTION 'No reasignar linea de devolucion'; END IF;
-- Las cantidades comerciales usan el factor de la venta, no el catalogo actual.
IF NEW.cantidad<=0 OR NEW.cantidad>det.cantidad THEN RAISE EXCEPTION 'Cantidad devuelta fuera de la venta original'; END IF;
SELECT incremento_base INTO incremento FROM huaman.producto WHERE id_producto=det.id_producto;
IF mod(NEW.cantidad*det.factor_base,incremento)<>0 THEN RAISE EXCEPTION 'Cantidad base no respeta precision fisica del producto'; END IF;
SELECT coalesce(sum(dd.cantidad),0),coalesce(sum(dd.importe),0) INTO aprobado,importe_aprobado FROM huaman.detalle_devolucion dd JOIN huaman.devolucion d ON d.id_devolucion=dd.id_devolucion
WHERE dd.id_detalle_venta=det.id_detalle_venta AND d.estado_devolucion='APROBADA' AND d.estado='A' AND dd.estado='A';
IF aprobado+NEW.cantidad>det.cantidad THEN RAISE EXCEPTION 'Devolucion acumulada supera cantidad vendida'; END IF;
NEW.id_producto:=det.id_producto;NEW.id_presentacion:=det.id_presentacion;NEW.presentacion_nombre:=det.presentacion_nombre;NEW.unidad_base_simbolo:=det.unidad_base_simbolo;
NEW.factor_base:=det.factor_base;NEW.costo_unitario_base:=det.costo_unitario_base;
NEW.importe:=round(det.importe*(aprobado+NEW.cantidad)/det.cantidad,2)-importe_aprobado;
IF NEW.importe<=0 THEN RAISE EXCEPTION 'Importe de devolucion redondea a cero'; END IF;
PERFORM huaman.validar_plan_retorno(NEW.id_producto,NEW.cantidad*NEW.factor_base,NEW.estado_producto,NEW.unidades_retorno);
RETURN NEW;
END $$;
CREATE FUNCTION huaman.solicitar_devolucion(p_venta bigint,p_forma text,p_motivo text,p_lineas jsonb,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;dev huaman.devolucion%ROWTYPE;det huaman.detalle_venta%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;
sol jsonb;motivo text:=nullif(btrim(p_motivo),'');dias integer;previo text;nuevo bigint;item jsonb;lid bigint;qty numeric;ids bigint[]:='{}';cobrado numeric;reintegrado numeric;saldo_deuda numeric;
BEGIN
actor:=huaman._actor_con_permiso('VEN.DEVOLVER');
IF p_venta IS NULL OR p_clave IS NULL OR p_forma IS NULL OR p_forma NOT IN ('EFECTIVO','YAPE','DEBITO','DESCUENTO_DEUDA') OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' OR p_lineas IS NULL OR jsonb_typeof(p_lineas)<>'array' OR jsonb_array_length(p_lineas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Datos de solicitud invalidos'; END IF;
sol:=jsonb_build_object('venta',p_venta,'forma',p_forma,'motivo',motivo,'lineas',p_lineas);
PERFORM pg_advisory_xact_lock(hashtextextended('DEVOLUCION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR');
IF FOUND THEN IF b.accion<>'VEN.DEV_SOLICITAR' OR b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra solicitud'; END IF;RETURN b.id_entidad;END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=p_venta FOR UPDATE;
IF NOT FOUND OR v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' THEN RAISE EXCEPTION 'Venta no confirmada'; END IF;
SELECT valor::integer INTO dias FROM huaman.parametro_sistema WHERE clave='VENTAS.DEVOLUCION_DIAS' AND estado='A';
IF dias IS NULL OR dias NOT BETWEEN 1 AND 365 OR v.fecha_venta::date>timezone('America/Lima',now())::date OR timezone('America/Lima',now())::date-v.fecha_venta::date>dias THEN RAISE EXCEPTION 'Venta fuera del plazo de devolucion configurado'; END IF;
IF EXISTS(SELECT 1 FROM huaman.devolucion WHERE id_venta=p_venta AND estado='A' AND estado_devolucion='PENDIENTE') THEN RAISE EXCEPTION 'Ya hay una solicitud pendiente para esta venta; revisar o rechazar antes de crear otra'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','SOLICITAR_DEVOLUCION',true);
INSERT INTO huaman.devolucion(id_venta,forma_reintegro,motivo,id_solicita,clave_solicitud) VALUES(p_venta,p_forma,motivo,actor,p_clave) RETURNING id_devolucion INTO nuevo;
FOR item IN SELECT value FROM jsonb_array_elements(p_lineas) LOOP
IF jsonb_typeof(item)<>'object' OR item-ARRAY['id_detalle_venta','cantidad','estado_producto','unidades']<>'{}'::jsonb OR jsonb_typeof(item->'id_detalle_venta') IS DISTINCT FROM 'number' OR (item->>'id_detalle_venta')::numeric<>trunc((item->>'id_detalle_venta')::numeric) OR jsonb_typeof(item->'cantidad') IS DISTINCT FROM 'number' OR coalesce(item->>'estado_producto','') NOT IN ('APTO','DANADO') THEN RAISE EXCEPTION 'Linea de solicitud invalida'; END IF;
lid:=(item->>'id_detalle_venta')::bigint;qty:=(item->>'cantidad')::numeric;
IF qty<=0 OR qty<>round(qty,6) OR lid=ANY(ids) THEN RAISE EXCEPTION 'Cantidad invalida o linea repetida'; END IF;ids:=array_append(ids,lid);
SELECT * INTO det FROM huaman.detalle_venta WHERE id_detalle_venta=lid AND id_venta=p_venta AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Linea ajena o inactiva'; END IF;
INSERT INTO huaman.detalle_devolucion(id_devolucion,id_detalle_venta,cantidad,estado_producto,unidades_retorno)
VALUES(nuevo,lid,qty,item->>'estado_producto',coalesce(item->'unidades','[]'::jsonb));
END LOOP;
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=nuevo;
IF dev.monto_reintegro<=0 THEN RAISE EXCEPTION 'Reintegro debe ser positivo'; END IF;
IF p_forma='DESCUENTO_DEUDA' THEN
SELECT saldo INTO saldo_deuda FROM huaman.cuenta_por_cobrar WHERE id_venta=p_venta AND estado='A' AND estado_cuenta IN ('PENDIENTE','VENCIDA');
IF saldo_deuda IS NULL OR dev.monto_reintegro>saldo_deuda THEN RAISE EXCEPTION 'No hay deuda suficiente para descontar'; END IF;
ELSE
SELECT coalesce(sum(monto),0) INTO cobrado FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio<>'CREDITO';
SELECT cobrado+coalesce(sum(a.monto),0) INTO cobrado FROM huaman.abono_credito a JOIN huaman.cuenta_por_cobrar cc USING(id_cuenta) WHERE cc.id_venta=p_venta AND a.estado='A';
SELECT coalesce(sum(monto_reintegro),0) INTO reintegrado FROM huaman.devolucion WHERE id_venta=p_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro<>'DESCUENTO_DEUDA';
IF dev.monto_reintegro>cobrado-reintegrado THEN RAISE EXCEPTION 'Reintegro monetario supera lo efectivamente cobrado; revisar deuda'; END IF;
IF p_forma='DEBITO' THEN
SELECT coalesce(sum(monto),0) INTO cobrado FROM huaman.pago WHERE id_venta=p_venta AND estado='A' AND medio='DEBITO';
SELECT cobrado+coalesce(sum(a.monto),0) INTO cobrado FROM huaman.abono_credito a JOIN huaman.cuenta_por_cobrar cc USING(id_cuenta) WHERE cc.id_venta=p_venta AND a.estado='A' AND a.medio='DEBITO';
SELECT coalesce(sum(monto_reintegro),0) INTO reintegrado FROM huaman.devolucion WHERE id_venta=p_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DEBITO';
IF dev.monto_reintegro>cobrado-reintegrado THEN RAISE EXCEPTION 'Reintegro de debito supera cobro de tarjeta disponible'; END IF;
END IF;
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'VEN.DEV_SOLICITAR','devolucion',nuevo,p_clave::text,jsonb_build_object('solicitud',sol,'monto_propuesto',dev.monto_reintegro));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
END $$;
CREATE FUNCTION huaman.rechazar_devolucion(p_devolucion bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;dev huaman.devolucion%ROWTYPE;venta_id bigint;b huaman.bitacora_evento%ROWTYPE;sol jsonb;previo text;motivo text:=nullif(btrim(p_motivo),'');
BEGIN
actor:=huaman._actor_con_permiso('VEN.DEVOLVER');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador rechaza devoluciones'; END IF;
IF p_devolucion IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' THEN RAISE EXCEPTION 'Datos de rechazo invalidos'; END IF;
sol:=jsonb_build_object('devolucion',p_devolucion,'motivo',motivo);
PERFORM pg_advisory_xact_lock(hashtextextended('DEVOLUCION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR');
IF FOUND THEN IF b.accion<>'VEN.DEV_RECHAZAR' OR b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otro rechazo'; END IF;RETURN b.id_entidad;END IF;
SELECT id_venta INTO venta_id FROM huaman.devolucion WHERE id_devolucion=p_devolucion;
IF NOT FOUND THEN RAISE EXCEPTION 'Devolucion inexistente'; END IF;
PERFORM 1 FROM huaman.venta WHERE id_venta=venta_id FOR UPDATE;
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=p_devolucion FOR UPDATE;
IF dev.estado<>'A' OR dev.estado_devolucion<>'PENDIENTE' THEN RAISE EXCEPTION 'Solicitud ya decidida'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','RECHAZAR_DEVOLUCION',true);
UPDATE huaman.devolucion SET estado_devolucion='RECHAZADA',id_autoriza=actor,fecha_decision=timezone('America/Lima',now()),motivo_rechazo=btrim(p_motivo),clave_rechazo=p_clave WHERE id_devolucion=p_devolucion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'VEN.DEV_RECHAZAR','devolucion',p_devolucion,p_clave::text,jsonb_build_object('solicitud',sol));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_devolucion;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'solicitar_devolucion' AS proceso,to_regprocedure('huaman.solicitar_devolucion(bigint,text,text,jsonb,uuid)') IS NOT NULL AS instalado
UNION ALL SELECT 'rechazar_devolucion',to_regprocedure('huaman.rechazar_devolucion(bigint,uuid,text)') IS NOT NULL;

-- FERRETERIA HUAMAN - BLOQUE22 - aprobar devoluciones
-- Requiere01 a21. Solo instala. No devuelve dinero ni ingresa material al instalar.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.solicitar_devolucion(bigint,text,text,jsonb,uuid)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque21'; END IF;
IF to_regprocedure('huaman.aprobar_devolucion(bigint,bigint,uuid,text,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque22 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE devolucion ADD COLUMN clave_aprobacion uuid UNIQUE;
ALTER TABLE devolucion ADD COLUMN observacion_aprobacion varchar(300);
ALTER TABLE detalle_devolucion ADD CONSTRAINT uq_det_devolucion_producto UNIQUE(id_detalle_devolucion,id_producto);
ALTER TABLE unidad_existencia ADD COLUMN id_detalle_devolucion bigint;
ALTER TABLE unidad_existencia ADD CONSTRAINT fk_unidad_devolucion FOREIGN KEY(id_detalle_devolucion,id_producto) REFERENCES detalle_devolucion(id_detalle_devolucion,id_producto) ON DELETE RESTRICT;
ALTER TABLE unidad_existencia DROP CONSTRAINT ck_unidad_origen_unico;
ALTER TABLE unidad_existencia ADD CONSTRAINT ck_unidad_origen_unico CHECK(num_nonnulls(id_detalle_ingreso,id_transformacion_origen,referencia_apertura,id_ajuste_origen,id_toma_origen,id_detalle_devolucion)=1);
CREATE UNIQUE INDEX ux_mov_devolucion_unico ON movimiento_caja(id_devolucion) WHERE tipo_movimiento='DEVOLUCION';
CREATE UNIQUE INDEX ux_reintegro_yape_dia ON devolucion((fecha_decision::date),referencia_reintegro) WHERE estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='YAPE';
DROP INDEX huaman.ux_devolucion_clave_evento;
CREATE UNIQUE INDEX ux_devolucion_clave_evento ON bitacora_evento(referencia) WHERE accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR','VEN.DEV_APROBAR');
CREATE OR REPLACE FUNCTION huaman._devolucion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('SOLICITAR_DEVOLUCION','RECHAZAR_DEVOLUCION','APROBAR_DEVOLUCION')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA','TRANSFORMAR_EXISTENCIA','REGISTRAR_AJUSTE','APROBAR_TOMA','APROBAR_DEVOLUCION')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._caja_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('ABRIR_CAJA','MOVIMIENTO_MANUAL_CAJA','CERRAR_CAJA','CONFIRMAR_VENTA','REGISTRAR_ABONO','APROBAR_DEVOLUCION')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_solicitud_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;modo text:=current_setting('app.proceso',true);
BEGIN
IF NOT coalesce(huaman._devolucion_en_curso(),false) THEN RAISE EXCEPTION 'Devoluciones solo mediante procesos'; END IF;
IF TG_OP='UPDATE' AND modo='APROBAR_DEVOLUCION' THEN
IF OLD.estado_devolucion<>'PENDIENTE' THEN RAISE EXCEPTION 'Solicitud ya decidida'; END IF;
IF NEW.estado_devolucion='PENDIENTE' AND pg_trigger_depth()>=2 AND (to_jsonb(NEW)-ARRAY['monto_reintegro','usmod','pcmod','fecmod']) IS NOT DISTINCT FROM (to_jsonb(OLD)-ARRAY['monto_reintegro','usmod','pcmod','fecmod']) THEN RETURN NEW; END IF;
IF NEW.estado_devolucion<>'APROBADA' OR NEW.id_autoriza IS NULL OR NEW.fecha_decision IS NULL OR NEW.id_caja IS NULL OR NEW.clave_aprobacion IS NULL OR (to_jsonb(NEW)-ARRAY['estado_devolucion','id_autoriza','fecha_decision','id_caja','referencia_reintegro','clave_aprobacion','observacion_aprobacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_devolucion','id_autoriza','fecha_decision','id_caja','referencia_reintegro','clave_aprobacion','observacion_aprobacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Aprobacion altera datos no autorizados'; END IF;
RETURN NEW;
END IF;
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
CREATE OR REPLACE FUNCTION huaman.solicitar_devolucion(p_venta bigint,p_forma text,p_motivo text,p_lineas jsonb,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;v huaman.venta%ROWTYPE;dev huaman.devolucion%ROWTYPE;det huaman.detalle_venta%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;
sol jsonb;motivo text:=nullif(btrim(p_motivo),'');dias integer;previo text;nuevo bigint;item jsonb;lid bigint;qty numeric;ids bigint[]:='{}';cobrado numeric;reintegrado numeric;saldo_deuda numeric;
BEGIN
actor:=huaman._actor_con_permiso('VEN.DEVOLVER');
IF p_venta IS NULL OR p_clave IS NULL OR p_forma IS NULL OR p_forma NOT IN ('EFECTIVO','YAPE','DEBITO','DESCUENTO_DEUDA') OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' OR p_lineas IS NULL OR jsonb_typeof(p_lineas)<>'array' OR jsonb_array_length(p_lineas) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Datos de solicitud invalidos'; END IF;
sol:=jsonb_build_object('venta',p_venta,'forma',p_forma,'motivo',motivo,'lineas',p_lineas);
PERFORM pg_advisory_xact_lock(hashtextextended('DEVOLUCION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR','VEN.DEV_APROBAR');
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
CREATE OR REPLACE FUNCTION huaman.rechazar_devolucion(p_devolucion bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;dev huaman.devolucion%ROWTYPE;venta_id bigint;b huaman.bitacora_evento%ROWTYPE;sol jsonb;previo text;motivo text:=nullif(btrim(p_motivo),'');
BEGIN
actor:=huaman._actor_con_permiso('VEN.DEVOLVER');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador rechaza devoluciones'; END IF;
IF p_devolucion IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' THEN RAISE EXCEPTION 'Datos de rechazo invalidos'; END IF;
sol:=jsonb_build_object('devolucion',p_devolucion,'motivo',motivo);
PERFORM pg_advisory_xact_lock(hashtextextended('DEVOLUCION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR','VEN.DEV_APROBAR');
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
CREATE OR REPLACE FUNCTION huaman.validar_detalle_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE dev huaman.devolucion%ROWTYPE;det huaman.detalle_venta%ROWTYPE;aprobado numeric;importe_aprobado numeric;incremento numeric;
BEGIN
IF NOT coalesce(huaman._devolucion_en_curso(),false) OR NEW.estado<>'A' THEN RAISE EXCEPTION 'Detalle sin proceso autorizado'; END IF;
IF TG_OP='UPDATE' THEN
IF current_setting('app.proceso',true)<>'APROBAR_DEVOLUCION' OR (to_jsonb(NEW)-ARRAY['importe','cantidad_base','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['importe','cantidad_base','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Aprobacion solo revalida importe'; END IF;
ELSIF current_setting('app.proceso',true)<>'SOLICITAR_DEVOLUCION' THEN RAISE EXCEPTION 'Detalle se crea en solicitud'; END IF;
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
CREATE OR REPLACE FUNCTION huaman.bloquear_credito_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
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
CREATE OR REPLACE FUNCTION huaman.registrar_abono(p_cuenta bigint,p_caja bigint,p_monto numeric,p_medio text,p_clave uuid,p_referencia text DEFAULT NULL,p_marca text DEFAULT NULL,p_ultimos text DEFAULT NULL,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.caja_diaria%ROWTYPE;deuda huaman.cuenta_por_cobrar%ROWTYPE;a huaman.abono_credito%ROWTYPE;nuevo bigint;previo text;restante numeric;idcliente bigint;
ref text:=nullif(btrim(p_referencia),'');marca text:=nullif(btrim(p_marca),'');ultimos text:=nullif(btrim(p_ultimos),'');obs text:=nullif(btrim(p_observacion),'');
BEGIN
actor:=huaman._actor_con_permiso('CRE.ABONAR');
IF p_cuenta IS NULL OR p_caja IS NULL OR p_clave IS NULL OR p_monto IS NULL OR p_monto::text IN ('NaN','Infinity','-Infinity') OR p_monto<=0 OR p_monto<>round(p_monto,2) OR p_medio IS NULL OR p_medio NOT IN ('EFECTIVO','YAPE','DEBITO') OR length(obs)>300 OR length(marca)>30 THEN RAISE EXCEPTION 'Datos del abono invalidos'; END IF;
IF (p_medio='EFECTIVO' AND ref IS NOT NULL) OR (p_medio='YAPE' AND (ref IS NULL OR ref !~ '^[0-9]{6,20}$')) OR (p_medio='DEBITO' AND (ref IS NULL OR length(ref)>40)) OR (p_medio<>'DEBITO' AND (marca IS NOT NULL OR ultimos IS NOT NULL)) OR (ultimos IS NOT NULL AND ultimos !~ '^[0-9]{4}$') THEN RAISE EXCEPTION 'Referencia o datos de pago invalidos'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('ABONO:'||p_clave::text,0));
SELECT * INTO a FROM huaman.abono_credito WHERE clave_idempotencia=p_clave;
IF FOUND THEN
IF (a.id_cuenta,a.id_caja,a.monto,a.medio,a.nro_operacion,a.marca_tarjeta,a.ultimos_cuatro,a.observacion) IS DISTINCT FROM (p_cuenta,p_caja,p_monto,p_medio,ref,marca,ultimos,obs) THEN RAISE EXCEPTION 'Clave usada con otros datos'; END IF;
RETURN a.id_abono;
END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=p_caja FOR UPDATE;
IF NOT FOUND OR c.estado<>'A' OR c.estado_caja<>'ABIERTA' OR c.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Se requiere caja abierta del dia'; END IF;
SELECT id_cliente INTO idcliente FROM huaman.cuenta_por_cobrar WHERE id_cuenta=p_cuenta;
IF NOT FOUND THEN RAISE EXCEPTION 'Cuenta inexistente'; END IF;
-- Mismo orden caja -> cliente que la confirmacion de ventas; serializa el limite disponible.
PERFORM 1 FROM huaman.cliente WHERE id_cliente=idcliente FOR UPDATE;
SELECT * INTO deuda FROM huaman.cuenta_por_cobrar WHERE id_cuenta=p_cuenta FOR UPDATE;
IF deuda.estado<>'A' OR deuda.estado_cuenta NOT IN ('PENDIENTE','VENCIDA') OR deuda.saldo<=0 OR p_monto>deuda.saldo THEN RAISE EXCEPTION 'Cuenta no cobrable o abono superior al saldo'; END IF;
IF deuda.saldo<>deuda.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=p_cuenta AND estado='A')-(SELECT coalesce(sum(monto_reintegro),0) FROM huaman.devolucion WHERE id_venta=deuda.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DESCUENTO_DEUDA') THEN RAISE EXCEPTION 'Saldo requiere revision; no corregir con un abono'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','REGISTRAR_ABONO',true);
INSERT INTO huaman.abono_credito(id_cuenta,id_caja,monto,medio,nro_operacion,clave_idempotencia,marca_tarjeta,ultimos_cuatro,observacion)
VALUES(p_cuenta,p_caja,p_monto,p_medio,ref,p_clave,marca,ultimos,obs) RETURNING id_abono INTO nuevo;
restante:=deuda.saldo-p_monto;
UPDATE huaman.cuenta_por_cobrar SET saldo=restante,estado_cuenta=CASE WHEN restante=0 THEN 'CANCELADA' WHEN fecha_vencimiento<c.fecha THEN 'VENCIDA' ELSE 'PENDIENTE' END WHERE id_cuenta=p_cuenta;
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,id_abono,clave_idempotencia) VALUES(p_caja,'ABONO',p_medio,'I',p_monto,nuevo,p_clave);
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'CRE.ABONAR','abono_credito',nuevo,p_clave::text,jsonb_build_object('cuenta',p_cuenta,'caja',p_caja,'monto',p_monto,'medio',p_medio,'saldo_anterior',deuda.saldo,'saldo_nuevo',restante));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
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
ELSE RAISE EXCEPTION 'Reintegro no habilitado'; END IF;
SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) INTO disponible FROM huaman.movimiento_caja WHERE id_caja=NEW.id_caja AND medio=NEW.medio;
IF disponible+(CASE WHEN NEW.sentido='I' THEN NEW.importe ELSE -NEW.importe END)<0 THEN RAISE EXCEPTION 'Egreso supera saldo disponible'; END IF;
RETURN NEW;
END $$;
CREATE FUNCTION huaman.aprobar_devolucion(p_devolucion bigint,p_caja bigint,p_clave uuid,p_referencia text DEFAULT NULL,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;dev huaman.devolucion%ROWTYPE;v huaman.venta%ROWTYPE;c huaman.caja_diaria%ROWTYPE;cc huaman.cuenta_por_cobrar%ROWTYPE;prod huaman.producto%ROWTYPE;dd huaman.detalle_devolucion%ROWTYPE;b huaman.bitacora_evento%ROWTYPE;
sol jsonb;ref text:=nullif(btrim(p_referencia),'');obs text:=nullif(btrim(p_observacion),'');venta_id bigint;dias integer;previo text;cobrado numeric;reintegrado numeric;restante numeric;qty numeric;saldo_nuevo numeric;promedio numeric;mov bigint;item jsonb;numero integer;pres_base bigint;condicion text;
BEGIN
actor:=huaman._actor_con_permiso('VEN.DEVOLVER');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador aprueba devoluciones'; END IF;
IF p_devolucion IS NULL OR p_caja IS NULL OR p_clave IS NULL OR length(obs)>300 OR coalesce(obs,'') ~ '[<>]' THEN RAISE EXCEPTION 'Datos de aprobacion invalidos'; END IF;
sol:=jsonb_build_object('devolucion',p_devolucion,'caja',p_caja,'referencia',ref,'observacion',obs);
PERFORM pg_advisory_xact_lock(hashtextextended('DEVOLUCION:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('VEN.DEV_SOLICITAR','VEN.DEV_RECHAZAR','VEN.DEV_APROBAR');
IF FOUND THEN IF b.accion<>'VEN.DEV_APROBAR' OR b.valor_nuevo->'solicitud' IS DISTINCT FROM sol THEN RAISE EXCEPTION 'Clave usada con otra operacion'; END IF;RETURN b.id_entidad;END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=p_caja FOR UPDATE;
IF NOT FOUND OR c.estado<>'A' OR c.estado_caja<>'ABIERTA' OR c.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Caja abierta del dia requerida'; END IF;
SELECT id_venta INTO venta_id FROM huaman.devolucion WHERE id_devolucion=p_devolucion;
IF NOT FOUND THEN RAISE EXCEPTION 'Devolucion inexistente'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=venta_id FOR UPDATE;
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=p_devolucion FOR UPDATE;
IF dev.estado<>'A' OR dev.estado_devolucion<>'PENDIENTE' OR v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' THEN RAISE EXCEPTION 'Solicitud o venta no disponibles'; END IF;
IF NOT v.entrega_inmediata AND NOT EXISTS(SELECT 1 FROM huaman.despacho WHERE id_venta=v.id_venta AND estado='A' AND estado_despacho='ENTREGADO') THEN RAISE EXCEPTION 'Verificar entrega fisica antes de aprobar devolucion; pedido pendiente no es producto retornado'; END IF;
SELECT valor::integer INTO dias FROM huaman.parametro_sistema WHERE clave='VENTAS.DEVOLUCION_DIAS' AND estado='A';
IF dias IS NULL OR dias NOT BETWEEN 1 AND 365 OR c.fecha-v.fecha_venta::date NOT BETWEEN 0 AND dias THEN RAISE EXCEPTION 'Venta fuera de plazo configurado'; END IF;
IF (dev.forma_reintegro IN ('EFECTIVO','DESCUENTO_DEUDA') AND ref IS NOT NULL) OR (dev.forma_reintegro='YAPE' AND (ref IS NULL OR ref !~ '^[0-9]{6,20}$')) OR (dev.forma_reintegro='DEBITO' AND (ref IS NULL OR length(ref)>40)) THEN RAISE EXCEPTION 'Referencia de reintegro incompatible o faltante'; END IF;
IF v.id_cliente IS NOT NULL THEN PERFORM 1 FROM huaman.cliente WHERE id_cliente=v.id_cliente FOR UPDATE; END IF;
SELECT * INTO cc FROM huaman.cuenta_por_cobrar WHERE id_venta=v.id_venta FOR UPDATE;
PERFORM 1 FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_devolucion WHERE id_devolucion=p_devolucion AND estado='A') ORDER BY id_producto FOR UPDATE;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_devolucion WHERE id_devolucion=p_devolucion AND estado='A') THEN RAISE EXCEPTION 'Solicitud sin lineas'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','APROBAR_DEVOLUCION',true);
-- Recalculo con cantidades y redondeos acumulados realmente aprobados, antes de decidir.
UPDATE huaman.detalle_devolucion SET cantidad=cantidad WHERE id_devolucion=p_devolucion AND estado='A';
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=p_devolucion;
IF dev.monto_reintegro<=0 THEN RAISE EXCEPTION 'Importe invalido'; END IF;
IF dev.forma_reintegro='DESCUENTO_DEUDA' THEN
IF cc.id_cuenta IS NULL OR cc.estado<>'A' OR cc.estado_cuenta NOT IN ('PENDIENTE','VENCIDA') OR cc.saldo<dev.monto_reintegro THEN RAISE EXCEPTION 'Saldo de deuda insuficiente; rechazar y corregir solicitud'; END IF;
IF cc.saldo<>cc.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=cc.id_cuenta AND estado='A')-(SELECT coalesce(sum(monto_reintegro),0) FROM huaman.devolucion WHERE id_venta=v.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DESCUENTO_DEUDA') THEN RAISE EXCEPTION 'Deuda requiere conciliacion'; END IF;
ELSE
SELECT coalesce(sum(monto),0) INTO cobrado FROM huaman.pago WHERE id_venta=v.id_venta AND estado='A' AND medio<>'CREDITO';
SELECT cobrado+coalesce(sum(a.monto),0) INTO cobrado FROM huaman.abono_credito a WHERE a.id_cuenta=cc.id_cuenta AND a.estado='A';
SELECT coalesce(sum(monto_reintegro),0) INTO reintegrado FROM huaman.devolucion WHERE id_venta=v.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro<>'DESCUENTO_DEUDA';
IF dev.monto_reintegro>cobrado-reintegrado THEN RAISE EXCEPTION 'Reintegro supera dinero efectivamente cobrado'; END IF;
IF dev.forma_reintegro='DEBITO' THEN
SELECT coalesce(sum(monto),0) INTO cobrado FROM huaman.pago WHERE id_venta=v.id_venta AND estado='A' AND medio='DEBITO';
SELECT cobrado+coalesce(sum(a.monto),0) INTO cobrado FROM huaman.abono_credito a WHERE a.id_cuenta=cc.id_cuenta AND a.estado='A' AND a.medio='DEBITO';
SELECT coalesce(sum(monto_reintegro),0) INTO reintegrado FROM huaman.devolucion WHERE id_venta=v.id_venta AND estado='A' AND estado_devolucion='APROBADA' AND forma_reintegro='DEBITO';
IF dev.monto_reintegro>cobrado-reintegrado THEN RAISE EXCEPTION 'Reintegro de tarjeta supera cobro de debito'; END IF;
END IF;
END IF;
FOR dd IN SELECT * FROM huaman.detalle_devolucion WHERE id_devolucion=p_devolucion AND estado='A' ORDER BY id_producto,id_detalle_devolucion LOOP
IF dd.estado_producto='DANADO' THEN CONTINUE; END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=dd.id_producto;
IF prod.estado<>'A' THEN RAISE EXCEPTION 'Reactivar producto apto antes de reingresar'; END IF;
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto bloqueado por conteo'; END IF;
IF prod.modo_control<>'GRANEL' AND prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=prod.id_producto AND estado='A') THEN RAISE EXCEPTION 'Stock fisico no conciliado'; END IF;
qty:=dd.cantidad_base;saldo_nuevo:=prod.stock_actual+qty;
promedio:=round((prod.stock_actual*prod.costo_promedio+qty*dd.costo_unitario_base)/saldo_nuevo,6);
IF promedio<=0 THEN RAISE EXCEPTION 'Costo recuperado invalido'; END IF;
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_devolucion,clave_idempotencia)
VALUES(prod.id_producto,'DEVOLUCION_VENTA','E',qty,prod.stock_actual,saldo_nuevo,dd.costo_unitario_base,p_devolucion,gen_random_uuid()) RETURNING id_movimiento INTO mov;
IF prod.modo_control<>'GRANEL' THEN
SELECT id_presentacion INTO pres_base FROM huaman.presentacion_producto WHERE id_producto=prod.id_producto AND es_base AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Presentacion base inactiva'; END IF;
numero:=0;
FOR item IN SELECT value FROM jsonb_array_elements(dd.unidades_retorno) LOOP
numero:=numero+1;condicion:=item->>'condicion';
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_detalle_devolucion)
VALUES(prod.id_producto,CASE WHEN condicion='ENVASE' THEN (item->>'id_presentacion')::bigint ELSE pres_base END,'DV-'||p_devolucion||'-'||dd.id_detalle_devolucion||'-'||numero,condicion,(item->>'cantidad')::numeric,(item->>'cantidad')::numeric,dd.id_detalle_devolucion);
END LOOP;
IF saldo_nuevo<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=prod.id_producto AND estado='A') THEN RAISE EXCEPTION 'Retorno fisico no coincide con saldo'; END IF;
END IF;
UPDATE huaman.producto SET stock_actual=saldo_nuevo,costo_promedio=promedio WHERE id_producto=prod.id_producto;
INSERT INTO huaman.historial_costo(id_producto,id_movimiento,motivo,referencia,stock_anterior,stock_nuevo,costo_promedio_anterior,costo_promedio_nuevo,ultimo_costo_anterior,ultimo_costo_nuevo)
VALUES(prod.id_producto,mov,'Devolucion apta al costo historico','DEVOLUCION:'||p_devolucion,prod.stock_actual,saldo_nuevo,prod.costo_promedio,promedio,prod.ultimo_costo_compra,prod.ultimo_costo_compra);
IF saldo_nuevo>prod.stock_minimo OR prod.stock_minimo=0 THEN
UPDATE huaman.alerta_stock SET estado_alerta='CERRADA',fecha_cierre=timezone('America/Lima',now()) WHERE id_producto=prod.id_producto AND estado='A' AND estado_alerta='ABIERTA';
ELSIF NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=prod.id_producto AND estado='A' AND estado_alerta='ABIERTA') THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(prod.id_producto,saldo_nuevo,prod.stock_minimo);
END IF;
END LOOP;
UPDATE huaman.devolucion SET estado_devolucion='APROBADA',id_autoriza=actor,fecha_decision=timezone('America/Lima',now()),id_caja=p_caja,referencia_reintegro=ref,clave_aprobacion=p_clave,observacion_aprobacion=obs WHERE id_devolucion=p_devolucion;
IF dev.forma_reintegro='DESCUENTO_DEUDA' THEN
restante:=cc.saldo-dev.monto_reintegro;
UPDATE huaman.cuenta_por_cobrar SET saldo=restante,estado_cuenta=CASE WHEN restante=0 THEN 'CANCELADA' WHEN fecha_vencimiento<c.fecha THEN 'VENCIDA' ELSE 'PENDIENTE' END WHERE id_cuenta=cc.id_cuenta;
ELSE
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,id_devolucion,clave_idempotencia) VALUES(p_caja,'DEVOLUCION',dev.forma_reintegro,'E',dev.monto_reintegro,p_devolucion,p_clave);
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'VEN.DEV_APROBAR','devolucion',p_devolucion,p_clave::text,jsonb_build_object('solicitud',sol,'venta',v.id_venta,'monto',dev.monto_reintegro,'forma',dev.forma_reintegro));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_devolucion;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'aprobar_devolucion' AS proceso,to_regprocedure('huaman.aprobar_devolucion(bigint,bigint,uuid,text,text)') IS NOT NULL AS instalado;

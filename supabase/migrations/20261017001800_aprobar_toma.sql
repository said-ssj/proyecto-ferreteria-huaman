-- FERRETERIA HUAMAN - BLOQUE 18 - aprobar toma y aplicar diferencias
-- Requiere 01 a 17. Solo instala; no aprueba tomas ni cambia stock real.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.guardar_conteo(bigint,bigint,numeric,integer,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 17'; END IF;
IF to_regprocedure('huaman.aprobar_toma(bigint,integer,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 18 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE toma_inventario ADD COLUMN clave_aprobacion uuid UNIQUE;
ALTER TABLE toma_inventario ADD COLUMN observacion_aprobacion varchar(300);
ALTER TABLE detalle_toma_inventario ADD COLUMN stock_previo_aprobacion numeric(18,6) CHECK(stock_previo_aprobacion>=0);
ALTER TABLE detalle_toma_inventario ADD COLUMN diferencia_aplicada numeric(18,6);
ALTER TABLE detalle_toma_inventario ADD CONSTRAINT ck_diferencia_aplicada CHECK((stock_previo_aprobacion IS NULL AND diferencia_aplicada IS NULL) OR (stock_previo_aprobacion IS NOT NULL AND diferencia_aplicada IS NOT NULL AND cantidad_contada IS NOT NULL AND diferencia_aplicada=cantidad_contada-stock_previo_aprobacion));
ALTER TABLE unidad_existencia ADD COLUMN id_toma_origen bigint;
ALTER TABLE unidad_existencia ADD CONSTRAINT fk_unidad_toma_producto FOREIGN KEY(id_toma_origen,id_producto) REFERENCES detalle_toma_inventario(id_toma,id_producto) ON DELETE RESTRICT;
ALTER TABLE unidad_existencia DROP CONSTRAINT ck_unidad_origen_unico;
ALTER TABLE unidad_existencia ADD CONSTRAINT ck_unidad_origen_unico CHECK(num_nonnulls(id_detalle_ingreso,id_transformacion_origen,referencia_apertura,id_ajuste_origen,id_toma_origen)=1);
DROP INDEX huaman.ux_toma_clave_evento;
CREATE UNIQUE INDEX ux_toma_clave_evento ON bitacora_evento(referencia) WHERE accion IN ('INV.TOMA_INICIAR','INV.TOMA_CONTAR','INV.TOMA_CERRAR','INV.TOMA_REABRIR','INV.TOMA_ANULAR','INV.TOMA_APROBAR');
CREATE OR REPLACE FUNCTION huaman._toma_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('INICIAR_TOMA','GUARDAR_CONTEO','CERRAR_TOMA','REABRIR_TOMA','ANULAR_TOMA','APROBAR_TOMA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA','TRANSFORMAR_EXISTENCIA','REGISTRAR_AJUSTE','APROBAR_TOMA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._reintento_toma(p_clave uuid,p_solicitud jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE b huaman.bitacora_evento%ROWTYPE;
BEGIN
IF p_clave IS NULL THEN RAISE EXCEPTION 'Clave requerida'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('TOMA:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('INV.TOMA_INICIAR','INV.TOMA_CONTAR','INV.TOMA_CERRAR','INV.TOMA_REABRIR','INV.TOMA_ANULAR','INV.TOMA_APROBAR');
IF FOUND THEN
IF b.valor_nuevo->'solicitud' IS DISTINCT FROM p_solicitud THEN RAISE EXCEPTION 'Clave usada con otros datos de toma'; END IF;
RETURN b.id_entidad;
END IF;
RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION huaman.validar_toma_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE modo text:=current_setting('app.proceso',true);t huaman.toma_inventario%ROWTYPE;
BEGIN
IF NOT coalesce(huaman._toma_en_curso(),false) THEN RAISE EXCEPTION 'Toma sin proceso interno'; END IF;
IF modo='APROBAR_TOMA' THEN
IF TG_OP<>'UPDATE' THEN RAISE EXCEPTION 'Aprobacion solo actualiza registros existentes'; END IF;
IF TG_TABLE_NAME='toma_inventario' THEN
IF OLD.estado_toma<>'CERRADA' OR NEW.estado_toma<>'APROBADA' OR NEW.revision<>OLD.revision+1 OR NEW.id_aprueba IS NULL OR NEW.fecha_aprobacion IS NULL OR NEW.clave_aprobacion IS NULL OR (to_jsonb(NEW)-ARRAY['estado_toma','revision','id_aprueba','fecha_aprobacion','clave_aprobacion','observacion_aprobacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_toma','revision','id_aprueba','fecha_aprobacion','clave_aprobacion','observacion_aprobacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Aprobacion de cabecera invalida'; END IF;
ELSE
SELECT * INTO t FROM huaman.toma_inventario WHERE id_toma=NEW.id_toma;
IF t.estado_toma<>'CERRADA' OR OLD.estado_linea<>'CONTADA' OR OLD.estado<>'A' OR NEW.stock_previo_aprobacion IS NULL OR NEW.diferencia_aplicada IS NULL OR (to_jsonb(NEW)-ARRAY['stock_previo_aprobacion','diferencia_aplicada','diferencia','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['stock_previo_aprobacion','diferencia_aplicada','diferencia','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Aplicacion no puede cambiar conteo ni snapshot'; END IF;
END IF;
RETURN NEW;
END IF;
IF TG_TABLE_NAME='toma_inventario' THEN
IF TG_OP='INSERT' THEN
IF modo<>'INICIAR_TOMA' OR NEW.estado_toma<>'EN_CONTEO' OR NEW.revision<>0 OR NEW.estado<>'A' OR num_nonnulls(NEW.id_aprueba,NEW.fecha_aprobacion,NEW.id_cierra,NEW.fecha_cierre,NEW.motivo_anulacion)>0 THEN RAISE EXCEPTION 'Inicio de toma invalido'; END IF;
ELSE
IF OLD.estado<>'A' OR NEW.estado<>'A' OR OLD.estado_toma IN ('APROBADA','ANULADA') OR NEW.revision<>OLD.revision+1 OR (to_jsonb(NEW)-ARRAY['estado_toma','revision','fecha_cierre','id_cierra','motivo_anulacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_toma','revision','fecha_cierre','id_cierra','motivo_anulacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Cabecera de toma inmutable fuera de transicion'; END IF;
IF NOT ((modo='CERRAR_TOMA' AND OLD.estado_toma='EN_CONTEO' AND NEW.estado_toma='CERRADA' AND NEW.fecha_cierre IS NOT NULL AND NEW.id_cierra IS NOT NULL) OR (modo='REABRIR_TOMA' AND OLD.estado_toma='CERRADA' AND NEW.estado_toma='EN_CONTEO' AND NEW.fecha_cierre IS NULL AND NEW.id_cierra IS NULL) OR (modo='ANULAR_TOMA' AND NEW.estado_toma='ANULADA' AND length(btrim(NEW.motivo_anulacion)) BETWEEN 10 AND 200)) THEN RAISE EXCEPTION 'Transicion de toma invalida'; END IF;
END IF;
ELSE
SELECT * INTO t FROM huaman.toma_inventario WHERE id_toma=NEW.id_toma;
IF t.estado<>'A' OR t.estado_toma<>'EN_CONTEO' THEN RAISE EXCEPTION 'Conteo no editable'; END IF;
IF TG_OP='INSERT' THEN
IF modo<>'INICIAR_TOMA' OR NEW.estado_linea<>'PENDIENTE' OR NEW.cantidad_contada IS NOT NULL OR NEW.revision<>0 OR NEW.unidades_contadas<>'[]'::jsonb THEN RAISE EXCEPTION 'Linea inicial invalida'; END IF;
ELSE
IF modo NOT IN ('GUARDAR_CONTEO','REABRIR_TOMA') OR NEW.revision<>OLD.revision+1 OR (to_jsonb(NEW)-ARRAY['cantidad_contada','diferencia','estado_linea','unidades_contadas','revision','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['cantidad_contada','diferencia','estado_linea','unidades_contadas','revision','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Linea solo modifica conteo; conserva snapshot'; END IF;
END IF;
END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.proteger_catalogo_en_toma() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF current_setting('app.proceso',true)='APROBAR_TOMA' AND coalesce(huaman._toma_en_curso(),false) THEN
IF (to_jsonb(NEW)-ARRAY['stock_actual','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['stock_actual','usmod','pcmod','fecmod']) OR NOT EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario d JOIN huaman.toma_inventario t USING(id_toma) WHERE t.id_toma=nullif(current_setting('app.toma_id',true),'')::bigint AND t.estado_toma='CERRADA' AND t.estado='A' AND d.estado='A' AND d.estado_linea='CONTADA' AND d.id_producto=NEW.id_producto AND d.cantidad_contada=NEW.stock_actual) THEN RAISE EXCEPTION 'Saldo no coincide con conteo autorizado'; END IF;
RETURN NEW;
END IF;
IF (NEW.stock_actual,NEW.costo_promedio,NEW.ultimo_costo_compra) IS DISTINCT FROM (OLD.stock_actual,OLD.costo_promedio,OLD.ultimo_costo_compra) AND EXISTS(SELECT 1 FROM huaman.toma_inventario t WHERE t.estado='A' AND t.estado_toma IN ('EN_CONTEO','CERRADA') AND (t.alcance='TODO' OR t.id_categoria=OLD.id_categoria OR EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario d WHERE d.id_toma=t.id_toma AND d.id_producto=OLD.id_producto))) THEN RAISE EXCEPTION 'Saldos y costos bloqueados por toma abierta'; END IF;
IF (NEW.id_categoria,NEW.estado,NEW.incremento_base,NEW.admite_fracciones) IS DISTINCT FROM (OLD.id_categoria,OLD.estado,OLD.incremento_base,OLD.admite_fracciones) AND EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario d JOIN huaman.toma_inventario t USING(id_toma) WHERE d.id_producto=OLD.id_producto AND t.estado='A' AND t.estado_toma IN ('EN_CONTEO','CERRADA')) THEN RAISE EXCEPTION 'No cambiar categoria, precision ni estado de producto incluido en toma abierta'; END IF;
RETURN NEW;
END $$;
CREATE FUNCTION huaman.aprobar_toma(p_toma bigint,p_revision integer,p_clave uuid,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;t huaman.toma_inventario%ROWTYPE;d huaman.detalle_toma_inventario%ROWTYPE;prod huaman.producto%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;pr huaman.presentacion_producto%ROWTYPE;
sol jsonb;nuevo bigint;previo text;prev_toma text;obs text:=nullif(btrim(p_observacion),'');delta numeric;lineas integer:=0;ajustes integer:=0;numero integer;pres_base bigint;
item jsonb;qty numeric;suma numeric;uid bigint;ids bigint[];condicion text;unidades_antes jsonb;
BEGIN
actor:=huaman._actor_con_permiso('INV.TOMA_GESTIONAR');
IF NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM' AND r.estado='A') THEN RAISE EXCEPTION 'Solo administrador puede aprobar toma'; END IF;
IF p_toma IS NULL OR p_revision IS NULL OR p_revision<0 OR length(obs)>300 OR coalesce(obs,'') ~ '[<>]' THEN RAISE EXCEPTION 'Datos de aprobacion invalidos'; END IF;
sol:=jsonb_build_object('paso','APROBAR','toma',p_toma,'revision',p_revision,'observacion',obs);nuevo:=huaman._reintento_toma(p_clave,sol);IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
SELECT * INTO t FROM huaman.toma_inventario WHERE id_toma=p_toma FOR UPDATE;
IF NOT FOUND OR t.estado<>'A' OR t.estado_toma<>'CERRADA' OR t.revision<>p_revision THEN RAISE EXCEPTION 'Toma no cerrada o modificada; recargue antes de aprobar'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario WHERE id_toma=p_toma AND estado='A' AND estado_linea='CONTADA') THEN RAISE EXCEPTION 'No hay lineas contadas para aprobar'; END IF;
PERFORM 1 FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_toma_inventario WHERE id_toma=p_toma AND estado='A' AND estado_linea='CONTADA') ORDER BY id_producto FOR UPDATE;
previo:=current_setting('app.proceso',true);prev_toma:=current_setting('app.toma_id',true);PERFORM set_config('app.proceso','APROBAR_TOMA',true);PERFORM set_config('app.toma_id',p_toma::text,true);
FOR d IN SELECT * FROM huaman.detalle_toma_inventario WHERE id_toma=p_toma AND estado='A' AND estado_linea='CONTADA' ORDER BY id_producto FOR UPDATE LOOP
lineas:=lineas+1;numero:=0;suma:=0;ids:='{}';
SELECT * INTO prod FROM huaman.producto WHERE id_producto=d.id_producto;
IF prod.estado<>'A' OR d.cantidad_contada IS NULL OR mod(d.cantidad_contada,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Producto inactivo o conteo incompatible'; END IF;
-- El modelo instalado bloquea movimientos durante conteo. Cambios de mantenimiento se revisan, no se absorben silenciosamente.
IF prod.stock_actual<>d.stock_sistema OR prod.costo_promedio<>d.costo_referencia THEN RAISE EXCEPTION 'Saldo o costo cambio desde inicio; revisar y rehacer toma antes de aprobar'; END IF;
delta:=d.cantidad_contada-prod.stock_actual;
IF (delta<>0 OR d.cantidad_contada>0) AND prod.costo_promedio<=0 THEN RAISE EXCEPTION 'Costo conocido requerido para aplicar conteo'; END IF;
PERFORM 1 FROM huaman.unidad_existencia WHERE id_producto=d.id_producto ORDER BY id_unidad_existencia FOR UPDATE;
IF prod.modo_control='GRANEL' THEN
IF d.unidades_contadas<>'[]'::jsonb THEN RAISE EXCEPTION 'Granel no usa unidades individuales'; END IF;
ELSE
-- Lista completa de existencias encontradas. Las omitidas equivalen a no encontradas.
FOR item IN SELECT value FROM jsonb_array_elements(d.unidades_contadas) LOOP
IF jsonb_typeof(item)<>'object' OR jsonb_typeof(item->'cantidad') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Existencia contada requiere objeto y cantidad'; END IF;
qty:=(item->>'cantidad')::numeric;
IF qty<=0 OR qty<>round(qty,6) OR mod(qty,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad fisica incompatible'; END IF;
suma:=suma+qty;
IF item?'id_unidad' THEN
IF item-ARRAY['id_unidad','cantidad']<>'{}'::jsonb OR jsonb_typeof(item->'id_unidad') IS DISTINCT FROM 'number' OR (item->>'id_unidad')::numeric<>trunc((item->>'id_unidad')::numeric) THEN RAISE EXCEPTION 'Identificador fisico invalido'; END IF;
uid:=(item->>'id_unidad')::bigint;IF uid=ANY(ids) THEN RAISE EXCEPTION 'Unidad repetida'; END IF;ids:=array_append(ids,uid);
SELECT * INTO u FROM huaman.unidad_existencia WHERE id_unidad_existencia=uid;
IF NOT FOUND OR u.id_producto<>d.id_producto OR u.estado<>'A' OR u.cantidad_disponible_base<=0 OR qty>u.cantidad_inicial_base OR (u.condicion_fisica='ENVASE' AND qty<>u.cantidad_inicial_base) THEN RAISE EXCEPTION 'Existencia identificada incompatible; material encontrado nuevo se registra separado'; END IF;
ELSE
IF item-ARRAY['condicion','cantidad','id_presentacion']<>'{}'::jsonb THEN RAISE EXCEPTION 'Campos fisicos no reconocidos'; END IF;
condicion:=item->>'condicion';
IF condicion IS NULL OR (prod.modo_control='ENVASES' AND condicion NOT IN ('ENVASE','SUELTO')) OR (prod.modo_control='TRAMOS' AND condicion<>'TRAMO') THEN RAISE EXCEPTION 'Condicion fisica incompatible'; END IF;
IF condicion='ENVASE' THEN
IF jsonb_typeof(item->'id_presentacion') IS DISTINCT FROM 'number' OR (item->>'id_presentacion')::numeric<>trunc((item->>'id_presentacion')::numeric) THEN RAISE EXCEPTION 'Envase requiere presentacion'; END IF;
SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=(item->>'id_presentacion')::bigint;
IF NOT FOUND OR pr.id_producto<>d.id_producto OR pr.estado<>'A' OR pr.id_unidad_venta IS NOT NULL OR pr.factor_base<>qty THEN RAISE EXCEPTION 'Envase contado no coincide con presentacion integra'; END IF;
ELSIF item?'id_presentacion' THEN RAISE EXCEPTION 'Solo envase indica presentacion'; END IF;
END IF;
END LOOP;
IF suma<>d.cantidad_contada THEN RAISE EXCEPTION 'Suma fisica no coincide con conteo'; END IF;
END IF;

IF prod.modo_control<>'GRANEL' THEN
SELECT coalesce(jsonb_agg(jsonb_build_object('id_unidad',id_unidad_existencia,'cantidad',cantidad_disponible_base) ORDER BY id_unidad_existencia),'[]'::jsonb) INTO unidades_antes FROM huaman.unidad_existencia WHERE id_producto=d.id_producto AND estado='A' AND cantidad_disponible_base>0;
SELECT id_presentacion INTO pres_base FROM huaman.presentacion_producto WHERE id_producto=d.id_producto AND es_base AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Sin presentacion base activa'; END IF;
UPDATE huaman.unidad_existencia SET cantidad_disponible_base=0 WHERE id_producto=d.id_producto AND estado='A' AND cantidad_disponible_base>0;
FOR item IN SELECT value FROM jsonb_array_elements(d.unidades_contadas) LOOP
numero:=numero+1;qty:=(item->>'cantidad')::numeric;
IF item?'id_unidad' THEN
UPDATE huaman.unidad_existencia SET cantidad_disponible_base=qty WHERE id_unidad_existencia=(item->>'id_unidad')::bigint;
ELSE
condicion:=item->>'condicion';
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_toma_origen)
VALUES(d.id_producto,CASE WHEN condicion='ENVASE' THEN (item->>'id_presentacion')::bigint ELSE pres_base END,'TI-'||p_toma||'-'||d.id_detalle_toma||'-'||numero,condicion,qty,qty,p_toma);
END IF;
END LOOP;
IF d.cantidad_contada<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=d.id_producto AND estado='A') THEN RAISE EXCEPTION 'Conteo aprobado no coincide con unidades fisicas'; END IF;
ELSE unidades_antes:='[]'::jsonb;
END IF;
IF delta<>0 THEN
ajustes:=ajustes+1;
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_toma,clave_idempotencia)
VALUES(d.id_producto,'AJUSTE_TOMA',CASE WHEN delta>0 THEN 'E' ELSE 'S' END,abs(delta),prod.stock_actual,d.cantidad_contada,prod.costo_promedio,p_toma,gen_random_uuid());
UPDATE huaman.producto SET stock_actual=d.cantidad_contada WHERE id_producto=d.id_producto;
END IF;
UPDATE huaman.detalle_toma_inventario SET stock_previo_aprobacion=prod.stock_actual,diferencia_aplicada=delta WHERE id_detalle_toma=d.id_detalle_toma;
IF d.cantidad_contada>prod.stock_minimo OR prod.stock_minimo=0 THEN
UPDATE huaman.alerta_stock SET estado_alerta='CERRADA',fecha_cierre=timezone('America/Lima',now()) WHERE id_producto=d.id_producto AND estado='A' AND estado_alerta='ABIERTA';
ELSIF NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=d.id_producto AND estado='A' AND estado_alerta='ABIERTA') THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(d.id_producto,d.cantidad_contada,prod.stock_minimo);
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo)
VALUES(actor,'INV.TOMA_APLICAR','detalle_toma_inventario',d.id_detalle_toma,p_clave::text,jsonb_build_object('stock',prod.stock_actual,'unidades',unidades_antes),jsonb_build_object('stock',d.cantidad_contada,'diferencia',delta,'unidades',d.unidades_contadas,'toma',p_toma,'costo_unitario_base',prod.costo_promedio));
END LOOP;
UPDATE huaman.toma_inventario SET estado_toma='APROBADA',revision=revision+1,id_aprueba=actor,fecha_aprobacion=timezone('America/Lima',now()),clave_aprobacion=p_clave,observacion_aprobacion=obs WHERE id_toma=p_toma;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'INV.TOMA_APROBAR','toma_inventario',p_toma,p_clave::text,jsonb_build_object('solicitud',sol,'lineas_contadas',lineas,'movimientos_ajuste',ajustes));
PERFORM set_config('app.proceso',coalesce(previo,''),true);PERFORM set_config('app.toma_id',coalesce(prev_toma,''),true);RETURN p_toma;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'aprobar_toma' AS proceso,to_regprocedure('huaman.aprobar_toma(bigint,integer,uuid,text)') IS NOT NULL AS instalado;

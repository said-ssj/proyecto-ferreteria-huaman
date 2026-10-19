-- FERRETERIA HUAMAN - BLOQUE 17 - toma: inicio, conteo y revision
-- Requiere 01 a 16. No cambia stock. Aprobacion transaccional en siguiente bloque.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.registrar_ajuste(bigint,text,numeric,bigint,text,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 16'; END IF;
IF to_regprocedure('huaman.iniciar_toma(text,bigint,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 17 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE toma_inventario ADD COLUMN revision integer NOT NULL DEFAULT 0 CHECK(revision>=0);
ALTER TABLE toma_inventario ADD COLUMN fecha_cierre timestamp;
ALTER TABLE toma_inventario ADD COLUMN id_cierra bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE detalle_toma_inventario ADD COLUMN revision integer NOT NULL DEFAULT 0 CHECK(revision>=0);
ALTER TABLE detalle_toma_inventario ADD COLUMN unidades_contadas jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(unidades_contadas)='array');
CREATE UNIQUE INDEX ux_toma_clave_evento ON bitacora_evento(referencia) WHERE accion IN ('INV.TOMA_INICIAR','INV.TOMA_CONTAR','INV.TOMA_CERRAR','INV.TOMA_REABRIR','INV.TOMA_ANULAR');
CREATE FUNCTION huaman._toma_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('INICIAR_TOMA','GUARDAR_CONTEO','CERRAR_TOMA','REABRIR_TOMA','ANULAR_TOMA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.bloquear_inventario_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF TG_TABLE_NAME IN ('toma_inventario','detalle_toma_inventario') THEN
IF NOT coalesce(huaman._toma_en_curso(),false) THEN RAISE EXCEPTION 'Toma solo mediante procesos habilitados'; END IF;
ELSIF TG_TABLE_NAME='movimiento_caja' THEN
IF NOT coalesce(huaman._caja_en_curso(),false) THEN RAISE EXCEPTION 'Movimiento de caja solo mediante proceso habilitado'; END IF;
ELSIF NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Escritura de inventario solo mediante proceso habilitado'; END IF;
RETURN NEW;
END $$;
CREATE FUNCTION huaman.validar_toma_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE modo text:=current_setting('app.proceso',true);t huaman.toma_inventario%ROWTYPE;
BEGIN
IF NOT coalesce(huaman._toma_en_curso(),false) THEN RAISE EXCEPTION 'Toma sin proceso interno'; END IF;
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
CREATE TRIGGER validar_toma BEFORE INSERT OR UPDATE ON toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.validar_toma_revision();
CREATE TRIGGER validar_toma BEFORE INSERT OR UPDATE ON detalle_toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.validar_toma_revision();
CREATE FUNCTION huaman.proteger_catalogo_en_toma() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF (NEW.stock_actual,NEW.costo_promedio,NEW.ultimo_costo_compra) IS DISTINCT FROM (OLD.stock_actual,OLD.costo_promedio,OLD.ultimo_costo_compra) AND EXISTS(SELECT 1 FROM huaman.toma_inventario t WHERE t.estado='A' AND t.estado_toma IN ('EN_CONTEO','CERRADA') AND (t.alcance='TODO' OR t.id_categoria=OLD.id_categoria OR EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario d WHERE d.id_toma=t.id_toma AND d.id_producto=OLD.id_producto))) THEN RAISE EXCEPTION 'Saldos y costos bloqueados por toma abierta'; END IF;
IF (NEW.id_categoria,NEW.estado,NEW.incremento_base,NEW.admite_fracciones) IS DISTINCT FROM (OLD.id_categoria,OLD.estado,OLD.incremento_base,OLD.admite_fracciones) AND EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario d JOIN huaman.toma_inventario t USING(id_toma) WHERE d.id_producto=OLD.id_producto AND t.estado='A' AND t.estado_toma IN ('EN_CONTEO','CERRADA')) THEN RAISE EXCEPTION 'No cambiar categoria, precision ni estado de producto incluido en toma abierta'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER proteger_catalogo_toma BEFORE UPDATE ON producto FOR EACH ROW EXECUTE FUNCTION huaman.proteger_catalogo_en_toma();
-- Busca reintentos bajo bloqueo por clave; las solicitudes quedan en bitacora.
CREATE FUNCTION huaman._reintento_toma(p_clave uuid,p_solicitud jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE b huaman.bitacora_evento%ROWTYPE;
BEGIN
IF p_clave IS NULL THEN RAISE EXCEPTION 'Clave requerida'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('TOMA:'||p_clave::text,0));
SELECT * INTO b FROM huaman.bitacora_evento WHERE referencia=p_clave::text AND accion IN ('INV.TOMA_INICIAR','INV.TOMA_CONTAR','INV.TOMA_CERRAR','INV.TOMA_REABRIR','INV.TOMA_ANULAR');
IF FOUND THEN
IF b.valor_nuevo->'solicitud' IS DISTINCT FROM p_solicitud THEN RAISE EXCEPTION 'Clave usada con otros datos de toma'; END IF;
RETURN b.id_entidad;
END IF;
RETURN NULL;
END $$;
CREATE FUNCTION huaman.iniciar_toma(p_alcance text,p_categoria bigint,p_clave uuid,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;nuevo bigint;previo text;sol jsonb;productos bigint[];obs text:=nullif(btrim(p_observacion),'');
BEGIN
actor:=huaman._actor_con_permiso('INV.TOMA_GESTIONAR');
IF p_alcance IS NULL OR p_alcance NOT IN ('TODO','CATEGORIA') OR (p_alcance='TODO' AND p_categoria IS NOT NULL) OR (p_alcance='CATEGORIA' AND p_categoria IS NULL) OR length(obs)>300 OR coalesce(obs,'') ~ '[<>]' THEN RAISE EXCEPTION 'Alcance u observacion invalidos'; END IF;
sol:=jsonb_build_object('paso','INICIAR','alcance',p_alcance,'categoria',p_categoria,'observacion',obs);nuevo:=huaman._reintento_toma(p_clave,sol);IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('TOMA_UNICA',0));
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA')) THEN RAISE EXCEPTION 'Ya hay una toma abierta'; END IF;
IF p_alcance='CATEGORIA' AND NOT EXISTS(SELECT 1 FROM huaman.categoria WHERE id_categoria=p_categoria AND estado='A') THEN RAISE EXCEPTION 'Categoria inexistente o inactiva'; END IF;
-- Espera operaciones previas y captura saldos tras adquirir los bloqueos.
SELECT array_agg(b.id_producto ORDER BY b.id_producto) INTO productos FROM (SELECT id_producto FROM huaman.producto WHERE estado='A' AND (p_alcance='TODO' OR id_categoria=p_categoria) ORDER BY id_producto FOR UPDATE) b;
IF productos IS NULL THEN RAISE EXCEPTION 'No hay productos activos en el alcance'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','INICIAR_TOMA',true);
INSERT INTO huaman.toma_inventario(alcance,id_categoria,id_responsable,observacion) VALUES(p_alcance,p_categoria,actor,obs) RETURNING id_toma INTO nuevo;
INSERT INTO huaman.detalle_toma_inventario(id_toma,id_producto,stock_sistema,costo_referencia)
SELECT nuevo,id_producto,stock_actual,costo_promedio FROM huaman.producto WHERE id_producto=ANY(productos) ORDER BY id_producto;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'INV.TOMA_INICIAR','toma_inventario',nuevo,p_clave::text,jsonb_build_object('solicitud',sol));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
END $$;
CREATE FUNCTION huaman.guardar_conteo(p_toma bigint,p_producto bigint,p_cantidad numeric,p_revision integer,p_clave uuid,p_unidades jsonb DEFAULT '[]'::jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;d huaman.detalle_toma_inventario%ROWTYPE;t huaman.toma_inventario%ROWTYPE;prod huaman.producto%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;pr huaman.presentacion_producto%ROWTYPE;
sol jsonb;nuevo bigint;previo text;item jsonb;qty numeric;suma numeric:=0;uid bigint;ids bigint[]:='{}';condicion text;
BEGIN
actor:=huaman._actor_con_permiso('INV.TOMA_CONTAR');
IF p_toma IS NULL OR p_producto IS NULL OR p_revision IS NULL OR p_revision<0 OR p_cantidad IS NULL OR p_cantidad::text IN ('NaN','Infinity','-Infinity') OR p_cantidad<0 OR p_cantidad<>round(p_cantidad,6) OR p_unidades IS NULL OR jsonb_typeof(p_unidades)<>'array' OR jsonb_array_length(p_unidades)>1000 THEN RAISE EXCEPTION 'Conteo invalido'; END IF;
sol:=jsonb_build_object('paso','CONTAR','toma',p_toma,'producto',p_producto,'cantidad',p_cantidad,'revision',p_revision,'unidades',p_unidades);nuevo:=huaman._reintento_toma(p_clave,sol);IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
SELECT * INTO t FROM huaman.toma_inventario WHERE id_toma=p_toma FOR UPDATE;
IF NOT FOUND OR t.estado<>'A' OR t.estado_toma<>'EN_CONTEO' THEN RAISE EXCEPTION 'Toma no editable'; END IF;
SELECT * INTO d FROM huaman.detalle_toma_inventario WHERE id_toma=p_toma AND id_producto=p_producto FOR UPDATE;
IF NOT FOUND OR d.estado<>'A' OR d.revision<>p_revision THEN RAISE EXCEPTION 'Linea inexistente o modificada; recargue el conteo'; END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=p_producto;
IF mod(p_cantidad,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Conteo incompatible con incremento base'; END IF;
IF prod.modo_control='GRANEL' THEN
IF p_unidades<>'[]'::jsonb THEN RAISE EXCEPTION 'Granel no usa unidades individuales'; END IF;
ELSE
-- Lista completa de existencias encontradas. Las omitidas equivalen a no encontradas.
FOR item IN SELECT value FROM jsonb_array_elements(p_unidades) LOOP
IF jsonb_typeof(item)<>'object' OR jsonb_typeof(item->'cantidad') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Existencia contada requiere objeto y cantidad'; END IF;
qty:=(item->>'cantidad')::numeric;
IF qty<=0 OR qty<>round(qty,6) OR mod(qty,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad fisica incompatible'; END IF;
suma:=suma+qty;
IF item?'id_unidad' THEN
IF item-ARRAY['id_unidad','cantidad']<>'{}'::jsonb OR jsonb_typeof(item->'id_unidad') IS DISTINCT FROM 'number' OR (item->>'id_unidad')::numeric<>trunc((item->>'id_unidad')::numeric) THEN RAISE EXCEPTION 'Identificador fisico invalido'; END IF;
uid:=(item->>'id_unidad')::bigint;IF uid=ANY(ids) THEN RAISE EXCEPTION 'Unidad repetida'; END IF;ids:=array_append(ids,uid);
SELECT * INTO u FROM huaman.unidad_existencia WHERE id_unidad_existencia=uid;
IF NOT FOUND OR u.id_producto<>p_producto OR u.estado<>'A' OR u.cantidad_disponible_base<=0 OR qty>u.cantidad_inicial_base OR (u.condicion_fisica='ENVASE' AND qty<>u.cantidad_inicial_base) THEN RAISE EXCEPTION 'Existencia identificada incompatible; material encontrado nuevo se registra separado'; END IF;
ELSE
IF item-ARRAY['condicion','cantidad','id_presentacion']<>'{}'::jsonb THEN RAISE EXCEPTION 'Campos fisicos no reconocidos'; END IF;
condicion:=item->>'condicion';
IF condicion IS NULL OR (prod.modo_control='ENVASES' AND condicion NOT IN ('ENVASE','SUELTO')) OR (prod.modo_control='TRAMOS' AND condicion<>'TRAMO') THEN RAISE EXCEPTION 'Condicion fisica incompatible'; END IF;
IF condicion='ENVASE' THEN
IF jsonb_typeof(item->'id_presentacion') IS DISTINCT FROM 'number' OR (item->>'id_presentacion')::numeric<>trunc((item->>'id_presentacion')::numeric) THEN RAISE EXCEPTION 'Envase requiere presentacion'; END IF;
SELECT * INTO pr FROM huaman.presentacion_producto WHERE id_presentacion=(item->>'id_presentacion')::bigint;
IF NOT FOUND OR pr.id_producto<>p_producto OR pr.estado<>'A' OR pr.id_unidad_venta IS NOT NULL OR pr.factor_base<>qty THEN RAISE EXCEPTION 'Envase contado no coincide con presentacion integra'; END IF;
ELSIF item?'id_presentacion' THEN RAISE EXCEPTION 'Solo envase indica presentacion'; END IF;
END IF;
END LOOP;
IF suma<>p_cantidad THEN RAISE EXCEPTION 'Suma fisica no coincide con conteo'; END IF;
END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','GUARDAR_CONTEO',true);
UPDATE huaman.detalle_toma_inventario SET cantidad_contada=p_cantidad,estado_linea='CONTADA',unidades_contadas=p_unidades,revision=revision+1 WHERE id_detalle_toma=d.id_detalle_toma;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo) VALUES(actor,'INV.TOMA_CONTAR','detalle_toma_inventario',d.id_detalle_toma,p_clave::text,jsonb_build_object('cantidad',d.cantidad_contada,'revision',d.revision,'unidades',d.unidades_contadas),jsonb_build_object('solicitud',sol,'revision',d.revision+1));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN d.id_detalle_toma;
END $$;
CREATE FUNCTION huaman._cambiar_revision_toma(p_toma bigint,p_revision integer,p_clave uuid,p_paso text,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;t huaman.toma_inventario%ROWTYPE;sol jsonb;nuevo bigint;previo text;motivo text:=nullif(btrim(p_motivo),'');
BEGIN
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Proceso interno'; END IF;
actor:=huaman._actor_con_permiso('INV.TOMA_GESTIONAR');
IF p_toma IS NULL OR p_revision IS NULL OR p_revision<0 OR p_paso IS NULL OR p_paso NOT IN ('CERRAR','REABRIR','ANULAR') THEN RAISE EXCEPTION 'Transicion invalida'; END IF;
IF p_paso IN ('REABRIR','ANULAR') AND (motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]') THEN RAISE EXCEPTION 'Motivo de 10 a 200 caracteres requerido'; END IF;
IF p_paso='REABRIR' AND NOT EXISTS(SELECT 1 FROM huaman.usuario u JOIN huaman.rol r USING(id_rol) WHERE u.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo administrador devuelve a conteo'; END IF;
sol:=jsonb_build_object('paso',p_paso,'toma',p_toma,'revision',p_revision,'motivo',motivo);nuevo:=huaman._reintento_toma(p_clave,sol);IF nuevo IS NOT NULL THEN RETURN nuevo; END IF;
SELECT * INTO t FROM huaman.toma_inventario WHERE id_toma=p_toma FOR UPDATE;
IF NOT FOUND OR t.estado<>'A' OR t.revision<>p_revision OR t.estado_toma IN ('APROBADA','ANULADA') THEN RAISE EXCEPTION 'Toma finalizada o modificada; recargue'; END IF;
IF p_paso='CERRAR' AND (t.estado_toma<>'EN_CONTEO' OR NOT EXISTS(SELECT 1 FROM huaman.detalle_toma_inventario WHERE id_toma=p_toma AND estado='A' AND estado_linea='CONTADA')) THEN RAISE EXCEPTION 'Cerrar requiere toma en conteo y al menos una linea contada'; END IF;
IF p_paso='REABRIR' AND t.estado_toma<>'CERRADA' THEN RAISE EXCEPTION 'Solo reabrir toma cerrada'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso',p_paso||'_TOMA',true);
UPDATE huaman.toma_inventario SET estado_toma=CASE p_paso WHEN 'CERRAR' THEN 'CERRADA' WHEN 'REABRIR' THEN 'EN_CONTEO' ELSE 'ANULADA' END,revision=revision+1,fecha_cierre=CASE WHEN p_paso='CERRAR' THEN timezone('America/Lima',now()) WHEN p_paso='REABRIR' THEN NULL ELSE fecha_cierre END,id_cierra=CASE WHEN p_paso='CERRAR' THEN actor WHEN p_paso='REABRIR' THEN NULL ELSE id_cierra END,motivo_anulacion=CASE WHEN p_paso='ANULAR' THEN motivo ELSE motivo_anulacion END WHERE id_toma=p_toma;
IF p_paso='REABRIR' THEN UPDATE huaman.detalle_toma_inventario SET cantidad_contada=NULL,estado_linea='PENDIENTE',unidades_contadas='[]',revision=revision+1 WHERE id_toma=p_toma AND estado='A'; END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo) VALUES(actor,'INV.TOMA_'||p_paso,'toma_inventario',p_toma,p_clave::text,jsonb_build_object('estado',t.estado_toma,'revision',t.revision),jsonb_build_object('solicitud',sol,'revision',t.revision+1));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_toma;
END $$;
CREATE FUNCTION huaman.cerrar_toma(p_toma bigint,p_revision integer,p_clave uuid) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT huaman._cambiar_revision_toma(p_toma,p_revision,p_clave,'CERRAR',NULL) $$;
CREATE FUNCTION huaman.reabrir_toma(p_toma bigint,p_revision integer,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT huaman._cambiar_revision_toma(p_toma,p_revision,p_clave,'REABRIR',p_motivo) $$;
CREATE FUNCTION huaman.anular_toma(p_toma bigint,p_revision integer,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$ SELECT huaman._cambiar_revision_toma(p_toma,p_revision,p_clave,'ANULAR',p_motivo) $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'iniciar_toma' AS proceso,to_regprocedure('huaman.iniciar_toma(text,bigint,uuid,text)') IS NOT NULL AS instalado
UNION ALL SELECT 'guardar_conteo',to_regprocedure('huaman.guardar_conteo(bigint,bigint,numeric,integer,uuid,jsonb)') IS NOT NULL
UNION ALL SELECT 'cerrar_toma',to_regprocedure('huaman.cerrar_toma(bigint,integer,uuid)') IS NOT NULL
UNION ALL SELECT 'reabrir_toma',to_regprocedure('huaman.reabrir_toma(bigint,integer,uuid,text)') IS NOT NULL
UNION ALL SELECT 'anular_toma',to_regprocedure('huaman.anular_toma(bigint,integer,uuid,text)') IS NOT NULL;

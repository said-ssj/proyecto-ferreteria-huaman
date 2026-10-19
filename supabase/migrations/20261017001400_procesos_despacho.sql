-- FERRETERIA HUAMAN - BLOQUE 14 - preparar y entregar despachos
-- Requiere 01 a 13, incluido 09B. Ejecutar completo una vez.
-- Solo instala; no prepara ni entrega pedidos reales.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
SELECT set_config('app.usuario','MIGRACION_014',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
DO $$ BEGIN
IF to_regprocedure('huaman.registrar_abono(bigint,bigint,numeric,text,uuid,text,text,text,text)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 13'; END IF;
IF to_regprocedure('huaman.preparar_despacho(bigint,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 14 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
-- PR11 y matriz vigente: VEN consulta; ADM/ALM/AYU preparan y entregan.
UPDATE huaman.rol_permiso rp SET estado='I'
FROM huaman.rol r,huaman.permiso p
WHERE rp.id_rol=r.id_rol AND rp.id_permiso=p.id_permiso AND r.codigo='VEN' AND p.codigo='DES.GESTIONAR' AND rp.estado='A';
ALTER TABLE despacho ADD COLUMN clave_preparacion uuid UNIQUE;
ALTER TABLE despacho ADD COLUMN clave_entrega uuid UNIQUE;
ALTER TABLE despacho ADD COLUMN observacion_preparacion varchar(300);
ALTER TABLE despacho ADD COLUMN observacion_entrega varchar(300);
CREATE FUNCTION huaman._despacho_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('PREPARAR_DESPACHO','ENTREGAR_DESPACHO')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_despacho_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;modo text:=current_setting('app.proceso',true);
BEGIN
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

-- Ayudante interno: solo invocado por los dos procesos publicos del backend.
CREATE FUNCTION huaman._procesar_despacho(p_despacho bigint,p_clave uuid,p_paso text,p_recibe text,p_observacion text) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;d huaman.despacho%ROWTYPE;v huaman.venta%ROWTYPE;venta_id bigint;previo text;nombre text;
recibe text:=nullif(btrim(p_recibe),'');obs text:=nullif(btrim(p_observacion),'');
BEGIN
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Proceso interno'; END IF;
actor:=huaman._actor_con_permiso('DES.GESTIONAR');
IF p_despacho IS NULL OR p_clave IS NULL OR p_paso IS NULL OR p_paso NOT IN ('PREPARAR','ENTREGAR') OR length(recibe)>100 OR length(obs)>300 OR (p_paso='PREPARAR' AND recibe IS NOT NULL) THEN RAISE EXCEPTION 'Datos de despacho invalidos'; END IF;
-- Se almacenan textos planos; el frontend debe escapar al mostrarlos.
IF coalesce(recibe,'') ~ '[<>]' OR coalesce(obs,'') ~ '[<>]' THEN RAISE EXCEPTION 'Ingresar texto simple sin etiquetas HTML'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('DESPACHO:'||p_clave::text,0));
SELECT id_venta INTO venta_id FROM huaman.despacho WHERE id_despacho=p_despacho;
IF NOT FOUND THEN RAISE EXCEPTION 'Despacho inexistente'; END IF;
-- Orden venta -> despacho, compatible con futura anulacion de la venta.
SELECT * INTO v FROM huaman.venta WHERE id_venta=venta_id FOR UPDATE;
SELECT * INTO d FROM huaman.despacho WHERE id_despacho=p_despacho FOR UPDATE;
IF p_paso='PREPARAR' AND d.clave_preparacion=p_clave THEN
IF d.observacion_preparacion IS DISTINCT FROM obs THEN RAISE EXCEPTION 'Clave de preparacion usada con otros datos'; END IF;
RETURN d.id_despacho;
ELSIF p_paso='ENTREGAR' AND d.clave_entrega=p_clave THEN
IF (d.recibe_nombre,d.observacion_entrega) IS DISTINCT FROM (recibe,obs) THEN RAISE EXCEPTION 'Clave de entrega usada con otros datos'; END IF;
RETURN d.id_despacho;
END IF;
IF EXISTS(SELECT 1 FROM huaman.despacho WHERE clave_preparacion=p_clave OR clave_entrega=p_clave) THEN RAISE EXCEPTION 'Clave usada en otra operacion de despacho'; END IF;
IF v.estado<>'A' OR v.estado_venta<>'CONFIRMADA' OR v.entrega_inmediata OR d.estado<>'A' OR d.estado_despacho='ANULADO' THEN RAISE EXCEPTION 'Despacho no disponible para esta venta'; END IF;
IF d.estado_despacho='ENTREGADO' THEN
SELECT concat_ws(' ',nombres,apellidos) INTO nombre FROM huaman.usuario WHERE id_usuario=d.id_entrega;
RAISE EXCEPTION 'Este despacho ya fue entregado por % a las %',nombre,to_char(d.fecha_entrega,'HH24:MI');
END IF;
previo:=current_setting('app.proceso',true);
IF p_paso='PREPARAR' THEN
IF d.estado_despacho<>'PENDIENTE' THEN RAISE EXCEPTION 'Este despacho ya fue preparado; recargue la lista'; END IF;
PERFORM set_config('app.proceso','PREPARAR_DESPACHO',true);
UPDATE huaman.despacho SET estado_despacho='PREPARADO',id_prepara=actor,fecha_preparacion=timezone('America/Lima',now()),clave_preparacion=p_clave,observacion_preparacion=obs WHERE id_despacho=p_despacho;
ELSE
IF d.estado_despacho<>'PREPARADO' THEN RAISE EXCEPTION 'Primero marque el despacho como preparado'; END IF;
PERFORM set_config('app.proceso','ENTREGAR_DESPACHO',true);
UPDATE huaman.despacho SET estado_despacho='ENTREGADO',id_entrega=actor,fecha_entrega=timezone('America/Lima',now()),clave_entrega=p_clave,recibe_nombre=recibe,observacion_entrega=obs WHERE id_despacho=p_despacho;
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo)
VALUES(actor,'DES.'||p_paso,'despacho',p_despacho,p_clave::text,jsonb_build_object('estado',d.estado_despacho),jsonb_build_object('estado',CASE WHEN p_paso='PREPARAR' THEN 'PREPARADO' ELSE 'ENTREGADO' END,'venta',venta_id,'recibe',recibe,'observacion',obs));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_despacho;
END $$;
CREATE FUNCTION huaman.preparar_despacho(p_despacho bigint,p_clave uuid,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
SELECT huaman._procesar_despacho(p_despacho,p_clave,'PREPARAR',NULL,p_observacion)
$$;
CREATE FUNCTION huaman.entregar_despacho(p_despacho bigint,p_clave uuid,p_recibe text DEFAULT NULL,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
SELECT huaman._procesar_despacho(p_despacho,p_clave,'ENTREGAR',p_recibe,p_observacion)
$$;
CREATE INDEX ix_despacho_pendiente ON despacho(estado_despacho,id_despacho) WHERE estado='A' AND estado_despacho IN ('PENDIENTE','PREPARADO');
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'preparar_despacho' AS proceso,to_regprocedure('huaman.preparar_despacho(bigint,uuid,text)') IS NOT NULL AS instalado
UNION ALL SELECT 'entregar_despacho',to_regprocedure('huaman.entregar_despacho(bigint,uuid,text,text)') IS NOT NULL;

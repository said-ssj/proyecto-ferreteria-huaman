-- FERRETERIA HUAMAN - BLOQUE 19 - emitir y anular cotizaciones
-- Requiere 01 a 18. Solo instala; no publica cotizaciones ni reserva stock.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.aprobar_toma(bigint,integer,uuid,text)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 18'; END IF;
IF to_regprocedure('huaman.emitir_cotizacion(bigint,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 19 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE cotizacion ADD COLUMN clave_emision uuid UNIQUE;
ALTER TABLE cotizacion ADD COLUMN clave_anulacion uuid UNIQUE;
ALTER TABLE cotizacion ADD COLUMN emitida_en timestamp;
ALTER TABLE cotizacion ADD COLUMN id_emite bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE cotizacion ADD COLUMN anulada_en timestamp;
ALTER TABLE cotizacion ADD COLUMN id_anula bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
CREATE FUNCTION huaman._cotizacion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('EMITIR_COTIZACION','ANULAR_COTIZACION')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.validar_cabecera_cotizacion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE modo text:=current_setting('app.proceso',true);
BEGIN
IF TG_OP='UPDATE' AND coalesce(huaman._cotizacion_en_curso(),false) THEN
IF modo='EMITIR_COTIZACION' AND OLD.estado_cotizacion='BORRADOR' AND NEW.estado_cotizacion='VIGENTE' THEN
IF NEW.clave_emision IS NULL OR NEW.emitida_en IS NULL OR NEW.id_emite IS NULL OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','vigente_hasta','clave_emision','emitida_en','id_emite','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','vigente_hasta','clave_emision','emitida_en','id_emite','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Emision altera datos no autorizados'; END IF;
RETURN NEW;
ELSIF modo='ANULAR_COTIZACION' AND OLD.estado_cotizacion IN ('BORRADOR','VIGENTE','VENCIDA') AND NEW.estado_cotizacion='ANULADA' THEN
IF NEW.clave_anulacion IS NULL OR NEW.anulada_en IS NULL OR NEW.id_anula IS NULL OR length(btrim(coalesce(NEW.motivo_anulacion,''))) NOT BETWEEN 10 AND 200 OR (to_jsonb(NEW)-ARRAY['estado_cotizacion','clave_anulacion','anulada_en','id_anula','motivo_anulacion','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['estado_cotizacion','clave_anulacion','anulada_en','id_anula','motivo_anulacion','usmod','pcmod','fecmod']) THEN RAISE EXCEPTION 'Anulacion altera datos no autorizados'; END IF;
RETURN NEW;
END IF;
END IF;
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
CREATE FUNCTION huaman.emitir_cotizacion(p_cotizacion bigint,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.cotizacion%ROWTYPE;previo text;dias integer;
BEGIN
actor:=huaman._actor_con_permiso('COC.COTIZAR');
IF p_cotizacion IS NULL OR p_clave IS NULL THEN RAISE EXCEPTION 'Cotizacion y clave requeridas'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('COTIZACION:'||p_clave::text,0));
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Cotizacion inexistente'; END IF;
IF c.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo gestionar cotizaciones propias'; END IF;
IF c.clave_emision=p_clave THEN RETURN p_cotizacion; END IF;
IF EXISTS(SELECT 1 FROM huaman.cotizacion WHERE clave_emision=p_clave OR clave_anulacion=p_clave) THEN RAISE EXCEPTION 'Clave usada en otra operacion de cotizacion'; END IF;
IF c.estado<>'A' OR c.estado_cotizacion<>'BORRADOR' OR c.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Solo emitir borrador de hoy; copie uno antiguo para recotizar'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.detalle_cotizacion WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Cotizacion sin lineas activas'; END IF;
SELECT valor::integer INTO dias FROM huaman.parametro_sistema WHERE clave='COTIZACION.VIGENCIA_DIAS' AND estado='A';
IF dias IS NULL OR dias NOT BETWEEN 1 AND 90 THEN RAISE EXCEPTION 'Vigencia no configurada'; END IF;
-- Bloqueos del catalogo en orden; una cotizacion no reserva ni descuenta stock.
PERFORM 1 FROM huaman.producto WHERE id_producto IN (SELECT id_producto FROM huaman.detalle_cotizacion WHERE id_cotizacion=p_cotizacion AND estado='A') ORDER BY id_producto FOR SHARE;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','EMITIR_COTIZACION',true);
-- Se actualizan precios vigentes del borrador antes de congelar su version emitida.
UPDATE huaman.detalle_cotizacion SET cantidad=cantidad WHERE id_cotizacion=p_cotizacion AND estado='A';
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion;
IF c.total<=0 THEN RAISE EXCEPTION 'Total de cotizacion debe ser positivo'; END IF;
UPDATE huaman.cotizacion SET estado_cotizacion='VIGENTE',vigente_hasta=fecha+dias,clave_emision=p_clave,emitida_en=timezone('America/Lima',now()),id_emite=actor WHERE id_cotizacion=p_cotizacion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COC.EMITIR','cotizacion',p_cotizacion,p_clave::text,jsonb_build_object('total',c.total,'vigente_hasta',c.fecha+dias));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_cotizacion;
END $$;
CREATE FUNCTION huaman.anular_cotizacion(p_cotizacion bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.cotizacion%ROWTYPE;previo text;motivo text:=nullif(btrim(p_motivo),'');
BEGIN
actor:=huaman._actor_con_permiso('COC.COTIZAR');
IF p_cotizacion IS NULL OR p_clave IS NULL OR motivo IS NULL OR length(motivo) NOT BETWEEN 10 AND 200 OR motivo ~ '[<>]' THEN RAISE EXCEPTION 'Cotizacion clave y motivo de 10 a 200 caracteres requeridos'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('COTIZACION:'||p_clave::text,0));
SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=p_cotizacion FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Cotizacion inexistente'; END IF;
IF c.id_vendedor<>actor AND NOT EXISTS(SELECT 1 FROM huaman.usuario actor_usuario JOIN huaman.rol r USING(id_rol) WHERE actor_usuario.id_usuario=actor AND r.codigo='ADM') THEN RAISE EXCEPTION 'Solo gestionar cotizaciones propias'; END IF;
IF c.clave_anulacion=p_clave THEN
IF c.motivo_anulacion IS DISTINCT FROM motivo THEN RAISE EXCEPTION 'Clave usada con otro motivo'; END IF;
RETURN p_cotizacion;
END IF;
IF EXISTS(SELECT 1 FROM huaman.cotizacion WHERE clave_emision=p_clave OR clave_anulacion=p_clave) THEN RAISE EXCEPTION 'Clave usada en otra operacion de cotizacion'; END IF;
IF c.estado<>'A' OR c.estado_cotizacion NOT IN ('BORRADOR','VIGENTE','VENCIDA') OR EXISTS(SELECT 1 FROM huaman.venta WHERE id_cotizacion=p_cotizacion AND estado='A') THEN RAISE EXCEPTION 'Cotizacion finalizada o vinculada a venta; no anular'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','ANULAR_COTIZACION',true);
UPDATE huaman.cotizacion SET estado_cotizacion='ANULADA',motivo_anulacion=motivo,clave_anulacion=p_clave,anulada_en=timezone('America/Lima',now()),id_anula=actor WHERE id_cotizacion=p_cotizacion;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo) VALUES(actor,'COC.ANULAR','cotizacion',p_cotizacion,p_clave::text,jsonb_build_object('motivo',motivo,'estado_anterior',c.estado_cotizacion));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_cotizacion;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'emitir_cotizacion' AS proceso,to_regprocedure('huaman.emitir_cotizacion(bigint,uuid)') IS NOT NULL AS instalado
UNION ALL SELECT 'anular_cotizacion',to_regprocedure('huaman.anular_cotizacion(bigint,uuid,text)') IS NOT NULL;

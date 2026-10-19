-- FERRETERIA HUAMAN - BLOQUE 11 - apertura, movimientos manuales y cierre de caja
-- Requiere bloques 01 a 10, incluido 09B. Ejecutar completo una sola vez.
-- Solo instala procesos: NO abre caja ni registra dinero real.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.confirmar_ingreso(bigint,uuid)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 10 antes'; END IF;
IF to_regprocedure('huaman.abrir_caja(numeric,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 11 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL de los bloques anteriores'; END IF;
END $$;
ALTER TABLE caja_diaria ADD COLUMN clave_apertura uuid UNIQUE;
ALTER TABLE caja_diaria ADD COLUMN clave_cierre uuid UNIQUE;

CREATE FUNCTION huaman._caja_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner)
AND coalesce(current_setting('app.proceso',true),'') IN ('ABRIR_CAJA','MOVIMIENTO_MANUAL_CAJA','CERRAR_CAJA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.bloquear_inventario_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF TG_TABLE_NAME='movimiento_caja' THEN
IF NOT coalesce(huaman._caja_en_curso(),false) THEN RAISE EXCEPTION 'Movimiento de caja solo mediante proceso habilitado'; END IF;
ELSIF NOT coalesce(huaman._apertura_en_curso(),false) THEN RAISE EXCEPTION 'Escritura de inventario solo mediante procesos habilitados'; END IF;
RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION huaman.validar_caja_estructura() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF NOT coalesce(huaman._caja_en_curso(),false) THEN RAISE EXCEPTION 'Usar procesos de apertura/cierre; no editar caja manualmente'; END IF;
IF TG_OP='INSERT' THEN
IF current_setting('app.proceso',true)<>'ABRIR_CAJA' OR NEW.estado_caja<>'ABIERTA' OR NEW.clave_apertura IS NULL THEN RAISE EXCEPTION 'Apertura invalida'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_usuario_apertura AND estado='A') THEN RAISE EXCEPTION 'Usuario de apertura invalido'; END IF;
IF NEW.fecha<>timezone('America/Lima',now())::date OR NEW.clave_cierre IS NOT NULL OR NEW.fecha_cierre IS NOT NULL OR NEW.id_usuario_cierre IS NOT NULL OR NEW.efectivo_esperado IS NOT NULL OR NEW.efectivo_contado IS NOT NULL OR NEW.yape_esperado IS NOT NULL OR NEW.yape_reportado IS NOT NULL OR NEW.debito_esperado IS NOT NULL OR NEW.debito_reportado IS NOT NULL THEN RAISE EXCEPTION 'Apertura con fecha o datos de cierre incompatibles'; END IF;
ELSE
IF OLD.estado_caja='CERRADA' THEN RAISE EXCEPTION 'Caja cerrada inmutable'; END IF;
IF current_setting('app.proceso',true)<>'CERRAR_CAJA' OR NEW.estado_caja<>'CERRADA' OR NEW.clave_cierre IS NULL THEN RAISE EXCEPTION 'Cambio de caja no permitido'; END IF;
IF (NEW.fecha,NEW.monto_inicial,NEW.id_usuario_apertura,NEW.obs_apertura,NEW.clave_apertura,NEW.estado) IS DISTINCT FROM (OLD.fecha,OLD.monto_inicial,OLD.id_usuario_apertura,OLD.obs_apertura,OLD.clave_apertura,OLD.estado) THEN RAISE EXCEPTION 'No alterar identidad o fondo inicial al cerrar'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_usuario_cierre AND estado='A') THEN RAISE EXCEPTION 'Usuario de cierre invalido'; END IF;
END IF;
RETURN NEW;
END $$;

CREATE FUNCTION huaman.validar_movimiento_monetario() RETURNS trigger
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
ELSE RAISE EXCEPTION 'Cobros y reintegros pendientes de sus procesos de venta/credito'; END IF;
SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) INTO disponible FROM huaman.movimiento_caja WHERE id_caja=NEW.id_caja AND medio=NEW.medio;
IF disponible+(CASE WHEN NEW.sentido='I' THEN NEW.importe ELSE -NEW.importe END)<0 THEN RAISE EXCEPTION 'Egreso supera saldo disponible'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_movimiento BEFORE INSERT ON movimiento_caja FOR EACH ROW EXECUTE FUNCTION huaman.validar_movimiento_monetario();

CREATE FUNCTION huaman.abrir_caja(p_fondo numeric,p_clave uuid,p_observacion text DEFAULT NULL) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.caja_diaria%ROWTYPE;previo text;nueva bigint;obs text:=nullif(btrim(p_observacion),'');
BEGIN
actor:=huaman._actor_con_permiso('CAJ.OPERAR');
IF p_clave IS NULL OR p_fondo IS NULL OR p_fondo::text IN ('NaN','Infinity','-Infinity') OR p_fondo<0 OR p_fondo<>round(p_fondo,2) OR length(coalesce(obs,''))>300 THEN RAISE EXCEPTION 'Fondo, observacion o clave invalidos'; END IF;
PERFORM pg_advisory_xact_lock(73211,1);
SELECT * INTO c FROM huaman.caja_diaria WHERE clave_apertura=p_clave;
IF FOUND THEN
IF c.monto_inicial<>p_fondo OR c.obs_apertura IS DISTINCT FROM obs OR c.id_usuario_apertura<>actor THEN RAISE EXCEPTION 'Clave de apertura ya usada con otros datos o usuario'; END IF;
RETURN c.id_caja;
END IF;
IF EXISTS(SELECT 1 FROM huaman.caja_diaria WHERE estado_caja='ABIERTA') THEN RAISE EXCEPTION 'Ya hay una caja abierta'; END IF;
IF EXISTS(SELECT 1 FROM huaman.caja_diaria WHERE fecha=timezone('America/Lima',now())::date) THEN RAISE EXCEPTION 'La caja de hoy ya existe; no abrir otro turno sin una regla definida'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','ABRIR_CAJA',true);
INSERT INTO huaman.caja_diaria(fecha,monto_inicial,id_usuario_apertura,obs_apertura,clave_apertura)
VALUES(timezone('America/Lima',now())::date,p_fondo,actor,obs,p_clave) RETURNING id_caja INTO nueva;
IF p_fondo>0 THEN
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,clave_idempotencia)
VALUES(nueva,'APERTURA','EFECTIVO','I',p_fondo,p_clave);
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'CAJ.ABRIR','caja_diaria',nueva,p_clave::text,jsonb_build_object('monto_inicial',p_fondo,'observacion',obs));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nueva;
END $$;

CREATE FUNCTION huaman.registrar_movimiento_caja(p_caja bigint,p_tipo text,p_importe numeric,p_motivo text,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.caja_diaria%ROWTYPE;m huaman.movimiento_caja%ROWTYPE;previo text;nuevo bigint;motivo_limpio text:=btrim(p_motivo);
BEGIN
actor:=huaman._actor_con_permiso('CAJ.OPERAR');
IF p_caja IS NULL OR p_clave IS NULL OR p_tipo IS NULL OR p_tipo NOT IN ('INGRESO_MANUAL','EGRESO_MANUAL') OR p_importe IS NULL OR p_importe::text IN ('NaN','Infinity','-Infinity') OR p_importe<=0 OR p_importe<>round(p_importe,2) OR motivo_limpio IS NULL OR length(motivo_limpio) NOT BETWEEN 10 AND 200 THEN RAISE EXCEPTION 'Datos del movimiento manual invalidos'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('MANUAL_CAJA:'||p_clave::text,0));
SELECT * INTO m FROM huaman.movimiento_caja WHERE clave_idempotencia=p_clave;
IF FOUND THEN
IF m.id_caja<>p_caja OR m.tipo_movimiento<>p_tipo OR m.importe<>p_importe OR m.motivo IS DISTINCT FROM motivo_limpio OR m.medio<>'EFECTIVO' THEN RAISE EXCEPTION 'Clave ya usada con otro movimiento'; END IF;
RETURN m.id_movimiento_caja;
END IF;
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=p_caja FOR UPDATE;
IF NOT FOUND OR c.estado<>'A' OR c.estado_caja<>'ABIERTA' THEN RAISE EXCEPTION 'Caja no disponible'; END IF;
IF c.fecha<>timezone('America/Lima',now())::date THEN RAISE EXCEPTION 'Cerrar la caja anterior antes de operar la fecha actual'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','MOVIMIENTO_MANUAL_CAJA',true);
INSERT INTO huaman.movimiento_caja(id_caja,tipo_movimiento,medio,sentido,importe,motivo,clave_idempotencia)
VALUES(p_caja,p_tipo,'EFECTIVO',CASE WHEN p_tipo='INGRESO_MANUAL' THEN 'I' ELSE 'E' END,p_importe,motivo_limpio,p_clave) RETURNING id_movimiento_caja INTO nuevo;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'CAJ.MANUAL','movimiento_caja',nuevo,p_clave::text,jsonb_build_object('caja',p_caja,'tipo',p_tipo,'importe',p_importe,'motivo',motivo_limpio));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
END $$;

CREATE FUNCTION huaman.cerrar_caja(p_caja bigint,p_efectivo numeric,p_yape numeric,p_debito numeric,p_observacion text,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;c huaman.caja_diaria%ROWTYPE;ef numeric;ya numeric;de numeric;previo text;obs text:=nullif(btrim(p_observacion),'');
BEGIN
actor:=huaman._actor_con_permiso('CAJ.OPERAR');
IF p_caja IS NULL OR p_clave IS NULL OR p_efectivo IS NULL OR p_yape IS NULL OR p_debito IS NULL OR p_efectivo::text IN ('NaN','Infinity','-Infinity') OR p_yape::text IN ('NaN','Infinity','-Infinity') OR p_debito::text IN ('NaN','Infinity','-Infinity') OR p_efectivo<0 OR p_yape<0 OR p_debito<0 OR p_efectivo<>round(p_efectivo,2) OR p_yape<>round(p_yape,2) OR p_debito<>round(p_debito,2) OR length(coalesce(obs,''))>200 THEN RAISE EXCEPTION 'Conteos, observacion o clave invalidos'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('CERRAR_CAJA:'||p_clave::text,0));
SELECT * INTO c FROM huaman.caja_diaria WHERE id_caja=p_caja FOR UPDATE;
IF NOT FOUND OR c.estado<>'A' THEN RAISE EXCEPTION 'Caja inexistente o inactiva'; END IF;
IF c.estado_caja='CERRADA' THEN
IF c.clave_cierre=p_clave AND c.efectivo_contado=p_efectivo AND c.yape_reportado=p_yape AND c.debito_reportado=p_debito AND c.obs_cierre IS NOT DISTINCT FROM obs THEN RETURN p_caja; END IF;
RAISE EXCEPTION 'Caja ya cerrada; no modificar sus resultados'; END IF;
IF EXISTS(SELECT 1 FROM huaman.caja_diaria WHERE clave_cierre=p_clave AND id_caja<>p_caja) THEN RAISE EXCEPTION 'Clave de cierre ya usada'; END IF;
IF EXISTS(SELECT 1 FROM huaman.venta WHERE id_caja=p_caja AND estado='A' AND estado_venta='BORRADOR' AND total>0) THEN RAISE EXCEPTION 'Resolver ventas pendientes antes del cierre'; END IF;
SELECT coalesce(sum(CASE WHEN medio='EFECTIVO' THEN CASE WHEN sentido='I' THEN importe ELSE -importe END ELSE 0 END),0),
coalesce(sum(CASE WHEN medio='YAPE' THEN CASE WHEN sentido='I' THEN importe ELSE -importe END ELSE 0 END),0),
coalesce(sum(CASE WHEN medio='DEBITO' THEN CASE WHEN sentido='I' THEN importe ELSE -importe END ELSE 0 END),0)
INTO ef,ya,de FROM huaman.movimiento_caja WHERE id_caja=p_caja;
IF (ef<>p_efectivo OR ya<>p_yape OR de<>p_debito) AND length(coalesce(obs,''))<10 THEN RAISE EXCEPTION 'Diferencia requiere observacion de al menos 10 caracteres'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','CERRAR_CAJA',true);
UPDATE huaman.caja_diaria SET estado_caja='CERRADA',fecha_cierre=timezone('America/Lima',now()),id_usuario_cierre=actor,
efectivo_esperado=ef,efectivo_contado=p_efectivo,yape_esperado=ya,yape_reportado=p_yape,debito_esperado=de,debito_reportado=p_debito,obs_cierre=obs,clave_cierre=p_clave WHERE id_caja=p_caja;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'CAJ.CERRAR','caja_diaria',p_caja,p_clave::text,jsonb_build_object('efectivo_esperado',ef,'efectivo_contado',p_efectivo,'yape_esperado',ya,'yape_reportado',p_yape,'debito_esperado',de,'debito_reportado',p_debito,'observacion',obs));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_caja;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'abrir_caja' AS proceso,to_regprocedure('huaman.abrir_caja(numeric,uuid,text)') IS NOT NULL AS instalado
UNION ALL SELECT 'registrar_movimiento_caja',to_regprocedure('huaman.registrar_movimiento_caja(bigint,text,numeric,text,uuid)') IS NOT NULL
UNION ALL SELECT 'cerrar_caja',to_regprocedure('huaman.cerrar_caja(bigint,numeric,numeric,numeric,text,uuid)') IS NOT NULL;

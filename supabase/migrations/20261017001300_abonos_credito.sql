-- FERRETERIA HUAMAN - BLOQUE 13 - abonos de fiado
-- Requiere 01 a 12, incluido 09B. Instala sin registrar cobros.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.confirmar_venta(bigint,bigint,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 12'; END IF;
IF to_regprocedure('huaman.registrar_abono(bigint,bigint,numeric,text,uuid,text,text,text,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 13 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
CREATE FUNCTION huaman._abono_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'')='REGISTRAR_ABONO'
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman._caja_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('ABRIR_CAJA','MOVIMIENTO_MANUAL_CAJA','CERRAR_CAJA','CONFIRMAR_VENTA','REGISTRAR_ABONO')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE OR REPLACE FUNCTION huaman.bloquear_credito_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
IF coalesce(huaman._abono_en_curso(),false) THEN
IF TG_TABLE_NAME='abono_credito' AND TG_OP='INSERT' THEN
IF NEW.estado<>'A' OR NEW.fecha_abono::date<>timezone('America/Lima',now())::date OR NOT EXISTS(SELECT 1 FROM huaman.caja_diaria WHERE id_caja=NEW.id_caja AND estado='A' AND estado_caja='ABIERTA' AND fecha=NEW.fecha_abono::date) OR NOT EXISTS(SELECT 1 FROM huaman.cuenta_por_cobrar WHERE id_cuenta=NEW.id_cuenta AND estado='A' AND estado_cuenta IN ('PENDIENTE','VENCIDA') AND saldo>=NEW.monto) THEN RAISE EXCEPTION 'Abono incompatible con deuda o caja'; END IF;
RETURN NEW;
ELSIF TG_TABLE_NAME='cuenta_por_cobrar' AND TG_OP='UPDATE' THEN
IF (to_jsonb(NEW)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) IS DISTINCT FROM (to_jsonb(OLD)-ARRAY['saldo','estado_cuenta','usmod','pcmod','fecmod']) OR NEW.saldo>=OLD.saldo OR NEW.saldo<0 OR NEW.saldo<>NEW.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=NEW.id_cuenta AND estado='A') OR NEW.estado_cuenta<>(CASE WHEN NEW.saldo=0 THEN 'CANCELADA' WHEN NEW.fecha_vencimiento<timezone('America/Lima',now())::date THEN 'VENCIDA' ELSE 'PENDIENTE' END) THEN RAISE EXCEPTION 'Actualizacion de deuda incompatible con abonos'; END IF;
RETURN NEW;
END IF;
RAISE EXCEPTION 'Operacion de credito no habilitada';
END IF;
IF TG_TABLE_NAME<>'cuenta_por_cobrar' OR TG_OP<>'INSERT' OR NOT coalesce(huaman._venta_en_curso(),false) OR current_setting('app.proceso',true)<>'CONFIRMAR_VENTA' THEN RAISE EXCEPTION 'Credito solo mediante proceso habilitado'; END IF;
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado_venta<>'CONFIRMADA' OR v.id_cliente IS DISTINCT FROM NEW.id_cliente OR NEW.monto_original<>v.total OR NEW.saldo<>v.total OR NEW.estado_cuenta<>'PENDIENTE' OR NEW.fecha_vencimiento<v.fecha_venta::date OR NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=v.id_venta AND medio='CREDITO' AND monto=v.total AND estado='A') THEN RAISE EXCEPTION 'Cuenta no coincide con fiado confirmado'; END IF;
RETURN NEW;
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
ELSE RAISE EXCEPTION 'Reintegros pendientes de sus procesos'; END IF;
SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) INTO disponible FROM huaman.movimiento_caja WHERE id_caja=NEW.id_caja AND medio=NEW.medio;
IF disponible+(CASE WHEN NEW.sentido='I' THEN NEW.importe ELSE -NEW.importe END)<0 THEN RAISE EXCEPTION 'Egreso supera saldo disponible'; END IF;
RETURN NEW;
END $$;
CREATE UNIQUE INDEX ux_mov_abono_unico ON movimiento_caja(id_abono) WHERE tipo_movimiento='ABONO';
CREATE UNIQUE INDEX ux_abono_yape_dia ON abono_credito((fecha_abono::date),nro_operacion) WHERE medio='YAPE' AND estado='A';
CREATE FUNCTION huaman.validar_referencia_yape_cruzada() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE dia date;
BEGIN
IF NEW.medio<>'YAPE' OR NEW.estado<>'A' THEN RETURN NEW; END IF;
IF TG_TABLE_NAME='pago' THEN dia:=NEW.fecha_pago; ELSE dia:=NEW.fecha_abono::date; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('YAPE:'||dia::text||':'||NEW.nro_operacion,0));
IF TG_TABLE_NAME='pago' THEN
IF EXISTS(SELECT 1 FROM huaman.abono_credito WHERE medio='YAPE' AND estado='A' AND fecha_abono::date=dia AND nro_operacion=NEW.nro_operacion) THEN RAISE EXCEPTION 'Operacion Yape ya usada en abono'; END IF;
ELSE
IF EXISTS(SELECT 1 FROM huaman.pago WHERE medio='YAPE' AND estado='A' AND fecha_pago=dia AND nro_operacion=NEW.nro_operacion) THEN RAISE EXCEPTION 'Operacion Yape ya usada en venta'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER referencia_yape BEFORE INSERT OR UPDATE ON pago FOR EACH ROW EXECUTE FUNCTION huaman.validar_referencia_yape_cruzada();
CREATE TRIGGER referencia_yape BEFORE INSERT ON abono_credito FOR EACH ROW EXECUTE FUNCTION huaman.validar_referencia_yape_cruzada();

CREATE FUNCTION huaman.registrar_abono(p_cuenta bigint,p_caja bigint,p_monto numeric,p_medio text,p_clave uuid,p_referencia text DEFAULT NULL,p_marca text DEFAULT NULL,p_ultimos text DEFAULT NULL,p_observacion text DEFAULT NULL) RETURNS bigint
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
IF deuda.saldo<>deuda.monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito WHERE id_cuenta=p_cuenta AND estado='A') THEN RAISE EXCEPTION 'Saldo requiere revision; no corregir con un abono'; END IF;
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
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'registrar_abono' AS proceso,to_regprocedure('huaman.registrar_abono(bigint,bigint,numeric,text,uuid,text,text,text,text)') IS NOT NULL AS instalado;

-- FERRETERIA HUAMAN - BLOQUE 15 - apertura de envases y cortes preparatorios
-- Requiere 01 a 14, incluido 09B. Ejecutar completo una vez.
-- Solo instala procesos. No convierte ni corta existencias reales.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.entregar_despacho(bigint,uuid,text,text)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 14'; END IF;
IF to_regprocedure('huaman.abrir_envase(bigint,uuid,text)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 15 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA','TRANSFORMAR_EXISTENCIA')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;

CREATE FUNCTION huaman._transformacion_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'')='TRANSFORMAR_EXISTENCIA'
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;
CREATE FUNCTION huaman.validar_transformacion_inmutable() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF TG_OP<>'INSERT' OR NOT coalesce(huaman._transformacion_en_curso(),false) THEN RAISE EXCEPTION 'Transformaciones solo por proceso; registros confirmados inmutables'; END IF;
IF TG_TABLE_NAME='transformacion_stock' THEN
IF NEW.estado_transformacion<>'CONFIRMADA' OR NEW.estado<>'A' THEN RAISE EXCEPTION 'Transformacion debe nacer confirmada en transaccion'; END IF;
ELSE
IF NEW.estado<>'A' OR NOT EXISTS(SELECT 1 FROM huaman.transformacion_stock WHERE id_transformacion=NEW.id_transformacion AND id_producto=NEW.id_producto AND estado='A' AND estado_transformacion='CONFIRMADA') THEN RAISE EXCEPTION 'Detalle sin transformacion confirmada'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_transformacion BEFORE INSERT OR UPDATE ON transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.validar_transformacion_inmutable();
CREATE TRIGGER validar_transformacion BEFORE INSERT OR UPDATE ON detalle_transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.validar_transformacion_inmutable();

CREATE FUNCTION huaman._transformar_existencia(p_origen bigint,p_tipo text,p_longitudes jsonb,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;prod huaman.producto%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;t huaman.transformacion_stock%ROWTYPE;
producto_id bigint;pres_base bigint;previo text;motivo text:=nullif(btrim(p_motivo),'');payload jsonb;anterior jsonb;
item jsonb;cantidad numeric;suma numeric:=0;total_origen numeric;transformacion bigint;destino bigint;numero integer:=0;condicion text;salidas jsonb;
BEGIN
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Proceso interno'; END IF;
actor:=huaman._actor_con_permiso('INV.TRANSFORMAR');
IF p_origen IS NULL OR p_clave IS NULL OR p_tipo IS NULL OR p_tipo NOT IN ('APERTURA_ENVASE','CORTE') OR motivo IS NULL OR length(motivo) NOT BETWEEN 5 AND 200 OR motivo ~ '[<>]' OR p_longitudes IS NULL OR jsonb_typeof(p_longitudes)<>'array' THEN RAISE EXCEPTION 'Datos de transformacion invalidos'; END IF;
IF (p_tipo='APERTURA_ENVASE' AND jsonb_array_length(p_longitudes)<>0) OR (p_tipo='CORTE' AND jsonb_array_length(p_longitudes) NOT BETWEEN 2 AND 1000) THEN RAISE EXCEPTION 'Apertura sin longitudes; corte requiere de 2 a 1000 piezas, incluido remanente'; END IF;
payload:=jsonb_build_object('origen',p_origen,'tipo',p_tipo,'longitudes',p_longitudes,'motivo',motivo);
PERFORM pg_advisory_xact_lock(hashtextextended('TRANSFORMACION:'||p_clave::text,0));
SELECT * INTO t FROM huaman.transformacion_stock WHERE clave_idempotencia=p_clave;
IF FOUND THEN
SELECT valor_nuevo->'solicitud' INTO anterior FROM huaman.bitacora_evento WHERE entidad='transformacion_stock' AND id_entidad=t.id_transformacion AND accion='INV.TRANSFORMAR' AND referencia=p_clave::text;
IF anterior IS DISTINCT FROM payload THEN RAISE EXCEPTION 'Clave usada con otra transformacion'; END IF;
RETURN t.id_transformacion;
END IF;
SELECT id_producto INTO producto_id FROM huaman.unidad_existencia WHERE id_unidad_existencia=p_origen;
IF NOT FOUND THEN RAISE EXCEPTION 'Unidad origen inexistente'; END IF;
-- Igual que ingresos y ventas: producto antes de unidad fisica.
SELECT * INTO prod FROM huaman.producto WHERE id_producto=producto_id FOR UPDATE;
SELECT * INTO u FROM huaman.unidad_existencia WHERE id_unidad_existencia=p_origen FOR UPDATE;
IF prod.estado<>'A' OR u.estado<>'A' OR u.cantidad_disponible_base<=0 OR prod.costo_promedio<=0 THEN RAISE EXCEPTION 'Producto o existencia no disponible'; END IF;
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto bloqueado por conteo'; END IF;
IF (p_tipo='APERTURA_ENVASE' AND (prod.modo_control<>'ENVASES' OR u.condicion_fisica<>'ENVASE' OR u.cantidad_disponible_base<>u.cantidad_inicial_base)) OR (p_tipo='CORTE' AND (prod.modo_control<>'TRAMOS' OR u.condicion_fisica<>'TRAMO')) THEN RAISE EXCEPTION 'Operacion incompatible con condicion fisica del origen'; END IF;
IF prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=producto_id AND estado='A') THEN RAISE EXCEPTION 'Saldo agregado no coincide con existencias; revisar antes de transformar'; END IF;
SELECT id_presentacion INTO pres_base FROM huaman.presentacion_producto WHERE id_producto=producto_id AND es_base AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Producto sin presentacion base activa'; END IF;
total_origen:=u.cantidad_disponible_base;
IF p_tipo='APERTURA_ENVASE' THEN salidas:=jsonb_build_array(total_origen);condicion:='SUELTO';ELSE salidas:=p_longitudes;condicion:='TRAMO'; END IF;
FOR item IN SELECT value FROM jsonb_array_elements(salidas) LOOP
IF jsonb_typeof(item)<>'number' THEN RAISE EXCEPTION 'Las longitudes deben ser numeros en unidad base'; END IF;
cantidad:=(item#>>'{}')::numeric;
IF cantidad::text IN ('NaN','Infinity','-Infinity') OR cantidad<=0 OR cantidad<>round(cantidad,6) OR mod(cantidad,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad de destino incompatible con incremento base'; END IF;
suma:=suma+cantidad;
END LOOP;
IF suma<>total_origen THEN RAISE EXCEPTION 'Destinos deben sumar todo el disponible del origen, incluido remanente; merma va por separado'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','TRANSFORMAR_EXISTENCIA',true);
INSERT INTO huaman.transformacion_stock(id_producto,tipo_transformacion,id_responsable,motivo,estado_transformacion,clave_idempotencia)
VALUES(producto_id,p_tipo,actor,motivo,'CONFIRMADA',p_clave) RETURNING id_transformacion INTO transformacion;
INSERT INTO huaman.detalle_transformacion_stock(id_transformacion,id_producto,id_unidad_existencia,sentido,cantidad_base,costo_unitario_base)
VALUES(transformacion,producto_id,p_origen,'S',total_origen,prod.costo_promedio);
UPDATE huaman.unidad_existencia SET cantidad_disponible_base=0 WHERE id_unidad_existencia=p_origen;
FOR item IN SELECT value FROM jsonb_array_elements(salidas) LOOP
numero:=numero+1;cantidad:=(item#>>'{}')::numeric;
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_transformacion_origen,id_unidad_origen)
VALUES(producto_id,pres_base,'TR-'||transformacion||'-'||numero,condicion,cantidad,cantidad,transformacion,p_origen) RETURNING id_unidad_existencia INTO destino;
INSERT INTO huaman.detalle_transformacion_stock(id_transformacion,id_producto,id_unidad_existencia,sentido,cantidad_base,costo_unitario_base)
VALUES(transformacion,producto_id,destino,'E',cantidad,prod.costo_promedio);
END LOOP;
-- Dos movimientos con efecto neto cero y mismo costo. No son venta, ingreso ni merma.
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_transformacion,clave_idempotencia)
VALUES(producto_id,'TRANSFORMACION','S',total_origen,prod.stock_actual,prod.stock_actual-total_origen,prod.costo_promedio,transformacion,gen_random_uuid());
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_transformacion,clave_idempotencia)
VALUES(producto_id,'TRANSFORMACION','E',total_origen,prod.stock_actual-total_origen,prod.stock_actual,prod.costo_promedio,transformacion,gen_random_uuid());
IF prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=producto_id AND estado='A') THEN RAISE EXCEPTION 'Transformacion no conserva cantidad fisica'; END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'INV.TRANSFORMAR','transformacion_stock',transformacion,p_clave::text,jsonb_build_object('solicitud',payload,'cantidad_base',total_origen,'costo_unitario_base',prod.costo_promedio,'piezas_destino',numero));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN transformacion;
END $$;
CREATE FUNCTION huaman.abrir_envase(p_origen bigint,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
SELECT huaman._transformar_existencia(p_origen,'APERTURA_ENVASE','[]'::jsonb,p_clave,p_motivo)
$$;
CREATE FUNCTION huaman.cortar_tramo(p_origen bigint,p_longitudes jsonb,p_clave uuid,p_motivo text) RETURNS bigint
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
SELECT huaman._transformar_existencia(p_origen,'CORTE',p_longitudes,p_clave,p_motivo)
$$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'abrir_envase' AS proceso,to_regprocedure('huaman.abrir_envase(bigint,uuid,text)') IS NOT NULL AS instalado
UNION ALL SELECT 'cortar_tramo',to_regprocedure('huaman.cortar_tramo(bigint,jsonb,uuid,text)') IS NOT NULL;

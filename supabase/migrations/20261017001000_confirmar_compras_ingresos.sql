-- FERRETERIA HUAMAN - BLOQUE 10 - emitir orden y confirmar ingreso
-- Requiere 01 a 09 y 09B. Ejecutar completo una vez.
-- Solo instala procesos; no crea compras ni actualiza existencias al instalar.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ DECLARE r record;BEGIN
IF to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)') IS NULL
OR NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='huaman' AND table_name='unidad_medida' AND column_name='codigo_sunat') THEN RAISE EXCEPTION 'Instalar 09 y 09B antes del bloque 10'; END IF;
IF to_regprocedure('huaman.confirmar_ingreso(bigint,uuid)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 10 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Ejecutar con el mismo propietario SQL de los bloques anteriores'; END IF;
-- Un ingreso puede contener rollos de diferente longitud en lineas separadas.
FOR r IN SELECT c.conname FROM pg_constraint c WHERE c.conrelid='huaman.detalle_ingreso'::regclass AND c.contype='u'
AND (SELECT array_agg(a.attname::text ORDER BY x.ord) FROM unnest(c.conkey) WITH ORDINALITY x(attnum,ord) JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=x.attnum)=ARRAY['id_ingreso','id_presentacion','condicion_fisica'] LOOP
EXECUTE format('ALTER TABLE huaman.detalle_ingreso DROP CONSTRAINT %I',r.conname);
END LOOP;
END $$;
CREATE INDEX ix_det_ingreso_ingreso_presentacion ON detalle_ingreso(id_ingreso,id_presentacion);
ALTER TABLE orden_compra ADD COLUMN clave_emision uuid UNIQUE;
ALTER TABLE ingreso_mercaderia ADD COLUMN clave_confirmacion uuid UNIQUE;

CREATE FUNCTION huaman._actor_con_permiso(p_permiso text) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;actor_nombre text;equipo text;
BEGIN
actor_nombre:=nullif(current_setting('app.usuario',true),'');equipo:=nullif(current_setting('app.equipo',true),'');
IF actor_nombre IS NULL OR equipo IS NULL OR length(actor_nombre)>100 OR length(equipo)>100 THEN RAISE EXCEPTION 'Falta contexto del servidor autenticado'; END IF;
SELECT u.id_usuario INTO actor FROM huaman.usuario u JOIN huaman.rol r USING(id_rol) JOIN huaman.rol_permiso rp USING(id_rol) JOIN huaman.permiso p USING(id_permiso)
WHERE lower(u.username)=lower(actor_nombre) AND u.estado='A' AND r.estado='A' AND rp.estado='A' AND p.estado='A' AND p.codigo=p_permiso;
IF NOT FOUND THEN RAISE EXCEPTION 'Usuario sin permiso %',p_permiso; END IF;
RETURN actor;
END $$;
-- Se conserva el nombre interno del bloque 09 para no alterar sus dependencias.
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner)
AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO')
FROM pg_proc p WHERE p.oid=to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)')
$$;
CREATE OR REPLACE FUNCTION huaman.validar_cabecera_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
DECLARE oc huaman.orden_compra%ROWTYPE;
BEGIN
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

CREATE FUNCTION huaman.emitir_orden_compra(p_orden bigint,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;oc huaman.orden_compra%ROWTYPE;previo text;
BEGIN
actor:=huaman._actor_con_permiso('COM.OC');
IF p_orden IS NULL OR p_clave IS NULL THEN RAISE EXCEPTION 'Orden y clave obligatorias'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('EMITIR_OC:'||p_clave::text,0));
SELECT * INTO oc FROM huaman.orden_compra WHERE id_orden_compra=p_orden FOR UPDATE;
IF NOT FOUND OR oc.estado<>'A' THEN RAISE EXCEPTION 'Orden inexistente o inactiva'; END IF;
IF oc.clave_emision=p_clave AND oc.estado_orden IN ('EMITIDA','PARCIAL','COMPLETA') THEN RETURN oc.id_orden_compra; END IF;
IF oc.estado_orden<>'BORRADOR' THEN RAISE EXCEPTION 'Orden ya emitida o no editable'; END IF;
IF EXISTS(SELECT 1 FROM huaman.orden_compra WHERE clave_emision=p_clave AND id_orden_compra<>p_orden) THEN RAISE EXCEPTION 'Clave ya usada por otra orden'; END IF;
IF oc.total_estimado<=0 OR NOT EXISTS(SELECT 1 FROM huaman.detalle_orden_compra WHERE id_orden_compra=p_orden AND estado='A') THEN RAISE EXCEPTION 'Orden sin lineas activas o total positivo'; END IF;
IF EXISTS(SELECT 1 FROM huaman.detalle_orden_compra d JOIN huaman.producto p ON p.id_producto=d.id_producto JOIN huaman.presentacion_producto pr ON pr.id_presentacion=d.id_presentacion WHERE d.id_orden_compra=p_orden AND d.estado='A' AND (p.estado<>'A' OR pr.estado<>'A')) THEN RAISE EXCEPTION 'Orden contiene productos/presentaciones inactivos'; END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','EMITIR_ORDEN',true);
UPDATE huaman.orden_compra SET estado_orden='EMITIDA',clave_emision=p_clave WHERE id_orden_compra=p_orden;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'COM.OC_EMITIR','orden_compra',p_orden,p_clave::text,jsonb_build_object('estado','EMITIDA','total_estimado',oc.total_estimado));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_orden;
END $$;

CREATE FUNCTION huaman.confirmar_ingreso(p_ingreso bigint,p_clave uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;ing huaman.ingreso_mercaderia%ROWTYPE;oc huaman.orden_compra%ROWTYPE;di huaman.detalle_ingreso%ROWTYPE;
prod huaman.producto%ROWTYPE;pres huaman.presentacion_producto%ROWTYPE;doc huaman.detalle_orden_compra%ROWTYPE;
previo text;mov bigint;qty numeric;costo numeric;nuevo_promedio numeric;saldo_nuevo numeric;pieza integer;por_pieza numeric;total_detalles numeric;
BEGIN
actor:=huaman._actor_con_permiso('COM.INGRESO');
IF p_ingreso IS NULL OR p_clave IS NULL THEN RAISE EXCEPTION 'Ingreso y clave obligatorios'; END IF;
PERFORM pg_advisory_xact_lock(hashtextextended('CONFIRMAR_INGRESO:'||p_clave::text,0));
SELECT * INTO ing FROM huaman.ingreso_mercaderia WHERE id_ingreso=p_ingreso FOR UPDATE;
IF NOT FOUND OR ing.estado<>'A' THEN RAISE EXCEPTION 'Ingreso inexistente o inactivo'; END IF;
IF ing.estado_ingreso='CONFIRMADO' AND ing.clave_confirmacion=p_clave THEN RETURN p_ingreso; END IF;
IF ing.estado_ingreso<>'BORRADOR' THEN RAISE EXCEPTION 'Ingreso ya confirmado o no editable'; END IF;
IF EXISTS(SELECT 1 FROM huaman.ingreso_mercaderia WHERE clave_confirmacion=p_clave AND id_ingreso<>p_ingreso) THEN RAISE EXCEPTION 'Clave ya usada por otro ingreso'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.proveedor WHERE id_proveedor=ing.id_proveedor AND estado='A') THEN RAISE EXCEPTION 'Proveedor inactivo'; END IF;
IF ing.id_orden_compra IS NOT NULL THEN
SELECT * INTO oc FROM huaman.orden_compra WHERE id_orden_compra=ing.id_orden_compra FOR UPDATE;
IF NOT FOUND OR oc.estado<>'A' OR oc.id_proveedor<>ing.id_proveedor OR oc.estado_orden NOT IN ('EMITIDA','PARCIAL') THEN RAISE EXCEPTION 'Orden debe estar emitida/parcial y corresponder al proveedor'; END IF;
END IF;
SELECT coalesce(sum(importe_adquisicion),0) INTO total_detalles FROM huaman.detalle_ingreso WHERE id_ingreso=p_ingreso AND estado='A';
IF total_detalles<=0 OR total_detalles<>ing.total THEN RAISE EXCEPTION 'Ingreso sin detalle positivo o con total inconsistente'; END IF;
-- Orden estable de bloqueo por producto; los borradores no bloquean productos al editar cantidades.
PERFORM p.id_producto FROM huaman.producto p WHERE p.id_producto IN (SELECT id_producto FROM huaman.detalle_ingreso WHERE id_ingreso=p_ingreso AND estado='A') ORDER BY p.id_producto FOR UPDATE;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','CONFIRMAR_INGRESO',true);
FOR di IN SELECT * FROM huaman.detalle_ingreso WHERE id_ingreso=p_ingreso AND estado='A' ORDER BY id_producto,id_detalle_ingreso LOOP
SELECT * INTO prod FROM huaman.producto WHERE id_producto=di.id_producto;
SELECT * INTO pres FROM huaman.presentacion_producto WHERE id_presentacion=di.id_presentacion;
IF prod.estado<>'A' OR pres.estado<>'A' OR pres.id_producto<>prod.id_producto OR pres.factor_base<>di.factor_base THEN RAISE EXCEPTION 'Producto/presentacion no disponible o equivalencia incompatible'; END IF;
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto bloqueado por toma de inventario'; END IF;
qty:=di.cantidad_base;
IF qty<=0 OR mod(qty,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad base incompatible'; END IF;
IF ing.id_orden_compra IS NOT NULL THEN
SELECT * INTO doc FROM huaman.detalle_orden_compra WHERE id_detalle_oc=di.id_detalle_oc FOR UPDATE;
IF NOT FOUND OR doc.estado<>'A' OR doc.id_orden_compra<>ing.id_orden_compra OR doc.id_producto<>di.id_producto OR doc.id_presentacion<>di.id_presentacion OR doc.cantidad_recibida_base+qty>doc.cantidad_base THEN RAISE EXCEPTION 'Recepcion supera pendiente o linea de orden incompatible'; END IF;
END IF;
IF (prod.modo_control='GRANEL' AND di.condicion_fisica<>'GRANEL') OR (prod.modo_control='ENVASES' AND di.condicion_fisica NOT IN ('GRANEL','ENVASE')) OR (prod.modo_control='TRAMOS' AND di.condicion_fisica<>'TRAMO') THEN RAISE EXCEPTION 'Condicion fisica incompatible'; END IF;
IF di.condicion_fisica='ENVASE' AND (pres.id_unidad_venta IS NOT NULL OR di.piezas<>di.cantidad_recibida) THEN RAISE EXCEPTION 'Envase integro incompatible con presentacion'; END IF;
IF di.condicion_fisica='TRAMO' AND (di.piezas IS NULL OR mod(qty/di.piezas,prod.incremento_base)<>0) THEN RAISE EXCEPTION 'Longitud por tramo incompatible'; END IF;
costo:=round(di.importe_adquisicion/qty,6);
IF costo<=0 THEN RAISE EXCEPTION 'Costo base redondea a cero; revisar precision y documento de adquisicion'; END IF;
saldo_nuevo:=prod.stock_actual+qty;
nuevo_promedio:=round((prod.stock_actual*prod.costo_promedio+di.importe_adquisicion)/saldo_nuevo,6);
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_ingreso,clave_idempotencia)
VALUES(prod.id_producto,'INGRESO_COMPRA','E',qty,prod.stock_actual,saldo_nuevo,costo,p_ingreso,gen_random_uuid()) RETURNING id_movimiento INTO mov;
IF prod.modo_control='ENVASES' AND di.condicion_fisica='GRANEL' THEN
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_detalle_ingreso)
VALUES(prod.id_producto,di.id_presentacion,'ING-'||p_ingreso||'-'||di.id_detalle_ingreso||'-SUELTO','SUELTO',qty,qty,di.id_detalle_ingreso);
ELSIF di.condicion_fisica IN ('ENVASE','TRAMO') THEN
por_pieza:=qty/di.piezas;
FOR pieza IN 1..di.piezas LOOP
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_detalle_ingreso)
VALUES(prod.id_producto,di.id_presentacion,'ING-'||p_ingreso||'-'||di.id_detalle_ingreso||'-'||pieza,di.condicion_fisica,por_pieza,por_pieza,di.id_detalle_ingreso);
END LOOP;
END IF;
UPDATE huaman.producto SET stock_actual=saldo_nuevo,ultimo_costo_compra=costo,costo_promedio=nuevo_promedio WHERE id_producto=prod.id_producto;
INSERT INTO huaman.historial_costo(id_producto,id_detalle_ingreso,id_movimiento,motivo,referencia,stock_anterior,stock_nuevo,costo_promedio_anterior,costo_promedio_nuevo,ultimo_costo_anterior,ultimo_costo_nuevo)
VALUES(prod.id_producto,di.id_detalle_ingreso,mov,'Ingreso de mercaderia confirmado','INGRESO:'||p_ingreso,prod.stock_actual,saldo_nuevo,prod.costo_promedio,nuevo_promedio,prod.ultimo_costo_compra,costo);
IF ing.id_orden_compra IS NOT NULL THEN UPDATE huaman.detalle_orden_compra SET cantidad_recibida_base=cantidad_recibida_base+qty WHERE id_detalle_oc=di.id_detalle_oc; END IF;
IF saldo_nuevo>prod.stock_minimo OR prod.stock_minimo=0 THEN
UPDATE huaman.alerta_stock SET estado_alerta='CERRADA',fecha_cierre=timezone('America/Lima',now()) WHERE id_producto=prod.id_producto AND estado='A' AND estado_alerta='ABIERTA';
ELSIF NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=prod.id_producto AND estado='A' AND estado_alerta='ABIERTA') THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(prod.id_producto,saldo_nuevo,prod.stock_minimo);
END IF;
END LOOP;
UPDATE huaman.ingreso_mercaderia SET estado_ingreso='CONFIRMADO',confirmado_en=timezone('America/Lima',now()),id_confirma=actor,clave_confirmacion=p_clave WHERE id_ingreso=p_ingreso;
IF ing.id_orden_compra IS NOT NULL THEN
UPDATE huaman.orden_compra SET estado_orden=CASE WHEN NOT EXISTS(SELECT 1 FROM huaman.detalle_orden_compra WHERE id_orden_compra=ing.id_orden_compra AND estado='A' AND cantidad_recibida_base<cantidad_base) THEN 'COMPLETA' ELSE 'PARCIAL' END WHERE id_orden_compra=ing.id_orden_compra;
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'COM.INGRESO_CONFIRMAR','ingreso_mercaderia',p_ingreso,p_clave::text,jsonb_build_object('estado','CONFIRMADO','total_adquisicion',ing.total));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN p_ingreso;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'emitir_orden_compra' AS proceso,to_regprocedure('huaman.emitir_orden_compra(bigint,uuid)') IS NOT NULL AS instalado
UNION ALL SELECT 'confirmar_ingreso',to_regprocedure('huaman.confirmar_ingreso(bigint,uuid)') IS NOT NULL;

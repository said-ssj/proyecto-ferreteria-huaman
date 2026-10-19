-- FERRETERIA HUAMAN - BLOQUE 09 - apertura inicial de inventario
-- Requiere 01 a 08. Ejecutar completo una sola vez.
-- INSTALA el proceso. No lo invoca y no carga existencias ni personas ficticias.
-- Acceso solo para el servidor de confianza; no exponer como RPC de cliente.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
SELECT set_config('app.usuario','MIGRACION_009',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
DO $$ BEGIN
IF to_regclass('huaman.asignacion_existencia_venta') IS NULL OR to_regprocedure('huaman.proteger_saldos_pendientes()') IS NULL THEN
RAISE EXCEPTION 'Instalar primero bloques 01 a 08'; END IF;
IF to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)') IS NOT NULL THEN
RAISE EXCEPTION 'Bloque 09 ya instalado. No reejecutar'; END IF;
END $$;
INSERT INTO permiso(codigo,modulo,descripcion) VALUES ('INV.APERTURA','INV','Registrar existencias iniciales; solo ADM');
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p WHERE r.codigo='ADM' AND p.codigo='INV.APERTURA';

-- INVOKER deliberado: un usuario SQL sin privilegios no se convierte en propietario al evaluar esta puerta.
CREATE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner)
AND coalesce(current_setting('app.proceso',true),'')='APERTURA_STOCK'
FROM pg_proc p WHERE p.oid=to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)')
$$;

CREATE OR REPLACE FUNCTION huaman.bloquear_inventario_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF NOT coalesce(huaman._apertura_en_curso(),false) THEN
RAISE EXCEPTION 'Escritura de inventario solo mediante procesos habilitados; no modificar movimientos ni saldos manualmente';
END IF;
RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION huaman.proteger_saldos_pendientes() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF (NEW.stock_actual,NEW.ultimo_costo_compra,NEW.costo_promedio) IS DISTINCT FROM (OLD.stock_actual,OLD.ultimo_costo_compra,OLD.costo_promedio)
AND NOT coalesce(huaman._apertura_en_curso(),false) THEN
RAISE EXCEPTION 'Saldo y costos solo cambian mediante procesos habilitados'; END IF;
RETURN NEW;
END $$;

CREATE FUNCTION huaman.apertura_stock(
p_producto bigint,p_cantidad numeric,p_costo_unitario_base numeric,p_clave uuid,p_unidades jsonb DEFAULT '[]'::jsonb
) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE prod huaman.producto%ROWTYPE;pres huaman.presentacion_producto%ROWTYPE;anterior huaman.movimiento_inventario%ROWTYPE;
actor bigint;usuario_actor text;equipo_actor text;proceso_previo text;
mov bigint;item jsonb;cant numeric;ident text;condicion text;presid bigint;suma numeric:=0;payload jsonb;prev_payload jsonb;
BEGIN
usuario_actor:=nullif(current_setting('app.usuario',true),'');equipo_actor:=nullif(current_setting('app.equipo',true),'');
IF usuario_actor IS NULL OR equipo_actor IS NULL OR length(usuario_actor)>100 OR length(equipo_actor)>100 THEN RAISE EXCEPTION 'Falta contexto del servidor autenticado'; END IF;
SELECT u.id_usuario INTO actor FROM huaman.usuario u JOIN huaman.rol r ON r.id_rol=u.id_rol
JOIN huaman.rol_permiso rp ON rp.id_rol=r.id_rol JOIN huaman.permiso p ON p.id_permiso=rp.id_permiso
WHERE lower(u.username)=lower(usuario_actor) AND u.estado='A' AND r.estado='A' AND rp.estado='A' AND p.estado='A' AND p.codigo='INV.APERTURA' AND r.codigo='ADM';
IF NOT FOUND THEN RAISE EXCEPTION 'Usuario sin permiso de apertura inicial'; END IF;
IF p_producto IS NULL OR p_clave IS NULL OR p_cantidad IS NULL OR p_costo_unitario_base IS NULL OR p_unidades IS NULL THEN RAISE EXCEPTION 'Parametros obligatorios incompletos'; END IF;
IF p_cantidad::text IN ('NaN','Infinity','-Infinity') OR p_costo_unitario_base::text IN ('NaN','Infinity','-Infinity')
OR p_cantidad<=0 OR p_costo_unitario_base<=0 OR p_cantidad<>round(p_cantidad,6) OR p_costo_unitario_base<>round(p_costo_unitario_base,6) THEN
RAISE EXCEPTION 'Cantidad y costo deben ser positivos, finitos y de hasta seis decimales'; END IF;
IF jsonb_typeof(p_unidades)<>'array' THEN RAISE EXCEPTION 'Unidades fisicas debe ser un arreglo JSON'; END IF;
payload:=jsonb_build_object('producto',p_producto,'cantidad',p_cantidad,'costo_unitario_base',p_costo_unitario_base,'unidades',p_unidades);
-- Serializa la misma clave incluso si se intenta usar con otro producto.
PERFORM pg_advisory_xact_lock(hashtextextended(p_clave::text,0));
SELECT * INTO anterior FROM huaman.movimiento_inventario WHERE clave_idempotencia=p_clave;
IF FOUND THEN
SELECT valor_nuevo INTO prev_payload FROM huaman.bitacora_evento WHERE accion='INV.APERTURA' AND entidad='producto' AND id_entidad=p_producto AND referencia=p_clave::text AND id_usuario=actor;
IF anterior.tipo_movimiento<>'SALDO_INICIAL' OR anterior.id_producto<>p_producto OR prev_payload IS DISTINCT FROM payload THEN
RAISE EXCEPTION 'Clave de idempotencia ya usada con otra solicitud o usuario'; END IF;
RETURN anterior.id_movimiento;
END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=p_producto FOR UPDATE;
IF NOT FOUND OR prod.estado<>'A' THEN RAISE EXCEPTION 'Producto inexistente o inactivo'; END IF;
IF mod(p_cantidad,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad incompatible con incremento base'; END IF;
IF prod.stock_actual<>0 OR prod.ultimo_costo_compra<>0 OR prod.costo_promedio<>0 OR EXISTS(SELECT 1 FROM huaman.movimiento_inventario WHERE id_producto=p_producto)
OR EXISTS(SELECT 1 FROM huaman.unidad_existencia WHERE id_producto=p_producto) THEN
RAISE EXCEPTION 'Producto ya tiene historia o saldo: usar compra/ajuste, no otra apertura'; END IF;
IF prod.modo_control='GRANEL' AND jsonb_array_length(p_unidades)<>0 THEN RAISE EXCEPTION 'Granel simple no requiere unidades fisicas individuales'; END IF;
IF prod.modo_control<>'GRANEL' AND jsonb_array_length(p_unidades)=0 THEN RAISE EXCEPTION 'Identificar envases, contenido suelto o tramos iniciales'; END IF;

-- Validar el detalle completo antes de crear movimientos.
FOR item IN SELECT value FROM jsonb_array_elements(p_unidades) LOOP
IF jsonb_typeof(item)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(item) k WHERE k NOT IN ('identificador','condicion','cantidad','id_presentacion')) THEN RAISE EXCEPTION 'Formato de unidad fisica invalido'; END IF;
ident:=upper(btrim(item->>'identificador'));condicion:=item->>'condicion';cant:=(item->>'cantidad')::numeric;presid:=nullif(item->>'id_presentacion','')::bigint;
IF ident IS NULL OR length(ident) NOT BETWEEN 1 AND 60 OR cant IS NULL OR cant::text IN ('NaN','Infinity','-Infinity') OR cant<=0 OR cant<>round(cant,6) OR mod(cant,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Identificador o cantidad fisica invalida'; END IF;
IF condicion IS NULL OR (prod.modo_control='ENVASES' AND condicion NOT IN ('ENVASE','SUELTO')) OR (prod.modo_control='TRAMOS' AND condicion<>'TRAMO') THEN RAISE EXCEPTION 'Condicion fisica incompatible con producto'; END IF;
IF presid IS NOT NULL THEN
SELECT * INTO pres FROM huaman.presentacion_producto WHERE id_presentacion=presid AND id_producto=p_producto AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Presentacion fisica inexistente o incompatible'; END IF;
END IF;
IF condicion='ENVASE' THEN
IF presid IS NULL THEN RAISE EXCEPTION 'Envase completo requiere presentacion'; END IF;
IF pres.id_unidad_venta IS NOT NULL OR cant<>pres.factor_base THEN RAISE EXCEPTION 'Cada envase integro debe equivaler a una presentacion comercial completa'; END IF;
END IF;
suma:=suma+cant;
END LOOP;
IF prod.modo_control<>'GRANEL' AND suma<>p_cantidad THEN RAISE EXCEPTION 'Detalle fisico no coincide con cantidad base total'; END IF;

proceso_previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','APERTURA_STOCK',true);
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,clave_idempotencia)
VALUES(p_producto,'SALDO_INICIAL','E',p_cantidad,0,p_cantidad,p_costo_unitario_base,p_clave) RETURNING id_movimiento INTO mov;
FOR item IN SELECT value FROM jsonb_array_elements(p_unidades) LOOP
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,referencia_apertura)
VALUES(p_producto,nullif(item->>'id_presentacion','')::bigint,upper(btrim(item->>'identificador')),item->>'condicion',(item->>'cantidad')::numeric,(item->>'cantidad')::numeric,'APERTURA:'||mov::text);
END LOOP;
UPDATE huaman.producto SET stock_actual=p_cantidad,ultimo_costo_compra=p_costo_unitario_base,costo_promedio=p_costo_unitario_base WHERE id_producto=p_producto;
INSERT INTO huaman.historial_costo(id_producto,id_movimiento,motivo,referencia,stock_anterior,stock_nuevo,costo_promedio_anterior,costo_promedio_nuevo,ultimo_costo_anterior,ultimo_costo_nuevo)
VALUES(p_producto,mov,'Apertura inicial de existencias','APERTURA:'||mov::text,0,p_cantidad,0,p_costo_unitario_base,0,p_costo_unitario_base);
IF p_cantidad<=prod.stock_minimo AND prod.stock_minimo>0 THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(p_producto,p_cantidad,prod.stock_minimo);
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_nuevo)
VALUES(actor,'INV.APERTURA','producto',p_producto,p_clave::text,payload);
PERFORM set_config('app.proceso',coalesce(proceso_previo,''),true);
RETURN mov;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'apertura_stock' AS proceso,
to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)') IS NOT NULL AS instalado,
(SELECT count(*) FROM information_schema.tables WHERE table_schema='huaman' AND table_type='BASE TABLE') AS tablas;

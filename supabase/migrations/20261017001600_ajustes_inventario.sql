-- FERRETERIA HUAMAN - BLOQUE 16 - ajustes de inventario
-- Requiere 01 a 15, incluido 09B. Solo instala; no ajusta existencias.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regprocedure('huaman.abrir_envase(bigint,uuid,text)') IS NULL THEN RAISE EXCEPTION 'Instalar bloque 15'; END IF;
IF to_regprocedure('huaman.registrar_ajuste(bigint,text,numeric,bigint,text,uuid,jsonb)') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 16 ya instalado'; END IF;
IF current_user<>pg_get_userbyid((SELECT proowner FROM pg_proc WHERE oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure)) THEN RAISE EXCEPTION 'Usar mismo propietario SQL'; END IF;
END $$;
ALTER TABLE ajuste_inventario ADD COLUMN clave_idempotencia uuid UNIQUE;
ALTER TABLE ajuste_inventario ADD COLUMN id_responsable bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE ajuste_inventario ADD CONSTRAINT uq_ajuste_producto UNIQUE(id_ajuste,id_producto);
ALTER TABLE unidad_existencia ADD COLUMN id_ajuste_origen bigint;
ALTER TABLE unidad_existencia ADD CONSTRAINT fk_unidad_ajuste FOREIGN KEY(id_ajuste_origen,id_producto) REFERENCES ajuste_inventario(id_ajuste,id_producto) ON DELETE RESTRICT;
DO $$ DECLARE restr record; BEGIN
FOR restr IN SELECT conname FROM pg_constraint WHERE conrelid='huaman.unidad_existencia'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%num_nonnulls%' LOOP
EXECUTE format('ALTER TABLE huaman.unidad_existencia DROP CONSTRAINT %I',restr.conname);
END LOOP;
END $$;
ALTER TABLE unidad_existencia ADD CONSTRAINT ck_unidad_origen_unico CHECK(num_nonnulls(id_detalle_ingreso,id_transformacion_origen,referencia_apertura,id_ajuste_origen)=1);
CREATE OR REPLACE FUNCTION huaman._apertura_en_curso() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,pg_temp AS $$
SELECT current_user=pg_get_userbyid(p.proowner) AND coalesce(current_setting('app.proceso',true),'') IN ('APERTURA_STOCK','EMITIR_ORDEN','CONFIRMAR_INGRESO','CONFIRMAR_VENTA','TRANSFORMAR_EXISTENCIA','REGISTRAR_AJUSTE')
FROM pg_proc p WHERE p.oid='huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'::regprocedure
$$;

CREATE FUNCTION huaman.validar_ajuste_confirmado() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,pg_temp AS $$
BEGIN
IF TG_OP<>'INSERT' OR NOT coalesce(huaman._apertura_en_curso(),false) OR current_setting('app.proceso',true)<>'REGISTRAR_AJUSTE' OR NEW.estado_ajuste<>'CONFIRMADO' OR NEW.estado<>'A' OR NEW.clave_idempotencia IS NULL OR NEW.id_responsable IS NULL THEN RAISE EXCEPTION 'Ajustes solo mediante proceso; confirmados inmutables'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_ajuste BEFORE INSERT OR UPDATE ON ajuste_inventario FOR EACH ROW EXECUTE FUNCTION huaman.validar_ajuste_confirmado();
CREATE FUNCTION huaman.registrar_ajuste(p_producto bigint,p_tipo text,p_cantidad numeric,p_motivo bigint,p_observacion text,p_clave uuid,p_unidades jsonb DEFAULT '[]'::jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE actor bigint;prod huaman.producto%ROWTYPE;u huaman.unidad_existencia%ROWTYPE;pres huaman.presentacion_producto%ROWTYPE;a huaman.ajuste_inventario%ROWTYPE;
obs text:=nullif(btrim(p_observacion),'');payload jsonb;anterior jsonb;previo text;item jsonb;qty numeric;suma numeric:=0;nuevo bigint;saldo_nuevo numeric;numero integer:=0;unidad bigint;presentacion bigint;condicion text;ident text;vistos bigint[]:='{}';
BEGIN
actor:=huaman._actor_con_permiso('INV.AJUSTAR');
IF p_producto IS NULL OR p_tipo IS NULL OR p_tipo NOT IN ('AUMENTO','DISMINUCION') OR p_cantidad IS NULL OR p_cantidad::text IN ('NaN','Infinity','-Infinity') OR p_cantidad<=0 OR p_cantidad<>round(p_cantidad,6) OR p_motivo IS NULL OR p_clave IS NULL OR obs IS NULL OR length(obs) NOT BETWEEN 5 AND 300 OR obs ~ '[<>]' OR p_unidades IS NULL OR jsonb_typeof(p_unidades)<>'array' THEN RAISE EXCEPTION 'Datos de ajuste invalidos'; END IF;
IF jsonb_array_length(p_unidades)>1000 THEN RAISE EXCEPTION 'Maximo 1000 unidades fisicas por ajuste'; END IF;
payload:=jsonb_build_object('producto',p_producto,'tipo',p_tipo,'cantidad',p_cantidad,'motivo',p_motivo,'observacion',obs,'unidades',p_unidades);
PERFORM pg_advisory_xact_lock(hashtextextended('AJUSTE:'||p_clave::text,0));
SELECT * INTO a FROM huaman.ajuste_inventario WHERE clave_idempotencia=p_clave;
IF FOUND THEN
SELECT valor_nuevo->'solicitud' INTO anterior FROM huaman.bitacora_evento WHERE entidad='ajuste_inventario' AND id_entidad=a.id_ajuste AND accion='INV.AJUSTAR' AND referencia=p_clave::text;
IF anterior IS DISTINCT FROM payload THEN RAISE EXCEPTION 'Clave usada con otros datos'; END IF;
RETURN a.id_ajuste;
END IF;
SELECT * INTO prod FROM huaman.producto WHERE id_producto=p_producto FOR UPDATE;
IF NOT FOUND OR prod.estado<>'A' OR prod.costo_promedio<=0 THEN RAISE EXCEPTION 'Producto activo con costo conocido requerido; use apertura o ingreso para inicializar'; END IF;
IF mod(p_cantidad,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad incompatible con incremento base'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.motivo_ajuste WHERE id_motivo_ajuste=p_motivo AND estado='A') THEN RAISE EXCEPTION 'Motivo inexistente o inactivo'; END IF;
IF EXISTS(SELECT 1 FROM huaman.toma_inventario WHERE estado='A' AND estado_toma IN ('EN_CONTEO','CERRADA') AND (alcance='TODO' OR id_categoria=prod.id_categoria)) THEN RAISE EXCEPTION 'Producto bloqueado por conteo'; END IF;
saldo_nuevo:=prod.stock_actual+CASE WHEN p_tipo='AUMENTO' THEN p_cantidad ELSE -p_cantidad END;
IF saldo_nuevo<0 THEN RAISE EXCEPTION 'Disminucion supera stock disponible'; END IF;
IF prod.modo_control='GRANEL' THEN
IF jsonb_array_length(p_unidades)<>0 THEN RAISE EXCEPTION 'Granel no requiere unidades fisicas'; END IF;
ELSE
IF jsonb_array_length(p_unidades)=0 OR prod.stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=p_producto AND estado='A') THEN RAISE EXCEPTION 'Unidades requeridas o saldo fisico inconsistente'; END IF;
END IF;
previo:=current_setting('app.proceso',true);PERFORM set_config('app.proceso','REGISTRAR_AJUSTE',true);
INSERT INTO huaman.ajuste_inventario(id_producto,estado_ajuste,costo_unitario_base,tipo_ajuste,cantidad,id_motivo_ajuste,observacion,clave_idempotencia,id_responsable)
VALUES(p_producto,'CONFIRMADO',prod.costo_promedio,p_tipo,p_cantidad,p_motivo,obs,p_clave,actor) RETURNING id_ajuste INTO nuevo;
FOR item IN SELECT value FROM jsonb_array_elements(p_unidades) LOOP
numero:=numero+1;
IF jsonb_typeof(item)<>'object' OR jsonb_typeof(item->'cantidad') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Unidad requiere objeto con cantidad numerica'; END IF;
qty:=(item->>'cantidad')::numeric;
IF qty<=0 OR qty<>round(qty,6) OR mod(qty,prod.incremento_base)<>0 THEN RAISE EXCEPTION 'Cantidad fisica incompatible'; END IF;
suma:=suma+qty;
IF p_tipo='DISMINUCION' THEN
IF item-ARRAY['id_unidad','cantidad']<>'{}'::jsonb OR jsonb_typeof(item->'id_unidad') IS DISTINCT FROM 'number' OR (item->>'id_unidad')::numeric<>trunc((item->>'id_unidad')::numeric) THEN RAISE EXCEPTION 'Disminucion requiere id_unidad entero y cantidad'; END IF;
unidad:=(item->>'id_unidad')::bigint;
IF unidad=ANY(vistos) THEN RAISE EXCEPTION 'No repetir unidad fisica'; END IF;vistos:=array_append(vistos,unidad);
SELECT * INTO u FROM huaman.unidad_existencia WHERE id_unidad_existencia=unidad FOR UPDATE;
IF NOT FOUND OR u.id_producto<>p_producto OR u.estado<>'A' OR qty>u.cantidad_disponible_base OR (u.condicion_fisica='ENVASE' AND qty<>u.cantidad_disponible_base) THEN RAISE EXCEPTION 'Unidad no disponible; envase cerrado se retira completo'; END IF;
UPDATE huaman.unidad_existencia SET cantidad_disponible_base=cantidad_disponible_base-qty WHERE id_unidad_existencia=unidad;
ELSE
IF item-ARRAY['condicion','cantidad','id_presentacion']<>'{}'::jsonb THEN RAISE EXCEPTION 'Campos fisicos de aumento no reconocidos'; END IF;
condicion:=item->>'condicion';presentacion:=NULL;
IF condicion IS NULL OR (prod.modo_control='ENVASES' AND condicion NOT IN ('ENVASE','SUELTO')) OR (prod.modo_control='TRAMOS' AND condicion<>'TRAMO') THEN RAISE EXCEPTION 'Condicion fisica incompatible'; END IF;
IF condicion='ENVASE' THEN
IF jsonb_typeof(item->'id_presentacion') IS DISTINCT FROM 'number' OR (item->>'id_presentacion')::numeric<>trunc((item->>'id_presentacion')::numeric) THEN RAISE EXCEPTION 'Envase requiere presentacion entera'; END IF;
presentacion:=(item->>'id_presentacion')::bigint;
SELECT * INTO pres FROM huaman.presentacion_producto WHERE id_presentacion=presentacion;
IF NOT FOUND OR pres.id_producto<>p_producto OR pres.estado<>'A' OR pres.id_unidad_venta IS NOT NULL OR pres.factor_base<>qty THEN RAISE EXCEPTION 'Envase debe coincidir con presentacion integra'; END IF;
ELSE
IF item?'id_presentacion' THEN RAISE EXCEPTION 'Solo envase declara presentacion comercial'; END IF;
SELECT id_presentacion INTO presentacion FROM huaman.presentacion_producto WHERE id_producto=p_producto AND es_base AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Sin presentacion base activa'; END IF;
END IF;
ident:='AJ-'||nuevo||'-'||numero;
INSERT INTO huaman.unidad_existencia(id_producto,id_presentacion,identificador,condicion_fisica,cantidad_inicial_base,cantidad_disponible_base,id_ajuste_origen)
VALUES(p_producto,presentacion,ident,condicion,qty,qty,nuevo);
END IF;
END LOOP;
IF prod.modo_control<>'GRANEL' AND suma<>p_cantidad THEN RAISE EXCEPTION 'Suma fisica no coincide con ajuste'; END IF;
INSERT INTO huaman.movimiento_inventario(id_producto,tipo_movimiento,sentido,cantidad,saldo_anterior,saldo,costo_unitario_base,id_ajuste,clave_idempotencia)
VALUES(p_producto,CASE WHEN p_tipo='AUMENTO' THEN 'AJUSTE_AUMENTO' ELSE 'AJUSTE_DISMINUCION' END,CASE WHEN p_tipo='AUMENTO' THEN 'E' ELSE 'S' END,p_cantidad,prod.stock_actual,saldo_nuevo,prod.costo_promedio,nuevo,p_clave);
UPDATE huaman.producto SET stock_actual=saldo_nuevo WHERE id_producto=p_producto;
IF prod.modo_control<>'GRANEL' AND saldo_nuevo<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia WHERE id_producto=p_producto AND estado='A') THEN RAISE EXCEPTION 'Ajuste no conserva saldo fisico'; END IF;
IF saldo_nuevo>prod.stock_minimo OR prod.stock_minimo=0 THEN
UPDATE huaman.alerta_stock SET estado_alerta='CERRADA',fecha_cierre=timezone('America/Lima',now()) WHERE id_producto=p_producto AND estado='A' AND estado_alerta='ABIERTA';
ELSIF NOT EXISTS(SELECT 1 FROM huaman.alerta_stock WHERE id_producto=p_producto AND estado='A' AND estado_alerta='ABIERTA') THEN
INSERT INTO huaman.alerta_stock(id_producto,stock_al_generar,stock_minimo_al_generar) VALUES(p_producto,saldo_nuevo,prod.stock_minimo);
END IF;
INSERT INTO huaman.bitacora_evento(id_usuario,accion,entidad,id_entidad,referencia,valor_anterior,valor_nuevo)
VALUES(actor,'INV.AJUSTAR','ajuste_inventario',nuevo,p_clave::text,jsonb_build_object('stock',prod.stock_actual),jsonb_build_object('stock',saldo_nuevo,'solicitud',payload,'costo_unitario_base',prod.costo_promedio));
PERFORM set_config('app.proceso',coalesce(previo,''),true);RETURN nuevo;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'registrar_ajuste' AS proceso,to_regprocedure('huaman.registrar_ajuste(bigint,text,numeric,bigint,text,uuid,jsonb)') IS NOT NULL AS instalado;

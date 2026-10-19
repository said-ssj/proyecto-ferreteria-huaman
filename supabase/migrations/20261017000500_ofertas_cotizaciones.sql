-- FERRETERIA HUAMAN - BLOQUE 05 - ofertas y cotizaciones
-- Ejecutar completo una sola vez despues de 01 a 04.
-- Sin datos ficticios; una cotizacion no reserva ni descuenta inventario.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
  IF to_regclass('huaman.detalle_ingreso') IS NULL THEN RAISE EXCEPTION 'Instalar primero bloques 01 a 04'; END IF;
IF to_regclass('huaman.oferta') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 05 ya instalado o parcial: oferta existe'; END IF;
IF to_regclass('huaman.cotizacion') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 05 ya instalado o parcial: cotizacion existe'; END IF;
IF to_regclass('huaman.detalle_cotizacion') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 05 ya instalado o parcial: detalle_cotizacion existe'; END IF;
END $$;
CREATE TABLE oferta (
id_oferta bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
id_presentacion bigint NOT NULL,
nombre varchar(80) NOT NULL CHECK (btrim(nombre)<>''),
precio_oferta numeric(18,6) NOT NULL CHECK (precio_oferta>0),
fecha_inicio date NOT NULL,fecha_fin date NOT NULL,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY (id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
CHECK (fecha_fin>=fecha_inicio),
-- Un rango singleton identifica la presentacion, sin depender de btree_gist.
EXCLUDE USING gist (int8range(id_presentacion,id_presentacion,'[]') WITH &&,
daterange(fecha_inicio,fecha_fin,'[]') WITH &&) WHERE (estado='A')
);
CREATE INDEX ix_oferta_producto_fechas ON oferta(id_producto,fecha_inicio,fecha_fin);
CREATE INDEX ix_oferta_presentacion ON oferta(id_presentacion);
CREATE TABLE cotizacion (
id_cotizacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
id_cliente bigint REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
nombre_interesado varchar(150),
id_vendedor bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
fecha date NOT NULL DEFAULT timezone('America/Lima',now())::date,
vigente_hasta date NOT NULL,
moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda='PEN'),
subtotal numeric(18,2) NOT NULL DEFAULT 0 CHECK (subtotal>=0),
descuento_total numeric(18,2) NOT NULL DEFAULT 0 CHECK (descuento_total>=0),
total numeric(18,2) NOT NULL DEFAULT 0 CHECK (total>=0),
observacion varchar(300),
estado_cotizacion varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_cotizacion IN ('BORRADOR','VIGENTE','VENCIDA','CONVERTIDA','ANULADA')),
motivo_anulacion varchar(200),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
CHECK (vigente_hasta>=fecha),CHECK (total=subtotal-descuento_total),
CHECK (estado_cotizacion<>'ANULADA' OR length(btrim(coalesce(motivo_anulacion,''))) BETWEEN 10 AND 200)
);
CREATE INDEX ix_cotizacion_cliente ON cotizacion(id_cliente);
CREATE INDEX ix_cotizacion_vendedor_fecha ON cotizacion(id_vendedor,fecha DESC);
CREATE INDEX ix_cotizacion_vigencia ON cotizacion(estado_cotizacion,vigente_hasta);
CREATE TABLE detalle_cotizacion (
id_detalle_cotizacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_cotizacion bigint NOT NULL REFERENCES cotizacion(id_cotizacion) ON DELETE RESTRICT,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
id_presentacion bigint NOT NULL,
producto_nombre varchar(120) NOT NULL,presentacion_nombre varchar(60) NOT NULL,unidad_base_simbolo varchar(8) NOT NULL,
cantidad numeric(18,6) NOT NULL CHECK (cantidad>0),
factor_base numeric(18,6) NOT NULL CHECK (factor_base>0),
cantidad_base numeric(24,12) GENERATED ALWAYS AS (cantidad*factor_base) STORED,
precio_lista numeric(18,6) NOT NULL CHECK (precio_lista>0),
precio_unitario numeric(18,6) NOT NULL CHECK (precio_unitario>0),
origen_precio varchar(10) NOT NULL CHECK (origen_precio IN ('NORMAL','MAYORISTA','OFERTA')),
id_oferta bigint REFERENCES oferta(id_oferta) ON DELETE RESTRICT,
id_precio_mayorista bigint REFERENCES precio_mayorista(id_precio_mayorista) ON DELETE RESTRICT,
descuento_monto numeric(18,2) GENERATED ALWAYS AS (round(cantidad*precio_lista,2)-round(cantidad*precio_unitario,2)) STORED,
importe numeric(18,2) GENERATED ALWAYS AS (round(cantidad*precio_unitario,2)) STORED,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY (id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
UNIQUE(id_cotizacion,id_presentacion),
CHECK (precio_unitario<=precio_lista AND round(cantidad*precio_unitario,2)>0),
CHECK ((origen_precio='NORMAL' AND id_oferta IS NULL AND id_precio_mayorista IS NULL) OR
       (origen_precio='OFERTA' AND id_oferta IS NOT NULL AND id_precio_mayorista IS NULL) OR
       (origen_precio='MAYORISTA' AND id_oferta IS NULL AND id_precio_mayorista IS NOT NULL))
);
CREATE INDEX ix_det_cot_producto_presentacion ON detalle_cotizacion(id_producto,id_presentacion);
CREATE INDEX ix_det_cot_oferta ON detalle_cotizacion(id_oferta);
CREATE INDEX ix_det_cot_mayorista ON detalle_cotizacion(id_precio_mayorista);

CREATE FUNCTION huaman.validar_oferta_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE p huaman.presentacion_producto%ROWTYPE;
BEGIN
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion FOR UPDATE;
  IF NOT FOUND OR p.id_producto<>NEW.id_producto THEN RAISE EXCEPTION 'Presentacion y producto no coinciden'; END IF;
  IF NEW.estado='A' AND (p.estado<>'A' OR NOT p.permite_venta OR NEW.precio_oferta>p.precio_normal) THEN RAISE EXCEPTION 'Oferta invalida para presentacion/precio normal'; END IF;
  IF TG_OP='UPDATE' AND (NEW.id_producto,NEW.id_presentacion) IS DISTINCT FROM (OLD.id_producto,OLD.id_presentacion) THEN RAISE EXCEPTION 'No reasignar una oferta historica'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_oferta BEFORE INSERT OR UPDATE ON oferta FOR EACH ROW EXECUTE FUNCTION huaman.validar_oferta_catalogo();

CREATE FUNCTION huaman.validar_cabecera_cotizacion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_vendedor AND estado='A') THEN RAISE EXCEPTION 'Vendedor inexistente o inactivo'; END IF;
  IF NEW.id_cliente IS NOT NULL AND NOT EXISTS(SELECT 1 FROM huaman.cliente WHERE id_cliente=NEW.id_cliente AND estado='A') THEN RAISE EXCEPTION 'Cliente inexistente o inactivo'; END IF;
  -- No publicar cotizaciones hasta instalar el proceso completo y sus autorizaciones.
  IF NEW.estado_cotizacion<>'BORRADOR' THEN RAISE EXCEPTION 'Emision y conversion pendientes del bloque de procesos de venta'; END IF;
  IF TG_OP='INSERT' AND (NEW.subtotal<>0 OR NEW.descuento_total<>0 OR NEW.total<>0) THEN RAISE EXCEPTION 'Totales se calculan desde detalles'; END IF;
  IF TG_OP='UPDATE' THEN
    IF (NEW.subtotal,NEW.descuento_total,NEW.total) IS DISTINCT FROM (OLD.subtotal,OLD.descuento_total,OLD.total) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar totales manualmente'; END IF;
    IF NEW.fecha<>OLD.fecha AND EXISTS(SELECT 1 FROM huaman.detalle_cotizacion WHERE id_cotizacion=NEW.id_cotizacion) THEN RAISE EXCEPTION 'Cotizacion con lineas: no cambiar fecha sin recotizar'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_cabecera BEFORE INSERT OR UPDATE ON cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.validar_cabecera_cotizacion();

CREATE FUNCTION huaman.validar_detalle_cotizacion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE c huaman.cotizacion%ROWTYPE;p huaman.presentacion_producto%ROWTYPE;prod huaman.producto%ROWTYPE;
        mayor huaman.precio_mayorista%ROWTYPE;promo huaman.oferta%ROWTYPE;
BEGIN
  SELECT * INTO c FROM huaman.cotizacion WHERE id_cotizacion=NEW.id_cotizacion FOR UPDATE;
  IF NOT FOUND OR c.estado_cotizacion<>'BORRADOR' OR c.estado<>'A' THEN RAISE EXCEPTION 'Cotizacion no editable'; END IF;
  IF TG_OP='UPDATE' AND NEW.id_cotizacion<>OLD.id_cotizacion THEN RAISE EXCEPTION 'No mover detalle a otra cotizacion'; END IF;
  SELECT * INTO prod FROM huaman.producto WHERE id_producto=NEW.id_producto;
  IF NOT FOUND OR prod.estado<>'A' THEN RAISE EXCEPTION 'Producto no disponible'; END IF;
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion FOR SHARE;
  IF NOT FOUND OR p.id_producto<>NEW.id_producto OR p.estado<>'A' OR NOT p.permite_venta THEN RAISE EXCEPTION 'Presentacion no disponible'; END IF;
  IF NEW.cantidad<p.minimo_venta OR mod(NEW.cantidad,p.incremento_venta)<>0 OR
     NEW.cantidad*p.factor_base<prod.minimo_venta_base OR mod(NEW.cantidad*p.factor_base,prod.incremento_base)<>0 THEN
    RAISE EXCEPTION 'Cantidad incompatible con minimo o incremento';
  END IF;
  NEW.producto_nombre:=prod.nombre;NEW.presentacion_nombre:=p.nombre;NEW.factor_base:=p.factor_base;
  SELECT abreviatura INTO NEW.unidad_base_simbolo FROM huaman.unidad_medida WHERE id_unidad=prod.id_unidad;
  NEW.precio_lista:=p.precio_normal;NEW.precio_unitario:=p.precio_normal;NEW.origen_precio:='NORMAL';NEW.id_oferta:=NULL;NEW.id_precio_mayorista:=NULL;
  SELECT * INTO mayor FROM huaman.precio_mayorista WHERE id_presentacion=p.id_presentacion AND estado='A' AND cantidad_minima<=NEW.cantidad ORDER BY cantidad_minima DESC LIMIT 1;
  IF FOUND AND mayor.precio<NEW.precio_unitario THEN NEW.precio_unitario:=mayor.precio;NEW.origen_precio:='MAYORISTA';NEW.id_precio_mayorista:=mayor.id_precio_mayorista; END IF;
  SELECT * INTO promo FROM huaman.oferta WHERE id_presentacion=p.id_presentacion AND estado='A' AND c.fecha BETWEEN fecha_inicio AND fecha_fin;
  IF FOUND AND promo.precio_oferta<NEW.precio_unitario THEN NEW.precio_unitario:=promo.precio_oferta;NEW.origen_precio:='OFERTA';NEW.id_oferta:=promo.id_oferta;NEW.id_precio_mayorista:=NULL; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_detalle BEFORE INSERT OR UPDATE ON detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.validar_detalle_cotizacion();
CREATE FUNCTION huaman.recalcular_total_cotizacion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  UPDATE huaman.cotizacion SET
    subtotal=(SELECT coalesce(sum(round(cantidad*precio_lista,2)),0) FROM huaman.detalle_cotizacion WHERE id_cotizacion=NEW.id_cotizacion AND estado='A'),
    descuento_total=(SELECT coalesce(sum(descuento_monto),0) FROM huaman.detalle_cotizacion WHERE id_cotizacion=NEW.id_cotizacion AND estado='A'),
    total=(SELECT coalesce(sum(importe),0) FROM huaman.detalle_cotizacion WHERE id_cotizacion=NEW.id_cotizacion AND estado='A')
  WHERE id_cotizacion=NEW.id_cotizacion;
  RETURN NULL;
END $$;
CREATE TRIGGER total_cotizacion AFTER INSERT OR UPDATE ON detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.recalcular_total_cotizacion();

ALTER TABLE huaman.oferta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.oferta FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.oferta FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.oferta FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.oferta FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.cotizacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.cotizacion FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.cotizacion FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.detalle_cotizacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_cotizacion FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_cotizacion FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_cotizacion FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'oferta' AS tabla,count(*) AS registros FROM huaman.oferta
UNION ALL SELECT 'cotizacion',count(*) FROM huaman.cotizacion
UNION ALL SELECT 'detalle_cotizacion',count(*) FROM huaman.detalle_cotizacion
ORDER BY tabla;

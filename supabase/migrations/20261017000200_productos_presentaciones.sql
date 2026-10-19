-- FERRETERIA HUAMAN - BLOQUE 02 - catalogo de productos y presentaciones
-- Requiere bloque 01 confirmado. Ejecutar TODO una sola vez.
-- No carga productos ficticios ni modifica stock real.
BEGIN;
SET LOCAL search_path TO huaman, pg_catalog;
SELECT set_config('app.usuario','MIGRACION_002',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
DO $$ BEGIN
  IF to_regclass('huaman.unidad_medida') IS NULL OR to_regprocedure('huaman.completar_auditoria()') IS NULL THEN
    RAISE EXCEPTION 'Primero instalar el bloque 01';
  END IF;
  IF to_regclass('huaman.categoria') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: categoria ya existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.motivo_ajuste') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: motivo_ajuste ya existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.producto') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: producto ya existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.presentacion_producto') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: presentacion_producto ya existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.codigo_presentacion') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: codigo_presentacion ya existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.precio_mayorista') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 02 ya instalado o incompleto: precio_mayorista ya existe. No reejecutar.'; END IF;
END $$;

CREATE TABLE categoria (
  id_categoria bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre varchar(60) NOT NULL UNIQUE,
  descripcion varchar(200),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE TABLE motivo_ajuste (
  id_motivo_ajuste bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre varchar(60) NOT NULL UNIQUE,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE UNIQUE INDEX ux_categoria_nombre_normal ON categoria(lower(btrim(nombre)));
ALTER TABLE categoria ADD CHECK (btrim(nombre) <> '');
CREATE UNIQUE INDEX ux_motivo_nombre_normal ON motivo_ajuste(lower(btrim(nombre)));
ALTER TABLE motivo_ajuste ADD CHECK (btrim(nombre) <> '');
CREATE TABLE producto (
  id_producto bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo varchar(30) NOT NULL UNIQUE CHECK (codigo = upper(btrim(codigo)) AND codigo <> ''),
  nombre varchar(120) NOT NULL CHECK (btrim(nombre) <> ''),
  descripcion varchar(300),
  id_categoria bigint NOT NULL REFERENCES categoria(id_categoria) ON DELETE RESTRICT,
  id_unidad bigint NOT NULL REFERENCES unidad_medida(id_unidad) ON DELETE RESTRICT,
  admite_fracciones boolean NOT NULL DEFAULT false,
  incremento_base numeric(18,6) NOT NULL DEFAULT 1 CHECK (incremento_base > 0),
  minimo_venta_base numeric(18,6) NOT NULL DEFAULT 1 CHECK (minimo_venta_base > 0),
  modo_control varchar(12) NOT NULL DEFAULT 'GRANEL' CHECK (modo_control IN ('GRANEL','ENVASES','TRAMOS')),
  ultimo_costo_compra numeric(18,6) NOT NULL DEFAULT 0 CHECK (ultimo_costo_compra >= 0),
  costo_promedio numeric(18,6) NOT NULL DEFAULT 0 CHECK (costo_promedio >= 0),
  stock_actual numeric(18,6) NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
  stock_minimo numeric(18,6) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
  ubicacion varchar(60),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (mod(minimo_venta_base,incremento_base)=0),
  CHECK (admite_fracciones OR (incremento_base=trunc(incremento_base) AND minimo_venta_base=trunc(minimo_venta_base)
         AND stock_actual=trunc(stock_actual) AND stock_minimo=trunc(stock_minimo)))
);
CREATE INDEX ix_producto_categoria ON producto(id_categoria);
CREATE INDEX ix_producto_unidad ON producto(id_unidad);
CREATE INDEX ix_producto_nombre ON producto(lower(nombre) text_pattern_ops);
CREATE TABLE presentacion_producto (
  id_presentacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  nombre varchar(60) NOT NULL CHECK (btrim(nombre) <> ''),
  -- NULL = envase comercial con equivalencia propia (bolsa, caja, rollo).
  id_unidad_venta bigint REFERENCES unidad_medida(id_unidad) ON DELETE RESTRICT,
  factor_base numeric(18,6) NOT NULL CHECK (factor_base > 0),
  es_base boolean NOT NULL DEFAULT false,
  permite_venta boolean NOT NULL DEFAULT true,
  admite_fracciones boolean NOT NULL DEFAULT false,
  incremento_venta numeric(18,6) NOT NULL DEFAULT 1 CHECK (incremento_venta > 0),
  minimo_venta numeric(18,6) NOT NULL DEFAULT 1 CHECK (minimo_venta > 0),
  -- PEN, IGV incluido; costo de adquisicion comparable se valida al vender.
  precio_normal numeric(18,6) NOT NULL CHECK (precio_normal > 0),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (mod(minimo_venta,incremento_venta)=0),
  CHECK (admite_fracciones OR (incremento_venta=trunc(incremento_venta) AND minimo_venta=trunc(minimo_venta))),
  CHECK (NOT es_base OR factor_base=1),
  CHECK (NOT es_base OR permite_venta),
  UNIQUE (id_producto,id_presentacion)
);
CREATE UNIQUE INDEX ux_presentacion_base_activa ON presentacion_producto(id_producto) WHERE es_base AND estado='A';
CREATE UNIQUE INDEX ux_presentacion_nombre_activo ON presentacion_producto(id_producto,lower(btrim(nombre))) WHERE estado='A';
CREATE INDEX ix_presentacion_unidad ON presentacion_producto(id_unidad_venta);
CREATE TABLE codigo_presentacion (
  id_codigo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_presentacion bigint NOT NULL REFERENCES presentacion_producto(id_presentacion) ON DELETE RESTRICT,
  codigo varchar(80) NOT NULL UNIQUE CHECK (codigo=btrim(codigo) AND codigo<>''),
  simbologia varchar(10) NOT NULL CHECK (simbologia IN ('CODE128','EAN13')),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((simbologia='EAN13' AND codigo ~ '^[0-9]{13}$') OR
         (simbologia='CODE128' AND codigo ~ '^[ -~]+$'))
);
CREATE UNIQUE INDEX ux_codigo_normalizado ON codigo_presentacion(upper(codigo));
CREATE INDEX ix_codigo_presentacion ON codigo_presentacion(id_presentacion);
CREATE TABLE precio_mayorista (
  id_precio_mayorista bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_presentacion bigint NOT NULL REFERENCES presentacion_producto(id_presentacion) ON DELETE RESTRICT,
  cantidad_minima numeric(18,6) NOT NULL CHECK (cantidad_minima > 0),
  precio numeric(18,6) NOT NULL CHECK (precio > 0),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);
CREATE UNIQUE INDEX ux_mayorista_minimo_activo ON precio_mayorista(id_presentacion,cantidad_minima) WHERE estado='A';

-- Valida unidades y protege el significado historico de un producto.
CREATE FUNCTION huaman.validar_producto_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE u huaman.unidad_medida%ROWTYPE;
BEGIN
  SELECT * INTO u FROM huaman.unidad_medida WHERE id_unidad=NEW.id_unidad;
  IF NOT FOUND OR u.estado<>'A' THEN RAISE EXCEPTION 'Unidad base inexistente o inactiva'; END IF;
  IF NEW.admite_fracciones AND NOT u.admite_decimales THEN RAISE EXCEPTION 'La unidad base no admite fracciones'; END IF;
  IF mod(NEW.incremento_base, power(10::numeric,-u.precision_cantidad))<>0 THEN RAISE EXCEPTION 'Incremento incompatible con precision de unidad'; END IF;
  IF NEW.modo_control='TRAMOS' AND u.magnitud<>'LONGITUD' THEN RAISE EXCEPTION 'Tramos requiere magnitud longitud'; END IF;
  IF TG_OP='INSERT' AND (NEW.stock_actual<>0 OR NEW.ultimo_costo_compra<>0 OR NEW.costo_promedio<>0) THEN
    RAISE EXCEPTION 'Crear producto sin existencias/costos; ingresarlos mediante apertura o compra auditable';
  END IF;
  IF TG_OP='UPDATE' AND (NEW.id_unidad,NEW.modo_control,NEW.admite_fracciones,NEW.incremento_base)
       IS DISTINCT FROM (OLD.id_unidad,OLD.modo_control,OLD.admite_fracciones,OLD.incremento_base) THEN
    RAISE EXCEPTION 'No reinterpretar unidad o control fisico: requiere migracion controlada';
  END IF;
  PERFORM pg_advisory_xact_lock(73210,1);
  IF EXISTS(SELECT 1 FROM huaman.codigo_presentacion WHERE upper(codigo)=NEW.codigo) THEN
    RAISE EXCEPTION 'Codigo interno colisiona con codigo de barras';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_catalogo BEFORE INSERT OR UPDATE ON producto
FOR EACH ROW EXECUTE FUNCTION huaman.validar_producto_catalogo();

CREATE FUNCTION huaman.validar_presentacion_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE p huaman.producto%ROWTYPE; b huaman.unidad_medida%ROWTYPE; v huaman.unidad_medida%ROWTYPE;
BEGIN
  IF TG_OP='UPDATE' AND (NEW.id_producto,NEW.factor_base,NEW.id_unidad_venta,NEW.es_base)
        IS DISTINCT FROM (OLD.id_producto,OLD.factor_base,OLD.id_unidad_venta,OLD.es_base) THEN
    RAISE EXCEPTION 'Equivalencia e identidad son inmutables: crear otra presentacion';
  END IF;
  SELECT * INTO p FROM huaman.producto WHERE id_producto=NEW.id_producto FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Producto inexistente'; END IF;
  SELECT * INTO b FROM huaman.unidad_medida WHERE id_unidad=p.id_unidad;
  IF NEW.es_base AND (NEW.id_unidad_venta IS DISTINCT FROM p.id_unidad) THEN
    RAISE EXCEPTION 'Presentacion base requiere unidad base del producto';
  END IF;
  IF NEW.id_unidad_venta IS NOT NULL THEN
    SELECT * INTO v FROM huaman.unidad_medida WHERE id_unidad=NEW.id_unidad_venta;
    IF NOT FOUND OR v.estado<>'A' OR v.magnitud<>b.magnitud THEN RAISE EXCEPTION 'Unidad de venta incompatible'; END IF;
    IF NEW.factor_base<>v.factor_referencia/b.factor_referencia THEN RAISE EXCEPTION 'Factor de conversion incorrecto'; END IF;
    IF NEW.admite_fracciones AND NOT v.admite_decimales THEN RAISE EXCEPTION 'La unidad de venta no admite fracciones'; END IF;
    IF mod(NEW.incremento_venta,power(10::numeric,-v.precision_cantidad))<>0 THEN RAISE EXCEPTION 'Incremento incompatible con unidad de venta'; END IF;
  END IF;
  IF mod(NEW.incremento_venta*NEW.factor_base,p.incremento_base)<>0 THEN
    RAISE EXCEPTION 'La cantidad resultante no respeta el incremento base del producto';
  END IF;
  IF NEW.minimo_venta*NEW.factor_base<p.minimo_venta_base THEN
    RAISE EXCEPTION 'Presentacion permite menos que el minimo base del producto';
  END IF;
  IF NEW.es_base AND NEW.estado='I' AND p.estado='A' THEN RAISE EXCEPTION 'Producto activo requiere base activa'; END IF;
  IF NEW.estado='A' AND EXISTS (SELECT 1 FROM huaman.precio_mayorista WHERE id_presentacion=NEW.id_presentacion AND estado='A' AND precio>NEW.precio_normal) THEN
    RAISE EXCEPTION 'Precio normal inferior a una regla mayorista activa: ajustar la regla primero';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_catalogo BEFORE INSERT OR UPDATE ON presentacion_producto
FOR EACH ROW EXECUTE FUNCTION huaman.validar_presentacion_catalogo();

-- Garantiza una presentacion base al finalizar la transaccion, no a mitad de un alta.
CREATE FUNCTION huaman.exigir_presentacion_base() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE pid bigint;
BEGIN
  pid:=NEW.id_producto;
  IF EXISTS(SELECT 1 FROM huaman.producto WHERE id_producto=pid AND estado='A') AND
    NOT EXISTS(SELECT 1 FROM huaman.presentacion_producto WHERE id_producto=pid AND es_base AND estado='A') THEN
    RAISE EXCEPTION 'Producto activo % sin presentacion base activa',pid;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER exigir_base AFTER INSERT OR UPDATE ON producto DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION huaman.exigir_presentacion_base();
CREATE CONSTRAINT TRIGGER exigir_base AFTER INSERT OR UPDATE ON presentacion_producto DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION huaman.exigir_presentacion_base();

CREATE FUNCTION huaman.validar_codigo_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE total integer:=0; i integer;
BEGIN
  PERFORM pg_advisory_xact_lock(73210,1);
  IF EXISTS(SELECT 1 FROM huaman.producto WHERE codigo=upper(NEW.codigo)) THEN RAISE EXCEPTION 'Codigo de barras colisiona con codigo interno'; END IF;
  IF TG_OP='UPDATE' AND (NEW.id_presentacion,NEW.codigo,NEW.simbologia) IS DISTINCT FROM (OLD.id_presentacion,OLD.codigo,OLD.simbologia) THEN
    RAISE EXCEPTION 'No reasignar identificador historico: inactivar y crear otro';
  END IF;
  IF NEW.simbologia='EAN13' THEN
    IF NEW.codigo !~ '^[0-9]{13}$' THEN RAISE EXCEPTION 'EAN13 requiere 13 digitos'; END IF;
    FOR i IN 1..12 LOOP total:=total+substring(NEW.codigo,i,1)::integer*CASE WHEN mod(i,2)=0 THEN 3 ELSE 1 END; END LOOP;
    IF mod(10-mod(total,10),10)<>substring(NEW.codigo,13,1)::integer THEN RAISE EXCEPTION 'Digito verificador EAN13 incorrecto'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_catalogo BEFORE INSERT OR UPDATE ON codigo_presentacion
FOR EACH ROW EXECUTE FUNCTION huaman.validar_codigo_catalogo();

CREATE FUNCTION huaman.validar_mayorista_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE p huaman.presentacion_producto%ROWTYPE;
BEGIN
  SELECT * INTO p FROM huaman.presentacion_producto WHERE id_presentacion=NEW.id_presentacion FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Presentacion inexistente'; END IF;
  IF NEW.estado='A' AND (p.estado<>'A' OR NOT p.permite_venta) THEN RAISE EXCEPTION 'Presentacion no disponible para mayorista'; END IF;
  IF NEW.precio>p.precio_normal THEN RAISE EXCEPTION 'Precio mayorista supera precio normal'; END IF;
  IF NEW.cantidad_minima<p.minimo_venta OR mod(NEW.cantidad_minima,p.incremento_venta)<>0 THEN RAISE EXCEPTION 'Minimo mayorista incompatible con cantidades permitidas'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_catalogo BEFORE INSERT OR UPDATE ON precio_mayorista
FOR EACH ROW EXECUTE FUNCTION huaman.validar_mayorista_catalogo();

ALTER TABLE huaman.categoria ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.categoria FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.categoria FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.categoria FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.categoria FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.motivo_ajuste ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.motivo_ajuste FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.motivo_ajuste FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.motivo_ajuste FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.motivo_ajuste FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.producto ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.producto FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.producto FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.producto FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.producto FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.presentacion_producto ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.presentacion_producto FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.presentacion_producto FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.presentacion_producto FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.presentacion_producto FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.codigo_presentacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.codigo_presentacion FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.codigo_presentacion FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.codigo_presentacion FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.codigo_presentacion FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.precio_mayorista ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.precio_mayorista FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.precio_mayorista FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.precio_mayorista FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.precio_mayorista FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

INSERT INTO categoria(nombre,descripcion) VALUES
('Construccion','Cemento, fierro y agregados'),('Pinturas','Pinturas y acabados'),
('Fijaciones','Clavos y tornillos'),('Gasfiteria','Tuberias y conexiones'),('Electricidad','Cables y accesorios');
INSERT INTO motivo_ajuste(nombre) VALUES ('Merma'),('Rotura'),('Perdida'),('Producto danado'),('Error de registro'),('Otro');
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'categoria' AS tabla,count(*) AS registros FROM huaman.categoria
UNION ALL SELECT 'motivo_ajuste',count(*) FROM huaman.motivo_ajuste
UNION ALL SELECT 'producto',count(*) FROM huaman.producto
UNION ALL SELECT 'presentacion_producto',count(*) FROM huaman.presentacion_producto
UNION ALL SELECT 'codigo_presentacion',count(*) FROM huaman.codigo_presentacion
UNION ALL SELECT 'precio_mayorista',count(*) FROM huaman.precio_mayorista
ORDER BY tabla;

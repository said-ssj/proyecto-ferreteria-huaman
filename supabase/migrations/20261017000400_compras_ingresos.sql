-- FERRETERIA HUAMAN - BLOQUE 04 - estructura de compras e ingresos
-- Requiere 01, 02 y 03 confirmados. Ejecutar TODO una sola vez.
-- No crea compras ficticias ni mueve inventario. Confirmacion pendiente de bloque de movimientos.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
  IF to_regclass('huaman.proveedor') IS NULL OR to_regclass('huaman.usuario') IS NULL THEN RAISE EXCEPTION 'Primero instalar bloques 01 a 03'; END IF;
  IF to_regclass('huaman.orden_compra') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 04 ya instalado o parcial: orden_compra existe'; END IF;
  IF to_regclass('huaman.detalle_orden_compra') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 04 ya instalado o parcial: detalle_orden_compra existe'; END IF;
  IF to_regclass('huaman.ingreso_mercaderia') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 04 ya instalado o parcial: ingreso_mercaderia existe'; END IF;
  IF to_regclass('huaman.detalle_ingreso') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 04 ya instalado o parcial: detalle_ingreso existe'; END IF;
END $$;

CREATE TABLE orden_compra (
  id_orden_compra bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  id_proveedor bigint NOT NULL REFERENCES proveedor(id_proveedor) ON DELETE RESTRICT,
  fecha date NOT NULL DEFAULT timezone('America/Lima',now())::date,
  fecha_entrega_estimada date,
  observacion varchar(300),
  moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda='PEN'),
  total_estimado numeric(18,2) NOT NULL DEFAULT 0 CHECK (total_estimado>=0),
  estado_orden varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_orden IN ('BORRADOR','EMITIDA','PARCIAL','COMPLETA','ANULADA')),
  motivo_anulacion varchar(200),
  usucre varchar(100) NOT NULL, pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (fecha_entrega_estimada IS NULL OR fecha_entrega_estimada>=fecha),
  CHECK (estado_orden<>'ANULADA' OR length(btrim(coalesce(motivo_anulacion,''))) BETWEEN 10 AND 200)
);
CREATE INDEX ix_oc_proveedor_fecha ON orden_compra(id_proveedor,fecha DESC);
CREATE TABLE detalle_orden_compra (
  id_detalle_oc bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_orden_compra bigint NOT NULL REFERENCES orden_compra(id_orden_compra) ON DELETE RESTRICT,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  id_presentacion bigint NOT NULL,
  presentacion_nombre varchar(60) NOT NULL,
  unidad_base_simbolo varchar(8) NOT NULL,
  factor_base numeric(18,6) NOT NULL CHECK (factor_base>0),
  cantidad_pedida numeric(18,6) NOT NULL CHECK (cantidad_pedida>0),
  cantidad_base numeric(24,12) GENERATED ALWAYS AS (cantidad_pedida*factor_base) STORED,
  cantidad_recibida_base numeric(24,12) NOT NULL DEFAULT 0 CHECK (cantidad_recibida_base>=0),
  -- Costo por presentacion, neto de impuestos recuperables; no mezclar con precio venta con IGV.
  costo_unitario numeric(18,6) NOT NULL CHECK (costo_unitario>0),
  importe_adquisicion numeric(18,2) GENERATED ALWAYS AS (round(cantidad_pedida*costo_unitario,2)) STORED,
  usucre varchar(100) NOT NULL, pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  FOREIGN KEY (id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
  UNIQUE(id_orden_compra,id_presentacion),
  CHECK (cantidad_recibida_base<=cantidad_pedida*factor_base),
  CHECK (round(cantidad_pedida*costo_unitario,2)>0)
);
CREATE INDEX ix_det_oc_producto_presentacion ON detalle_orden_compra(id_producto,id_presentacion);
CREATE TABLE ingreso_mercaderia (
  id_ingreso bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  id_proveedor bigint NOT NULL REFERENCES proveedor(id_proveedor) ON DELETE RESTRICT,
  id_orden_compra bigint REFERENCES orden_compra(id_orden_compra) ON DELETE RESTRICT,
  nro_guia varchar(30) NOT NULL CHECK (btrim(nro_guia)<>'' AND nro_guia=btrim(nro_guia)),
  fecha_ingreso date NOT NULL DEFAULT timezone('America/Lima',now())::date,
  observacion varchar(300),
  moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda='PEN'),
  total numeric(18,2) NOT NULL DEFAULT 0 CHECK (total>=0),
  estado_ingreso varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_ingreso IN ('BORRADOR','CONFIRMADO','ANULADO')),
  confirmado_en timestamp,
  id_confirma bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  motivo_anulacion varchar(200),
  usucre varchar(100) NOT NULL, pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((estado_ingreso='CONFIRMADO' AND confirmado_en IS NOT NULL AND id_confirma IS NOT NULL) OR
         (estado_ingreso<>'CONFIRMADO' AND confirmado_en IS NULL AND id_confirma IS NULL)),
  CHECK (estado_ingreso<>'ANULADO' OR length(btrim(coalesce(motivo_anulacion,''))) BETWEEN 10 AND 200)
);
CREATE UNIQUE INDEX ux_ingreso_guia ON ingreso_mercaderia(id_proveedor,upper(nro_guia));
CREATE INDEX ix_ingreso_orden ON ingreso_mercaderia(id_orden_compra);
CREATE INDEX ix_ingreso_fecha ON ingreso_mercaderia(fecha_ingreso DESC);
CREATE INDEX ix_ingreso_confirma ON ingreso_mercaderia(id_confirma);
CREATE TABLE detalle_ingreso (
  id_detalle_ingreso bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_ingreso bigint NOT NULL REFERENCES ingreso_mercaderia(id_ingreso) ON DELETE RESTRICT,
  id_detalle_oc bigint REFERENCES detalle_orden_compra(id_detalle_oc) ON DELETE RESTRICT,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  id_presentacion bigint NOT NULL,
  presentacion_nombre varchar(60) NOT NULL,
  unidad_base_simbolo varchar(8) NOT NULL,
  factor_base numeric(18,6) NOT NULL CHECK (factor_base>0),
  cantidad_recibida numeric(18,6) NOT NULL CHECK (cantidad_recibida>0),
  cantidad_base numeric(24,12) GENERATED ALWAYS AS (cantidad_recibida*factor_base) STORED,
  costo_unitario numeric(18,6) NOT NULL CHECK (costo_unitario>0),
  importe_adquisicion numeric(18,2) GENERATED ALWAYS AS (round(cantidad_recibida*costo_unitario,2)) STORED,
  condicion_fisica varchar(10) NOT NULL DEFAULT 'GRANEL' CHECK (condicion_fisica IN ('GRANEL','ENVASE','TRAMO')),
  -- Cantidad de rollos/envases enteros identificables al confirmar el ingreso.
  piezas integer CHECK (piezas>0),
  usucre varchar(100) NOT NULL, pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  usmod varchar(100), pcmod varchar(100), fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  FOREIGN KEY (id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
  UNIQUE(id_ingreso,id_presentacion,condicion_fisica),
  CHECK (round(cantidad_recibida*costo_unitario,2)>0),
  CHECK ((condicion_fisica='GRANEL' AND piezas IS NULL) OR (condicion_fisica IN ('ENVASE','TRAMO') AND piezas IS NOT NULL)),
  CHECK (condicion_fisica<>'ENVASE' OR cantidad_recibida=trunc(cantidad_recibida))
);
CREATE INDEX ix_det_ingreso_producto_presentacion ON detalle_ingreso(id_producto,id_presentacion);
CREATE INDEX ix_det_ingreso_oc ON detalle_ingreso(id_detalle_oc);

-- Este bloque instala documentos BORRADOR: no es todavia el proceso de confirmar inventario.
CREATE FUNCTION huaman.validar_cabecera_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE oc huaman.orden_compra%ROWTYPE;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM huaman.proveedor WHERE id_proveedor=NEW.id_proveedor AND estado='A') THEN RAISE EXCEPTION 'Proveedor inexistente o inactivo'; END IF;
  IF TG_TABLE_NAME='orden_compra' THEN
    IF NEW.estado_orden<>'BORRADOR' THEN RAISE EXCEPTION 'Emision de orden pendiente del bloque de procesos'; END IF;
    IF TG_OP='INSERT' AND NEW.total_estimado<>0 THEN RAISE EXCEPTION 'El total se obtiene de los detalles'; END IF;
    IF TG_OP='UPDATE' AND NEW.total_estimado<>OLD.total_estimado AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar el total manualmente'; END IF;
  ELSE
    IF NEW.estado_ingreso<>'BORRADOR' THEN RAISE EXCEPTION 'Confirmacion/anulacion pendiente del bloque de movimientos; no ajustar stock manualmente'; END IF;
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
CREATE TRIGGER validar_cabecera BEFORE INSERT OR UPDATE ON orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.validar_cabecera_compra();
CREATE TRIGGER validar_cabecera BEFORE INSERT OR UPDATE ON ingreso_mercaderia FOR EACH ROW EXECUTE FUNCTION huaman.validar_cabecera_compra();

CREATE FUNCTION huaman.validar_detalle_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE p huaman.presentacion_producto%ROWTYPE; prod huaman.producto%ROWTYPE;
        ing huaman.ingreso_mercaderia%ROWTYPE; oc huaman.orden_compra%ROWTYPE; d huaman.detalle_orden_compra%ROWTYPE;
        cantidad numeric; unidad text;
BEGIN
  SELECT * INTO prod FROM huaman.producto WHERE id_producto=NEW.id_producto FOR UPDATE;
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
CREATE TRIGGER validar_detalle BEFORE INSERT OR UPDATE ON detalle_orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.validar_detalle_compra();
CREATE TRIGGER validar_detalle BEFORE INSERT OR UPDATE ON detalle_ingreso FOR EACH ROW EXECUTE FUNCTION huaman.validar_detalle_compra();

CREATE FUNCTION huaman.recalcular_total_compra() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF TG_TABLE_NAME='detalle_orden_compra' THEN
    UPDATE huaman.orden_compra SET total_estimado=(SELECT coalesce(sum(importe_adquisicion),0) FROM huaman.detalle_orden_compra WHERE id_orden_compra=NEW.id_orden_compra AND estado='A') WHERE id_orden_compra=NEW.id_orden_compra;
  ELSE
    UPDATE huaman.ingreso_mercaderia SET total=(SELECT coalesce(sum(importe_adquisicion),0) FROM huaman.detalle_ingreso WHERE id_ingreso=NEW.id_ingreso AND estado='A') WHERE id_ingreso=NEW.id_ingreso;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER total_compra AFTER INSERT OR UPDATE ON detalle_orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.recalcular_total_compra();
CREATE TRIGGER total_compra AFTER INSERT OR UPDATE ON detalle_ingreso FOR EACH ROW EXECUTE FUNCTION huaman.recalcular_total_compra();

ALTER TABLE huaman.orden_compra ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.orden_compra FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.orden_compra FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.detalle_orden_compra ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_orden_compra FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_orden_compra FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_orden_compra FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.ingreso_mercaderia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.ingreso_mercaderia FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.ingreso_mercaderia FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.ingreso_mercaderia FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.ingreso_mercaderia FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.detalle_ingreso ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_ingreso FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_ingreso FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_ingreso FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_ingreso FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'orden_compra' AS tabla,count(*) AS registros FROM huaman.orden_compra
UNION ALL SELECT 'detalle_orden_compra',count(*) FROM huaman.detalle_orden_compra
UNION ALL SELECT 'ingreso_mercaderia',count(*) FROM huaman.ingreso_mercaderia
UNION ALL SELECT 'detalle_ingreso',count(*) FROM huaman.detalle_ingreso
ORDER BY tabla;

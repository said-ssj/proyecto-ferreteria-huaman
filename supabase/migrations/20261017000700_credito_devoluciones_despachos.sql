-- FERRETERIA HUAMAN - BLOQUE 07 - credito, devoluciones y despacho
-- Despues de bloques 01 a 06. Ejecutar completo una sola vez.
-- Estructura y validaciones; cobros, reintegros y stock requieren procesos posteriores.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regclass('huaman.archivo_comprobante') IS NULL THEN RAISE EXCEPTION 'Instalar primero bloques 01 a 06'; END IF;
IF to_regclass('huaman.cuenta_por_cobrar') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 07 ya instalado o parcial: cuenta_por_cobrar existe'; END IF;
IF to_regclass('huaman.abono_credito') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 07 ya instalado o parcial: abono_credito existe'; END IF;
IF to_regclass('huaman.devolucion') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 07 ya instalado o parcial: devolucion existe'; END IF;
IF to_regclass('huaman.detalle_devolucion') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 07 ya instalado o parcial: detalle_devolucion existe'; END IF;
IF to_regclass('huaman.despacho') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 07 ya instalado o parcial: despacho existe'; END IF;
END $$;

CREATE TABLE cuenta_por_cobrar (
  id_cuenta bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_venta bigint NOT NULL UNIQUE REFERENCES venta(id_venta) ON DELETE RESTRICT,
  id_cliente bigint NOT NULL REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  monto_original numeric(18,2) NOT NULL CHECK (monto_original > 0),
  saldo numeric(18,2) NOT NULL CHECK (saldo >= 0),
  fecha_vencimiento date NOT NULL,
  estado_cuenta varchar(10) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_cuenta IN ('PENDIENTE', 'VENCIDA', 'CANCELADA', 'ANULADA')),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (estado_cuenta NOT IN ('PENDIENTE','VENCIDA') OR saldo>0),
  CHECK (saldo <= monto_original),
  CHECK (estado_cuenta NOT IN ('CANCELADA','ANULADA') OR saldo = 0)
);

CREATE TABLE abono_credito (
  id_abono bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_cuenta bigint NOT NULL REFERENCES cuenta_por_cobrar(id_cuenta) ON DELETE RESTRICT,
  id_caja bigint NOT NULL REFERENCES caja_diaria(id_caja) ON DELETE RESTRICT,
  monto numeric(18,2) NOT NULL CHECK (monto > 0),
  medio varchar(8) NOT NULL CHECK (medio IN ('EFECTIVO', 'YAPE', 'DEBITO')),
  nro_operacion varchar(40),
  fecha_abono timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  clave_idempotencia uuid NOT NULL UNIQUE,
  marca_tarjeta varchar(30),ultimos_cuatro char(4),
  observacion varchar(300),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((medio = 'YAPE' AND nro_operacion IS NOT NULL AND nro_operacion ~ '^[0-9]{6,20}$') OR (medio = 'EFECTIVO' AND nro_operacion IS NULL) OR (medio='DEBITO' AND length(btrim(coalesce(nro_operacion,''))) BETWEEN 1 AND 40)),
  CHECK ((medio='DEBITO' AND (ultimos_cuatro IS NULL OR ultimos_cuatro ~ '^[0-9]{4}$')) OR (medio<>'DEBITO' AND ultimos_cuatro IS NULL AND marca_tarjeta IS NULL))
);

CREATE TABLE devolucion (
  id_devolucion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  id_venta bigint NOT NULL REFERENCES venta(id_venta) ON DELETE RESTRICT,
  estado_devolucion varchar(10) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_devolucion IN ('PENDIENTE', 'APROBADA', 'RECHAZADA')),
  fecha_solicitud timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
  referencia_reintegro varchar(40),
  forma_reintegro varchar(16) NOT NULL CHECK (forma_reintegro IN ('EFECTIVO', 'YAPE', 'DESCUENTO_DEUDA', 'DEBITO')),
  monto_reintegro numeric(18,2) NOT NULL DEFAULT 0 CHECK (monto_reintegro >= 0),
  motivo varchar(200) NOT NULL,
  id_solicita bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  id_autoriza bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  fecha_decision timestamp,
  motivo_rechazo varchar(200),
  id_caja bigint REFERENCES caja_diaria(id_caja) ON DELETE RESTRICT,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (length(trim(motivo)) BETWEEN 10 AND 200),
  CHECK ((estado_devolucion<>'PENDIENTE' OR (id_autoriza IS NULL AND fecha_decision IS NULL))),
  CHECK (estado_devolucion = 'PENDIENTE' OR (id_autoriza IS NOT NULL AND fecha_decision IS NOT NULL)),
  CHECK (estado_devolucion <> 'RECHAZADA' OR (motivo_rechazo IS NOT NULL AND length(trim(motivo_rechazo)) BETWEEN 10 AND 200)),
  CHECK (estado_devolucion <> 'APROBADA' OR id_caja IS NOT NULL),
  CHECK (estado_devolucion <> 'APROBADA' OR forma_reintegro<>'DEBITO' OR length(btrim(coalesce(referencia_reintegro,'')))>0)
);

CREATE TABLE detalle_devolucion (
  id_detalle_devolucion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_devolucion bigint NOT NULL REFERENCES devolucion(id_devolucion) ON DELETE RESTRICT,
  id_detalle_venta bigint NOT NULL REFERENCES detalle_venta(id_detalle_venta) ON DELETE RESTRICT,
  cantidad numeric(18,6) NOT NULL CHECK (cantidad > 0),
  estado_producto varchar(6) NOT NULL CHECK (estado_producto IN ('APTO', 'DANADO')),
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  id_presentacion bigint NOT NULL,
  presentacion_nombre varchar(60) NOT NULL,unidad_base_simbolo varchar(8) NOT NULL,
  factor_base numeric(18,6) NOT NULL CHECK (factor_base>0),
  cantidad_base numeric(24,12) GENERATED ALWAYS AS (cantidad*factor_base) STORED,
  costo_unitario_base numeric(18,6) NOT NULL CHECK (costo_unitario_base>=0),
  importe numeric(18,2) NOT NULL CHECK (importe > 0),
  FOREIGN KEY (id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  UNIQUE (id_devolucion, id_detalle_venta)
);

CREATE TABLE despacho (
  id_despacho bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  id_venta bigint NOT NULL UNIQUE REFERENCES venta(id_venta) ON DELETE RESTRICT,
  estado_despacho varchar(10) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_despacho IN ('PENDIENTE', 'PREPARADO', 'ENTREGADO', 'ANULADO')),
  id_prepara bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  fecha_preparacion timestamp,
  id_entrega bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  fecha_entrega timestamp,
  recibe_nombre varchar(100),
  observacion varchar(300),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (estado_despacho <> 'PREPARADO' OR (id_prepara IS NOT NULL AND fecha_preparacion IS NOT NULL)),
  CHECK (estado_despacho <> 'ENTREGADO' OR (id_entrega IS NOT NULL AND fecha_entrega IS NOT NULL))
);

CREATE INDEX ix_cuenta_cliente_estado ON cuenta_por_cobrar(id_cliente,estado_cuenta);
CREATE INDEX ix_cuenta_vencimiento ON cuenta_por_cobrar(fecha_vencimiento) WHERE saldo>0;
CREATE INDEX ix_abono_cuenta ON abono_credito(id_cuenta,fecha_abono DESC);
CREATE INDEX ix_abono_caja ON abono_credito(id_caja);
CREATE INDEX ix_devolucion_venta ON devolucion(id_venta);
CREATE INDEX ix_devolucion_solicita ON devolucion(id_solicita);
CREATE INDEX ix_devolucion_autoriza ON devolucion(id_autoriza);
CREATE INDEX ix_devolucion_caja ON devolucion(id_caja);
CREATE INDEX ix_det_dev_venta ON detalle_devolucion(id_detalle_venta);
CREATE INDEX ix_det_dev_producto ON detalle_devolucion(id_producto,id_presentacion);
CREATE INDEX ix_despacho_prepara ON despacho(id_prepara);
CREATE INDEX ix_despacho_entrega ON despacho(id_entrega);

-- Los cambios monetarios necesitan movimientos de caja/credito atomicos: no habilitarlos parcialmente.
CREATE FUNCTION huaman.bloquear_credito_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Cuentas y abonos se registraran mediante procesos transaccionales de venta/caja; no editar saldos manualmente'; END $$;
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON cuenta_por_cobrar FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_credito_pendiente();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON abono_credito FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_credito_pendiente();

CREATE FUNCTION huaman.validar_solicitud_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta FOR UPDATE;
IF NOT FOUND OR v.estado_venta<>'CONFIRMADA' THEN RAISE EXCEPTION 'Devolucion requiere venta confirmada'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_solicita AND estado='A') THEN RAISE EXCEPTION 'Solicitante inexistente o inactivo'; END IF;
IF NEW.fecha_solicitud<v.fecha_venta THEN RAISE EXCEPTION 'Solicitud anterior a la venta'; END IF;
IF NEW.estado_devolucion<>'PENDIENTE' THEN RAISE EXCEPTION 'Decision y reintegro pendientes del proceso de devolucion'; END IF;
IF NEW.id_caja IS NOT NULL OR NEW.referencia_reintegro IS NOT NULL THEN RAISE EXCEPTION 'Solicitud pendiente no registra caja ni reintegro ejecutado'; END IF;
IF NEW.forma_reintegro='DESCUENTO_DEUDA' AND NOT EXISTS(SELECT 1 FROM huaman.cuenta_por_cobrar WHERE id_venta=v.id_venta AND saldo>0 AND estado='A') THEN RAISE EXCEPTION 'La venta no tiene deuda pendiente'; END IF;
IF NEW.forma_reintegro='DEBITO' AND NOT EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=v.id_venta AND medio='DEBITO' AND estado='A') THEN RAISE EXCEPTION 'No existe pago de debito en la venta'; END IF;
IF TG_OP='INSERT' AND NEW.monto_reintegro<>0 THEN RAISE EXCEPTION 'El reintegro se obtiene de los detalles'; END IF;
IF TG_OP='UPDATE' THEN
IF (NEW.id_venta,NEW.id_solicita,NEW.fecha_solicitud) IS DISTINCT FROM (OLD.id_venta,OLD.id_solicita,OLD.fecha_solicitud) THEN RAISE EXCEPTION 'Identidad de solicitud inmutable'; END IF;
IF NEW.monto_reintegro<>OLD.monto_reintegro AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No modificar reintegro manualmente'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_solicitud BEFORE INSERT OR UPDATE ON devolucion FOR EACH ROW EXECUTE FUNCTION huaman.validar_solicitud_devolucion();

CREATE FUNCTION huaman.validar_detalle_devolucion() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE dev huaman.devolucion%ROWTYPE;det huaman.detalle_venta%ROWTYPE;aprobado numeric;importe_aprobado numeric;incremento numeric;
BEGIN
SELECT * INTO dev FROM huaman.devolucion WHERE id_devolucion=NEW.id_devolucion FOR UPDATE;
IF NOT FOUND OR dev.estado_devolucion<>'PENDIENTE' OR dev.estado<>'A' THEN RAISE EXCEPTION 'Solicitud no editable'; END IF;
SELECT * INTO det FROM huaman.detalle_venta WHERE id_detalle_venta=NEW.id_detalle_venta FOR UPDATE;
IF NOT FOUND OR det.id_venta<>dev.id_venta OR det.estado<>'A' THEN RAISE EXCEPTION 'Linea no pertenece a la venta'; END IF;
IF TG_OP='UPDATE' AND (NEW.id_devolucion,NEW.id_detalle_venta) IS DISTINCT FROM (OLD.id_devolucion,OLD.id_detalle_venta) THEN RAISE EXCEPTION 'No reasignar linea de devolucion'; END IF;
-- Las cantidades comerciales usan el factor de la venta, no el catalogo actual.
IF NEW.cantidad<=0 OR NEW.cantidad>det.cantidad THEN RAISE EXCEPTION 'Cantidad devuelta fuera de la venta original'; END IF;
SELECT incremento_base INTO incremento FROM huaman.producto WHERE id_producto=det.id_producto;
IF mod(NEW.cantidad*det.factor_base,incremento)<>0 THEN RAISE EXCEPTION 'Cantidad base no respeta precision fisica del producto'; END IF;
SELECT coalesce(sum(dd.cantidad),0),coalesce(sum(dd.importe),0) INTO aprobado,importe_aprobado FROM huaman.detalle_devolucion dd JOIN huaman.devolucion d ON d.id_devolucion=dd.id_devolucion
WHERE dd.id_detalle_venta=det.id_detalle_venta AND d.estado_devolucion='APROBADA' AND d.estado='A' AND dd.estado='A';
IF aprobado+NEW.cantidad>det.cantidad THEN RAISE EXCEPTION 'Devolucion acumulada supera cantidad vendida'; END IF;
NEW.id_producto:=det.id_producto;NEW.id_presentacion:=det.id_presentacion;NEW.presentacion_nombre:=det.presentacion_nombre;NEW.unidad_base_simbolo:=det.unidad_base_simbolo;
NEW.factor_base:=det.factor_base;NEW.costo_unitario_base:=det.costo_unitario_base;
NEW.importe:=round(det.importe*(aprobado+NEW.cantidad)/det.cantidad,2)-importe_aprobado;
IF NEW.importe<=0 THEN RAISE EXCEPTION 'Importe de devolucion redondea a cero'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_detalle BEFORE INSERT OR UPDATE ON detalle_devolucion FOR EACH ROW EXECUTE FUNCTION huaman.validar_detalle_devolucion();
CREATE FUNCTION huaman.recalcular_reintegro() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
UPDATE huaman.devolucion SET monto_reintegro=(SELECT coalesce(sum(importe),0) FROM huaman.detalle_devolucion WHERE id_devolucion=NEW.id_devolucion AND estado='A') WHERE id_devolucion=NEW.id_devolucion;
RETURN NULL;
END $$;
CREATE TRIGGER total_reintegro AFTER INSERT OR UPDATE ON detalle_devolucion FOR EACH ROW EXECUTE FUNCTION huaman.recalcular_reintegro();

CREATE FUNCTION huaman.validar_despacho_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v huaman.venta%ROWTYPE;
BEGIN
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta;
IF NOT FOUND OR v.estado_venta<>'CONFIRMADA' OR v.entrega_inmediata THEN RAISE EXCEPTION 'Despacho requiere venta confirmada con entrega pendiente'; END IF;
IF NEW.estado_despacho<>'PENDIENTE' THEN RAISE EXCEPTION 'Preparacion/entrega pendientes del proceso de despacho'; END IF;
IF NEW.id_prepara IS NOT NULL OR NEW.fecha_preparacion IS NOT NULL OR NEW.id_entrega IS NOT NULL OR NEW.fecha_entrega IS NOT NULL OR NEW.recibe_nombre IS NOT NULL THEN RAISE EXCEPTION 'Despacho pendiente no tiene datos de entrega ejecutada'; END IF;
IF TG_OP='UPDATE' AND NEW.id_venta<>OLD.id_venta THEN RAISE EXCEPTION 'No reasignar despacho a otra venta'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_despacho BEFORE INSERT OR UPDATE ON despacho FOR EACH ROW EXECUTE FUNCTION huaman.validar_despacho_pendiente();

ALTER TABLE huaman.cuenta_por_cobrar ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.cuenta_por_cobrar FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.cuenta_por_cobrar FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.cuenta_por_cobrar FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.cuenta_por_cobrar FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.abono_credito ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.abono_credito FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.abono_credito FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.abono_credito FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.abono_credito FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.devolucion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.devolucion FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.devolucion FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.devolucion FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.devolucion FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.detalle_devolucion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_devolucion FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_devolucion FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_devolucion FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_devolucion FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.despacho ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.despacho FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.despacho FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.despacho FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.despacho FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'cuenta_por_cobrar' AS tabla,count(*) AS registros FROM huaman.cuenta_por_cobrar
UNION ALL SELECT 'abono_credito',count(*) FROM huaman.abono_credito
UNION ALL SELECT 'devolucion',count(*) FROM huaman.devolucion
UNION ALL SELECT 'detalle_devolucion',count(*) FROM huaman.detalle_devolucion
UNION ALL SELECT 'despacho',count(*) FROM huaman.despacho
ORDER BY tabla;

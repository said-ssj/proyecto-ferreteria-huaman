-- FERRETERIA HUAMAN - BLOQUE 08 - inventario, movimientos y control fisico
-- Despues de 01 a 07. Ejecutar completo una sola vez.
-- Completa 46 tablas. NO habilita todavia los procesos transaccionales.
-- Las escrituras operativas quedan bloqueadas hasta instalar y probar dichos procesos.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regclass('huaman.despacho') IS NULL THEN RAISE EXCEPTION 'Instalar primero bloques 01 a 07'; END IF;
IF to_regclass('huaman.ajuste_inventario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: ajuste_inventario existe'; END IF;
IF to_regclass('huaman.toma_inventario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: toma_inventario existe'; END IF;
IF to_regclass('huaman.detalle_toma_inventario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: detalle_toma_inventario existe'; END IF;
IF to_regclass('huaman.alerta_stock') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: alerta_stock existe'; END IF;
IF to_regclass('huaman.transformacion_stock') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: transformacion_stock existe'; END IF;
IF to_regclass('huaman.unidad_existencia') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: unidad_existencia existe'; END IF;
IF to_regclass('huaman.detalle_transformacion_stock') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: detalle_transformacion_stock existe'; END IF;
IF to_regclass('huaman.movimiento_inventario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: movimiento_inventario existe'; END IF;
IF to_regclass('huaman.movimiento_caja') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: movimiento_caja existe'; END IF;
IF to_regclass('huaman.historial_costo') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: historial_costo existe'; END IF;
IF to_regclass('huaman.asignacion_existencia_venta') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 08 ya instalado o parcial: asignacion_existencia_venta existe'; END IF;
END $$;

CREATE TABLE ajuste_inventario (
  id_ajuste bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  estado_ajuste varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_ajuste IN ('BORRADOR','CONFIRMADO','ANULADO')),
  costo_unitario_base numeric(18,6) NOT NULL CHECK (costo_unitario_base>=0),
  tipo_ajuste varchar(12) NOT NULL CHECK (tipo_ajuste IN ('AUMENTO', 'DISMINUCION')),
  cantidad numeric(18,6) NOT NULL CHECK (cantidad > 0),
  id_motivo_ajuste bigint NOT NULL REFERENCES motivo_ajuste(id_motivo_ajuste) ON DELETE RESTRICT,
  observacion varchar(300) NOT NULL,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (length(trim(observacion)) BETWEEN 5 AND 300)
);

CREATE TABLE toma_inventario (
  id_toma bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  numero bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  alcance varchar(9) NOT NULL CHECK (alcance IN ('TODO', 'CATEGORIA')),
  id_categoria bigint REFERENCES categoria(id_categoria) ON DELETE RESTRICT,
  id_responsable bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  fecha_inicio timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  estado_toma varchar(9) NOT NULL DEFAULT 'EN_CONTEO' CHECK (estado_toma IN ('EN_CONTEO', 'CERRADA', 'APROBADA', 'ANULADA')),
  id_aprueba bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  fecha_aprobacion timestamp,
  observacion varchar(300),
  motivo_anulacion varchar(200),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((alcance = 'CATEGORIA' AND id_categoria IS NOT NULL) OR (alcance = 'TODO' AND id_categoria IS NULL)),
  CHECK (estado_toma<>'ANULADA' OR length(btrim(coalesce(motivo_anulacion,'')))>=10),
  CHECK (estado_toma <> 'APROBADA' OR (id_aprueba IS NOT NULL AND fecha_aprobacion IS NOT NULL))
);

CREATE TABLE detalle_toma_inventario (
  id_detalle_toma bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_toma bigint NOT NULL REFERENCES toma_inventario(id_toma) ON DELETE RESTRICT,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  stock_sistema numeric(18,6) NOT NULL CHECK (stock_sistema >= 0),
  cantidad_contada numeric(18,6) CHECK (cantidad_contada >= 0),
  diferencia numeric(18,6) GENERATED ALWAYS AS (cantidad_contada - stock_sistema) STORED,
  costo_referencia numeric(18,6) NOT NULL CHECK (costo_referencia >= 0),
  estado_linea varchar(9) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_linea IN ('PENDIENTE', 'CONTADA')),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  UNIQUE (id_toma, id_producto),
  CHECK ((estado_linea = 'CONTADA' AND cantidad_contada IS NOT NULL) OR (estado_linea = 'PENDIENTE' AND cantidad_contada IS NULL))
);

CREATE TABLE alerta_stock (
  id_alerta bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
  stock_al_generar numeric(18,6) NOT NULL CHECK (stock_al_generar >= 0),
  stock_minimo_al_generar numeric(18,6) NOT NULL CHECK (stock_minimo_al_generar >= 0),
  estado_alerta varchar(7) NOT NULL DEFAULT 'ABIERTA' CHECK (estado_alerta IN ('ABIERTA', 'CERRADA')),
  fecha_cierre timestamp,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((estado_alerta = 'CERRADA' AND fecha_cierre IS NOT NULL) OR (estado_alerta = 'ABIERTA' AND fecha_cierre IS NULL))
);

CREATE INDEX ix_ajuste_producto ON ajuste_inventario(id_producto,feccre DESC);
CREATE INDEX ix_ajuste_motivo ON ajuste_inventario(id_motivo_ajuste);
CREATE UNIQUE INDEX ux_toma_abierta ON toma_inventario((1)) WHERE estado_toma IN ('EN_CONTEO','CERRADA') AND estado='A';
CREATE INDEX ix_toma_categoria ON toma_inventario(id_categoria);
CREATE INDEX ix_toma_responsable ON toma_inventario(id_responsable);
CREATE INDEX ix_toma_aprueba ON toma_inventario(id_aprueba);
CREATE INDEX ix_det_toma_producto ON detalle_toma_inventario(id_producto);
CREATE UNIQUE INDEX ux_alerta_abierta_producto ON alerta_stock(id_producto) WHERE estado_alerta='ABIERTA' AND estado='A';
ALTER TABLE detalle_ingreso ADD CONSTRAINT uq_det_ingreso_producto UNIQUE(id_detalle_ingreso,id_producto);
ALTER TABLE detalle_venta ADD CONSTRAINT uq_det_venta_producto UNIQUE(id_detalle_venta,id_producto);
CREATE TABLE transformacion_stock (
id_transformacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
tipo_transformacion varchar(16) NOT NULL CHECK (tipo_transformacion IN ('APERTURA_ENVASE','CORTE')),
fecha timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
id_responsable bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
motivo varchar(200) NOT NULL CHECK (length(btrim(motivo)) BETWEEN 5 AND 200),
estado_transformacion varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_transformacion IN ('BORRADOR','CONFIRMADA','ANULADA')),
clave_idempotencia uuid NOT NULL UNIQUE,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
UNIQUE(id_transformacion,id_producto)
);
CREATE INDEX ix_transformacion_producto ON transformacion_stock(id_producto,fecha DESC);
CREATE INDEX ix_transformacion_responsable ON transformacion_stock(id_responsable);
CREATE TABLE unidad_existencia (
id_unidad_existencia bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
id_presentacion bigint,
identificador varchar(60) NOT NULL UNIQUE CHECK (btrim(identificador)<>''),
condicion_fisica varchar(6) NOT NULL CHECK (condicion_fisica IN ('ENVASE','SUELTO','TRAMO')),
cantidad_inicial_base numeric(18,6) NOT NULL CHECK (cantidad_inicial_base>0),
cantidad_disponible_base numeric(18,6) NOT NULL CHECK (cantidad_disponible_base>=0),
id_detalle_ingreso bigint REFERENCES detalle_ingreso(id_detalle_ingreso) ON DELETE RESTRICT,
id_transformacion_origen bigint,
id_unidad_origen bigint,
referencia_apertura varchar(100),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY(id_producto,id_presentacion) REFERENCES presentacion_producto(id_producto,id_presentacion) ON DELETE RESTRICT,
FOREIGN KEY(id_detalle_ingreso,id_producto) REFERENCES detalle_ingreso(id_detalle_ingreso,id_producto) ON DELETE RESTRICT,
FOREIGN KEY(id_transformacion_origen,id_producto) REFERENCES transformacion_stock(id_transformacion,id_producto) ON DELETE RESTRICT,
UNIQUE(id_unidad_existencia,id_producto),
FOREIGN KEY(id_unidad_origen,id_producto) REFERENCES unidad_existencia(id_unidad_existencia,id_producto) ON DELETE RESTRICT,
CHECK (id_unidad_origen IS NULL OR id_unidad_origen<>id_unidad_existencia),
CHECK (cantidad_disponible_base<=cantidad_inicial_base),
CHECK (referencia_apertura IS NULL OR btrim(referencia_apertura)<>''),
CHECK (condicion_fisica<>'ENVASE' OR (id_presentacion IS NOT NULL AND cantidad_disponible_base IN (0,cantidad_inicial_base))),
CHECK (num_nonnulls(id_detalle_ingreso,id_transformacion_origen,referencia_apertura)=1)
);
CREATE INDEX ix_unidad_producto ON unidad_existencia(id_producto,condicion_fisica) WHERE cantidad_disponible_base>0 AND estado='A';
CREATE INDEX ix_unidad_presentacion ON unidad_existencia(id_producto,id_presentacion);
CREATE INDEX ix_unidad_ingreso ON unidad_existencia(id_detalle_ingreso);
CREATE INDEX ix_unidad_transformacion ON unidad_existencia(id_transformacion_origen,id_producto);
CREATE INDEX ix_unidad_origen ON unidad_existencia(id_unidad_origen,id_producto);
CREATE TABLE detalle_transformacion_stock (
id_detalle_transformacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_transformacion bigint NOT NULL,
id_producto bigint NOT NULL,
id_unidad_existencia bigint NOT NULL,
sentido char(1) NOT NULL CHECK (sentido IN ('E','S')),
cantidad_base numeric(18,6) NOT NULL CHECK (cantidad_base>0),
costo_unitario_base numeric(18,6) NOT NULL CHECK (costo_unitario_base>=0),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY(id_transformacion,id_producto) REFERENCES transformacion_stock(id_transformacion,id_producto) ON DELETE RESTRICT,
FOREIGN KEY(id_unidad_existencia,id_producto) REFERENCES unidad_existencia(id_unidad_existencia,id_producto) ON DELETE RESTRICT,
UNIQUE(id_transformacion,id_unidad_existencia,sentido)
);
CREATE INDEX ix_det_transformacion_unidad ON detalle_transformacion_stock(id_unidad_existencia,id_producto);
CREATE TABLE movimiento_inventario (
id_movimiento bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
tipo_movimiento varchar(20) NOT NULL CHECK (tipo_movimiento IN ('SALDO_INICIAL','INGRESO_COMPRA','SALIDA_VENTA','DEVOLUCION_VENTA','ANULACION_VENTA','AJUSTE_AUMENTO','AJUSTE_DISMINUCION','AJUSTE_TOMA','TRANSFORMACION')),
sentido char(1) NOT NULL CHECK (sentido IN ('E','S')),
cantidad numeric(18,6) NOT NULL CHECK (cantidad>0),
saldo_anterior numeric(18,6) NOT NULL CHECK (saldo_anterior>=0),
saldo numeric(18,6) NOT NULL CHECK (saldo>=0),
costo_unitario_base numeric(18,6) NOT NULL CHECK (costo_unitario_base>=0),
id_venta bigint REFERENCES venta(id_venta) ON DELETE RESTRICT,
id_ingreso bigint REFERENCES ingreso_mercaderia(id_ingreso) ON DELETE RESTRICT,
id_devolucion bigint REFERENCES devolucion(id_devolucion) ON DELETE RESTRICT,
id_ajuste bigint REFERENCES ajuste_inventario(id_ajuste) ON DELETE RESTRICT,
id_toma bigint REFERENCES toma_inventario(id_toma) ON DELETE RESTRICT,
id_transformacion bigint,
clave_idempotencia uuid NOT NULL UNIQUE,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY(id_transformacion,id_producto) REFERENCES transformacion_stock(id_transformacion,id_producto) ON DELETE RESTRICT,
CHECK (saldo=saldo_anterior+CASE WHEN sentido='E' THEN cantidad ELSE -cantidad END),
UNIQUE(id_movimiento,id_producto),
CHECK ((tipo_movimiento='SALDO_INICIAL' AND sentido='E' AND saldo_anterior=0 AND num_nonnulls(id_venta,id_ingreso,id_devolucion,id_ajuste,id_toma,id_transformacion)=0) OR
 (num_nonnulls(id_venta,id_ingreso,id_devolucion,id_ajuste,id_toma,id_transformacion)=1 AND (
 (tipo_movimiento='INGRESO_COMPRA' AND sentido='E' AND id_ingreso IS NOT NULL) OR
 (tipo_movimiento='SALIDA_VENTA' AND sentido='S' AND id_venta IS NOT NULL) OR
 (tipo_movimiento='ANULACION_VENTA' AND sentido='E' AND id_venta IS NOT NULL) OR
 (tipo_movimiento='DEVOLUCION_VENTA' AND sentido='E' AND id_devolucion IS NOT NULL) OR
 (tipo_movimiento='AJUSTE_AUMENTO' AND sentido='E' AND id_ajuste IS NOT NULL) OR
 (tipo_movimiento='AJUSTE_DISMINUCION' AND sentido='S' AND id_ajuste IS NOT NULL) OR
 (tipo_movimiento='AJUSTE_TOMA' AND id_toma IS NOT NULL) OR
 (tipo_movimiento='TRANSFORMACION' AND id_transformacion IS NOT NULL))))
);
CREATE INDEX ix_mov_inv_producto_fecha ON movimiento_inventario(id_producto,feccre DESC);
CREATE UNIQUE INDEX ux_mov_saldo_inicial_producto ON movimiento_inventario(id_producto) WHERE tipo_movimiento='SALDO_INICIAL';
CREATE INDEX ix_mov_inv_venta ON movimiento_inventario(id_venta);
CREATE INDEX ix_mov_inv_ingreso ON movimiento_inventario(id_ingreso);
CREATE INDEX ix_mov_inv_devolucion ON movimiento_inventario(id_devolucion);
CREATE INDEX ix_mov_inv_ajuste ON movimiento_inventario(id_ajuste);
CREATE INDEX ix_mov_inv_toma ON movimiento_inventario(id_toma);
CREATE INDEX ix_mov_inv_transformacion ON movimiento_inventario(id_transformacion,id_producto);
CREATE TABLE movimiento_caja (
  id_movimiento_caja bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_caja bigint NOT NULL REFERENCES caja_diaria(id_caja) ON DELETE RESTRICT,
  tipo_movimiento varchar(16) NOT NULL CHECK (tipo_movimiento IN ('APERTURA', 'VENTA', 'ABONO', 'DEVOLUCION', 'ANULACION', 'INGRESO_MANUAL', 'EGRESO_MANUAL')),
  medio varchar(8) NOT NULL CHECK (medio IN ('EFECTIVO', 'YAPE', 'DEBITO')),
  sentido char(1) NOT NULL CHECK (sentido IN ('I', 'E')),
  importe numeric(18,2) NOT NULL CHECK (importe > 0),
  id_venta bigint REFERENCES venta(id_venta) ON DELETE RESTRICT,
  id_abono bigint REFERENCES abono_credito(id_abono) ON DELETE RESTRICT,
  id_devolucion bigint REFERENCES devolucion(id_devolucion) ON DELETE RESTRICT,
  motivo varchar(200),
  clave_idempotencia uuid NOT NULL UNIQUE,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((tipo_movimiento IN ('VENTA','ANULACION') AND id_venta IS NOT NULL AND num_nonnulls(id_venta,id_abono,id_devolucion) = 1) OR (tipo_movimiento = 'ABONO' AND id_abono IS NOT NULL AND num_nonnulls(id_venta,id_abono,id_devolucion) = 1) OR (tipo_movimiento = 'DEVOLUCION' AND id_devolucion IS NOT NULL AND num_nonnulls(id_venta,id_abono,id_devolucion) = 1) OR (tipo_movimiento IN ('APERTURA','INGRESO_MANUAL','EGRESO_MANUAL') AND num_nonnulls(id_venta,id_abono,id_devolucion) = 0)),
  CHECK (tipo_movimiento NOT IN ('INGRESO_MANUAL','EGRESO_MANUAL') OR (motivo IS NOT NULL AND length(trim(motivo)) BETWEEN 10 AND 200)),
  CHECK ((tipo_movimiento IN ('APERTURA','VENTA','ABONO','INGRESO_MANUAL') AND sentido = 'I') OR (tipo_movimiento IN ('DEVOLUCION','ANULACION','EGRESO_MANUAL') AND sentido = 'E')),
  CHECK (tipo_movimiento <> 'APERTURA' OR medio = 'EFECTIVO')
);
CREATE INDEX ix_mov_caja_caja_fecha ON movimiento_caja(id_caja,feccre DESC);
CREATE UNIQUE INDEX ux_mov_apertura_caja ON movimiento_caja(id_caja) WHERE tipo_movimiento='APERTURA';
CREATE INDEX ix_mov_caja_venta ON movimiento_caja(id_venta);
CREATE INDEX ix_mov_caja_abono ON movimiento_caja(id_abono);
CREATE INDEX ix_mov_caja_devolucion ON movimiento_caja(id_devolucion);
CREATE TABLE historial_costo (
id_historial_costo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
id_detalle_ingreso bigint REFERENCES detalle_ingreso(id_detalle_ingreso) ON DELETE RESTRICT,
id_movimiento bigint REFERENCES movimiento_inventario(id_movimiento) ON DELETE RESTRICT,
motivo varchar(200) NOT NULL CHECK (length(btrim(motivo)) BETWEEN 5 AND 200),
referencia varchar(100) NOT NULL CHECK (btrim(referencia)<>''),
stock_anterior numeric(18,6) NOT NULL CHECK (stock_anterior>=0),
stock_nuevo numeric(18,6) NOT NULL CHECK (stock_nuevo>=0),
costo_promedio_anterior numeric(18,6) NOT NULL CHECK (costo_promedio_anterior>=0),
costo_promedio_nuevo numeric(18,6) NOT NULL CHECK (costo_promedio_nuevo>=0),
ultimo_costo_anterior numeric(18,6) NOT NULL CHECK (ultimo_costo_anterior>=0),
ultimo_costo_nuevo numeric(18,6) NOT NULL CHECK (ultimo_costo_nuevo>=0),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
,
FOREIGN KEY(id_detalle_ingreso,id_producto) REFERENCES detalle_ingreso(id_detalle_ingreso,id_producto) ON DELETE RESTRICT,
FOREIGN KEY(id_movimiento,id_producto) REFERENCES movimiento_inventario(id_movimiento,id_producto) ON DELETE RESTRICT
);
CREATE INDEX ix_historial_costo_producto_fecha ON historial_costo(id_producto,feccre DESC);
CREATE INDEX ix_historial_costo_ingreso ON historial_costo(id_detalle_ingreso);
CREATE INDEX ix_historial_costo_movimiento ON historial_costo(id_movimiento);
CREATE TABLE asignacion_existencia_venta (
id_asignacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_detalle_venta bigint NOT NULL REFERENCES detalle_venta(id_detalle_venta) ON DELETE RESTRICT,
id_producto bigint NOT NULL,
id_unidad_existencia bigint NOT NULL,
numero_pieza integer NOT NULL CHECK (numero_pieza>0),
cantidad_base numeric(18,6) NOT NULL CHECK (cantidad_base>0),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
FOREIGN KEY(id_unidad_existencia,id_producto) REFERENCES unidad_existencia(id_unidad_existencia,id_producto) ON DELETE RESTRICT,
FOREIGN KEY(id_detalle_venta,id_producto) REFERENCES detalle_venta(id_detalle_venta,id_producto) ON DELETE RESTRICT,
UNIQUE(id_detalle_venta,numero_pieza)
);
CREATE INDEX ix_asignacion_unidad ON asignacion_existencia_venta(id_unidad_existencia,id_producto);

-- Las tablas de movimientos son append-only, incluso para el administrador.
CREATE TRIGGER inmutable BEFORE UPDATE ON movimiento_inventario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER inmutable BEFORE UPDATE ON movimiento_caja FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER inmutable BEFORE UPDATE ON historial_costo FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();

CREATE FUNCTION huaman.bloquear_inventario_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Inventario pendiente de procesos transaccionales: no insertar movimientos ni modificar saldos manualmente'; END $$;

ALTER TABLE huaman.ajuste_inventario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.ajuste_inventario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.ajuste_inventario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.ajuste_inventario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.ajuste_inventario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.ajuste_inventario FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.toma_inventario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.toma_inventario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.toma_inventario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.detalle_toma_inventario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_toma_inventario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_toma_inventario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.detalle_toma_inventario FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.alerta_stock ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.alerta_stock FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.alerta_stock FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.alerta_stock FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.alerta_stock FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.alerta_stock FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.transformacion_stock ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.transformacion_stock FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.transformacion_stock FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.unidad_existencia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.unidad_existencia FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.unidad_existencia FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.unidad_existencia FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.unidad_existencia FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.unidad_existencia FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.detalle_transformacion_stock ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_transformacion_stock FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_transformacion_stock FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.detalle_transformacion_stock FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.movimiento_inventario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.movimiento_inventario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.movimiento_inventario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.movimiento_inventario FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.movimiento_caja ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.movimiento_caja FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.movimiento_caja FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.movimiento_caja FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.movimiento_caja FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.movimiento_caja FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.historial_costo ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.historial_costo FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.historial_costo FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.historial_costo FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.historial_costo FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.historial_costo FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

ALTER TABLE huaman.asignacion_existencia_venta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.asignacion_existencia_venta FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.asignacion_existencia_venta FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.asignacion_existencia_venta FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.asignacion_existencia_venta FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER proceso_pendiente BEFORE INSERT OR UPDATE ON huaman.asignacion_existencia_venta FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_inventario_pendiente();

-- Cerrar tambien la edicion directa de los saldos que existian en producto desde bloque 02.
CREATE FUNCTION huaman.proteger_saldos_pendientes() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
IF (NEW.stock_actual,NEW.ultimo_costo_compra,NEW.costo_promedio) IS DISTINCT FROM (OLD.stock_actual,OLD.ultimo_costo_compra,OLD.costo_promedio) THEN
RAISE EXCEPTION 'Saldo y costos solo cambian mediante procesos transaccionales; aun pendientes';
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER proteger_saldos BEFORE UPDATE ON producto FOR EACH ROW EXECUTE FUNCTION huaman.proteger_saldos_pendientes();
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'ajuste_inventario' AS tabla,count(*) AS registros FROM huaman.ajuste_inventario
UNION ALL SELECT 'toma_inventario' AS tabla,count(*) AS registros FROM huaman.toma_inventario
UNION ALL SELECT 'detalle_toma_inventario' AS tabla,count(*) AS registros FROM huaman.detalle_toma_inventario
UNION ALL SELECT 'alerta_stock' AS tabla,count(*) AS registros FROM huaman.alerta_stock
UNION ALL SELECT 'transformacion_stock' AS tabla,count(*) AS registros FROM huaman.transformacion_stock
UNION ALL SELECT 'unidad_existencia' AS tabla,count(*) AS registros FROM huaman.unidad_existencia
UNION ALL SELECT 'detalle_transformacion_stock' AS tabla,count(*) AS registros FROM huaman.detalle_transformacion_stock
UNION ALL SELECT 'movimiento_inventario' AS tabla,count(*) AS registros FROM huaman.movimiento_inventario
UNION ALL SELECT 'movimiento_caja' AS tabla,count(*) AS registros FROM huaman.movimiento_caja
UNION ALL SELECT 'historial_costo' AS tabla,count(*) AS registros FROM huaman.historial_costo
UNION ALL SELECT 'asignacion_existencia_venta' AS tabla,count(*) AS registros FROM huaman.asignacion_existencia_venta
ORDER BY tabla;

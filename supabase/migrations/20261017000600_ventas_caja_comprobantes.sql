-- FERRETERIA HUAMAN - BLOQUE 06 - estructura de ventas, caja y comprobantes
-- Despues de 01 a 05. Ejecutar TODO una sola vez.
-- Sin ventas, pagos, usuarios ni archivos ficticios. NO habilita confirmacion/emision.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
DO $$ BEGIN
IF to_regclass('huaman.detalle_cotizacion') IS NULL THEN RAISE EXCEPTION 'Instalar primero bloques 01 a 05'; END IF;
IF to_regclass('huaman.caja_diaria') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: caja_diaria existe'; END IF;
IF to_regclass('huaman.venta') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: venta existe'; END IF;
IF to_regclass('huaman.detalle_venta') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: detalle_venta existe'; END IF;
IF to_regclass('huaman.pago') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: pago existe'; END IF;
IF to_regclass('huaman.comprobante_venta') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: comprobante_venta existe'; END IF;
IF to_regclass('huaman.archivo_comprobante') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 06 ya instalado o parcial: archivo_comprobante existe'; END IF;
END $$;
CREATE TABLE caja_diaria (
  id_caja bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha date NOT NULL UNIQUE DEFAULT timezone('America/Lima', now())::date,
  monto_inicial numeric(12,2) NOT NULL CHECK (monto_inicial >= 0),
  id_usuario_apertura bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  obs_apertura varchar(300),
  estado_caja varchar(8) NOT NULL DEFAULT 'ABIERTA' CHECK (estado_caja IN ('ABIERTA', 'CERRADA')),
  fecha_cierre timestamp,
  id_usuario_cierre bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  efectivo_esperado numeric(12,2),
  efectivo_contado numeric(12,2) CHECK (efectivo_contado >= 0),
  diferencia_efectivo numeric(12,2) GENERATED ALWAYS AS (efectivo_contado - efectivo_esperado) STORED,
  yape_esperado numeric(12,2),
  yape_reportado numeric(12,2) CHECK (yape_reportado >= 0),
  diferencia_yape numeric(12,2) GENERATED ALWAYS AS (yape_reportado - yape_esperado) STORED,
  debito_esperado numeric(18,2),
  debito_reportado numeric(18,2) CHECK (debito_reportado>=0),
  diferencia_debito numeric(18,2) GENERATED ALWAYS AS (debito_reportado-debito_esperado) STORED,
  obs_cierre varchar(300),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (estado_caja <> 'CERRADA' OR (fecha_cierre IS NOT NULL AND id_usuario_cierre IS NOT NULL AND efectivo_esperado IS NOT NULL AND efectivo_contado IS NOT NULL AND yape_esperado IS NOT NULL AND yape_reportado IS NOT NULL AND debito_esperado IS NOT NULL AND debito_reportado IS NOT NULL)),
  CHECK (estado_caja <> 'CERRADA' OR ((diferencia_efectivo = 0 AND diferencia_yape = 0 AND diferencia_debito = 0) OR (obs_cierre IS NOT NULL AND length(trim(obs_cierre)) BETWEEN 10 AND 200)))
);
CREATE UNIQUE INDEX ux_una_caja_abierta ON caja_diaria((1)) WHERE estado_caja='ABIERTA';
CREATE INDEX ix_caja_usuario_apertura ON caja_diaria(id_usuario_apertura);
CREATE INDEX ix_caja_usuario_cierre ON caja_diaria(id_usuario_cierre);
CREATE TABLE venta (
id_venta bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_caja bigint NOT NULL REFERENCES caja_diaria(id_caja) ON DELETE RESTRICT,
id_cliente bigint REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
id_vendedor bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
id_cotizacion bigint UNIQUE REFERENCES cotizacion(id_cotizacion) ON DELETE RESTRICT,
id_venta_origen bigint REFERENCES venta(id_venta) ON DELETE RESTRICT,
tipo_comprobante char(1) NOT NULL DEFAULT 'B' CHECK (tipo_comprobante IN ('B','F','N')),
fecha_venta timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
moneda char(3) NOT NULL DEFAULT 'PEN' CHECK (moneda='PEN'),
cliente_tipo_doc char(3) CHECK (cliente_tipo_doc IN ('DNI','RUC')),
cliente_nro_doc varchar(11),cliente_nombre varchar(150) NOT NULL DEFAULT 'CLIENTE VARIOS',cliente_direccion varchar(200),
subtotal numeric(18,2) NOT NULL DEFAULT 0 CHECK (subtotal>=0),
descuento_total numeric(18,2) NOT NULL DEFAULT 0 CHECK (descuento_total>=0),
total numeric(18,2) NOT NULL DEFAULT 0 CHECK (total>=0),
igv_porcentaje numeric(5,2) NOT NULL DEFAULT 18 CHECK (igv_porcentaje BETWEEN 0 AND 100),
base_imponible numeric(18,2) GENERATED ALWAYS AS (round(total/(1+igv_porcentaje/100),2)) STORED,
igv numeric(18,2) GENERATED ALWAYS AS (total-round(total/(1+igv_porcentaje/100),2)) STORED,
entrega_inmediata boolean NOT NULL DEFAULT false,
id_autoriza_descuento bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
clave_idempotencia uuid NOT NULL UNIQUE,
estado_venta varchar(10) NOT NULL DEFAULT 'BORRADOR' CHECK (estado_venta IN ('BORRADOR','CONFIRMADA','ANULADA')),
motivo_anulacion varchar(200),fecha_anulacion timestamp,
id_usuario_anula bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
CHECK (total=subtotal-descuento_total),
CHECK (id_venta_origen IS NULL OR id_venta_origen<>id_venta),
CHECK (tipo_comprobante<>'F' OR (id_cliente IS NOT NULL AND cliente_tipo_doc='RUC' AND cliente_nro_doc ~ '^[0-9]{11}$' AND length(btrim(cliente_nombre))>=3 AND length(btrim(cliente_direccion))>=5)),
CHECK (estado_venta<>'ANULADA' OR (length(btrim(coalesce(motivo_anulacion,''))) BETWEEN 10 AND 200 AND fecha_anulacion IS NOT NULL AND id_usuario_anula IS NOT NULL))
);
CREATE INDEX ix_venta_cliente ON venta(id_cliente);
CREATE INDEX ix_venta_vendedor_fecha ON venta(id_vendedor,fecha_venta DESC);
CREATE INDEX ix_venta_caja ON venta(id_caja);
CREATE INDEX ix_venta_origen ON venta(id_venta_origen);
CREATE INDEX ix_venta_fecha_estado ON venta(fecha_venta DESC,estado_venta);
CREATE INDEX ix_venta_autoriza ON venta(id_autoriza_descuento);
CREATE INDEX ix_venta_anula ON venta(id_usuario_anula);
CREATE TABLE detalle_venta (
id_detalle_venta bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_venta bigint NOT NULL REFERENCES venta(id_venta) ON DELETE RESTRICT,
id_producto bigint NOT NULL REFERENCES producto(id_producto) ON DELETE RESTRICT,
id_presentacion bigint NOT NULL,
producto_nombre varchar(120) NOT NULL,presentacion_nombre varchar(60) NOT NULL,unidad_base_simbolo varchar(8) NOT NULL,
cantidad numeric(18,6) NOT NULL CHECK (cantidad>0),
factor_base numeric(18,6) NOT NULL CHECK (factor_base>0),
cantidad_base numeric(24,12) GENERATED ALWAYS AS (cantidad*factor_base) STORED,
costo_unitario_base numeric(18,6) NOT NULL CHECK (costo_unitario_base>=0),
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
UNIQUE(id_venta,id_presentacion),
CHECK (precio_unitario<=precio_lista AND round(cantidad*precio_unitario,2)>0),
CHECK ((origen_precio='NORMAL' AND id_oferta IS NULL AND id_precio_mayorista IS NULL) OR
       (origen_precio='OFERTA' AND id_oferta IS NOT NULL AND id_precio_mayorista IS NULL) OR
       (origen_precio='MAYORISTA' AND id_oferta IS NULL AND id_precio_mayorista IS NOT NULL))
);
CREATE INDEX ix_det_venta_producto_presentacion ON detalle_venta(id_producto,id_presentacion);
CREATE INDEX ix_det_venta_oferta ON detalle_venta(id_oferta);
CREATE INDEX ix_det_venta_mayorista ON detalle_venta(id_precio_mayorista);
CREATE TABLE pago (
id_pago bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_venta bigint NOT NULL REFERENCES venta(id_venta) ON DELETE RESTRICT,
medio varchar(8) NOT NULL CHECK (medio IN ('EFECTIVO','YAPE','DEBITO','CREDITO')),
monto numeric(18,2) NOT NULL CHECK (monto>0),
monto_recibido numeric(18,2),vuelto numeric(18,2),
nro_operacion varchar(40),marca_tarjeta varchar(30),ultimos_cuatro char(4),
fecha_pago date NOT NULL DEFAULT timezone('America/Lima',now())::date,usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
UNIQUE(id_venta,medio),
CHECK ((medio='EFECTIVO' AND monto_recibido IS NOT NULL AND monto_recibido>=monto AND vuelto=monto_recibido-monto AND vuelto IS NOT NULL AND nro_operacion IS NULL) OR
       (medio='YAPE' AND nro_operacion ~ '^[0-9]{6,20}$' AND nro_operacion IS NOT NULL AND monto_recibido IS NULL AND vuelto IS NULL) OR
       (medio='DEBITO' AND length(btrim(coalesce(nro_operacion,''))) BETWEEN 1 AND 40 AND monto_recibido IS NULL AND vuelto IS NULL) OR
       (medio='CREDITO' AND monto_recibido IS NULL AND vuelto IS NULL AND nro_operacion IS NULL)),
CHECK ((medio='DEBITO' AND (ultimos_cuatro IS NULL OR ultimos_cuatro ~ '^[0-9]{4}$')) OR (medio<>'DEBITO' AND ultimos_cuatro IS NULL AND marca_tarjeta IS NULL))
);
CREATE UNIQUE INDEX ux_pago_yape_dia ON pago(fecha_pago,nro_operacion) WHERE medio='YAPE' AND estado='A';
CREATE TABLE comprobante_venta (
id_comprobante bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_venta bigint NOT NULL UNIQUE REFERENCES venta(id_venta) ON DELETE RESTRICT,
id_serie bigint NOT NULL REFERENCES serie_comprobante(id_serie) ON DELETE RESTRICT,
tipo_comprobante char(1) NOT NULL CHECK (tipo_comprobante IN ('B','F','N')),
serie char(4) NOT NULL,numero integer NOT NULL CHECK (numero>0),
fecha_emision timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
cliente_tipo_doc char(3) CHECK (cliente_tipo_doc IN ('DNI','RUC')),
cliente_nro_doc varchar(11),cliente_nombre varchar(150) NOT NULL,cliente_direccion varchar(200),
negocio_nombre varchar(150) NOT NULL,negocio_ruc varchar(11),negocio_direccion varchar(200),negocio_telefono varchar(30),
formato varchar(10) NOT NULL CHECK (formato IN ('A4','TICKET_80')),
version_plantilla integer NOT NULL CHECK (version_plantilla>0),
mensaje_final varchar(300),
base_imponible numeric(18,2) NOT NULL CHECK (base_imponible>0),
igv numeric(18,2) NOT NULL CHECK (igv>=0),total numeric(18,2) NOT NULL CHECK (total>0),
estado_comprobante varchar(8) NOT NULL DEFAULT 'EMITIDO' CHECK (estado_comprobante IN ('EMITIDO','ANULADO')),
estado_tributario varchar(12) NOT NULL DEFAULT 'NO_INTEGRADO' CHECK (estado_tributario IN ('NO_INTEGRADO','PENDIENTE','ACEPTADO','RECHAZADO','NO_APLICA')),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
UNIQUE(serie,numero),CHECK (base_imponible+igv=total),
CHECK (serie ~ '^[BFN][0-9]{3}$' AND left(serie,1)=tipo_comprobante),
CHECK (tipo_comprobante<>'N' OR estado_tributario='NO_APLICA'),
CHECK ((cliente_tipo_doc IS NULL AND cliente_nro_doc IS NULL) OR
       (cliente_tipo_doc='DNI' AND cliente_nro_doc IS NOT NULL AND cliente_nro_doc ~ '^[0-9]{8}$' AND cliente_nro_doc<>'00000000') OR
       (cliente_tipo_doc='RUC' AND cliente_nro_doc IS NOT NULL AND cliente_nro_doc ~ '^[0-9]{11}$' AND cliente_nro_doc<>'00000000000')),
CHECK (tipo_comprobante<>'F' OR (cliente_tipo_doc IS NOT NULL AND cliente_tipo_doc='RUC' AND cliente_nro_doc IS NOT NULL AND length(btrim(cliente_nombre))>=3 AND length(btrim(coalesce(cliente_direccion,'')))>=5))
);
CREATE INDEX ix_comprobante_serie ON comprobante_venta(id_serie);
CREATE TABLE archivo_comprobante (
id_archivo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
id_comprobante bigint NOT NULL REFERENCES comprobante_venta(id_comprobante) ON DELETE RESTRICT,
tipo_archivo varchar(3) NOT NULL CHECK (tipo_archivo IN ('XML','CDR')),
version integer NOT NULL DEFAULT 1 CHECK (version>0),
ubicacion_privada varchar(500),hash_sha256 varchar(64),
estado_archivo varchar(10) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado_archivo IN ('PENDIENTE','DISPONIBLE','ERROR')),
detalle_error varchar(300),usucre varchar(100) NOT NULL,pccre varchar(100) NOT NULL,
feccre timestamp NOT NULL DEFAULT timezone('America/Lima',now()),
usmod varchar(100),pcmod varchar(100),fecmod timestamp,
estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
UNIQUE(id_comprobante,tipo_archivo,version),
CHECK (hash_sha256 IS NULL OR hash_sha256 ~ '^[0-9a-f]{64}$'),
CHECK (estado_archivo<>'DISPONIBLE' OR (length(btrim(coalesce(ubicacion_privada,'')))>0 AND hash_sha256 IS NOT NULL)),
CHECK (estado_archivo<>'ERROR' OR length(btrim(coalesce(detalle_error,'')))>0)
);

CREATE FUNCTION huaman.validar_caja_estructura() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_usuario_apertura AND estado='A') THEN RAISE EXCEPTION 'Usuario de apertura inexistente o inactivo'; END IF;
IF NEW.estado_caja<>'ABIERTA' THEN RAISE EXCEPTION 'Cierre pendiente del bloque de movimientos y conciliacion'; END IF;
IF NEW.fecha_cierre IS NOT NULL OR NEW.id_usuario_cierre IS NOT NULL OR NEW.efectivo_esperado IS NOT NULL OR NEW.efectivo_contado IS NOT NULL OR NEW.yape_esperado IS NOT NULL OR NEW.yape_reportado IS NOT NULL OR NEW.debito_esperado IS NOT NULL OR NEW.debito_reportado IS NOT NULL THEN RAISE EXCEPTION 'Caja abierta no contiene valores de cierre'; END IF;
IF TG_OP='UPDATE' AND (NEW.fecha,NEW.monto_inicial,NEW.id_usuario_apertura,NEW.estado) IS DISTINCT FROM (OLD.fecha,OLD.monto_inicial,OLD.id_usuario_apertura,OLD.estado) THEN RAISE EXCEPTION 'Apertura inmutable: correccion mediante proceso autorizado'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_caja BEFORE INSERT OR UPDATE ON caja_diaria FOR EACH ROW EXECUTE FUNCTION huaman.validar_caja_estructura();

CREATE FUNCTION huaman.validar_venta_borrador() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE cli huaman.cliente%ROWTYPE; caj huaman.caja_diaria%ROWTYPE;
BEGIN
IF NEW.estado_venta<>'BORRADOR' THEN RAISE EXCEPTION 'Confirmacion/anulacion pendiente de movimientos de inventario, caja y credito'; END IF;
SELECT * INTO caj FROM huaman.caja_diaria WHERE id_caja=NEW.id_caja FOR UPDATE;
IF NOT FOUND OR caj.estado_caja<>'ABIERTA' OR caj.estado<>'A' OR caj.fecha<>NEW.fecha_venta::date THEN RAISE EXCEPTION 'Venta requiere caja abierta de la fecha indicada'; END IF;
IF NOT EXISTS(SELECT 1 FROM huaman.usuario WHERE id_usuario=NEW.id_vendedor AND estado='A') THEN RAISE EXCEPTION 'Vendedor inexistente o inactivo'; END IF;
IF NEW.id_cliente IS NULL THEN
NEW.cliente_tipo_doc:=NULL;NEW.cliente_nro_doc:=NULL;NEW.cliente_nombre:='CLIENTE VARIOS';NEW.cliente_direccion:=NULL;
ELSE
SELECT * INTO cli FROM huaman.cliente WHERE id_cliente=NEW.id_cliente AND estado='A';
IF NOT FOUND THEN RAISE EXCEPTION 'Cliente inexistente o inactivo'; END IF;
NEW.cliente_tipo_doc:=cli.tipo_documento;NEW.cliente_nro_doc:=cli.nro_documento;NEW.cliente_nombre:=cli.nombre_razon_social;NEW.cliente_direccion:=cli.direccion;
END IF;
IF NEW.tipo_comprobante='F' AND (NEW.id_cliente IS NULL OR NEW.cliente_tipo_doc<>'RUC') THEN RAISE EXCEPTION 'Factura requiere cliente con RUC, razon social y direccion'; END IF;
IF NEW.id_venta_origen IS NOT NULL AND NOT EXISTS(SELECT 1 FROM huaman.venta WHERE id_venta=NEW.id_venta_origen AND estado_venta='CONFIRMADA') THEN RAISE EXCEPTION 'Venta origen no confirmada'; END IF;
IF NEW.id_cotizacion IS NOT NULL THEN RAISE EXCEPTION 'Conversion de cotizacion pendiente del bloque de procesos'; END IF;
IF TG_OP='INSERT' AND (NEW.subtotal<>0 OR NEW.descuento_total<>0 OR NEW.total<>0) THEN RAISE EXCEPTION 'Totales se calculan desde detalles'; END IF;
IF TG_OP='UPDATE' THEN
IF (NEW.subtotal,NEW.descuento_total,NEW.total) IS DISTINCT FROM (OLD.subtotal,OLD.descuento_total,OLD.total) AND pg_trigger_depth()<2 THEN RAISE EXCEPTION 'No editar totales manualmente'; END IF;
IF (NEW.id_caja,NEW.id_vendedor,NEW.fecha_venta,NEW.clave_idempotencia,NEW.igv_porcentaje,NEW.id_venta_origen) IS DISTINCT FROM (OLD.id_caja,OLD.id_vendedor,OLD.fecha_venta,OLD.clave_idempotencia,OLD.igv_porcentaje,OLD.id_venta_origen) THEN RAISE EXCEPTION 'Identidad y base fiscal del borrador inmutables'; END IF;
IF EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' GROUP BY id_venta HAVING sum(monto)>NEW.total) THEN RAISE EXCEPTION 'Reducir pagos provisionales antes de reducir el total'; END IF;
IF NEW.id_cliente IS NULL AND EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' AND medio='CREDITO') THEN RAISE EXCEPTION 'Fiado requiere cliente identificado'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_cabecera BEFORE INSERT OR UPDATE ON venta FOR EACH ROW EXECUTE FUNCTION huaman.validar_venta_borrador();
CREATE FUNCTION huaman.validar_detalle_venta() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE c huaman.venta%ROWTYPE;p huaman.presentacion_producto%ROWTYPE;prod huaman.producto%ROWTYPE;
        mayor huaman.precio_mayorista%ROWTYPE;promo huaman.oferta%ROWTYPE;
BEGIN
  SELECT * INTO c FROM huaman.venta WHERE id_venta=NEW.id_venta FOR UPDATE;
  IF NOT FOUND OR c.estado_venta<>'BORRADOR' OR c.estado<>'A' THEN RAISE EXCEPTION 'Cotizacion no editable'; END IF;
  IF TG_OP='UPDATE' AND NEW.id_venta<>OLD.id_venta THEN RAISE EXCEPTION 'No mover detalle a otra venta'; END IF;
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
  NEW.costo_unitario_base:=prod.costo_promedio;NEW.precio_lista:=p.precio_normal;NEW.precio_unitario:=p.precio_normal;NEW.origen_precio:='NORMAL';NEW.id_oferta:=NULL;NEW.id_precio_mayorista:=NULL;
  SELECT * INTO mayor FROM huaman.precio_mayorista WHERE id_presentacion=p.id_presentacion AND estado='A' AND cantidad_minima<=NEW.cantidad ORDER BY cantidad_minima DESC LIMIT 1;
  IF FOUND AND mayor.precio<NEW.precio_unitario THEN NEW.precio_unitario:=mayor.precio;NEW.origen_precio:='MAYORISTA';NEW.id_precio_mayorista:=mayor.id_precio_mayorista; END IF;
  SELECT * INTO promo FROM huaman.oferta WHERE id_presentacion=p.id_presentacion AND estado='A' AND c.fecha_venta::date BETWEEN fecha_inicio AND fecha_fin;
  IF FOUND AND promo.precio_oferta<NEW.precio_unitario THEN NEW.precio_unitario:=promo.precio_oferta;NEW.origen_precio:='OFERTA';NEW.id_oferta:=promo.id_oferta;NEW.id_precio_mayorista:=NULL; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_detalle BEFORE INSERT OR UPDATE ON detalle_venta FOR EACH ROW EXECUTE FUNCTION huaman.validar_detalle_venta();
CREATE FUNCTION huaman.recalcular_total_venta() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  UPDATE huaman.venta SET
    subtotal=(SELECT coalesce(sum(round(cantidad*precio_lista,2)),0) FROM huaman.detalle_venta WHERE id_venta=NEW.id_venta AND estado='A'),
    descuento_total=(SELECT coalesce(sum(descuento_monto),0) FROM huaman.detalle_venta WHERE id_venta=NEW.id_venta AND estado='A'),
    total=(SELECT coalesce(sum(importe),0) FROM huaman.detalle_venta WHERE id_venta=NEW.id_venta AND estado='A')
  WHERE id_venta=NEW.id_venta;
  RETURN NULL;
END $$;
CREATE TRIGGER total_venta AFTER INSERT OR UPDATE ON detalle_venta FOR EACH ROW EXECUTE FUNCTION huaman.recalcular_total_venta();
CREATE FUNCTION huaman.validar_pago_provisional() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v huaman.venta%ROWTYPE;otros numeric;
BEGIN
SELECT * INTO v FROM huaman.venta WHERE id_venta=NEW.id_venta FOR UPDATE;
IF NOT FOUND OR v.estado_venta<>'BORRADOR' OR v.estado<>'A' THEN RAISE EXCEPTION 'Pago provisional requiere borrador editable'; END IF;
IF TG_OP='UPDATE' AND NEW.id_venta<>OLD.id_venta THEN RAISE EXCEPTION 'No mover pago entre ventas'; END IF;
IF NEW.fecha_pago<>v.fecha_venta::date THEN RAISE EXCEPTION 'Fecha de pago incompatible con venta'; END IF;
SELECT coalesce(sum(monto),0) INTO otros FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' AND id_pago<>NEW.id_pago;
IF NEW.estado='A' THEN
IF otros+NEW.monto>v.total THEN RAISE EXCEPTION 'Pagos superan total de venta'; END IF;
IF NEW.medio='CREDITO' AND (v.id_cliente IS NULL OR otros<>0) THEN RAISE EXCEPTION 'Fiado requiere cliente y no se mezcla con otros medios'; END IF;
IF NEW.medio<>'CREDITO' AND EXISTS(SELECT 1 FROM huaman.pago WHERE id_venta=NEW.id_venta AND estado='A' AND medio='CREDITO' AND id_pago<>NEW.id_pago) THEN RAISE EXCEPTION 'No mezclar con fiado'; END IF;
END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_pago BEFORE INSERT OR UPDATE ON pago FOR EACH ROW EXECUTE FUNCTION huaman.validar_pago_provisional();
CREATE FUNCTION huaman.bloquear_emision_pendiente() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN RAISE EXCEPTION 'Emision y anulacion pendientes del bloque de procesos; no insertar comprobantes manualmente'; END $$;
CREATE TRIGGER emision_pendiente BEFORE INSERT OR UPDATE ON comprobante_venta FOR EACH ROW EXECUTE FUNCTION huaman.bloquear_emision_pendiente();
CREATE FUNCTION huaman.validar_archivo_comprobante() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE c huaman.comprobante_venta%ROWTYPE;
BEGIN
SELECT * INTO c FROM huaman.comprobante_venta WHERE id_comprobante=NEW.id_comprobante;
IF NOT FOUND OR c.tipo_comprobante='N' THEN RAISE EXCEPTION 'XML/CDR solo para comprobante electronico de boleta o factura'; END IF;
IF TG_OP='UPDATE' AND OLD.estado_archivo='DISPONIBLE' THEN RAISE EXCEPTION 'Archivo disponible inmutable: registrar otra version'; END IF;
IF TG_OP='UPDATE' AND (NEW.id_comprobante,NEW.tipo_archivo,NEW.version) IS DISTINCT FROM (OLD.id_comprobante,OLD.tipo_archivo,OLD.version) THEN RAISE EXCEPTION 'No reasignar identidad del archivo'; END IF;
IF NEW.ubicacion_privada ~* '^https?://' THEN RAISE EXCEPTION 'Guardar clave privada de almacenamiento, no URL publica o firmada persistente'; END IF;
RETURN NEW;
END $$;
CREATE TRIGGER validar_archivo BEFORE INSERT OR UPDATE ON archivo_comprobante FOR EACH ROW EXECUTE FUNCTION huaman.validar_archivo_comprobante();

ALTER TABLE huaman.caja_diaria ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.caja_diaria FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.caja_diaria FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.caja_diaria FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.caja_diaria FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.venta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.venta FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.venta FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.venta FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.venta FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.detalle_venta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.detalle_venta FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.detalle_venta FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.detalle_venta FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.detalle_venta FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.pago ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.pago FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.pago FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.pago FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.pago FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.comprobante_venta ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.comprobante_venta FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.comprobante_venta FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.comprobante_venta FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.comprobante_venta FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.archivo_comprobante ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.archivo_comprobante FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.archivo_comprobante FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.archivo_comprobante FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.archivo_comprobante FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'caja_diaria' AS tabla,count(*) AS registros FROM huaman.caja_diaria
UNION ALL SELECT 'venta',count(*) FROM huaman.venta
UNION ALL SELECT 'detalle_venta',count(*) FROM huaman.detalle_venta
UNION ALL SELECT 'pago',count(*) FROM huaman.pago
UNION ALL SELECT 'comprobante_venta',count(*) FROM huaman.comprobante_venta
UNION ALL SELECT 'archivo_comprobante',count(*) FROM huaman.archivo_comprobante
ORDER BY tabla;

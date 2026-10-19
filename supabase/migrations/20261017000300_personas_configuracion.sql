-- FERRETERIA HUAMAN - BLOQUE 03 - personas, seguridad y configuracion
-- Requiere bloques 01 y 02 confirmados. Ejecutar TODO una sola vez.
-- No crea usuarios, contrasenas, clientes ni proveedores de ejemplo.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
SELECT set_config('app.usuario','MIGRACION_003',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
DO $$ BEGIN
  IF to_regclass('huaman.producto') IS NULL OR to_regclass('huaman.precio_mayorista') IS NULL THEN
    RAISE EXCEPTION 'Primero instalar bloques 01 y 02';
  END IF;
  IF to_regclass('huaman.usuario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: usuario existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.sesion_usuario') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: sesion_usuario existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.bitacora_evento') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: bitacora_evento existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.parametro_sistema') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: parametro_sistema existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.serie_comprobante') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: serie_comprobante existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.proveedor') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: proveedor existe. No reejecutar.'; END IF;
  IF to_regclass('huaman.cliente') IS NOT NULL THEN RAISE EXCEPTION 'Bloque 03 ya instalado o parcial: cliente existe. No reejecutar.'; END IF;
END $$;

CREATE TABLE usuario (
  id_usuario bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username varchar(30) NOT NULL,
  clave_hash varchar(100) NOT NULL,
  nombres varchar(100) NOT NULL,
  apellidos varchar(100) NOT NULL,
  dni char(8) NOT NULL UNIQUE,
  telefono varchar(20),
  correo varchar(100),
  id_rol bigint NOT NULL REFERENCES rol(id_rol) ON DELETE RESTRICT,
  clave_temporal boolean NOT NULL DEFAULT true,
  intentos_fallidos smallint NOT NULL DEFAULT 0 CHECK (intentos_fallidos >= 0),
  bloqueado_hasta timestamp,
  ultimo_ingreso timestamp,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (dni ~ '^[0-9]{8}$' AND dni <> '00000000'),
  CHECK (btrim(nombres)<>'' AND btrim(apellidos)<>''),
  CHECK (username ~ '^[A-Za-z0-9._-]{4,30}$'),
  CHECK (clave_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$')
);

CREATE TABLE sesion_usuario (
  id_sesion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_usuario bigint NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  token_id uuid NOT NULL UNIQUE,
  inicio timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  ultima_actividad timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  cerrada_en timestamp,
  motivo_cierre varchar(12) CHECK (motivo_cierre IN ('LOGOUT', 'EXPIRADA', 'REVOCADA')),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK ((cerrada_en IS NULL AND motivo_cierre IS NULL) OR (cerrada_en IS NOT NULL AND motivo_cierre IS NOT NULL)),
  CHECK (ultima_actividad >= inicio),
  CHECK (cerrada_en IS NULL OR cerrada_en >= ultima_actividad)
);

CREATE TABLE bitacora_evento (
  id_evento bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_usuario bigint REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  accion varchar(40) NOT NULL,
  entidad varchar(40) NOT NULL,
  id_entidad bigint,
  referencia varchar(60),
  valor_anterior jsonb,
  valor_nuevo jsonb,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE TABLE parametro_sistema (
  id_parametro bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave varchar(50) NOT NULL UNIQUE,
  grupo varchar(20) NOT NULL CHECK (grupo IN ('NEGOCIO', 'VENTAS', 'COTIZACION', 'SEGURIDAD', 'COMPROBANTE')),
  valor varchar(300) NOT NULL,
  valor_defecto varchar(300) NOT NULL,
  tipo_dato varchar(10) NOT NULL CHECK (tipo_dato IN ('TEXTO', 'ENTERO', 'DECIMAL')),
  valor_min numeric(10,2),
  valor_max numeric(10,2),
  descripcion varchar(200) NOT NULL,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (valor_min IS NULL OR valor_max IS NULL OR valor_min <= valor_max)
);

CREATE TABLE serie_comprobante (
  id_serie bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_comprobante char(1) NOT NULL CHECK (tipo_comprobante IN ('B', 'F', 'N')),
  serie char(4) NOT NULL UNIQUE,
  correlativo_inicial integer NOT NULL DEFAULT 1 CHECK (correlativo_inicial >= 1),
  ultimo_correlativo integer NOT NULL DEFAULT 0 CHECK (ultimo_correlativo >= 0),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (serie ~ '^[BFN][0-9]{3}$' AND left(serie,1) = tipo_comprobante),
  CHECK (ultimo_correlativo >= correlativo_inicial - 1)
);

CREATE TABLE proveedor (
  id_proveedor bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ruc char(11) NOT NULL UNIQUE,
  razon_social varchar(150) NOT NULL,
  contacto varchar(100),
  telefono varchar(20),
  correo varchar(100),
  direccion varchar(200),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (ruc ~ '^[0-9]{11}$' AND ruc <> '00000000000'),
  CHECK (btrim(razon_social)<>'')
);

CREATE TABLE cliente (
  id_cliente bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tipo_documento char(3) NOT NULL CHECK (tipo_documento IN ('DNI', 'RUC')),
  nro_documento varchar(11) NOT NULL UNIQUE,
  nombre_razon_social varchar(150) NOT NULL,
  telefono varchar(20),
  correo varchar(100),
  direccion varchar(200),
  limite_credito numeric(18,2) NOT NULL DEFAULT 0 CHECK (limite_credito >= 0),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  CHECK (btrim(nombre_razon_social)<>'' AND upper(btrim(nombre_razon_social))<>'CLIENTE VARIOS'),
  CHECK ((tipo_documento = 'DNI' AND nro_documento ~ '^[0-9]{8}$' AND nro_documento <> '00000000') OR (tipo_documento = 'RUC' AND nro_documento ~ '^[0-9]{11}$' AND nro_documento <> '00000000000' AND direccion IS NOT NULL AND length(trim(direccion)) >= 5))
);

CREATE UNIQUE INDEX ux_usuario_username_normal ON usuario(lower(username));
CREATE INDEX ix_usuario_rol ON usuario(id_rol);
CREATE INDEX ix_sesion_usuario ON sesion_usuario(id_usuario,inicio DESC);
CREATE INDEX ix_evento_usuario_fecha ON bitacora_evento(id_usuario,feccre DESC);
CREATE INDEX ix_evento_entidad_fecha ON bitacora_evento(entidad,id_entidad,feccre DESC);
CREATE INDEX ix_cliente_nombre ON cliente(lower(nombre_razon_social) text_pattern_ops);
CREATE INDEX ix_proveedor_nombre ON proveedor(lower(razon_social) text_pattern_ops);

CREATE FUNCTION huaman.validar_usuario_catalogo() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM huaman.rol WHERE id_rol=NEW.id_rol AND estado='A') THEN RAISE EXCEPTION 'Rol inexistente o inactivo'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_usuario BEFORE INSERT OR UPDATE ON usuario
FOR EACH ROW EXECUTE FUNCTION huaman.validar_usuario_catalogo();

CREATE FUNCTION huaman.proteger_sesion_cerrada() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF (NEW.id_usuario,NEW.token_id,NEW.inicio) IS DISTINCT FROM (OLD.id_usuario,OLD.token_id,OLD.inicio) THEN RAISE EXCEPTION 'Identidad de sesion inmutable'; END IF;
  IF OLD.cerrada_en IS NOT NULL AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Una sesion cerrada es inmutable'; END IF;
  IF NEW.ultima_actividad<OLD.ultima_actividad THEN RAISE EXCEPTION 'La actividad no retrocede'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER proteger_sesion BEFORE UPDATE ON sesion_usuario
FOR EACH ROW EXECUTE FUNCTION huaman.proteger_sesion_cerrada();

CREATE FUNCTION huaman.validar_parametro_sistema() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v text; n numeric;
BEGIN
  IF NEW.tipo_dato='TEXTO' AND (NEW.valor_min IS NOT NULL OR NEW.valor_max IS NOT NULL) THEN
    RAISE EXCEPTION 'Texto no admite limites numericos';
  END IF;
  FOREACH v IN ARRAY ARRAY[NEW.valor,NEW.valor_defecto] LOOP
    IF NEW.tipo_dato IN ('ENTERO','DECIMAL') THEN
      IF (NEW.tipo_dato='ENTERO' AND v !~ '^-?[0-9]+$') OR
         (NEW.tipo_dato='DECIMAL' AND v !~ '^-?[0-9]+([.][0-9]+)?$') THEN
        RAISE EXCEPTION 'Valor incompatible con tipo de parametro %',NEW.clave;
      END IF;
      n:=v::numeric;
      IF (NEW.valor_min IS NOT NULL AND n<NEW.valor_min) OR (NEW.valor_max IS NOT NULL AND n>NEW.valor_max) THEN
        RAISE EXCEPTION 'Valor fuera de limites para %',NEW.clave;
      END IF;
    END IF;
  END LOOP;
  IF NEW.clave='COMPROBANTE.FORMATO' AND (NEW.valor NOT IN ('A4','TICKET_80') OR NEW.valor_defecto NOT IN ('A4','TICKET_80')) THEN
    RAISE EXCEPTION 'Formato de comprobante invalido';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER validar_parametro BEFORE INSERT OR UPDATE ON parametro_sistema
FOR EACH ROW EXECUTE FUNCTION huaman.validar_parametro_sistema();

CREATE FUNCTION huaman.proteger_serie_usada() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.ultimo_correlativo<OLD.ultimo_correlativo THEN RAISE EXCEPTION 'El correlativo no puede retroceder'; END IF;
  IF OLD.ultimo_correlativo>=OLD.correlativo_inicial AND
     (NEW.serie,NEW.tipo_comprobante,NEW.correlativo_inicial) IS DISTINCT FROM (OLD.serie,OLD.tipo_comprobante,OLD.correlativo_inicial) THEN
    RAISE EXCEPTION 'No modificar identidad de una serie usada';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER proteger_serie BEFORE UPDATE ON serie_comprobante
FOR EACH ROW EXECUTE FUNCTION huaman.proteger_serie_usada();

-- Nunca registrar passwords, hashes, tokens de sesion ni datos completos de tarjetas en la bitacora.
-- El backend debe redactar datos sensibles ANTES de construir valor_anterior/valor_nuevo.
CREATE TRIGGER inmutable BEFORE UPDATE ON bitacora_evento
FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.usuario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.usuario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.usuario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.usuario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.usuario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.sesion_usuario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.sesion_usuario FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.sesion_usuario FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.sesion_usuario FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.sesion_usuario FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.bitacora_evento ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.bitacora_evento FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.bitacora_evento FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.bitacora_evento FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.bitacora_evento FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.parametro_sistema ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.parametro_sistema FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.parametro_sistema FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.parametro_sistema FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.parametro_sistema FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.serie_comprobante ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.serie_comprobante FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.serie_comprobante FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.serie_comprobante FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.serie_comprobante FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.proveedor ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.proveedor FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.proveedor FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.proveedor FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.proveedor FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.cliente ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.cliente FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.cliente FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.cliente FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.cliente FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

-- Series de desarrollo: no habilitan emision electronica ni acreditan autorizacion tributaria.
INSERT INTO serie_comprobante(tipo_comprobante,serie) VALUES ('B','B001'),('F','F001'),('N','N001');
INSERT INTO parametro_sistema(clave,grupo,valor,valor_defecto,tipo_dato,valor_min,valor_max,descripcion) VALUES
('NEGOCIO.NOMBRE_COMERCIAL','NEGOCIO','Ferretería Huamán','Ferretería Huamán','TEXTO',NULL,NULL,'Nombre comercial'),
('NEGOCIO.RAZON_SOCIAL','NEGOCIO','','','TEXTO',NULL,NULL,'Completar antes de operar'),
('NEGOCIO.RUC','NEGOCIO','','','TEXTO',NULL,NULL,'RUC real pendiente de configurar'),
('NEGOCIO.DIRECCION','NEGOCIO','','','TEXTO',NULL,NULL,'Dirección real pendiente de configurar'),
('NEGOCIO.TELEFONO','NEGOCIO','','','TEXTO',NULL,NULL,'Teléfono del negocio'),
('NEGOCIO.LOGO','NEGOCIO','','','TEXTO',NULL,NULL,'Ruta o identificador del logo; no base64'),
('VENTAS.IGV_PORC','VENTAS','18','18','DECIMAL','0','30','IGV incluido en los precios'),
('VENTAS.DESCUENTO_MAX_PORC','VENTAS','5','5','DECIMAL','0','100','Máximo de descuento sin autorización'),
('VENTAS.BOLETA_DNI_DESDE','VENTAS','700','700','DECIMAL','0',NULL,'Supuesto S3 pendiente de validar; no constituye verificación normativa'),
('VENTAS.PLAZO_CREDITO_DIAS','VENTAS','30','30','ENTERO','1','180','Días de plazo de crédito'),
('COTIZACION.VIGENCIA_DIAS','COTIZACION','7','7','ENTERO','1','90','Vigencia de cotizaciones'),
('VENTAS.DEVOLUCION_DIAS','VENTAS','30','30','ENTERO','1','365','Plazo de devolución; máximo propuesto por validar'),
('SEGURIDAD.SESION_MIN','SEGURIDAD','30','30','ENTERO','5','120','Expiración por inactividad'),
('SEGURIDAD.INTENTOS_MAX','SEGURIDAD','5','5','ENTERO','1','20','Intentos fallidos; máximo propuesto por validar'),
('SEGURIDAD.BLOQUEO_MIN','SEGURIDAD','15','15','ENTERO','1','120','Bloqueo; máximo propuesto por validar'),
('COMPROBANTE.FORMATO','COMPROBANTE','TICKET_80','TICKET_80','TEXTO',NULL,NULL,'A4 o TICKET_80'),
('COMPROBANTE.PIE','COMPROBANTE','Gracias por su preferencia.','Gracias por su preferencia.','TEXTO',NULL,NULL,'Texto al pie del comprobante');

INSERT INTO parametro_sistema(clave,grupo,valor,valor_defecto,tipo_dato,valor_min,valor_max,descripcion) VALUES
('NEGOCIO.MONEDA','NEGOCIO','PEN','PEN','TEXTO',NULL,NULL,'Moneda de operacion'),
('SEGURIDAD.ZONA_HORARIA','SEGURIDAD','America/Lima','America/Lima','TEXTO',NULL,NULL,'Zona horaria del negocio'),
('COMPROBANTE.VERSION_PLANTILLA','COMPROBANTE','1','1','ENTERO',1,999999,'Version de representacion impresa; conservar por documento'),
('COMPROBANTE.MOSTRAR_CODIGO','COMPROBANTE','0','0','ENTERO',0,1,'Codigo interno de consulta solo cuando exista generacion verificable'),
('COMPROBANTE.EMISION_ELECTRONICA','COMPROBANTE','0','0','ENTERO',0,1,'Integracion tributaria pendiente; no habilitar sin implementacion');
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
SELECT 'usuario' AS tabla,count(*) AS registros FROM huaman.usuario
UNION ALL SELECT 'sesion_usuario',count(*) FROM huaman.sesion_usuario
UNION ALL SELECT 'bitacora_evento',count(*) FROM huaman.bitacora_evento
UNION ALL SELECT 'parametro_sistema',count(*) FROM huaman.parametro_sistema
UNION ALL SELECT 'serie_comprobante',count(*) FROM huaman.serie_comprobante
UNION ALL SELECT 'proveedor',count(*) FROM huaman.proveedor
UNION ALL SELECT 'cliente',count(*) FROM huaman.cliente
ORDER BY tabla;

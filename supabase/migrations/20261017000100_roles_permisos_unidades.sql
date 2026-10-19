-- FERRETERIA HUAMAN - BLOQUE 01 - roles, permisos y unidades
-- Para el esquema huaman ya creado, sin estas cuatro tablas.
-- Instalacion unica. Ejecutar TODO el archivo, sin seleccionar un fragmento.
-- No contiene usuarios, claves ni productos de ejemplo.
BEGIN;
SET LOCAL search_path TO huaman, pg_catalog;
DO $$ BEGIN
  IF to_regnamespace('huaman') IS NULL THEN
    RAISE EXCEPTION 'Primero crear el esquema huaman';
  END IF;
  IF to_regclass('huaman.rol') IS NOT NULL
     OR to_regclass('huaman.permiso') IS NOT NULL
     OR to_regclass('huaman.rol_permiso') IS NOT NULL
     OR to_regclass('huaman.unidad_medida') IS NOT NULL THEN
    RAISE EXCEPTION 'El bloque 01 ya esta instalado o hay tablas previas. No volver a ejecutar; revisar primero.';
  END IF;
END $$;
REVOKE ALL ON SCHEMA huaman FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA huaman REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA huaman REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA huaman REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE rol (
  id_rol bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo varchar(10) NOT NULL UNIQUE,
  nombre varchar(60) NOT NULL,
  descripcion varchar(200),
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE TABLE permiso (
  id_permiso bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo varchar(40) NOT NULL UNIQUE,
  modulo varchar(30) NOT NULL,
  descripcion varchar(150) NOT NULL,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE TABLE rol_permiso (
  id_rol_permiso bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_rol bigint NOT NULL REFERENCES rol(id_rol) ON DELETE RESTRICT,
  id_permiso bigint NOT NULL REFERENCES permiso(id_permiso) ON DELETE RESTRICT,
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I')),
  UNIQUE (id_rol, id_permiso)
);

CREATE TABLE unidad_medida (
  id_unidad bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre varchar(40) NOT NULL UNIQUE,
  abreviatura varchar(8) NOT NULL UNIQUE,
  admite_decimales boolean NOT NULL DEFAULT false,
  magnitud varchar(10) NOT NULL CHECK (magnitud IN ('CONTEO','PESO','LONGITUD','VOLUMEN')),
  factor_referencia numeric(18,6) NOT NULL CHECK (factor_referencia > 0),
  precision_cantidad smallint NOT NULL CHECK (precision_cantidad BETWEEN 0 AND 6),
  CHECK (admite_decimales = (precision_cantidad > 0)),
  -- Referencias: unidad, kilogramo, metro y litro, segun magnitud.
  -- Bolsas/cajas/rollos se definiran en presentacion_producto por producto.
  usucre varchar(100) NOT NULL,
  pccre varchar(100) NOT NULL,
  feccre timestamp NOT NULL DEFAULT timezone('America/Lima', now()),
  usmod varchar(100),
  pcmod varchar(100),
  fecmod timestamp,
  estado char(1) NOT NULL DEFAULT 'A' CHECK (estado IN ('A','I'))
);

CREATE FUNCTION huaman.completar_auditoria() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $$
DECLARE
  actor text := nullif(current_setting('app.usuario', true), '');
  equipo text := nullif(current_setting('app.equipo', true), '');
BEGIN
  IF actor IS NULL OR equipo IS NULL OR length(actor) > 100 OR length(equipo) > 100 THEN
    RAISE EXCEPTION 'Falta contexto de auditoría de la transacción';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.usucre := actor; NEW.pccre := equipo;
    NEW.feccre := timezone('America/Lima', now());
    NEW.usmod := NULL; NEW.pcmod := NULL; NEW.fecmod := NULL;
  ELSE
    NEW.usucre := OLD.usucre; NEW.pccre := OLD.pccre; NEW.feccre := OLD.feccre;
    NEW.usmod := actor; NEW.pcmod := equipo;
    NEW.fecmod := timezone('America/Lima', now());
  END IF;
  RETURN NEW;
END $$;
CREATE FUNCTION huaman.rechazar_mutacion() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  RAISE EXCEPTION 'Operacion % no permitida sobre %: usar baja logica', TG_OP, TG_TABLE_NAME;
END $$;

ALTER TABLE huaman.rol ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.rol FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.rol
FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.rol
FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.rol
FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.permiso ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.permiso FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.permiso
FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.permiso
FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.permiso
FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.rol_permiso ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.rol_permiso FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.rol_permiso
FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.rol_permiso
FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.rol_permiso
FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();

ALTER TABLE huaman.unidad_medida ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE huaman.unidad_medida FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER auditoria BEFORE INSERT OR UPDATE ON huaman.unidad_medida
FOR EACH ROW EXECUTE FUNCTION huaman.completar_auditoria();
CREATE TRIGGER no_delete BEFORE DELETE ON huaman.unidad_medida
FOR EACH ROW EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE TRIGGER no_truncate BEFORE TRUNCATE ON huaman.unidad_medida
FOR EACH STATEMENT EXECUTE FUNCTION huaman.rechazar_mutacion();
CREATE INDEX ix_rol_permiso_permiso ON huaman.rol_permiso(id_permiso);
SELECT set_config('app.usuario','MIGRACION_001',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
INSERT INTO rol(codigo,nombre,descripcion) VALUES
('ADM','Administradora','Administración completa'),
('VEN','Vendedor de mostrador','Venta, caja y cobranza'),
('ALM','Encargado de almacén','Compras e inventario'),
('AYU','Ayudante de almacén y despacho','Conteo y despacho');
INSERT INTO permiso(codigo,modulo,descripcion) VALUES
('SEG.USUARIOS','SEG','Gestionar usuarios'),
('SEG.PERMISOS','SEG','Ver y ajustar permisos de roles'),
('SEG.BITACORA','SEG','Consultar bitácora'),
('SEG.PERFIL','SEG','Cambiar contraseña propia'),
('INI.VER','INI','Ver panel de inicio'),
('CFG.PARAMETROS','CFG','Gestionar parámetros'),
('CFG.SERIES','CFG','Gestionar series y correlativos'),
('PRO.VER','PRO','Consultar productos'),
('PRO.GESTIONAR','PRO','Crear y editar productos'),
('PRO.PRECIOS','PRO','Editar costo y precio'),
('PRO.INACTIVAR','PRO','Inactivar y reactivar producto'),
('CAT.GESTIONAR','CAT','Gestionar categorías'),
('UNI.GESTIONAR','UNI','Gestionar unidades de medida'),
('PRV.GESTIONAR','PRV','Gestionar proveedores'),
('CLI.VER','CLI','Consultar clientes'),
('CLI.GESTIONAR','CLI','Crear y editar clientes'),
('CLI.CREDITO','CLI','Fijar límite de crédito'),
('COM.OC','COM','Crear, emitir y consultar órdenes de compra'),
('COM.OC_ANULAR','COM','Anular orden de compra'),
('COM.INGRESO','COM','Registrar ingreso de mercadería'),
('INV.VER','INV','Consultar inventario y kardex'),
('INV.ALERTAS','INV','Ver alertas de stock'),
('INV.AJUSTAR','INV','Registrar ajustes de inventario'),
('INV.TOMA_GESTIONAR','INV','Iniciar, cerrar y aprobar toma de inventario'),
('INV.TOMA_CONTAR','INV','Registrar conteos'),
('VEN.VENDER','VEN','Registrar ventas en el punto de venta'),
('VEN.DESCUENTO','VEN','Aplicar descuento hasta el límite'),
('VEN.DESCUENTO_AUTORIZAR','VEN','Autorizar descuento sobre el límite'),
('VEN.HISTORIAL','VEN','Consultar historial de ventas'),
('VEN.REIMPRIMIR','VEN','Reimprimir comprobante'),
('VEN.ANULAR','VEN','Anular venta'),
('VEN.DEVOLVER','VEN','Registrar devolución'),
('COC.COTIZAR','COC','Gestionar cotizaciones'),
('COC.OFERTAS','COC','Gestionar ofertas'),
('CRE.VER','CRE','Consultar cuentas por cobrar'),
('CRE.ABONAR','CRE','Registrar abonos'),
('CAJ.OPERAR','CAJ','Abrir, cerrar caja y registrar movimientos'),
('CAJ.HISTORIAL','CAJ','Consultar historial de cajas'),
('DES.VER','DES','Consultar despachos'),
('DES.GESTIONAR','DES','Preparar y entregar despachos'),
('REP.VENTAS','REP','Reporte de ventas'),
('REP.INVENTARIO','REP','Reporte de inventario'),
('REP.CAJA','REP','Reporte de cajas'),
('REP.EXPORTAR','REP','Exportar reportes');
INSERT INTO permiso(codigo,modulo,descripcion) VALUES
('PRO.COSTOS','PRO','Consultar costos de producto; solo ADM'),
('PRO.PRESENTACIONES','PRO','Administrar presentaciones'),
('PRO.MAYORISTA','PRO','Configurar precios mayoristas'),
('REP.DASHBOARD','REP','Dashboard financiero; solo ADM'),
('REP.PRODUCTO','REP','Graficos financieros por producto; solo ADM'),
('REP.CENTRO','REP','Centro administrativo de reportes'),
('VEN.COPIAR','VEN','Copiar productos de venta anterior'),
('VEN.XML','VEN','Descargar XML original autorizado'),
('CFG.ETIQUETAS','CFG','Configurar y generar etiquetas'),
('CFG.TICKET','CFG','Configurar ticket'),
('PRO.MEDIDAS','PRO','Configurar unidades y fraccionamiento'),
('INV.TRANSFORMAR','INV','Convertir envases y preparar cortes'),
('VEN.MEDIDAS','VEN','Vender por unidad o medida');
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p WHERE r.codigo = 'ADM';
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p
WHERE r.codigo = 'VEN' AND p.codigo IN ('SEG.PERFIL', 'INI.VER', 'PRO.VER', 'CLI.VER', 'CLI.GESTIONAR', 'INV.VER', 'VEN.VENDER', 'VEN.DESCUENTO', 'VEN.HISTORIAL', 'VEN.REIMPRIMIR', 'VEN.DEVOLVER', 'COC.COTIZAR', 'CRE.VER', 'CRE.ABONAR', 'CAJ.OPERAR', 'DES.VER', 'DES.GESTIONAR');
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p
WHERE r.codigo = 'ALM' AND p.codigo IN ('SEG.PERFIL', 'INI.VER', 'PRO.VER', 'PRO.GESTIONAR', 'CAT.GESTIONAR', 'PRV.GESTIONAR', 'COM.OC', 'COM.INGRESO', 'INV.VER', 'INV.ALERTAS', 'INV.AJUSTAR', 'INV.TOMA_GESTIONAR', 'INV.TOMA_CONTAR', 'DES.VER', 'DES.GESTIONAR', 'REP.INVENTARIO', 'REP.EXPORTAR');
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p
WHERE r.codigo = 'AYU' AND p.codigo IN ('SEG.PERFIL', 'INI.VER', 'PRO.VER', 'INV.VER', 'INV.TOMA_CONTAR', 'DES.VER', 'DES.GESTIONAR');
INSERT INTO rol_permiso(id_rol,id_permiso)
SELECT r.id_rol,p.id_permiso FROM rol r CROSS JOIN permiso p
WHERE (r.codigo='VEN' AND p.codigo IN ('VEN.COPIAR','VEN.XML','VEN.MEDIDAS'))
   OR (r.codigo='ALM' AND p.codigo='INV.TRANSFORMAR');
INSERT INTO unidad_medida(nombre,abreviatura,admite_decimales,magnitud,factor_referencia,precision_cantidad) VALUES
('Unidad','und',false,'CONTEO',1,0),
('Kilogramo','kg',true,'PESO',1,3),
('Gramo','g',false,'PESO',0.001,0),
('Metro','m',true,'LONGITUD',1,3),
('Centimetro','cm',true,'LONGITUD',0.01,1),
('Litro','L',true,'VOLUMEN',1,3),
('Mililitro','mL',false,'VOLUMEN',0.001,0);
REVOKE ALL ON ALL SEQUENCES IN SCHEMA huaman FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION huaman.completar_auditoria(), huaman.rechazar_mutacion() FROM PUBLIC, anon, authenticated, service_role;
COMMIT;

-- Resultado esperado: cuatro filas. Los permisos de aplicacion aun NO autentican usuarios.
SELECT 'rol' AS tabla, count(*) AS registros FROM huaman.rol
UNION ALL SELECT 'permiso',count(*) FROM huaman.permiso
UNION ALL SELECT 'rol_permiso',count(*) FROM huaman.rol_permiso
UNION ALL SELECT 'unidad_medida',count(*) FROM huaman.unidad_medida
ORDER BY tabla;

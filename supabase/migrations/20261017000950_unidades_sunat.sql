-- FERRETERIA HUAMAN - BLOQUE 09B - codigos SUNAT de unidades existentes
-- Requiere bloques 01 a 09. Ejecutar completo una sola vez.
-- Conserva IDs, abreviaturas, factores, precision y relaciones existentes.
-- Referencia: catalogo SUNAT 03 / unidades comerciales.
BEGIN;
SET LOCAL search_path TO huaman,pg_catalog;
SELECT set_config('app.usuario','MIGRACION_009B',true);
SELECT set_config('app.equipo','SQL_EDITOR',true);
DO $$ BEGIN
IF to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)') IS NULL THEN RAISE EXCEPTION 'Primero instalar bloque 09'; END IF;
IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='huaman' AND table_name='unidad_medida' AND column_name IN ('codigo_sunat','descripcion_comercial')) THEN
RAISE EXCEPTION 'Bloque 09B ya instalado o parcial: no reejecutar'; END IF;
IF (SELECT count(*) FROM huaman.unidad_medida WHERE abreviatura IN ('und','kg','g','m','cm','L','mL'))<>7
OR EXISTS(SELECT 1 FROM huaman.unidad_medida WHERE abreviatura NOT IN ('und','kg','g','m','cm','L','mL')) THEN
RAISE EXCEPTION 'Catalogo distinto a las siete unidades previstas; revisar mapeo antes de continuar'; END IF;
END $$;
ALTER TABLE huaman.unidad_medida ADD COLUMN codigo_sunat varchar(3);
ALTER TABLE huaman.unidad_medida ADD COLUMN descripcion_comercial varchar(80);
UPDATE huaman.unidad_medida u
SET codigo_sunat=m.codigo,descripcion_comercial=m.descripcion
FROM (VALUES
('und','NIU','Número de unidades'),
('kg','KGM','Kilogramos'),
('g','GRM','Gramos'),
('m','MTR','Metros'),
('cm','CMT','Centímetros'),
('L','LTR','Litros'),
('mL','MLT','Mililitros')
) AS m(abreviatura,codigo,descripcion)
WHERE u.abreviatura=m.abreviatura;
ALTER TABLE huaman.unidad_medida ALTER COLUMN codigo_sunat SET NOT NULL;
ALTER TABLE huaman.unidad_medida ALTER COLUMN descripcion_comercial SET NOT NULL;
ALTER TABLE huaman.unidad_medida ADD CONSTRAINT uq_unidad_codigo_sunat UNIQUE(codigo_sunat);
ALTER TABLE huaman.unidad_medida ADD CONSTRAINT ck_unidad_codigo_sunat_formato CHECK(codigo_sunat ~ '^[A-Z0-9]{2,3}$');
ALTER TABLE huaman.unidad_medida ADD CONSTRAINT ck_unidad_descripcion_comercial CHECK(btrim(descripcion_comercial)<>'');
COMMENT ON COLUMN huaman.unidad_medida.codigo_sunat IS 'Código comercial SUNAT; separado del símbolo visible. Verificar catálogo al incorporar otras unidades.';
COMMENT ON COLUMN huaman.unidad_medida.descripcion_comercial IS 'Etiqueta comercial legible; no sustituye factores o unidad base.';
COMMIT;
SELECT nombre AS unidad_fisica,codigo_sunat,descripcion_comercial,abreviatura AS simbolo
FROM huaman.unidad_medida ORDER BY id_unidad;

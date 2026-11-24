-- Clientes consultados en POS: la identificación permanece en el borrador;
-- el alta definitiva se realiza dentro de la transacción de confirmación.
BEGIN;
SET LOCAL lock_timeout='8s';
SET LOCAL statement_timeout='40s';
ALTER TABLE huaman.venta ADD COLUMN cliente_propuesto jsonb;
ALTER TABLE huaman.cliente ADD COLUMN datos_identificacion jsonb;
ALTER TABLE huaman.cliente ADD CONSTRAINT ck_cliente_identificacion CHECK(datos_identificacion IS NULL OR (jsonb_typeof(datos_identificacion)='object' AND octet_length(datos_identificacion::text)<=4096));
ALTER TABLE huaman.venta ADD CONSTRAINT ck_cliente_propuesto CHECK(cliente_propuesto IS NULL OR coalesce((id_cliente IS NULL AND estado_venta='BORRADOR' AND jsonb_typeof(cliente_propuesto)='object' AND octet_length(cliente_propuesto::text)<=8192 AND cliente_propuesto->>'tipoDocumento' IN ('DNI','RUC') AND cliente_propuesto->>'documento' ~ '^(?!0+$)([0-9]{8}|[0-9]{11})$' AND length(btrim(cliente_propuesto->>'nombre')) BETWEEN 3 AND 150 AND ((cliente_propuesto->>'tipoDocumento'='DNI' AND length(cliente_propuesto->>'documento')=8) OR (cliente_propuesto->>'tipoDocumento'='RUC' AND length(cliente_propuesto->>'documento')=11 AND length(btrim(cliente_propuesto->>'direccion')) BETWEEN 5 AND 200))),false));
DO $migration$
DECLARE definition text; old text; updated text; constraint_name name;
BEGIN
 SELECT conname INTO STRICT constraint_name FROM pg_constraint WHERE conrelid='huaman.venta'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%tipo_comprobante%' AND pg_get_constraintdef(oid) LIKE '%id_cliente%';
 EXECUTE format('ALTER TABLE huaman.venta DROP CONSTRAINT %I',constraint_name);
 ALTER TABLE huaman.venta ADD CONSTRAINT ck_venta_cliente_factura CHECK(tipo_comprobante<>'F' OR ((id_cliente IS NOT NULL OR (estado_venta='BORRADOR' AND cliente_propuesto IS NOT NULL)) AND cliente_tipo_doc='RUC' AND cliente_nro_doc ~ '^[0-9]{11}$' AND length(btrim(cliente_nombre))>=3 AND length(btrim(cliente_direccion))>=5));
 SELECT replace(pg_get_functiondef('huaman.validar_venta_borrador()'::regprocedure),E'\r','') INTO definition;
 old := $old$IF NEW.id_cliente IS NULL THEN
NEW.cliente_tipo_doc:=NULL;NEW.cliente_nro_doc:=NULL;NEW.cliente_nombre:='CLIENTE VARIOS';NEW.cliente_direccion:=NULL;
ELSE$old$;
 updated:=replace(definition,old,$new$IF NEW.id_cliente IS NULL THEN
 IF NEW.cliente_propuesto IS NULL THEN
  NEW.cliente_tipo_doc:=NULL;NEW.cliente_nro_doc:=NULL;NEW.cliente_nombre:='CLIENTE VARIOS';NEW.cliente_direccion:=NULL;
 ELSE
  NEW.cliente_tipo_doc:=NEW.cliente_propuesto->>'tipoDocumento';
  NEW.cliente_nro_doc:=NEW.cliente_propuesto->>'documento';
  NEW.cliente_nombre:=btrim(NEW.cliente_propuesto->>'nombre');
  NEW.cliente_direccion:=nullif(btrim(NEW.cliente_propuesto->>'direccion'),'');
 END IF;
ELSE$new$);
 IF updated=definition THEN RAISE EXCEPTION 'Revisar la versión del validador de venta antes de instalar'; END IF;
 definition:=updated;
 updated:=replace(definition,$old$(NEW.id_cliente IS NULL OR NEW.cliente_tipo_doc<>'RUC')$old$,$new$(NEW.cliente_tipo_doc IS DISTINCT FROM 'RUC' OR (NEW.id_cliente IS NULL AND NEW.cliente_propuesto IS NULL))$new$);
 IF updated=definition THEN RAISE EXCEPTION 'Revisar la validación del cliente con RUC'; END IF;
 EXECUTE updated;
END
$migration$;
COMMENT ON COLUMN huaman.venta.cliente_propuesto IS 'Identificación revisada para un cliente nuevo; solo en borrador. Alta y vinculación atómicas al confirmar.';
COMMENT ON COLUMN huaman.cliente.datos_identificacion IS 'Datos adicionales de la consulta RUC revisados en POS; independientes de la habilitación interna del cliente.';
COMMIT;

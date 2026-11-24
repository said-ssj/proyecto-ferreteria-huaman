-- Only executed in a disposable loopback database by RepositoryPerformanceDatabaseTest.
-- All business triggers and constraints remain enabled.
SELECT set_config('app.usuario','workflow.admin',true),set_config('app.equipo','PERFORMANCE_TEST',true);
SET LOCAL statement_timeout='240s';
DO $$
DECLARE category_id bigint; unit_id bigint; actor_id bigint; cash_id bigint; series_id bigint;
        product_id bigint; presentation_id bigint; sale_id bigint; operation uuid; i integer;
BEGIN
 SELECT id_usuario INTO STRICT actor_id FROM huaman.usuario WHERE username='workflow.admin';
 INSERT INTO huaman.categoria(nombre) VALUES('Catálogo de rendimiento') RETURNING id_categoria INTO category_id;
 SELECT id_unidad INTO STRICT unit_id FROM huaman.unidad_medida WHERE codigo_sunat='NIU';
 INSERT INTO huaman.producto(codigo,nombre,id_categoria,id_unidad,stock_minimo)
 SELECT 'PF'||lpad(n::text,5,'0'),'Herramienta de prueba '||lpad(n::text,5,'0'),category_id,unit_id,5 FROM generate_series(1,10000) n;
 INSERT INTO huaman.presentacion_producto(id_producto,nombre,id_unidad_venta,factor_base,es_base,precio_normal)
 SELECT id_producto,'Unidad',unit_id,1,true,10 FROM huaman.producto WHERE id_categoria=category_id;
 INSERT INTO huaman.codigo_presentacion(id_presentacion,codigo,simbologia)
 SELECT b.id_presentacion,'BC'||p.codigo,'CODE128' FROM huaman.presentacion_producto b JOIN huaman.producto p USING(id_producto) WHERE p.id_categoria=category_id;
 FOR product_id IN SELECT id_producto FROM huaman.producto WHERE id_categoria=category_id ORDER BY id_producto LOOP
  PERFORM huaman.apertura_stock(product_id,1000,2,gen_random_uuid(),'[]'::jsonb);
 END LOOP;
 UPDATE huaman.parametro_sistema SET valor='20123456789' WHERE clave='NEGOCIO.RUC';
 UPDATE huaman.parametro_sistema SET valor='Dirección de prueba local' WHERE clave='NEGOCIO.DIRECCION';
 cash_id:=huaman.abrir_caja(0,gen_random_uuid(),'Caja exclusiva de rendimiento');
 SELECT min(id_serie) INTO series_id FROM huaman.serie_comprobante WHERE tipo_comprobante='N' AND estado='A';
 FOR i IN 1..3000 LOOP
  SELECT p.id_producto,b.id_presentacion INTO product_id,presentation_id FROM huaman.producto p
   JOIN huaman.presentacion_producto b USING(id_producto) WHERE p.codigo='PF'||lpad((((i-1)%100)+1)::text,5,'0') AND b.es_base;
  operation:=gen_random_uuid();
  INSERT INTO huaman.venta(id_caja,id_vendedor,tipo_comprobante,entrega_inmediata,clave_idempotencia,igv_porcentaje)
  VALUES(cash_id,actor_id,'N',true,operation,18) RETURNING id_venta INTO sale_id;
  INSERT INTO huaman.detalle_venta(id_venta,id_producto,id_presentacion,cantidad) VALUES(sale_id,product_id,presentation_id,1);
  INSERT INTO huaman.pago(id_venta,medio,monto,monto_recibido,vuelto) VALUES(sale_id,'EFECTIVO',10,10,0);
  PERFORM huaman.confirmar_venta(sale_id,series_id,operation,'[]'::jsonb);
 END LOOP;
END $$;
SET CONSTRAINTS ALL IMMEDIATE;

-- FERRETERIA HUAMAN - BLOQUE25 - REVISION SOLO LECTURA
-- Requiere01 a24. No crea funciones/tablas/usuarios ni cambia datos o permisos.
-- OK = control satisfecho; REVISAR = requiere analizar; INFO = inventario de estado.
-- No muestra hashes, claves ni datos identificatorios de personas.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
WITH esperadas(nombre) AS (VALUES
('abono_credito'),
('ajuste_inventario'),
('alerta_stock'),
('archivo_comprobante'),
('asignacion_existencia_venta'),
('bitacora_evento'),
('caja_diaria'),
('categoria'),
('cliente'),
('codigo_presentacion'),
('comprobante_venta'),
('cotizacion'),
('cuenta_por_cobrar'),
('despacho'),
('detalle_cotizacion'),
('detalle_devolucion'),
('detalle_ingreso'),
('detalle_orden_compra'),
('detalle_toma_inventario'),
('detalle_transformacion_stock'),
('detalle_venta'),
('devolucion'),
('historial_costo'),
('ingreso_mercaderia'),
('motivo_ajuste'),
('movimiento_caja'),
('movimiento_inventario'),
('oferta'),
('orden_compra'),
('pago'),
('parametro_sistema'),
('permiso'),
('precio_mayorista'),
('presentacion_producto'),
('producto'),
('proveedor'),
('rol'),
('rol_permiso'),
('serie_comprobante'),
('sesion_usuario'),
('toma_inventario'),
('transformacion_stock'),
('unidad_existencia'),
('unidad_medida'),
('usuario'),
('venta')), procesos(firma) AS (VALUES
('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'),
('huaman.emitir_orden_compra(bigint,uuid)'),
('huaman.confirmar_ingreso(bigint,uuid)'),
('huaman.abrir_caja(numeric,uuid,text)'),
('huaman.registrar_movimiento_caja(bigint,text,numeric,text,uuid)'),
('huaman.cerrar_caja(bigint,numeric,numeric,numeric,text,uuid)'),
('huaman.confirmar_venta(bigint,bigint,uuid,jsonb)'),
('huaman.descartar_venta(bigint,uuid,text)'),
('huaman.registrar_abono(bigint,bigint,numeric,text,uuid,text,text,text,text)'),
('huaman.preparar_despacho(bigint,uuid,text)'),
('huaman.entregar_despacho(bigint,uuid,text,text)'),
('huaman.abrir_envase(bigint,uuid,text)'),
('huaman.cortar_tramo(bigint,jsonb,uuid,text)'),
('huaman.registrar_ajuste(bigint,text,numeric,bigint,text,uuid,jsonb)'),
('huaman.iniciar_toma(text,bigint,uuid,text)'),
('huaman.guardar_conteo(bigint,bigint,numeric,integer,uuid,jsonb)'),
('huaman.cerrar_toma(bigint,integer,uuid)'),
('huaman.reabrir_toma(bigint,integer,uuid,text)'),
('huaman.anular_toma(bigint,integer,uuid,text)'),
('huaman.aprobar_toma(bigint,integer,uuid,text)'),
('huaman.emitir_cotizacion(bigint,uuid)'),
('huaman.anular_cotizacion(bigint,uuid,text)'),
('huaman.convertir_cotizacion(bigint,bigint,text,uuid)'),
('huaman.recalcular_cotizacion(bigint,integer,uuid)'),
('huaman.solicitar_devolucion(bigint,text,text,jsonb,uuid)'),
('huaman.rechazar_devolucion(bigint,uuid,text)'),
('huaman.aprobar_devolucion(bigint,bigint,uuid,text,text)'),
('huaman.anular_venta(bigint,uuid,text,boolean,jsonb,jsonb)'),
('huaman.anular_orden_compra(bigint,uuid,text)'),
('huaman.anular_ingreso_borrador(bigint,uuid,text)')), tablas AS (
SELECT c.oid,c.relname,c.relrowsecurity,c.relowner FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='huaman' AND c.relkind='r'
), funciones AS (
SELECT p.* FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='huaman'
), roles_api AS (SELECT oid,rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role')),
controles(orden,control,valor,esperado,bien,informativo) AS (
SELECT 1,'Tablas esperadas',count(*)::text,'46',count(*)=46,false FROM tablas WHERE relname IN (SELECT nombre FROM esperadas)
UNION ALL SELECT 2,'Tablas faltantes',count(*)::text,'0',count(*)=0,false FROM esperadas e WHERE NOT EXISTS(SELECT 1 FROM tablas t WHERE t.relname=e.nombre)
UNION ALL SELECT 3,'Tablas adicionales',count(*)::text,'0',count(*)=0,false FROM tablas WHERE relname NOT IN(SELECT nombre FROM esperadas)
UNION ALL SELECT 4,'Procesos operativos instalados',count(*)::text,'30',count(*)=30,false FROM procesos WHERE to_regprocedure(firma) IS NOT NULL
UNION ALL SELECT 5,'Tablas sin RLS',count(*)::text,'0',count(*)=0,false FROM tablas WHERE NOT relrowsecurity
UNION ALL SELECT 6,'Politicas Data API en esquema privado',count(*)::text,'0',count(*)=0,false FROM pg_policy WHERE polrelid IN(SELECT oid FROM tablas)
UNION ALL SELECT 7,'Roles API presentes',count(*)::text,'3',count(*)=3,false FROM roles_api
UNION ALL SELECT 8,'Accesos API al esquema',count(*)::text,'0',count(*)=0,false FROM roles_api r CROSS JOIN pg_namespace n WHERE n.nspname='huaman' AND (has_schema_privilege(r.oid,n.oid,'USAGE') OR has_schema_privilege(r.oid,n.oid,'CREATE'))
UNION ALL SELECT 9,'Permisos PUBLIC al esquema',count(*)::text,'0',count(*)=0,false FROM pg_namespace n CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a WHERE n.nspname='huaman' AND a.grantee=0
UNION ALL SELECT 10,'Permisos API a tablas',count(*)::text,'0',count(*)=0,false FROM roles_api r CROSS JOIN tablas t WHERE has_table_privilege(r.oid,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
UNION ALL SELECT 11,'Permisos PUBLIC a tablas',count(*)::text,'0',count(*)=0,false FROM pg_class c CROSS JOIN LATERAL aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a WHERE c.oid IN(SELECT oid FROM tablas) AND a.grantee=0
UNION ALL SELECT 12,'Ejecuciones API de funciones',count(*)::text,'0',count(*)=0,false FROM roles_api r CROSS JOIN funciones p WHERE has_function_privilege(r.oid,p.oid,'EXECUTE')
UNION ALL SELECT 13,'Ejecuciones PUBLIC de funciones',count(*)::text,'0',count(*)=0,false FROM funciones p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE'
UNION ALL SELECT 14,'Permisos API a secuencias',count(*)::text,'0',count(*)=0,false FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN roles_api r WHERE n.nspname='huaman' AND c.relkind='S' AND has_sequence_privilege(r.oid,c.oid,'USAGE,SELECT,UPDATE')
UNION ALL SELECT 15,'Permisos PUBLIC a secuencias',count(*)::text,'0',count(*)=0,false FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(coalesce(c.relacl,acldefault('S',c.relowner))) a WHERE n.nspname='huaman' AND c.relkind='S' AND a.grantee=0
UNION ALL SELECT 16,'Funciones con propietario diferente',count(*)::text,'0',count(*)=0,false FROM funciones p WHERE p.proowner<>(SELECT proowner FROM funciones WHERE oid=to_regprocedure('huaman.apertura_stock(bigint,numeric,numeric,uuid,jsonb)'))
UNION ALL SELECT 17,'SECURITY DEFINER sin ruta segura',count(*)::text,'0',count(*)=0,false FROM funciones p WHERE p.prosecdef AND NOT EXISTS(SELECT 1 FROM unnest(p.proconfig) cfg WHERE replace(cfg,' ','')='search_path=pg_catalog,pg_temp')
UNION ALL SELECT 18,'Tablas con auditoria incompleta',count(*)::text,'0',count(*)=0,false FROM tablas t WHERE (SELECT count(*) FROM pg_attribute a WHERE a.attrelid=t.oid AND a.attnum>0 AND NOT a.attisdropped AND a.attname IN ('usucre','pccre','feccre','usmod','pcmod','fecmod','estado'))<>7
UNION ALL SELECT 19,'Guardas de auditoria/borrado faltantes',count(*)::text,'0',count(*)=0,false FROM tablas t CROSS JOIN (VALUES('auditoria'),('no_delete'),('no_truncate')) requeridos(nombre) WHERE NOT EXISTS(SELECT 1 FROM pg_trigger g WHERE g.tgrelid=t.oid AND g.tgname=requeridos.nombre AND g.tgenabled IN ('O','A') AND NOT g.tgisinternal)
UNION ALL SELECT 20,'Registros historicos sin guarda inmutable',count(*)::text,'0',count(*)=0,false FROM tablas t WHERE t.relname IN ('bitacora_evento','movimiento_inventario','movimiento_caja','historial_costo') AND NOT EXISTS(SELECT 1 FROM pg_trigger g WHERE g.tgrelid=t.oid AND g.tgname='inmutable' AND g.tgenabled IN ('O','A'))
UNION ALL SELECT 21,'Disparadores operativos deshabilitados',count(*)::text,'0',count(*)=0,false FROM pg_trigger WHERE tgrelid IN(SELECT oid FROM tablas) AND NOT tgisinternal AND tgenabled NOT IN ('O','A')
UNION ALL SELECT 22,'Restricciones sin validar',count(*)::text,'0',count(*)=0,false FROM pg_constraint WHERE conrelid IN(SELECT oid FROM tablas) AND NOT convalidated
UNION ALL SELECT 23,'Indices invalidos o incompletos',count(*)::text,'0',count(*)=0,false FROM pg_index WHERE indrelid IN(SELECT oid FROM tablas) AND (NOT indisvalid OR NOT indisready)
UNION ALL SELECT 24,'Roles funcionales activos',count(*)::text,'4',count(*)=4,false FROM huaman.rol WHERE codigo IN ('ADM','VEN','ALM','AYU') AND estado='A'
UNION ALL SELECT 25,'VEN con gestion de despachos activa',count(*)::text,'0',count(*)=0,false FROM huaman.rol_permiso rp JOIN huaman.rol r USING(id_rol) JOIN huaman.permiso p USING(id_permiso) WHERE r.codigo='VEN' AND p.codigo='DES.GESTIONAR' AND rp.estado='A'
UNION ALL SELECT 26,'Unidades sin codigo SUNAT',count(*)::text,'0',count(*)=0,false FROM huaman.unidad_medida WHERE codigo_sunat IS NULL OR btrim(codigo_sunat)=''
UNION ALL SELECT 27,'Productos con saldo distinto al kardex',count(*)::text,'0',count(*)=0,false FROM huaman.producto p WHERE stock_actual<>(SELECT coalesce(sum(CASE WHEN sentido='E' THEN cantidad ELSE -cantidad END),0) FROM huaman.movimiento_inventario m WHERE m.id_producto=p.id_producto)
UNION ALL SELECT 28,'Productos con saldo fisico inconsistente',count(*)::text,'0',count(*)=0,false FROM huaman.producto p WHERE modo_control IN ('ENVASES','TRAMOS') AND stock_actual<>(SELECT coalesce(sum(cantidad_disponible_base),0) FROM huaman.unidad_existencia u WHERE u.id_producto=p.id_producto AND u.estado='A')
UNION ALL SELECT 29,'Saltos en cadena del kardex',count(*)::text,'0',count(*)=0,false FROM (SELECT saldo_anterior,lag(saldo,1,0::numeric) OVER(PARTITION BY id_producto ORDER BY id_movimiento) previo FROM huaman.movimiento_inventario) k WHERE saldo_anterior<>previo
UNION ALL SELECT 30,'Cuentas por cobrar sin conciliacion',count(*)::text,'0',count(*)=0,false FROM huaman.cuenta_por_cobrar cc WHERE saldo<>(CASE WHEN estado_cuenta='ANULADA' THEN 0 ELSE monto_original-(SELECT coalesce(sum(monto),0) FROM huaman.abono_credito a WHERE a.id_cuenta=cc.id_cuenta AND a.estado='A')-(SELECT coalesce(sum(monto_reintegro),0) FROM huaman.devolucion d WHERE d.id_venta=cc.id_venta AND d.estado='A' AND d.estado_devolucion='APROBADA' AND d.forma_reintegro='DESCUENTO_DEUDA') END)
UNION ALL SELECT 31,'Ventas y comprobantes sin concordancia',count(*)::text,'0',count(*)=0,false FROM huaman.venta v LEFT JOIN huaman.comprobante_venta c USING(id_venta) WHERE (v.estado_venta IN ('CONFIRMADA','ANULADA') AND (c.id_comprobante IS NULL OR c.total<>v.total OR c.estado_comprobante<>CASE WHEN v.estado_venta='ANULADA' THEN 'ANULADO' ELSE 'EMITIDO' END)) OR (v.estado_venta='BORRADOR' AND c.id_comprobante IS NOT NULL)
UNION ALL SELECT 32,'Series con correlativo menor al utilizado',count(*)::text,'0',count(*)=0,false FROM huaman.serie_comprobante s WHERE ultimo_correlativo<(SELECT coalesce(max(numero),0) FROM huaman.comprobante_venta c WHERE c.id_serie=s.id_serie)
UNION ALL SELECT 33,'Recepciones de orden sin conciliacion',count(*)::text,'0',count(*)=0,false FROM huaman.detalle_orden_compra d WHERE cantidad_recibida_base<>(SELECT coalesce(sum(di.cantidad_base),0) FROM huaman.detalle_ingreso di JOIN huaman.ingreso_mercaderia i USING(id_ingreso) WHERE di.id_detalle_oc=d.id_detalle_oc AND di.estado='A' AND i.estado='A' AND i.estado_ingreso='CONFIRMADO')
UNION ALL SELECT 34,'Ordenes anuladas con saldo por cancelar',count(*)::text,'0',count(*)=0,false FROM huaman.detalle_orden_compra d JOIN huaman.orden_compra o USING(id_orden_compra) WHERE o.estado_orden='ANULADA' AND d.estado='A' AND d.cantidad_base<>d.cantidad_recibida_base+d.cantidad_cancelada_base
UNION ALL SELECT 35,'Cajas cerradas sin conciliacion de ledger',count(*)::text,'0',count(*)=0,false FROM huaman.caja_diaria c WHERE estado_caja='CERRADA' AND (efectivo_esperado<>(SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) FROM huaman.movimiento_caja m WHERE m.id_caja=c.id_caja AND medio='EFECTIVO') OR yape_esperado<>(SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) FROM huaman.movimiento_caja m WHERE m.id_caja=c.id_caja AND medio='YAPE') OR debito_esperado<>(SELECT coalesce(sum(CASE WHEN sentido='I' THEN importe ELSE -importe END),0) FROM huaman.movimiento_caja m WHERE m.id_caja=c.id_caja AND medio='DEBITO'))
UNION ALL SELECT 36,'Tomas aprobadas sin aplicacion concordante',count(*)::text,'0',count(*)=0,false FROM huaman.detalle_toma_inventario d JOIN huaman.toma_inventario t USING(id_toma) WHERE t.estado_toma='APROBADA' AND ((d.estado_linea='CONTADA' AND (d.diferencia_aplicada IS NULL OR d.stock_previo_aprobacion IS NULL)) OR (d.estado_linea='PENDIENTE' AND d.diferencia_aplicada IS NOT NULL))
UNION ALL SELECT 37,'Devoluciones aprobadas sin efecto financiero',count(*)::text,'0',count(*)=0,false FROM huaman.devolucion d WHERE estado_devolucion='APROBADA' AND ((forma_reintegro='DESCUENTO_DEUDA' AND (NOT EXISTS(SELECT 1 FROM huaman.cuenta_por_cobrar cc WHERE cc.id_venta=d.id_venta) OR EXISTS(SELECT 1 FROM huaman.movimiento_caja m WHERE m.id_devolucion=d.id_devolucion))) OR (forma_reintegro<>'DESCUENTO_DEUDA' AND NOT EXISTS(SELECT 1 FROM huaman.movimiento_caja m WHERE m.id_devolucion=d.id_devolucion AND m.tipo_movimiento='DEVOLUCION' AND m.medio=d.forma_reintegro AND m.importe=d.monto_reintegro AND m.sentido='E')))
UNION ALL SELECT 90,'Usuarios registrados',count(*)::text,'0 antes de crear accesos',true,true FROM huaman.usuario
UNION ALL SELECT 91,'Administradores activos',count(*)::text,'0 antes de crear accesos',true,true FROM huaman.usuario u JOIN huaman.rol r USING(id_rol) WHERE u.estado='A' AND r.estado='A' AND r.codigo='ADM'
UNION ALL SELECT 92,'Productos registrados',count(*)::text,'0 si solo se instalaron bloques',true,true FROM huaman.producto
UNION ALL SELECT 93,'Ventas registradas',count(*)::text,'0 si solo se instalaron bloques',true,true FROM huaman.venta
UNION ALL SELECT 94,'Version PostgreSQL',current_setting('server_version'),'Informativo; validar en servidor real',true,true
)
SELECT control,CASE WHEN informativo THEN 'INFO' WHEN bien THEN 'OK' ELSE 'REVISAR' END AS resultado,valor AS encontrado,esperado
FROM controles ORDER BY orden;
COMMIT;

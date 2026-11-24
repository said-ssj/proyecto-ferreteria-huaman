# Base de datos

Scripts versionados para PostgreSQL en Supabase, esquema `huaman`.

## Contenido

- `migrations/`: estructura, restricciones, roles funcionales, permisos y procesos comerciales. Hay 27 scripts; el ajuste de unidades SUNAT tiene una numeración intermedia.
- `diagnostics/`: revisión de solo lectura del esquema y procesos instalados.

Los scripts se conservan como fuente del esquema. Para una base nueva, revisar los requisitos de cada archivo y aplicar en orden de nombre. No volver a ejecutar la instalación completa sobre una base que ya contiene las tablas. La aplicación no los ejecuta automáticamente y esta carpeta no configura por sí sola un despliegue mediante CLI.

## Datos y operaciones

No se incluyen exportaciones de usuarios, contraseñas, clientes, proveedores, existencias ni ventas reales. Los datos iniciales de las migraciones corresponden a catálogos y parámetros del sistema.

La carga de productos debe respetar categorías, unidades, presentación base y contexto de auditoría. Las existencias y costos se registran mediante apertura de inventario o ingresos de mercadería. Los movimientos de caja, saldos, pagos y auditoría se generan mediante los procesos correspondientes.

Mantener las credenciales de conexión en el archivo privado del backend. No incluirlas en scripts, documentación o código del frontend.

## Actualización de identidad visual

`20261025000100_identidad_visual.sql` agrega la tabla de configuración `huaman.identidad_visual` y cambia el nombre visible de ADM a «Administrador/a». No modifica las asignaciones de permisos. El logo es opcional; no se inserta una imagen de ejemplo. Instalar esta migración una sola vez después de las anteriores y antes de utilizar el backend con la configuración de logo/favicon.

## Actualización de imágenes de productos

`20261026000100_imagen_producto.sql` añade `huaman.producto_imagen`: una miniatura JPEG opcional por producto, hasta 64 KiB, con FK, hash y auditoría. Aplica después de identidad visual y antes de iniciar el backend actualizado. No requiere Storage ni contiene imágenes iniciales. La aplicación accede mediante el backend autenticado; se mantienen RLS y revocación de acceso directo.

## Clientes nuevos en el punto de venta

`20261124015130_pos_clientes_diferidos.sql` incorpora la identificación provisional en el borrador y los datos fiscales adicionales del cliente. Aplicar una vez sobre el esquema actualizado, antes de iniciar el backend con esta funcionalidad. La migración verifica la versión del validador de ventas y conserva sus demás controles; no cambia permisos ni RLS.

La búsqueda de DNI o RUC consulta primero los registros internos. Si el documento no existe, utiliza Decolecta (RENIEC para DNI y SUNAT para RUC). Consultar o descartar un borrador no crea un cliente. El backend crea o reutiliza al cliente al confirmar la venta, dentro de la misma transacción; un fallo revierte también el alta. La consulta de identificación no constituye emisión de comprobantes electrónicos.

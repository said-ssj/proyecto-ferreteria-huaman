# Base de datos

Scripts versionados para PostgreSQL en Supabase, esquema `huaman`.

## Contenido

- `migrations/`: estructura, restricciones, roles funcionales, permisos y procesos comerciales. Hay 25 scripts; el ajuste de unidades SUNAT tiene una numeración intermedia.
- `diagnostics/`: revisión de solo lectura del esquema y procesos instalados.

Los scripts se conservan como fuente del esquema. Para una base nueva, revisar los requisitos de cada archivo y aplicar en orden de nombre. No volver a ejecutar la instalación completa sobre una base que ya contiene las tablas. La aplicación no los ejecuta automáticamente y esta carpeta no configura por sí sola un despliegue mediante CLI.

## Datos y operaciones

No se incluyen exportaciones de usuarios, contraseñas, clientes, proveedores, existencias ni ventas reales. Los datos iniciales de las migraciones corresponden a catálogos y parámetros del sistema.

La carga de productos debe respetar categorías, unidades, presentación base y contexto de auditoría. Las existencias y costos se registran mediante apertura de inventario o ingresos de mercadería. Los movimientos de caja, saldos, pagos y auditoría se generan mediante los procesos correspondientes.

Mantener las credenciales de conexión en el archivo privado del backend. No incluirlas en scripts, documentación o código del frontend.

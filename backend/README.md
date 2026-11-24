# Backend

API de Java 21 y Spring Boot 3.4.5. Utiliza PostgreSQL, Spring Security y transacciones para acceder al esquema `huaman` de Supabase.

## Configuración privada

Copiar `.env.example` como `.env` dentro de esta carpeta. Ejecutar siempre con esta carpeta como directorio de trabajo para cargar el archivo y resolver las rutas de certificados.

| Variable | Uso |
|---|---|
| SERVER_PORT | Puerto HTTP; 8080 por defecto |
| SPRING_PROFILES_ACTIVE | `local`, `local,db` o `prod,db` |
| SPRING_DATASOURCE_URL | URL JDBC de PostgreSQL con TLS |
| SPRING_DATASOURCE_USERNAME | Usuario de base de datos |
| SPRING_DATASOURCE_PASSWORD | Contraseña privada de base de datos |
| CORS_ALLOWED_ORIGINS | Orígenes exactos autorizados, separados por coma |
| DB_POOL_SIZE | Tamaño máximo del pool; 5 por defecto |

El perfil `db` habilita la conexión real. Sin él, el arranque local no proporciona acceso a los módulos de datos. El perfil `prod` requiere configurar los orígenes permitidos; no habilita los de desarrollo de forma implícita.

Utilizar el pooler de Supabase en modo sesión para las transacciones JDBC. La URL debe conservar la verificación TLS completa. El certificado público de referencia está en `certs/prod-ca-2021.crt`; no es una clave privada.

## Ejecución

Desde esta carpeta en Windows:

```text
mvnw.cmd spring-boot:run
```

En otros sistemas utilizar `./mvnw`. El endpoint `GET /actuator/health` es público y no muestra detalles internos. Su estado por sí solo no demuestra que una operación comercial funcione.

## Verificación y empaquetado

```text
mvnw.cmd verify
mvnw.cmd package
```

Las pruebas de integración contra una base real requieren su configuración explícita; no deben confundirse con las pruebas ordinarias que se ejecutan sin ella. Revisar las condiciones de cada clase de prueba antes de habilitarlas.

## Administrador inicial

Para una base nueva sin usuarios, completar privadamente `BOOTSTRAP_ADMIN_USUARIO`, `BOOTSTRAP_ADMIN_NOMBRES`, `BOOTSTRAP_ADMIN_APELLIDOS` y `BOOTSTRAP_ADMIN_DNI`. Compilar el artefacto de alta con:

```text
mvnw.cmd package -Dbackend.artifact-name=ferreteria-huaman-admin
```

Después ejecutar `crear-administrador.cmd` en una consola interactiva. La contraseña se introduce de forma oculta y no se guarda en el código. La utilidad se niega a continuar si ya existen usuarios. El perfil de alta no se utiliza para la ejecución habitual.

## Reglas de operación

Las peticiones de negocio requieren autenticación y permisos del servidor. Los costos, stock, saldos e identificación del actor se determinan en el backend o en procesos SQL; no se aceptan libremente desde la interfaz. Las contraseñas se verifican con BCrypt y las sesiones usan tokens opacos.

Hibernate no crea ni actualiza el esquema y la inicialización SQL automática está desactivada. Consultar [Supabase](../supabase/README.md) y los documentos funcionales en `docs/`. El [README general](../README.md) describe las áreas pendientes.

Administración de usuarios y consulta de roles conectadas: [contratos y verificación](docs/USUARIOS_ROLES.md).

Configuración general, series y etiquetas conectadas: [alcance y verificación](docs/CONFIGURACION_SERIES_IMPRESION.md).

Bitácora conectada: [consulta, filtros y protección de datos](docs/BITACORA.md).

Reportes y gráficos conectados: [criterios de cálculo y verificación](docs/REPORTES.md).

Edición de permisos por perfil: [contratos, protección y pruebas](docs/ROLES_PERMISOS.md).

Laboratorio XML local sin firma ni envío fiscal: [alcance y verificación](docs/XML_PRUEBAS.md).


Los recorridos operativos completos se verifican en `AuditWorkflowDatabaseTest`: compra/ingreso/venta/despacho/devolución/cierre y compra/venta a crédito/abonos/cierre. Requieren `HUAMAN_DB_INTEGRATION=true`, base de pruebas configurada y administrador de pruebas. Conservan la guarda que omite escenarios si existe una caja del día; usar una base aislada para ejecutarlos sin interferir con el negocio. Las transacciones se revierten y se verifica la limpieza del escenario.

## Concurrencia y reintentos

`ConcurrencyDatabaseTest` ejecuta transacciones con confirmaciones reales en conexiones separadas. Comprueba ventas de la última unidad, solicitudes duplicadas, abonos superiores al saldo combinado y cierre de caja frente a cobros, confirmaciones y devoluciones, en ambos órdenes. También verifica que los bloqueos de cuentas sigan serializando los cambios de seguridad.

Esta batería requiere **PostgreSQL local desechable**; no se ejecuta con las credenciales habituales ni con `HUAMAN_DB_INTEGRATION`. Preparar una base local `huaman_concurrency_template` con las migraciones del proyecto y únicamente datos iniciales, sin productos, ventas, cajas ni usuarios del negocio. Marcarla con `COMMENT ON DATABASE huaman_concurrency_template IS 'HUAMAN_DISPOSABLE_CONCURRENCY_TEMPLATE'`.

En PowerShell, desde `backend`, configurar para ese proceso:

```powershell
$env:HUAMAN_CONCURRENCY_DB='true'
$env:HUAMAN_CONCURRENCY_TEMPLATE_URL='jdbc:postgresql://127.0.0.1:55439/huaman_concurrency_template'
.\mvnw.cmd -q '-Dtest=ConcurrencyDatabaseTest' test
```

El servidor local debe permitir al usuario técnico `postgres` sin contraseña crear y eliminar bases de prueba; esto corresponde exclusivamente al entorno desechable enlazado a loopback. La prueba valida host, nombre y marcador, ignora la importación de `.env`, crea un clon por caso y elimina solamente ese clon al terminar. No utiliza `TRUNCATE` ni desactiva disparadores; tampoco modifica la plantilla. Si se interrumpe abruptamente la JVM, pueden quedar clones locales con prefijo `huaman_race_` para revisar.

## Permisos de acceso a la API

`PermissionBoundaryApiTest` descubre las rutas de los controladores y comprueba autenticación, ausencia de permisos, contraseña temporal y acceso con todos los permisos declarados en las migraciones. Incluye combinaciones representativas de ventas, almacén y ayudante, sesiones vencidas y rechazo de borrado físico/rutas desconocidas.

```text
mvnw.cmd -q -Dtest=PermissionBoundaryApiTest test
```

No requiere una base de datos. Usa filtros de seguridad y asignación de rutas reales con servicios simulados. Un interceptor exclusivo de pruebas confirma que una petición autorizada llegó al controlador sin ejecutar el negocio; las pruebas de servicios e integración comprueban por separado propiedad, restricciones por rol, costos y cambios de permisos antes de escribir. Las combinaciones de permisos operativos son casos de prueba configurables, no una copia de la matriz actual de Supabase.

## Medición de consultas

`RepositoryPerformanceDatabaseTest` mide los repositorios reales con HikariCP, 10 000 productos/códigos, 3 000 ventas confirmadas y 13 000 movimientos de inventario. Usa la misma plantilla local marcada de las pruebas de concurrencia, sin importar `.env` ni conectarse a Supabase. El usuario local `workflow.admin` debe existir en la plantilla, sin datos comerciales ni otras cuentas. Cada ejecución crea y elimina su propio clon `huaman_perf_`.

```powershell
$env:HUAMAN_PERFORMANCE_DB='true'
$env:HUAMAN_PERFORMANCE_TEMPLATE_URL='jdbc:postgresql://127.0.0.1:55439/huaman_concurrency_template'
.\mvnw.cmd -q '-Dtest=RepositoryPerformanceDatabaseTest' '-Dhuaman.performance.run=baseline' test
```

El resultado queda en `target/performance-baseline.json`, con medianas, máximos, muestras y planes de catálogo/código de barras. La preparación conserva disparadores y restricciones; puede tardar varios minutos. Cada consulta se calienta dos veces y se mide siete veces, comprobando también sus resultados. No impone tiempos absolutos de CI ni representa latencia HTTP, red de Supabase o carga simultánea de usuarios.

## Identidad visual del negocio

La migración `20261025000100_identidad_visual.sql` incorpora un único logo compartido y normaliza el nombre del rol ADM a «Administrador/a». Debe instalarse una sola vez antes de usar las rutas nuevas; las migraciones no se ejecutan automáticamente.

- `GET /api/identidad-visual`: nombre comercial, ruta del logo, opción de favicon y versión. Es público para representar el ingreso y no devuelve otros parámetros del negocio.
- `GET /api/identidad-visual/logo/{sha256}`: PNG normalizado, identificado por su contenido, con caché pública y `nosniff`.
- `PUT /api/identidad-visual`: requiere sesión, permiso `CFG.PARAMETROS` y rol ADM vigente. Admite imagen Base64, quitar logo, opción de favicon y versión de concurrencia.

Se aceptan PNG/JPEG de hasta 512 KB y 2048 × 2048 píxeles. El servidor comprueba contenido y dimensiones antes de decodificar completamente, y genera un PNG cuadrado de 256 px conservando proporción y transparencia. La imagen normalizada pequeña se guarda en una tabla de configuración, protegida con RLS y sin acceso directo para roles públicos. La auditoría conserva únicamente metadatos, sin Base64 ni bytes de imagen. No requiere claves de Storage ni cambia el modelo de fotografías del catálogo.

## Imágenes de productos

Instalar una sola vez `20261026000100_imagen_producto.sql` antes de iniciar esta versión. Añade miniaturas opcionales en `huaman.producto_imagen`, sin originales ni imágenes iniciales.

- `GET /api/productos/{id}/imagen`: hash y versión; permisos de lectura del catálogo.
- `GET /api/productos/{id}/imagen/{hash}`: JPEG privado autenticado, `no-store`, `nosniff`.
- `PUT /api/productos/{id}/imagen`: `PRO.GESTIONAR`; imagen Base64 o quitarImagen, más versión. Revalida permisos y sesión en la transacción, bloquea el producto y rechaza versiones obsoletas.

Solo PNG/JPEG de hasta 2 MiB y 4096 × 4096. Normaliza a 320 × 320 sin distorsión, JPEG de hasta 64 KiB y sin metadatos. Auditoría sin contenido binario; no modifica costos, stock ni otros campos del producto.

## Consulta RUC con Decolecta

Configurar `DECOLECTA_API_KEY` en el archivo privado `backend/.env` y reiniciar el backend. La consulta autenticada `GET /api/consultas/ruc?numero=RUC` requiere `CLI.GESTIONAR` o `PRV.GESTIONAR`. Solo el servidor llama al proveedor por HTTPS y cabecera Authorization. La respuesta no incluye la clave.

Los formularios de clientes y proveedores permiten consultar el RUC y aplicar razón social y dirección antes de guardar. Estado tributario, condición y ubicación se muestran para consulta; no se añaden columnas de BD. Se conserva el ingreso manual ante fallos. Caché de respuestas correctas en memoria durante 10 minutos (hasta 64 RUC), una petición externa simultánea y separación de 2 segundos entre consultas nuevas. La caché se vacía al reiniciar. No se reintentan llamadas automáticamente.

Esta integración utiliza el endpoint básico de RUC. DNI, tipo de cambio y emisión tributaria no forman parte de este cambio. En Render se configura la misma variable privada y se despliega el backend actualizado.

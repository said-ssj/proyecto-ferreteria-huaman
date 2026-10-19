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

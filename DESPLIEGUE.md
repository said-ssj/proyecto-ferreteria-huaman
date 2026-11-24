# Despliegue en Render y Vercel

El mismo repositorio contiene el backend de Spring Boot, el frontend de Angular y las migraciones de PostgreSQL. Render ejecuta el backend, Vercel sirve la aplicación web y Supabase conserva los datos.

## 1. Preparar el repositorio y Supabase

- Sube el contenido de la carpeta de publicación a GitHub, incluida la configuración de despliegue. Mantén el archivo privado del backend fuera del repositorio.
- En el panel de Supabase, confirma que el proyecto esté activo. Para una base nueva, aplica los SQL de `supabase/migrations` en orden. En una base existente, aplica solo las migraciones pendientes. El backend no ejecuta migraciones durante el arranque.
- En **Connect → Session pooler**, copia el host y el usuario exactos. Conserva la contraseña de la base para configurarla en Render.

## 2. Crear el backend en Render

En Render, elige **New → Blueprint** y selecciona el repositorio. El archivo `render.yaml` define un servicio Docker con perfil `prod,db` y comprobación en `/actuator/health`. La plantilla selecciona el plan Free. Puedes cambiar el plan al configurar el servicio.

| Variable | Valor |
|---|---|
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://HOST_DEL_SESSION_POOLER:5432/postgres?sslmode=verify-full&sslrootcert=/app/certs/prod-ca-2021.crt` |
| `SPRING_DATASOURCE_USERNAME` | Usuario completo de Session pooler, por ejemplo `postgres.<referencia>` |
| `SPRING_DATASOURCE_PASSWORD` | Contraseña de PostgreSQL, ingresada directamente en Render |
| `CORS_ALLOWED_ORIGINS` | Origen exacto de Vercel, por ejemplo `https://mi-proyecto.vercel.app`, sin barra final. Si aún no tienes el dominio definitivo, puedes usar el dominio previsto y corregirlo después. |

Si prefieres **New → Web Service**, elige Docker, establece **Root Directory** en `backend`, **Dockerfile Path** en `./Dockerfile`, **Docker Build Context** en `.` y **Health Check Path** en `/actuator/health`. Añade las variables de la tabla y `SPRING_PROFILES_ACTIVE=prod,db`. Puedes usar `DB_POOL_SIZE=3` como en la plantilla. Render proporciona `PORT`.

Cuando esté activo, verifica `https://TU-SERVICIO.onrender.com/actuator/health`. Debe devolver `{"status":"UP"}`. Guarda el origen público del servicio para configurar Vercel.

## 3. Crear el frontend en Vercel

Importa el mismo repositorio y configura **Root Directory** en `frontend`. En **Build and Deployment**, selecciona **Node.js 24.x**. `frontend/vercel.json` configura la instalación, compilación, salida estática y las rutas de Angular.

En las variables de entorno de producción de Vercel añade:

| Variable | Valor |
|---|---|
| `BACKEND_ORIGIN` | `https://TU-SERVICIO.onrender.com` |

El frontend agrega `/api` al origen configurado. Las credenciales de Supabase se ingresan únicamente en Render. Si cambias `BACKEND_ORIGIN`, vuelve a desplegar el frontend. En Render, actualiza `CORS_ALLOWED_ORIGINS` con el dominio real que asignó Vercel. Puedes registrar varios dominios exactos separados por comas.

## 4. Comprobar el despliegue

1. Abre el dominio de Vercel y comprueba que se cargue el nombre comercial configurado.
2. Inicia sesión y abre Productos. Recarga esa ruta para verificar que Vercel sirva la aplicación también al entrar por una ruta interna.
3. Si el backend registra `ENOTFOUND: tenant/user ... not found`, comprueba el estado de Supabase y vuelve a copiar host y usuario de **Session pooler**. Si el navegador rechaza una petición por CORS, compara el dominio abierto con el valor guardado en Render.

Para desarrollo local se conservan los comandos `npm start` y `mvnw.cmd spring-boot:run`, con el proxy local hacia el puerto 8080.

Referencias oficiales: [Docker en Render](https://render.com/docs/docker), [Blueprints](https://render.com/docs/blueprint-spec), [configuración de Vercel](https://vercel.com/docs/project-configuration/vercel-json) y [conexión con PostgreSQL en Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres).

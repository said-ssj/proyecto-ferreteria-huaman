# Ferretería Huamán

Sistema web de ventas e inventario para una ferretería, desarrollado como proyecto de Responsabilidad Social Universitaria. La interfaz prioriza textos legibles, controles amplios, navegación por teclado, flujos sencillos y ocho temas visuales.

## Tecnologías

- Frontend: Angular 22, TypeScript y Angular Material.
- Backend: Java 21 y Spring Boot 3.4.5.
- Base de datos: PostgreSQL en Supabase, esquema `huaman`.

El frontend accede a la API del backend. Las credenciales de PostgreSQL se configuran únicamente en el servidor.

## Avance actual

Están implementados los módulos de autenticación y permisos, perfil, administración de usuarios, administración de roles y permisos, bitácora, reportes y gráficos administrativos, configuración general, series de comprobantes, preferencias de impresión y etiquetas con códigos de barras, categorías y unidades, productos y presentaciones, códigos de barras, precios mayoristas, clientes, proveedores, compras e ingresos, inventario, caja, punto de venta, historial de ventas, cotizaciones, créditos y abonos, despachos, devoluciones y ofertas.

La base incluye conversiones de presentaciones y control de productos por granel, envases o tramos. Los procesos comerciales conservan auditoría, control transaccional y validaciones de concurrencia.

Existe un laboratorio local de XML de prueba sin firma ni envíos. Continúa pendiente la integración fiscal: validación completa, firma y comunicación con SUNAT. Las pantallas existentes de estas áreas no implican que todas sus acciones estén conectadas. La impresión física está pendiente de comprobación.

## Estructura

| Carpeta | Contenido |
|---|---|
| frontend | Aplicación Angular, recursos y pruebas |
| backend | API, reglas de aplicación y pruebas |
| supabase/migrations | Scripts SQL versionados de estructura y procesos |
| supabase/diagnostics | Consultas de diagnóstico |

## Preparación local

1. Instalar Java 21, Node.js compatible con Angular 22 y npm. El backend incluye Maven Wrapper.
2. Copiar `backend/.env.example` como `backend/.env` y completar la configuración privada del entorno.
3. Consultar [backend](backend/README.md), [frontend](frontend/README.md) y [base de datos](supabase/README.md) para los detalles de ejecución.

No se incluyen cuentas, contraseñas, datos comerciales reales, dependencias instaladas ni compilaciones. La cuenta administradora inicial se configura para cada entorno; no existe una contraseña pública predeterminada.

## Despliegue

Consulta la [guía de Render y Vercel](DESPLIEGUE.md) para configurar ambos servicios y conectarlos con Supabase.

## Estado de verificación

Las últimas verificaciones del 26/10/2026 registran 207 pruebas del frontend, 1013 pruebas ordinarias del backend y 104 integraciones en PostgreSQL local aprobadas. También se aprobaron 13 casos de concurrencia y una medición de 13 consultas con 10 000 productos y 3 000 ventas de prueba. La compilación del frontend quedó sin avisos de tamaño; conserva el aviso CommonJS de JsBarcode. Estas verificaciones no sustituyen las pruebas con la configuración del entorno de destino ni la impresión física.

Las migraciones no se ejecutan automáticamente al iniciar el backend. No deben repetirse sobre una base ya instalada.

Administración de usuarios y consulta de roles: [funciones, endpoints y verificaciones](backend/docs/USUARIOS_ROLES.md).

Configuración, series y etiquetas: [funciones y verificaciones](backend/docs/CONFIGURACION_SERIES_IMPRESION.md).

Consulta de Bitácora: [alcance y verificaciones](backend/docs/BITACORA.md).

Reportes y gráficos: [criterios de cálculo, permisos y descargas](backend/docs/REPORTES.md).

Edición protegida de roles: [alcance, reglas y verificación](backend/docs/ROLES_PERMISOS.md).

XML de prueba local: [alcance, límites y verificación](backend/docs/XML_PRUEBAS.md).

Las preferencias incluyen tamaño de interfaz (90 %, 95 % y 100 %) e imágenes opcionales de productos. Se pueden cargar miniaturas desde el catálogo y alternar texto o texto e imagen sin cambiar la vista de lista o tarjetas.

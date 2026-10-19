# Ferretería Huamán

Sistema web de ventas e inventario para una ferretería, desarrollado como proyecto de Responsabilidad Social Universitaria. La interfaz prioriza textos legibles, controles amplios, navegación por teclado, flujos sencillos y seis temas visuales.

## Tecnologías

- Frontend: Angular 22, TypeScript y Angular Material.
- Backend: Java 21 y Spring Boot 3.4.5.
- Base de datos: PostgreSQL en Supabase, esquema `huaman`.

El frontend accede a la API del backend. Las credenciales de PostgreSQL se configuran únicamente en el servidor.

## Avance actual

Están implementados los módulos de autenticación y permisos, perfil, categorías y unidades, productos y presentaciones, códigos de barras, precios mayoristas, clientes, proveedores, compras e ingresos, inventario, caja, punto de venta, historial de ventas, cotizaciones, créditos y abonos, despachos, devoluciones y ofertas.

La base incluye conversiones de presentaciones y control de productos por granel, envases o tramos. Los procesos comerciales conservan auditoría, control transaccional y validaciones de concurrencia.

Continúan en desarrollo los reportes y gráficos administrativos, administración de usuarios y configuración general, y la integración de facturación electrónica/XML. Las pantallas existentes de estas áreas no implican que todas sus acciones estén conectadas. La impresión física está pendiente de comprobación.

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

## Estado de verificación

El proyecto incluye pruebas de frontend y backend. La revisión anterior aprobó 106 pruebas del frontend y la compilación de producción, con advertencias de tamaño pendientes de optimización. Es un registro de esa ejecución anterior, no una ejecución automática de esta copia. Antes de desplegar, deben repetirse las comprobaciones con la configuración del entorno de destino.

Las migraciones no se ejecutan automáticamente al iniciar el backend. No deben repetirse sobre una base ya instalada.

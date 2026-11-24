# Frontend

Aplicación Angular con Angular Material, componentes independientes y rutas protegidas por sesión y permisos. Utiliza recursos de fuentes e iconos locales y conserva sus licencias en `public/fonts`.

## Desarrollo

Desde esta carpeta:

```text
npm ci
npm start
```

La aplicación se sirve en `http://localhost:4200`. El archivo `proxy.conf.json` dirige las peticiones `/api` al backend local en el puerto 8080. Iniciar también el backend para utilizar los módulos conectados.

## Pruebas y compilación

```text
npm test -- --watch=false
npm run build
```

La compilación de producción se genera en `dist/`. Los presupuestos actuales pueden producir advertencias de tamaño; se mantienen visibles.

## Configuración

No colocar contraseñas de base de datos, claves privadas ni claves con permisos de servidor en el frontend. En un despliegue, configurar el servidor web para servir las rutas de Angular y dirigir `/api` a la API con HTTPS. El proxy de desarrollo no configura el servidor de producción.

## Interfaz y alcance

Temas disponibles: Plomo, Gris suave, Pizarra neutra, Alto contraste, Lectura cálida y Noche suave. Los controles incluyen foco visible y adaptación a pantallas estrechas. Estas características no constituyen una certificación integral WCAG.

Consultar el [avance general](../README.md) para distinguir los módulos conectados de los pendientes. Las pruebas están junto a los servicios, componentes y páginas en `src/`.

Usuarios y roles utilizan el componente dedicado `Users` y el servicio `UserAdminService`. El editor dedicado RolePermissions permite ajustar perfiles operativos; ADM permanece protegido. Ver [documentación del módulo](../backend/docs/USUARIOS_ROLES.md).

Configuración general, series y etiquetas conectadas: [alcance y verificación](../backend/docs/CONFIGURACION_SERIES_IMPRESION.md).

Bitácora conectada: [consulta, filtros y protección de datos](../backend/docs/BITACORA.md).

Reportes y gráficos conectados: [criterios de cálculo y verificación](../backend/docs/REPORTES.md).

Edición de roles: [reglas y verificación](../backend/docs/ROLES_PERMISOS.md).

Laboratorio XML local sin firma ni envío fiscal: [alcance y verificación](../backend/docs/XML_PRUEBAS.md).


En Tickets y etiquetas se pueden imprimir 13 formatos: rollos de 100 × 150 hasta 25 × 15 mm, lazo de 50 × 15 mm y hojas A4 de 24 o 40 etiquetas. Incluye posición inicial para hojas usadas, comprobación de anchura del código y documento de impresión aislado. Imprimir a 100 % y comprobar el papel y los márgenes reales.

## Identidad visual y temas

El encabezado permite seleccionar cualquiera de los ocho temas desde un menú Material, sin navegar ni reiniciar el formulario actual. La preferencia continúa guardándose en este navegador. El menú admite teclado y Escape, devuelve el foco al botón y muestra el tema activo.

Administración puede configurar el logo en **Parámetros del sistema → Logo e icono de la pestaña**; Apariencia y accesibilidad incluye un acceso a esa configuración. El archivo se previsualiza localmente y solo se envía al pulsar Guardar identidad visual. Se puede elegir si el logo se utiliza también como favicon. Sin imagen, se usa una inicial del nombre comercial en menú, ingreso y favicon. El nombre comercial se edita en la sección Información del negocio.

Las rutas públicas de identidad visual requieren el backend actualizado y la migración correspondiente. El resto de parámetros y las escrituras conservan sus permisos. La tabla de configuración permite un logo pequeño para el negocio; las imágenes de productos son un alcance separado.

## Tamaño de interfaz e imágenes de productos

En Apariencia y accesibilidad se puede reducir la interfaz a 95 % o 90 % y restablecer a 100 %. La impresión mantiene sus medidas. La elección se guarda en este navegador, al igual que Solo texto / Texto e imagen, disponible también en catálogo, punto de venta y selección de productos. Esta elección es independiente de lista / tarjetas.

Con `PRO.GESTIONAR`, la acción Imagen de Productos permite cargar, reemplazar o quitar un PNG/JPG de hasta 2 MB. Primero se guarda el producto nuevo. La foto solo se envía al guardar la imagen. Requiere el backend y la migración de imágenes actualizados. Los productos sin imagen conservan nombre y código; no se añaden fotos de ejemplo.

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

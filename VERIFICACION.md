# Verificación de la entrega

Fecha: 15 de septiembre de 2026. Entorno: Windows, Python 3.14.7; sin Xcode ni compilador Swift disponible.

## Ejecutado con resultado correcto

### Backend: 10 pruebas

Comando:

```sh
python -W error::ResourceWarning -m unittest discover -s Backend -p 'test_*.py' -v
```

- Mapeo de artículo, fecha UTC y exclusión del contenido completo.
- Rechazo de enlaces inseguros, títulos inválidos y fechas ilegibles.
- Identidad estable al cambiar parámetros de seguimiento de una URL.
- Caché separada por país y categoría.
- Validación de parámetros y búsquedas vacías o demasiado largas.
- Errores 401/403/429/500 sin revelar la clave del proveedor.
- Respuesta controlada del adaptador upstream.
- Error explícito cuando no hay clave configurada.
- Carga de configuración local y prioridad de variables del hosting.
- Petición HTTP real a un servidor local de prueba con proveedor controlado; contrato de éxito y error 400.

No se hicieron peticiones al proveedor real: falta la credencial de la cuenta elegida.

### Proyecto: validación estructural

Comando: `python Scripts/validate_project.py`.

- Se pudo analizar el formato del proyecto de Xcode.
- Los 24 archivos Swift de la aplicación pertenecen una sola vez al target MyNews.
- Los 4 archivos de pruebas pertenecen una sola vez al target MyNewsTests.
- Todas las referencias de archivos resuelven a rutas existentes.
- Existe un único punto de entrada `@main`.
- El esquema compartido referencia los targets correctos.
- Info.plist, PrivacyInfo.xcprivacy, catálogo de assets y payload APNs tienen sintaxis válida.

La validación estructural no equivale a compilar Swift ni verifica el diseño visual.

## Incluido, pendiente de ejecutar en Mac

**15 pruebas XCTest**, ejecutables con Command+U:

- FeedTests: 5 (filtrado, deduplicación, orden, URL segura y serialización).
- StorageAndLoadingTests: 3 (persistencia/reinicio, caché aislada y respuesta obsoleta).
- NotificationPolicyTests: 4 (elegibilidad, duplicados/intervalo, máximo diario y exclusiones).
- NetworkingTests: 3 (contrato backend, autenticación y obligación de HTTPS).

También quedan pendientes la compilación, la ejecución del simulador, la revisión visual, la prueba del permiso real, compartir, Safari, local notifications y recepción con `simctl push`. Sigue README.md para hacerlo.

## Dependencias externas aún sin activar

- Clave y plan de NewsData.io, con cobertura/licencia adecuada al producto.
- Hosting HTTPS, gateway, cuotas y controles de acceso para el backend de producción.
- Registro autenticado de instalaciones, worker y credenciales APNs según el diseño de PUSH.md.
- Cuenta/firma de Apple, icono final y validación de distribución para crear una app instalable fuera del simulador.

La entrega contiene código y proyecto, no un IPA firmado ni un servicio publicado. Se puede recorrer toda la aplicación con datos ficticios después de compilarla en un Mac.

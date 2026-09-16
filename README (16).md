# MyNews — aplicación nativa iOS

Proyecto SwiftUI con las 15 fases desarrolladas en código y documentación. Incluye `MyNews.xcodeproj`, pantallas completas, servicios, almacenamiento, tests y backend adaptador de noticias. El modo inicial utiliza noticias ficticias para poder probar la app sin una cuenta de proveedor.

**Estado de verificación:** desarrollado en Windows. El backend pasó sus pruebas automatizadas y se verificó la estructura del proyecto. No se ha compilado ni ejecutado la app con Xcode, ni firmado un IPA. La conexión real requiere una clave de proveedor y un backend HTTPS. Push está diseñado y tiene soporte de recepción, pero no está desplegado ni enviando notificaciones reales.

## Abrir en un Mac

1. Copia o descomprime la carpeta completa `MyNews` en el Mac.
2. Abre **MyNews.xcodeproj**. Ya no necesitas crear un proyecto nuevo ni copiar archivos Swift manualmente.
3. Usa Xcode 16 o posterior y un simulador de iPhone instalado con iOS 17 o posterior. El proyecto usa modo de lenguaje Swift 5 con comprobación de concurrencia completa.
4. Selecciona el esquema **MyNews**, un simulador de iPhone y pulsa **Command+R**.
5. Para ejecutar los tests incluidos, pulsa **Command+U**.
6. Para instalar en un iPhone físico, configura tu Team y un Bundle Identifier propio en **Signing & Capabilities**, conecta el dispositivo y selecciónalo como destino.

No necesitas claves, backend ni permisos push para recorrer la demo. Las imágenes de ejemplo usan Picsum y requieren internet; si fallan, aparece un placeholder. Los titulares son ficticios y los enlaces de la demo abren example.com.

## Qué incluye

- Onboarding con selección de país, búsqueda de países, doce temas y permiso opcional de notificaciones.
- Home personalizado con imágenes, titulares, fuente, fecha, país y categoría; actualización manual.
- Explorar por temas y búsqueda con cancelación de solicitudes anteriores.
- Detalle con resumen, Safari integrado, compartir y guardar.
- Biblioteca persistente de guardados y configuración de país, temas, avisos y apariencia.
- Notificación local de prueba y política de avisos con deduplicación y límites de frecuencia.
- Errores comprensibles y caché de noticias por consulta para acceso temporal sin conexión.
- Protocolo intercambiable, MockNewsService y RealNewsService con URLSession/async-await.
- Backend Python que adapta NewsData.io y conserva la clave del proveedor en el servidor.
- Diseño de backend push: registro autenticado, cola, esquema SQL, reglas APNs y payload de simulador.

## Documentación por fases y código completo

- [FASES.md](FASES.md): qué hace cada fase, archivos exactos, explicación, cómo probar y compatibilidad.
- [CODIGO-SWIFT.md](CODIGO-SWIFT.md): contenido completo de los archivos Swift; también puedes abrirlos directamente.
- [Backend/README.md](Backend/README.md): configuración de API real y límites del adaptador.
- [Backend/PUSH.md](Backend/PUSH.md): arquitectura y requisitos para notificaciones push.
- [VERIFICACION.md](VERIFICACION.md): comprobaciones realizadas y pruebas pendientes en Mac.

## Estructura

```text
MyNews/
├── MyNews.xcodeproj/       Proyecto y esquema compartido
├── MyNews/
│   ├── App/               Entrada, dependencias y recepción de notificaciones
│   ├── Models/            Artículos, países, categorías y preferencias
│   ├── Views/             Onboarding, Home, Detail, Explore, Saved, Settings
│   ├── ViewModels/        Estado de app y cargas asíncronas
│   ├── Services/
│   │   ├── News/          Protocolo, mock, real y orden del feed
│   │   ├── Notifications/ Permisos, programación y política de frecuencia
│   │   └── Storage/       UserDefaults y caché en disco
│   ├── Networking/        HTTP y errores
│   ├── Components/        Tarjetas y selectores reutilizables
│   ├── Utilities/         Reservado para utilidades futuras
│   └── Resources/         Info.plist, assets y manifiesto de privacidad
├── MyNewsTests/           Tests XCTest de lógica e integración del cliente
├── Backend/               Adaptador Python, tests y diseño push
└── Scripts/               Generación y validación de artefactos
```

## Prueba manual recomendada

1. Completa onboarding con Costa Rica y Tecnología, Deportes y Ciencia.
2. Entra a Home y comprueba que aparecen esas categorías y la indicación de demo.
3. Abre un detalle, guarda, comparte y abre el enlace original.
4. Ve a Guardados, cierra la app y ábrela de nuevo: la noticia debe persistir.
5. Busca “ciencia” en Explorar y después una palabra sin resultados.
6. Cambia el país y los temas desde Configuración; Home debe actualizarse.
7. Activa notificaciones, selecciona categorías y envía la prueba local a cinco segundos.
8. Prueba apariencia oscura, texto grande y rotación del iPhone.
9. Borra preferencias: debe volver al onboarding y conservar los guardados.
10. Cuando configures la API real, carga noticias, desconecta internet y actualiza: debe mostrar la caché y su fecha.

## Verificaciones automatizadas

En Windows, Linux o Mac con Python:

```sh
python Scripts/validate_project.py
python -m unittest discover -s Backend -p 'test_*.py' -v
```

En Mac, desde Xcode: **Command+U**. Por terminal, sustituye el destino por un simulador instalado:

```sh
xcodebuild -list -project MyNews.xcodeproj
xcodebuild test -project MyNews.xcodeproj -scheme MyNews -destination 'platform=iOS Simulator,name=TU_SIMULADOR' CODE_SIGNING_ALLOWED=NO
```

## API real y push

El backend local puede cargar la clave desde `Backend/.env`. Ese archivo privado no se incluye en Git ni en el ZIP. Para iniciar desde esta carpeta: `python Backend/server.py`. El servidor local no sustituye al hosting HTTPS requerido por el iPhone. Para generar un ZIP actualizado sin credenciales, ejecuta `python Scripts/package_project.py`.

Configura `NEWSDATA_API_KEY` solamente en el servidor. Publica el adaptador detrás de HTTPS y escribe su URL en `MyNews/Resources/Info.plist`, clave `NewsBackendURL`. No se ha creado hosting ni contratado un plan. El adaptador aproxima algunas categorías y no infiere urgencia a partir de titulares; sus límites están detallados en Backend/README.md.

Para push con la app cerrada, implementa y despliega el registro autenticado y worker de `Backend/PUSH.md`, configura las credenciales de Apple y habilita la capacidad del target. La fase 14 entrega ese diseño, el esquema de datos y la recepción preparada. El botón local funciona independientemente de ese despliegue.

La distribución en App Store también requiere icono final, firma, pruebas en dispositivos, política de privacidad y revisión de los datos tratados por el proveedor/backend elegido. El manifiesto incluido describe el almacenamiento local actual; debe revisarse al activar servicios externos.

## Referencias técnicas

- [SwiftUI App](https://developer.apple.com/documentation/swiftui/app)
- [URLSession](https://developer.apple.com/documentation/foundation/urlsession)
- [Notificaciones locales](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [NewsData: primera petición](https://newsdata.io/blog/how-to-make-your-first-request-with-newsdata-io/)

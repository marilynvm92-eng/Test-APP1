# Guía de las 15 fases

Todas las rutas son relativas a la carpeta raíz `MyNews`, donde está `MyNews.xcodeproj`. El código completo de cada archivo está en esa ruta; `CODIGO-SWIFT.md` también reúne todos los archivos Swift para leerlos en orden. No necesitas copiarlos a mano: ya pertenecen al target del proyecto.

## 1. Estructura

**Archivos:** `MyNews.xcodeproj/project.pbxproj`, `MyNews.xcodeproj/xcshareddata/xcschemes/MyNews.xcscheme`, `MyNews/App/MyNewsApp.swift`, `MyNews/App/RootView.swift`.

La app crea un único AppState e inyecta sus dependencias mediante EnvironmentObject. RootView muestra onboarding o TabView según preferencias persistidas. `Scripts/generate_project.py` permite regenerar el proyecto si agregas nuevos archivos fuera de Xcode; requiere Python 3.9+ y no es necesario para abrirlo.

**Prueba:** abrir el proyecto, seleccionar esquema MyNews, simulador iOS 17+ y pulsar Command+R. **Compatibilidad:** se conserva el único `@main` de la fase inicial y el nombre RootView; su pantalla provisional fue reemplazada por la navegación real.

## 2. Modelos

**Archivos:** `MyNews/Models/NewsArticle.swift`, `MyNews/Models/Preferences.swift`.

NewsArticle incluye todos los campos pedidos y es Codable, Hashable, Identifiable y Sendable. Preferences define país, temas, temas de avisos, apariencia y onboarding. Las doce categorías tienen títulos y símbolos. Country obtiene países ISO del sistema y nombres en español.

**Prueba:** ejecutar FeedTests para serialización y URLs. **Compatibilidad:** los servicios, almacenamiento y pantallas comparten estos tipos; la API normaliza sus campos antes de entregarlos al iPhone.

## 3. Datos mock

**Archivos:** `MyNews/Services/News/NewsService.swift`, `MyNews/Services/News/MockNewsService.swift`.

El protocolo define titulares, noticias por categoría y búsqueda. MockNewsService genera noticias ficticias identificadas como demo, URLs de ejemplo e imágenes remotas. FeedRanker elimina IDs/URLs repetidas, limita al país y temas, y admite historias internacionales pertinentes. Ordena por día de publicación; dentro del mismo día prioriza país y luego hora.

**Prueba:** dejar NewsBackendURL vacío, elegir Costa Rica y Ciencia; verificar tarjetas demo. **Compatibilidad:** RealNewsService implementa el mismo protocolo.

## 4. Onboarding

**Archivo:** `MyNews/Views/Onboarding/OnboardingView.swift`.

Cuatro pasos: bienvenida, país, temas y explicación de notificaciones. El permiso del sistema solo se pide tras pulsar Activar. Ahora no y denegación permiten entrar a la aplicación. Los cambios de selección se persisten y el onboarding se completa únicamente al finalizar.

**Prueba:** instalar por primera vez, terminar el flujo y reiniciar la app; debe entrar a Home. **Compatibilidad:** usa UserPreferences; no crea otro almacenamiento.

## 5. País

**Archivo:** `MyNews/Components/PreferencePickers.swift`, tipo CountryPicker.

Lista con banderas, nombres, búsqueda y marca de selección. Se reutiliza en onboarding y Configuración. Costa Rica es la selección inicial.

**Prueba:** buscar México, seleccionarlo, cerrar y volver a abrir. **Compatibilidad:** usa códigos ISO en todos los servicios.

## 6. Categorías

**Archivo:** `MyNews/Components/PreferencePickers.swift`, tipo CategoryPicker.

Rejilla adaptable con selección múltiple. Onboarding no deja continuar sin temas. Configuración impide quitar el último tema.

**Prueba:** seleccionar/dejar vacío durante onboarding y comprobar el botón. **Compatibilidad:** usa Set<NewsCategory>, sin duplicados ni strings sueltos en las vistas.

## 7. Home

**Archivos:** `MyNews/Views/Home/HomeView.swift`, `MyNews/ViewModels/NewsListViewModel.swift`, `MyNews/Components/ArticleCard.swift`.

Feed personalizado, tarjetas con imagen, fecha, país, categoría y fuente, navegación a detalle y pull-to-refresh. NewsListViewModel controla loading, error, contenido y fallback de caché. Un identificador de generación evita que una respuesta antigua sustituya una búsqueda o selección más reciente.

**Prueba:** cambiar país/temas desde Configuración y volver a Home. **Compatibilidad:** la clave de carga contiene país, categorías y proveedor; no mezcla respuestas de selecciones distintas.

## 8. Detalle

**Archivo:** `MyNews/Views/Detail/ArticleDetailView.swift`.

Imagen, título, resumen, fecha, fuente, guardado y ShareLink. SafariView usa SFSafariViewController para abrir enlaces HTTP/HTTPS. No se muestra un artículo completo copiado de la fuente.

**Prueba:** abrir tarjeta, compartir y pulsar Leer noticia completa; en demo se abre example.com. **Compatibilidad:** recibe el mismo NewsArticle mostrado en el feed.

## 9. Búsqueda

**Archivo:** `MyNews/Views/Explore/ExploreView.swift`.

Noticias por categoría y buscador con espera de 350 ms; cancela cargas anteriores al cambiar texto. La búsqueda global sustituye temporalmente el filtro de categoría. Límite de 200 caracteres por consulta.

**Prueba:** buscar “ciencia” y luego un texto sin coincidencias; cambiar rápidamente el término. **Compatibilidad:** usa el mismo protocolo y ViewModel que Home, con otra clave de caché.

## 10. Guardados

**Archivos:** `MyNews/Views/Saved/SavedView.swift`, `MyNews/ViewModels/AppState.swift`, `MyNews/Services/Storage/LocalStore.swift`.

Almacena todos los campos del artículo mediante JSON en UserDefaults. Añade/quita desde detalle y quita desde menú contextual. Límite de 500 artículos para mantener sencillo y acotado el almacenamiento. El resumen funciona sin internet; las imágenes y el enlace original pueden necesitar conexión.

**Prueba:** guardar una noticia, terminar y reiniciar la app, entrar a Guardados y quitarla. **Compatibilidad:** comparte datos y acción de guardado entre todas las pestañas.

## 11. Configuración

**Archivo:** `MyNews/Views/Settings/SettingsView.swift`.

País, temas, temas de avisos, permiso real de iOS, apariencia sistema/claro/oscuro y reinicio de preferencias con confirmación. Borrar preferencias conserva guardados y registro de avisos, limpia caché y cancela notificaciones pendientes.

**Prueba:** cambiar apariencia y reiniciar preferencias; debe aparecer onboarding con guardados conservados. **Compatibilidad:** todos los controles modifican el mismo AppState.

## 12. API real

**Archivos:** `MyNews/Services/News/RealNewsService.swift`, `MyNews/Networking/HTTPClient.swift`, `MyNews/Networking/NewsError.swift`, `Backend/server.py`, `Backend/.env.example`, `MyNews/Resources/Info.plist`.

RealNewsService usa async/await y URLSession. El backend adapta NewsData.io al modelo común y guarda la clave fuera de la aplicación. Lee `Backend/README.md` para conexión, límites del proveedor, cobertura, clasificación aproximada y despliegue HTTPS.

**Prueba:** ejecutar pruebas Python; después configurar una clave propia en un servidor HTTPS y NewsBackendURL en Info.plist. **Compatibilidad:** las vistas no cambian al alternar proveedores. La integración está escrita y probada con fixtures; la consulta con credenciales reales está pendiente.

## 13. Notificaciones locales

**Archivos:** `MyNews/Services/Notifications/NotificationService.swift`, `MyNews/Services/Notifications/NotificationPolicy.swift`, `MyNews/App/AppDelegate.swift`.

Permiso con UserNotifications y botón de prueba a cinco segundos. La política selecciona urgentes, limita frecuencia, respeta país/temas y guarda IDs 30 días. Cambiar preferencias cancela pendientes y evita que una programación en curso las ignore. Home evalúa artículos reales recién cargados; NewsData no proporciona aquí una señal de urgencia fiable, de modo que su adaptador no marca artículos automáticamente como urgentes.

**Prueba:** activar permiso, elegir temas de avisos y pulsar prueba. Ejecutar NotificationPolicyTests para reglas. **Compatibilidad:** usa las preferencias existentes y el modelo de artículo.

## 14. Backend push

**Archivos:** `Backend/PUSH.md`, `Backend/push-schema.sql`, `Backend/sample.apns`, `MyNews/App/AppDelegate.swift`.

Diseño de ingesta, registro autenticado de instalaciones, preferencias versionadas, cola persistente, transacciones, deduplicación, límites, APNs y reintentos. AppDelegate prepara recepción de tokens y apertura de enlaces. Registro remoto y endpoints de instalaciones están intencionalmente por integrar cuando exista el servidor autenticado; no hay envío real activado.

**Prueba:** `xcrun simctl push` con el payload incluido, según PUSH.md. **Compatibilidad:** push reutiliza país/temas/URL. Al activarlo, hay que desactivar avisos automáticos locales de noticias para evitar duplicados. Esta fase solicitaba diseñar el backend, no contratarlo ni publicar un servicio push.

## 15. Diseño, errores y caché

**Archivos:** `MyNews/Components/ArticleCard.swift`, `MyNews/Services/Storage/NewsCache.swift`, `MyNews/Networking/NewsError.swift`, `MyNews/Resources/PrivacyInfo.xcprivacy`, `MyNewsTests/*.swift`, `Backend/test_server.py`.

Tarjetas redondeadas, tipografía semántica, colores de sistema, placeholders de imágenes y modo oscuro. Caché atómica en disco: hasta 30 consultas, 100 artículos cada una, máximo siete días de antigüedad; muestra fecha y aviso de fallback. Los errores se traducen a mensajes comprensibles y ofrecen reintento. El manifiesto declara el uso local de UserDefaults y fechas de archivos.

**Prueba:** ejecutar Command+U, recorrer flujos con texto grande y claro/oscuro; tras una carga real, desconectar internet y actualizar. **Compatibilidad:** pruebas de filtrado, serialización, persistencia, aislamiento de caché, carreras y límites de avisos.

## Alcance de la verificación

Las pruebas Python y la validación estructural se pueden ejecutar en Windows. Los tests Swift están incluidos en el target MyNewsTests pero requieren Xcode y no se han ejecutado en este entorno. Tampoco se ha hecho una revisión visual en simulador. No hay binario IPA firmado ni publicación App Store.

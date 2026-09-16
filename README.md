# Backend de noticias reales

`server.py` implementa el contrato de `RealNewsService` con NewsData.io. Funciona con Python 3.11 o superior, sin dependencias adicionales. No contiene una API key.

## Ejecutar

En una terminal de tu servidor, define `NEWSDATA_API_KEY` mediante el gestor de secretos o las variables de entorno de tu hosting. Para desarrollo local, el script también carga `Backend/.env` automáticamente; puedes crearlo a partir de `.env.example`. Las variables del hosting tienen prioridad. El archivo `.env` está excluido de Git y del ZIP generado con `Scripts/package_project.py`.

```sh
python3 server.py
```

Escucha en `127.0.0.1:8080`. Puedes comprobar la vida del proceso con `http://127.0.0.1:8080/health`. Health no verifica la credencial del proveedor. Si falta la clave, las rutas de noticias responden 503.

Para conectar un iPhone, coloca el backend detrás de una URL HTTPS con certificado válido. En `MyNews/Resources/Info.plist`, escribe esa dirección en `NewsBackendURL`, por ejemplo `https://news.tudominio.com`. Usa solo el origen o prefijo base, sin `/v1/headlines`. Compila de nuevo. Si lo dejas vacío, la app usa los datos ficticios sin necesitar este backend.

La clave del proveedor permanece en el servidor. No la pongas en Info.plist, Swift, xcconfig ni en un header fijo dentro de la app. Una URL de backend no es un secreto.

## Contrato implementado

```text
GET /health
GET /v1/headlines?country=CR&categories=technology,sports,science
GET /v1/search?q=Costa%20Rica
```

Respuesta de noticias: `{"articles": [...]}`. Cada artículo usa exactamente las claves de `NewsArticle.swift`, con fechas UTC ISO 8601 sin fracciones, país ISO de dos letras o null, categoría del enum y URLs HTTP/HTTPS. `imageURL` y `country` pueden ser null. Los fallos devuelven `{"error": "mensaje"}` y un estado HTTP apropiado.

La aplicación mapea 401/403, 429, errores de servidor, desconexión y decodificación a mensajes en español. La caché del iPhone permite consultar la última respuesta válida de la misma consulta durante siete días.

## Proveedor y límites explícitos

- NewsData documenta el endpoint `/api/1/latest`, filtros por país, categoría y consulta, y Costa Rica con `CR`.
- Se obtiene una página por categoría, hasta 100 artículos únicos en total. No se descarga el catálogo histórico completo ni se implementa paginación infinita.
- Caché de servidor: diez minutos por consulta y hasta 300 entradas; máximo tres solicitudes upstream simultáneas. Elegir doce categorías puede consumir hasta doce peticiones en una carga sin caché. Revisa la cuota del plan antes de desplegar.
- `economy` usa business más palabras clave; `culture` y `gaming` se aproximan mediante categorías y palabras clave. Es una clasificación inicial, no una taxonomía exacta. Puede dejar fuera noticias en otros idiomas. Sustituye el adaptador para refinarlo sin cambiar las vistas.
- El país del proveedor indica cobertura/origen de sus noticias y no garantiza que cada artículo trate específicamente de ese país. Las consultas de titulares se restringen al país; la búsqueda es global y devuelve país null en esta versión.
- La categoría `top` alimenta Última hora, pero **no** establece automáticamente `isBreakingNews=true`: falta una señal editorial fiable de urgencia. Por ello este adaptador no dispara avisos automáticos de noticias. Puedes probar avisos con el botón local; para producción añade clasificación editorial explícita.
- Solo se utiliza el título, resumen, enlace, fecha y atribución. Se descarta el campo de artículo completo. La disponibilidad, frescura, países, uso comercial y derechos dependen de la cuenta contratada con el proveedor.

## Despliegue

El servidor incluido es una implementación de desarrollo del adaptador. Para publicarlo, colócalo detrás de un gateway HTTPS con límites por cliente y globales, timeouts y control de acceso/App Attest acorde al producto. No expongas el servidor de desarrollo directamente a internet. Añade cuotas que protejan el saldo del proveedor; la caché por sí sola no impide búsquedas arbitrarias repetidas. No registres URLs upstream, porque incluyen la clave.

No se ha contratado un proveedor, creado hosting ni hecho una consulta real con credenciales en esta entrega. Las pruebas usan respuestas controladas.

## Pruebas

Desde la raíz del proyecto:

```sh
python3 -m unittest discover -s Backend -p 'test_*.py' -v
```

Comprueban normalización, exclusión de artículos inseguros o inválidos, deduplicación, caché, errores upstream, protección de la clave y una petición HTTP end-to-end con proveedor controlado.

## Fuentes

- [Primera petición con NewsData](https://newsdata.io/blog/how-to-make-your-first-request-with-newsdata-io/)
- [Cobertura de Costa Rica](https://newsdata.io/news-sources/costa-rica-breaking-news-api)
- [Categorías del proveedor](https://newsdata.io/blog/news-categories-by-newsdata-io/)
- [Objetos de respuesta](https://newsdata.io/blog/news-api-response-object/)
- [Arquitectura push](PUSH.md)

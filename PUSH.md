# Fase 14 — Diseño del backend de notificaciones push

## Estado de esta entrega

Las notificaciones locales están implementadas. `AppDelegate.swift` recibe tokens y abre enlaces HTTPS al tocar una notificación. `sample.apns` permite probar la recepción en el simulador. Este documento y `push-schema.sql` definen el backend push; no hay servicio push desplegado ni envío APNs activo. La fase solicitada consiste en diseñar esa arquitectura.

## Flujo

```text
NewsData u otro proveedor → ingesta periódica → normalización / deduplicación
→ clasificación de urgencia → coincidencia país + temas
→ límites y preferencias → cola persistente → worker APNs → iPhone
```

La app no puede consultar continuamente el proveedor cuando está cerrada. El backend hace la ingesta. No se necesitan notificaciones silenciosas ni el modo background remote-notification para mostrar estos avisos visibles.

## Registro de instalaciones

1. En un Mac, configura un identificador de app propio y un equipo Apple con capacidad Push Notifications. Añade esa capacidad al target. Xcode genera el entitlement `aps-environment` y lo firma según el perfil.
2. En el servidor, guarda la clave APNs `.p8`, Key ID, Team ID y Bundle ID en un gestor de secretos. No los copies a la app ni al repositorio.
3. Implementa una sesión de instalación autenticada con token corto, almacenado en Keychain, y validación App Attest antes de aceptar registros. No utilices el device token como autenticación.
4. Después del permiso de iOS y solo cuando ese backend esté disponible, llama a `UIApplication.shared.registerForRemoteNotifications()` desde el actor principal. Repite el registro al iniciar; APNs puede cambiar el token.
5. En `AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`, sustituye el almacenamiento provisional por el envío autenticado al endpoint descrito abajo. No actives ese registro en la demo sin backend.

Contrato por implementar:

| Endpoint | Comportamiento |
| --- | --- |
| `PUT /v1/installations/{id}` | Registrar/rotar token y guardar país, temas de notificación, enabled, timezone y versión de preferencias |
| `DELETE /v1/installations/{id}` | Revocar instalación, borrar token y cancelar pendientes |
| `PATCH /v1/installations/{id}/preferences` | Actualizar preferencias con control de versión y cancelar cola obsoleta |

El servidor deriva `owner_subject` de la sesión, comprueba que el ID pertenece a esa sesión y valida enums, longitudes y zonas horarias. Nunca confía en un owner enviado por el cliente. Cifra device tokens en reposo; guarda hashes solo para deduplicar. No registra tokens, búsquedas ni secretos en logs.

Al desactivar notificaciones, borrar preferencias o revocar el permiso en iOS, sincroniza `enabled=false`. Conserva la operación pendiente localmente si no hay conexión y reintenta. Expira instalaciones sin actividad y elimina tokens ante `410 Unregistered`. Incluye eliminación de la instalación y política de retención en la versión publicada.

## Reglas y concurrencia

- Solo noticias con urgencia editorial verificada; la categoría `top` de un proveedor no es prueba de urgencia.
- País seleccionado o noticia internacional expresamente pertinente; categoría incluida en las preferencias de avisos.
- Máximo 3 avisos diarios por instalación en su zona horaria y mínimo 60 minutos entre ellos. Excluye artículos de más de 6 horas y fechas futuras.
- ID y hash de URL canónica únicos por instalación. Mantén las claves de deduplicación al menos 30 días.
- Abre transacción y bloquea la fila de instalación (`SELECT ... FOR UPDATE`). Revisa límites, versión y enabled, reserva el envío e inserta en una outbox con clave única. Las reservas pendientes también cuentan para evitar carreras.
- Un worker reclama una reserva; vuelve a verificar enabled, versión y límites antes de enviar. Una modificación de preferencias cancela reservas antiguas.
- Si se activa push, desactiva los avisos automáticos locales de noticias para evitar avisos dobles. Mantén únicamente el botón de prueba local.

## Envío APNs

Usa HTTP/2 y TLS con APNs sandbox para desarrollo o producción para distribución. Firma el JWT con ES256 usando la clave del servidor; incluye `iss` (Team ID), `iat` y `kid` (Key ID). Renueva y reutiliza el token según los límites de Apple.

Envía `POST /3/device/{token}` con `authorization: bearer ...`, `apns-topic` igual al Bundle ID, `apns-push-type: alert`, `apns-priority: 10`, expiración corta y `apns-collapse-id` derivado de la noticia. Incluye `aps.alert`, sonido y `articleURL` HTTPS validada.

- `200`: APNs aceptó el mensaje; no significa que el usuario lo recibió o lo leyó.
- `410`: elimina el token inválido.
- `429`/`5xx`: reintento exponencial con jitter, vencimiento y límite de intentos.
- `400`/`403`: revisar payload, topic o credenciales; no repetir indefinidamente.
- Un timeout después de enviar es ambiguo: la entrega exactamente una vez no está garantizada. Registra el intento; usa collapse ID y evita reintentos agresivos.

## Prueba de recepción en simulador

Con la app instalada y el permiso concedido:

```sh
xcrun simctl push booted com.example.mynews Backend/sample.apns
```

Si cambias el Bundle ID, actualiza el comando y `Simulator Target Bundle`. Toca el aviso y verifica que abre la página de ejemplo en Safari integrado. Esto prueba la recepción, no la autenticación ni una entrega real mediante APNs.

## Referencias

- [Registro del dispositivo](https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications())
- [Conexión con APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-connection-to-apns)
- [Solicitar permisos](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

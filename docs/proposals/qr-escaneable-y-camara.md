# QR escaneable y lectura con cámara

- **Estado:** IMPLEMENTADO en la demo (aprobado por Juanmi, 2026-10-11). Más abajo se conserva la propuesta original como contexto.

## Implementación

- **Dependencias** (versiones fijas, resueltas con Flutter 3.35.2 / Dart 3.9):
  - `qr_flutter` 4.1.0 (y `qr` 3.0.2): Dart puro, sin código nativo ni permisos.
  - `mobile_scanner` 7.4.2: Android con CameraX y ML Kit (minSdk 23; el proyecto usa 24); iOS con AVFoundation y Apple Vision (iOS 12; el proyecto usa 13.0).
  - ML Kit **incluido** en la app (`dev.steenbakker.mobile_scanner.useUnbundled=false` en `android/gradle.properties`): no depende de descargar el modelo con Google Play Services en el primer uso.
- **QR** (`CredentialQrView`, `ticket_widgets.dart`): codifica solo la credencial vigente; identidad y estado se consultan en `TicketGateway`. Negro sobre blanco opaco, margen de 4 módulos, corrección M y tamaño adaptable (hasta 260 dp). Al reemplazar la credencial, el QR cambia con ella.
- **Lectura** (`CredentialScannerPage`, `credential_scanner.dart`): en Puerta, Caja y el comprobante de venta del promotor, con el botón «Leer QR con la cámara» / «Leer QR del comprador».
  - Solo QR. Una lectura por intento: la primera cierra el lector y las detecciones repetidas se ignoran. Una lectura que llega cuando el puesto ya no está no hace nada.
  - Lo leído sigue el mismo camino que lo escrito: Puerta consulta (`doorCheck`) y la persona confirma el ingreso; Caja y el promotor piden confirmar el canje, que va por `TicketGateway` con un identificador por intento (idempotente).
  - Permiso denegado, sin cámara o fallo: se explica, con «Reintentar» cuando tiene sentido. «Escribir la credencial» vuelve al campo manual, que sigue disponible.
  - La cámara se detiene al salir de la app, se reanuda al volver y se libera al cerrar el lector.
- **Un solo QR (2026-10-12):** «Mi QR» del cliente es el QR de su entrada de la noche; barra lo lee (o escribe la credencial) solo para identificar la cuenta, con `TicketGateway.identifyAccount`. Detalle en [pedidos de barra](../business-rules/pedidos-barra.md).
- **Permisos:** `android.permission.CAMERA` (con `android.hardware.camera` no obligatoria) y `NSCameraUsageDescription`: «Rumbaap usa la cámara solo cuando el personal la activa para leer el código QR de las entradas en la puerta, la taquilla o la entrega de manillas. No se guardan fotos.»
- **Privacidad:**
  - El QR no lleva nombre, cédula ni estado. La app no guarda fotos ni escribe en registros el código leído.
  - Según los [términos de ML Kit](https://developers.google.com/ml-kit/terms), el procesamiento de las imágenes ocurre en el dispositivo y ML Kit no envía las imágenes ni sus resultados a Google, pero **sí envía a Google métricas de rendimiento y uso de las APIs**. No se promete cero telemetría. En iOS la lectura usa Apple Vision, no ML Kit.
- **Validación:**
  - Tests de widgets con una plataforma de cámara simulada (permisos, fallos, duplicados, ciclo de vida, contexto, consulta y confirmación por el gateway).
  - Android (emulador): ML Kit decodificó con `analyzeImage` el PNG realmente renderizado del QR; la lectura de fotogramas con la cámara virtual se documenta en el informe de cada entrega.
  - Pendiente: dispositivo Android físico e iOS en macOS/Xcode (`iOS NATIVE VALIDATION PENDING`; el simulador de iOS no tiene cámara).

## Propuesta original

## Qué falta

1. **Mostrar un QR real** con la credencial opaca (12 caracteres) en la ficha de la entrada.
2. **Leerlo con la cámara** en los puestos de Seguridad, Caja y el promotor (su lote). El resultado debe ir por `TicketGateway`, igual que la lectura manual.

## Dependencias candidatas (a verificar antes de aprobar)

| Paquete | Para qué | Notas a comprobar |
|---|---|---|
| `qr_flutter` | Generar el QR en pantalla | Dart puro, sin código nativo ni permisos. Comprobar la última versión compatible con Flutter 3.35.2 / Dart 3.9, su licencia y su mantenimiento. |
| `mobile_scanner` | Leer el QR con la cámara | Código nativo: en Android usa ML Kit (Google) y en iOS el framework de Apple. Comprobar la versión compatible con Flutter 3.35.2 / Dart 3.9, el minSdk que exige (el proyecto usa 24), la versión mínima de iOS (el proyecto usa 13.0), si el modelo de ML Kit va incluido o se descarga con Google Play Services, el tamaño añadido, la licencia y el mantenimiento. |

- **Alternativa sin dependencia de cámara:** mantener la entrada manual como respaldo accesible. Se recomienda conservarla en cualquier caso, para cuando falle la cámara o la luz.
- **Versión:** no se fija aquí. Se fijará tras resolverla con `flutter pub get` en una rama aparte, como se hizo con `shared_preferences`.

## Permisos (mismo cambio, CLAUDE.md §9)

- **Android:** `android.permission.CAMERA` en `AndroidManifest.xml`; se pide en tiempo de ejecución.
- **iOS:** `NSCameraUsageDescription` en `Info.plist`. El texto visible es una decisión de producto, por ejemplo: «Para leer el código de las entradas en la puerta y la taquilla».
- **Solo para el personal:** el cliente no necesita la cámara para mostrar su QR.

## Privacidad

- El QR contiene solo la credencial opaca: ni nombre, ni cédula, ni estado.
- La lectura debería hacerse en el dispositivo, sin enviar imágenes. Hay que confirmar en la documentación del paquete si ML Kit envía algo; el uso sin conexión es lo esperado.
- No se guardan fotos.

## Validación

- Android en emulador (cámara virtual) y en dispositivo físico.
- iOS solo en macOS/Xcode con un dispositivo real: el simulador no tiene cámara. Seguirá como `iOS NATIVE VALIDATION PENDING` hasta entonces.

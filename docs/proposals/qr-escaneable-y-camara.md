# Propuesta: QR escaneable y lectura con cámara

- **Estado:** `PROPUESTA` pendiente de revisión. No hay nada instalado ni aprobado.
- **Pendiente de frontend registrado:** la ilustración del QR (no escaneable) y la entrada manual de la credencial no cierran el recorrido de puerta y taquilla. Hoy la lectura es una SIMULACIÓN.

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

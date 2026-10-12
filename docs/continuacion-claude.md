# Continuación — checkpoint del 2026-10-12

Para retomar: `git rev-parse HEAD` y `git status`. Este archivo se guarda en un commit solo de documentación posterior al código; el hash de ese commit no se fija aquí.

## Estado

- Rama: `feat/frontend-operations-demo` (solo local, sin push). Fase: prototipo frontend con datos de demostración (CLAUDE.md §1).
- Último commit de código: `0b2324b0d0a19196adccb526c12a2cc8f4143ee8`, tree `44c0fee`. Contiene el flujo de champaña VIP y el cumpleaños en las reservas.
- Checks de ese código: `git diff --check` limpio, `dart format` sin cambios, `flutter analyze` sin problemas y suite completa 477/477 (exit 0).

## APK verificados (sin `RUMBAAP_DEMO_NOW`, firma verificada con apksigner)

Carpeta: `C:\Users\draco\Downloads\rumbaap-0b2324b\`

| Archivo | Bytes | SHA-256 |
|---|---|---|
| `rumbaap-0b2324b-debug.apk` | 162271237 | `aef58463d4f00d96dbb9fbe1d1dfd3f74258ff8dec9970c956088bf1f07ad3de` |
| `rumbaap-0b2324b-profile.apk` | 88529266 | `30e295b21f601a0bf9411d1ca4027d61e73a74b3f986011e916be2995037d5c6` |

Empaquetado limpio: antes de compilar se borran `build/app/outputs/apk/*/*.apk` y `build/app/outputs/flutter-apk/*.apk`; si no, quedan huecos vacíos (unos 15–18 MB) dentro del zip.

## QA nativa ejecutada (Android, 2026-10-12)

- Pixel_7 (API 34) en `emulator-5580`: un solo arranque con `-memory 1536 -cores 2 -gpu host -no-window -no-snapshot -no-audio`, sin cámaras. Boot en 38 s; `adb install -r` del debug conservó los datos; `font_scale` restaurado a 1.0; AVD cerrado al terminar.
- Probado por la interfaz, lunes 15:05 (Colombia):
  - el cliente A creó la reserva R15 (mesa M03, viernes 16 de octubre) con un cumpleaños de demostración;
  - el seguimiento del cliente no muestra acciones de administración;
  - la administración confirmó condiciones con decoración, la marcó preparada y ajustó el acuerdo: la decoración pasó a «por revisar otra vez» y el acuerdo anterior quedó visible;
  - todo persiste tras `force-stop` y reapertura.
- Champaña: solo comprobado el bloqueo fuera de horario (Barra y mesero sin noche en curso, sin botón de salida). El flujo completo NO se probó en dispositivo.
- Logcat: 0 errores de Flutter, 0 desbordes, 0 FATAL. La captura `04_form_lleno.png` muestra un error de escritura del teclado (las notas cayeron en el nombre) que se corrigió antes de enviar.
- Evidencia: `C:\Users\draco\Downloads\rumbaap-0b2324b\qa-nativa-2026-10-12\`. Contiene 16 PNG, `logcat.txt`, `emu_out.log` y `emu_err.log`.

## Reglas afectadas

- [Beneficios VIP](business-rules/beneficios-vip.md): champaña y cortesías.
- [Cumpleaños](business-rules/cumpleanos.md).
- Datos confirmados:
  - entrevistas: E1 P6 (registro en papel), E1 P7 (las promociones actuales son solo de cumpleaños) y E2 P13 (decoración antes de la apertura, si corresponde);
  - pedido del usuario de incluir el cumpleaños;
  - confirmado por el usuario sobre VIP:
    - 1 botella de champaña por mesa y 6 entradas de cortesía, que se canjean por manillas en taquilla;
    - las cortesías se canjean tras la verificación del prepago y la aprobación de la reserva;
    - la champaña sale solo con la mesa ocupada y la petición de la mesa: salida en Barra y entrega del mesero;
    - prepago de 2.000.000: con un consumo de 2.300.000 solo se cobran 300.000;
    - el saldo no usado se pierde esa noche, sin devolución;
    - aplicarlo a otra noche se acuerda directamente con la administración, sin transferencia automática.
- Decisiones de prototipo, pendientes de validar con el cliente:
  - cumpleaños: atributo opcional normal/VIP, sus campos y estados; la decoración la marca solo la administración; edición con historial;
  - champaña: petición también desde la app; permisos resueltos por identidad; un solo evento por reserva/mesa/local/noche, idempotente; reserva terminada sin pasos nuevos.

## Pendientes

1. Flujo positivo completo de la champaña en una noche en curso (cliente o mesero → Barra → mesero), en dispositivo.
2. Vista estrecha con texto grande en el dispositivo. En tests, a 320 px y 2×, las filas de la lista de reservas son más altas que la lista (era así antes de este cambio).
3. Cámara física, iOS nativo (macOS/Xcode) y Android API 24.
4. NOT DECIDED:
   - marca y precio de la champaña;
   - efecto de terminar la reserva sobre los demás beneficios (no afecta al vencimiento del saldo ni revoca derechos ya otorgados);
   - correcciones de ventas contra el prepago;
   - otros cargos que puedan marcar la decoración;
   - promociones, importes y fechas de cumpleaños.

## Siguiente paso

Bloque nuevo con Sonnet (CLAUDE.md §15): definir con Codex la próxima tarea. Para la QA positiva de la champaña hace falta una noche en curso real, sin falsificar la fecha.

## Estado de la herramienta

- Modelo activo: Sonnet 5.5.
- Preferencia persistente local no guardada: el clasificador automático la rechazó; sin reintentos ni cambios de permisos.

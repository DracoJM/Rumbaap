# Continuación — checkpoint del 2026-10-12 (pausa hasta el 2026-10-13)

Entrada canónica para retomar. Leer este archivo, `git branch --show-current` y `git status`; después, solo el tema afectado en el [índice](README.md#índice-por-tema). El detalle (hashes, fuentes externas, estados, decisiones abiertas) está en [`continuidad/fuentes-y-evidencia.md`](continuidad/fuentes-y-evidencia.md). No releer todo `docs/` ni el transcript, ni repetir checks o builds aprobados.

## Estado

- Rama `feat/frontend-operations-demo` (solo local, sin push). Prototipo frontend con datos ficticios, sin backend, pagos reales ni inventario (CLAUDE.md §1).
- **Última entrega de CÓDIGO: `1279f61`** (árbol `42215944b125`). El commit de HEAD posterior a este solo cambia `docs/`: `lib/`, `test/`, `pubspec.*`, `android/` e `ios/` son idénticos a `1279f61` (comprobar con `git rev-parse HEAD:lib 1279f61:lib`, igual para las demás rutas).
- Verificado por ejecución antes de `1279f61` (exit 0): `dart format`, `git diff --check`, `flutter analyze` y suite completa **506/506**. Los 31 de `map_interactions_test` ya están en los 506: no se suman.
- APK de `1279f61`, sin `RUMBAAP_DEMO_NOW`, firmados con la clave de debug (válidos para la demostración, no para distribuir): carpeta `C:\Users\draco\Downloads\rumbaap-1279f61\` con `entrega.txt`, debug (177 289 347 B) y release (67 290 550 B); hashes en el detalle. Inmutables: no recompilar sin cambio de producción.

## Evidencia y límites

- **Android nativo anterior (`0b2324b`)**: `Downloads\rumbaap-0b2324b\qa-nativa-2026-10-12\`. Cumpleaños, persistencia tras `force-stop` y champaña solo con su bloqueo fuera de horario. Se conserva intacta.
- **QA nativa de `1279f61`: NINGÚN paso se hizo.**
- **18 capturas de render de widgets** (`Downloads\rumbaap-qa-widgets-2026-10-12\`): datos ficticios y reloj inyectado solo en el montaje del test. No son QA Android. Límites: el mapa pinta sus etiquetas con `TextPainter` y en test salen como rectángulos Ahem, así que no es fiel; la barra inferior se desplaza en horizontal de forma intencional cuando no caben las secciones (con Roboto cabe a 393 dp y se desplaza al 200 %).
- Emulador `Pixel_7` cerrado: lo abre el usuario a mano. El arranque por el asistente fue denegado por el clasificador («Interfere With Workloads»; sin reintentos ni alternativas), igual que guardar Sonnet como modelo por defecto. Modelo de la sesión: Sonnet 5.5. Equipo de 16 GB de RAM: medir la RAM antes del emulador, sin prometer RAM libre estable ni borrar datos de la app.

## Siguiente tarea (13 de octubre)

1. El usuario abre `Pixel_7`. Confirmar con `adb devices` (ruta absoluta del SDK) que existe y qué versión (debug o release) está instalada; no borrar datos (`adb install -r` los conserva).
2. Probar en dispositivo lo nuevo: formularios, foco y teclado real (en Barra, «Escribir la credencial» enfoca «Credencial»; cancelar el lector no); venta y entrega de manilla propia del promotor fuera de fecha (venta «Comprador QA diseno», con datos ficticios; contador «Sin entregar: N de M»; sin doble entrega); Barra «Cliente sin cuenta» (campos opcionales, estado no verificado, sin atribuir a una cuenta anterior) y los motivos de «Sin mesa» (el selector solo ofrece reservas confirmadas u ocupadas de la noche en curso); persistencia tras `force-stop`; Promotor y Barra a 320 dp / texto 200 % (restaurar `font_scale`).
3. Flujo positivo de VIP, cortesías, llegada y consumo, y champaña con petición y entrega: solo en una noche activa real, sin falsear el reloj ni usar APK con reloj forzado. Sigue pendiente.
4. Después: iOS nativo (macOS/Xcode), Android API 24 y cámara física. Al cerrar, actualizar este checkpoint (qué cambió, qué se probó, qué no, siguiente paso).

## Derechos y fronteras que no se deben perder

(Detalle y estado en las reglas enlazadas; mandan las aclaraciones del hilo de trabajo actual sobre champaña, saldo VIP, comprador, entrega de manillas, cumpleaños y Barra. Manillas (A8) y el ejemplo de 300 mil (A7): aclaraciones previas del contexto maestro de ChatGPT v42 (11-oct 19:09), fuente indirecta.)

- **Reservas** ([reservas-y-noches](business-rules/reservas-y-noches.md)): mesa normal gratis, con consumo mínimo de 400.000 COP; la tolerancia la maneja el personal («300 mil» fue un ejemplo del entrevistado, no otro umbral) y no hay cobros, multas ni bloqueos automáticos. El borrador normal dura 10 min; la confirmada no usa ese temporizador de 10 min. Hora límite de 11 p. m.: dato operativo conocido; su liberación automática NO está implementada (pendiente técnico); no desaloja una mesa ocupada ni aplica a la VIP pagada. Capacidad de la normal: `NOT DECIDED`.
- **Mapa y horario**: 20 mesas normales + 2 VIP, sin cambios. Viernes a domingo, 8:30 p. m.–3:00 a. m. de Colombia: horario registrado (N1, `VALIDATED`) y configuración actual del calendario del prototipo, no una imposición nueva al cliente.
- **VIP** ([pedidos-barra](business-rules/pedidos-barra.md), [beneficios-vip](business-rules/beneficios-vip.md)): prepago de 2.000.000 COP por mesa; hasta 20 personas por mesa y 40 juntas (4M; E2 P9). La unión transaccional indivisible es un criterio técnico futuro, no implementada. Se cobra solo el excedente; el saldo no usado se pierde al terminar esa noche, sin devolución. En cancelación o no llegada, la frontera confirmada es manual: puede acordarse otra noche directamente con la administración (gestión pendiente, sin devolver, vencer ni trasladar automáticamente); los pasos, condiciones y circuito financiero específicos siguen `NOT DECIDED`. 1 botella de champaña y 6 cortesías por mesa, fuera del consumo, que se habilitan tras verificar el prepago y aprobar la reserva. La champaña sale solo con la mesa ocupada y una petición: Barra registra la salida y el mesero confirma la entrega. Caja canjea las cortesías por manillas solo en noche en curso y Barra solo registra ventas y la salida de la champaña (Barra no canjea manillas): restricciones de implementación, no condiciones ratificadas.
- **Cumpleaños** ([cumpleanos](business-rules/cumpleanos.md)): según las entrevistas (E1 P6, P7; E2 P13); la administración confirma condiciones y decoración antes de abrir; sin beneficios automáticos. Importe, paquete y ventana: `NOT DECIDED`.
- **Entradas y Promotor** ([entradas](business-rules/entradas.md)): venta con nombre, teléfono y cédula obligatorios; las ventas anteriores cargan sin ellos. El promotor entrega la manilla de su propio lote en cualquier momento, una vez por entrada, con pago comprobado, derecho activo y credencial; no da acceso automático ni hay lector QR. Otros actores (Caja, Seguridad, otro promotor) no tienen esa excepción. Las manillas son físicas, transferibles y no nominativas, y el reingreso se controla con ellas; la edad la comprueba el personal. Fórmula de puntos y vinculación futura: `NOT DECIDED`. Inventario, comisiones, subpromotores, monedero y traslado de consumos: fuera de alcance, no se abren por defecto.
- **Barra** ([pedidos-barra](business-rules/pedidos-barra.md)): campo «Credencial» (con foco solo al elegir escribir a mano); cliente sin cuenta con datos opcionales y no verificados, separado de la cuenta (`accountId`) y guardado en la venta; «Sin mesa» disponible siempre.
- **Siguen `NOT DECIDED`**: backend, base de datos, hosting, autenticación, pagos, analytics, CI/CD, macOS, flavors; marca y precio de la champaña; pasos, condiciones y circuito financiero de la cancelación/no-show de la VIP (solo la frontera manual está confirmada); destino de los beneficios no usados al finalizar; corrección de ventas contra el prepago; precios, carta y pagos reales.

## Reglas de trabajo aplicables (CLAUDE.md)

Humanos deciden; Claude no inventa requisitos (§2–3). Sin commit, push, merge ni tag sin aprobación (§7); sin dependencias nuevas (§8). Informar ejecutado, inspeccionado y pendiente (§5). Un bloque, sin subagentes, `rg` y lecturas acotadas; checkpoint al cerrar (§15).

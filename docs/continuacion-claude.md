# Continuación — checkpoint del 2026-10-14 (cierre local del incremento visual)

Entrada canónica para retomar. Leer este archivo, `git branch --show-current` y `git status`; después, solo el tema afectado en el [índice](README.md#índice-por-tema). El detalle (hashes, fuentes externas, estados, decisiones abiertas) está en [`continuidad/fuentes-y-evidencia.md`](continuidad/fuentes-y-evidencia.md). No releer todo `docs/` ni el transcript, ni repetir checks o builds aprobados.

## Estado

- Rama `feat/frontend-operations-demo` (solo local, sin push). Prototipo frontend con datos ficticios, sin backend, pagos reales ni inventario (CLAUDE.md §1).
- **Base histórica:** `1279f61` (última entrega de código anterior, árbol `42215944b125`) y `491028c` (HEAD de partida de este incremento, que solo cambió `docs/` respecto a `1279f61`). Verificado por ejecución antes de `1279f61` (exit 0): `dart format`, `git diff --check`, `flutter analyze` y suite completa **506/506** (los 31 de `map_interactions_test` ya están incluidos).
- **Incremento actual:** mejora visual compartida (ADR 0005) en un commit local posterior a `491028c`. Su hash no se escribe aquí: se comprueba con `git log --oneline -3` y lo registra el `entrega.txt` de la entrega externa. Cambia solo presentación (14 archivos: 9 de `lib/`, 2 de `test/` y 3 de `docs/`); no cambia reglas, permisos, modelos, snapshots, dependencias ni `android/`/`ios/`.
- **Checks del incremento (no sumar entre sí):** `dart format`, `flutter analyze` y `git diff --check` sin incidencias. Suite completa **527/527** (una vez, en serie), ejecutada **antes** del último ajuste pequeño (la búsqueda de Personal). Tras ese ajuste solo se ejecutaron los archivos afectados, `shared_design_test` y `guest_reservation_test`: **103/103** finales. No hay una suite completa posterior.
- **APK del incremento** (debug, firmado con la clave de debug; sirve para la demostración, no para distribuir; sin `RUMBAAP_DEMO_NOW`): SHA-256 `5216a2841a90320eab47b37c7205dad44c847fdf3fe9d71e36f5fe3f08421667`, 177 291 443 B; carpeta de entrega `C:\Users\draco\Downloads\rumbaap-<hash-corto-del-commit>\` con `entrega.txt`. Los APK de `1279f61` (debug y release, en `rumbaap-1279f61`) son **históricos** y no se actualizan.

## Evidencia y límites

- **Android nativo anterior (`0b2324b`)**: `Downloads\rumbaap-0b2324b\qa-nativa-2026-10-12\`. Cumpleaños, persistencia tras `force-stop` y champaña solo con su bloqueo fuera de horario. Se conserva intacta.
- **QA nativa de navegación de `1279f61`** (capturas por ADB, solo navegación, no es QA funcional): `Downloads\rumbaap-qa-diseno-2026-10-14\02-base-1279f61-*.png`. **QA nativa del incremento actual** (APK final): ver «Actualización» más abajo.
- **18 capturas de render de widgets** (`Downloads\rumbaap-qa-widgets-2026-10-12\`): datos ficticios y reloj inyectado solo en el montaje del test. No son QA Android. Límites: el mapa pinta sus etiquetas con `TextPainter` y en test salen como rectángulos Ahem, así que no es fiel; la barra inferior se desplaza en horizontal de forma intencional cuando no caben las secciones (con Roboto cabe a 393 dp y se desplaza al 200 %).
- Emulador `Pixel_7`: el arranque automático fue denegado antes por el clasificador («Interfere With Workloads»); el 2026-10-14 el usuario lo abrió a mano y luego pidió y autorizó explícitamente abrirlo. No se reinicia ni se cierra por iniciativa propia. Guardar Sonnet como modelo por defecto también fue denegado. Modelo de la sesión: Sonnet 5.5. Equipo de 16 GB de RAM: medir la RAM antes del emulador, sin prometer RAM libre estable ni borrar datos de la app.

## Siguiente tarea (histórico del 13 de octubre; ver el estado actual en «Actualización»)

1. El usuario abre `Pixel_7`. Confirmar con `adb devices` (ruta absoluta del SDK) que existe y qué versión (debug o release) está instalada; no borrar datos (`adb install -r` los conserva).
2. Probar en dispositivo lo nuevo: formularios, foco y teclado real (en Barra, «Escribir la credencial» enfoca «Credencial»; cancelar el lector no); venta y entrega de manilla propia del promotor fuera de fecha (venta «Comprador QA diseno», con datos ficticios; contador «Sin entregar: N de M»; sin doble entrega); Barra «Cliente sin cuenta» (campos opcionales, estado no verificado, sin atribuir a una cuenta anterior) y los motivos de «Sin mesa» (el selector solo ofrece reservas confirmadas u ocupadas de la noche en curso); persistencia tras `force-stop`; Promotor y Barra a 320 dp / texto 200 % (restaurar `font_scale`).
3. Flujo positivo de VIP, cortesías, llegada y consumo, y champaña con petición y entrega: solo en una noche activa real, sin falsear el reloj ni usar APK con reloj forzado. Sigue pendiente.
4. Después: iOS nativo (macOS/Xcode), Android API 24 y cámara física. Al cerrar, actualizar este checkpoint (qué cambió, qué se probó, qué no, siguiente paso).

## Actualización 2026-10-14 (cierre local del incremento visual)

**Ya hecho en `Pixel_7` (`emulator-5554`, Android; ANDROID VALIDATED solo para lo listado):**
- Navegación de `1279f61` (base) y, con el APK final, mapa cliente, abrir y cerrar una mesa sin reservar, Más, Entradas del Promotor, Admin (Pendientes, Reservas y Actividad, también desplazando el selector), Barra y Personal, a 411 dp / texto 1.0 y a 320 dp / texto 2.0.
- Barra: «Escribir la credencial» enfoca «Credencial» y abre el teclado; cerrar el lector no lo hace; alternar cliente con/sin cuenta limpia credencial y contacto; sin ventas fuera de horario. El lector abrió con la escena virtual del emulador: **no valida una cámara física**.
- Promotor: campos obligatorios exigidos; una venta demo ficticia **C1** («Comprador QA diseno 14», 3000000000, 1000000000, noche futura, 1 entrada), pago comprobado, una entrega de manilla del lote propio («Sin entregar: 0 de 1», sin doble entrega) y persistencia tras `force-stop` de la app. C1 se **conserva**.
- «+» / «−» de Personas: funcionan (1 → 2 → 1); el fallo inicial fue un selector de prueba erróneo, no del control.
- Defectos a 320 dp / 200 % corregidos y reprobados: pestaña activa entera a la vista, regreso Más → Mapa deslizando la fila, y búsqueda de Actividad y de Personal («Buscar» más ayuda). Causas en el ADR 0005.
- Ajustes del emulador restaurados tras cada fase: densidad física 420 sin override y `font_scale` 1.0.

**Pendiente (no hecho; no se simula):**
- Flujo positivo de VIP, cortesías, llegada, consumo y champaña, solo en una noche activa real, sin falsear el reloj ni usar APK con reloj forzado.
- iOS nativo (macOS/Xcode): `iOS NATIVE VALIDATION PENDING`; el código Dart compartido pasó los tests, incluidas las variantes `TargetPlatform.iOS` (`iOS SHARED CODE VALIDATED`).
- Android API 24 y cámara física (el lector solo se vio con la escena virtual del emulador).

**Plan de QA operativa (2026-10-20, solo documentación; nada ejecutado):** [`qa/plan-validacion-operativa.md`](qa/plan-validacion-operativa.md). Recoge la matriz de 8 escenarios, las discrepancias señaladas sin corregir (reservas sin actor, prepago en dos pasos) y las diferencias con el resumen de continuidad externo.

## Actualización 2026-10-20 (actor y cargo de las acciones de reserva; sin commit)

- **Encargo:** opción A, autorizada por Juanmi con el adjunto `Rumbaap_Continuidad 1.md` (corte RC-20261019-2337). Antes de cambiar nada se verificó en el código el hallazgo 1 del plan de QA.
- **Cambio** (sobre `9d50e1d`, sin commit ni push):
  - Confirmar prepago, rechazar, registrar llegada, revocar y liberar exigen un `actorId`, que el libro autoriza (`ReservationBook.canPerform`) y guarda en el evento (`ReservationEvent.actorId`).
  - La matriz es la que ya aplicaban las vistas: administración todas; el mesero, además, la llegada. Está en `RumbaapApp.reservationActionAllowed`.
  - Las vistas pasan la identidad activa y conservan la comprobación de estado tras las confirmaciones.
  - Los eventos antiguos, las altas y vencimientos, y la siembra (`seedArrival`) quedan sin actor.
  - El snapshot añade la clave opcional `actorId` sin cambiar el formato.
  - Detalle en [actor y cargo](architecture/admin-reservations-demo.md#actor-y-cargo-de-las-acciones-de-reserva-2026-10-20).
- **Sin tocar:** el circuito de prepago, los beneficios, el saldo, el cumpleaños, el mapa y el diseño. Tampoco dependencias, `android/`, `ios/` ni `pubspec.lock`.
- **Comprobación (ejecutada, Windows):**
  - format sin cambios, analyze sin problemas y `git diff --check` limpio;
  - tests afectados en serie: 434/434;
  - suite completa en serie, una vez: **537/537**, que incluye a los anteriores.
  - La evidencia está en el plan de QA.
- **Límites:** no se compiló APK ni se abrió el emulador. La interfaz no muestra todavía el actor de las reservas (cambio visible, pendiente de aprobación). Sin identidad activa, `ReservationActions` no ofrece acciones, y en la app siempre la hay. Son identidades ficticias, no autenticación.
- **Siguiente paso:** revisión de Juanmi y commit, si lo aprueba. Después, la QA nativa del plan en una noche válida real.

## Actualización 2026-10-20 (QA nativa Android de A; sin commit)

- **APK:** `Downloads\rumbaap-9d50e1d+A-2026-10-20\rumbaap-9d50e1d+A-debug.apk`, SHA-256 `939d64aebd87bef0c47ee23698aee3a6a6aaf70fbc853c589168a62d932ebefa`. Fuente: 9d50e1d más el parche sin commit. El instalado en `Pixel_7` tiene el mismo SHA y los datos se conservaron.
- **ANDROID VALIDATED:**
  - el actor guardado tras un cierre forzado y la reapertura: revocar R22, confirmar el prepago de R23 y rechazar R31, los tres `admin-1`;
  - la navegación por roles;
  - la llegada desactivada fuera de horario.
  - Las altas, sin actor, como estaba previsto.
- **Bloqueado por horario:** la llegada, liberar, Barra, VIP, cortesías y champaña.
- **Detalle:** [plan de QA](qa/plan-validacion-operativa.md#qa-nativa-android-de-a-2026-10-20-0055-0106-fuera-de-la-noche) y el `entrega.txt` de la carpeta.
- **Siguiente bloque autorizado por Juanmi:** extender el actor y el cargo a las altas, conservando los permisos de cada flujo (solicitudes del cliente y del promotor, operaciones del personal y reservas directas), sin copiar la matriz de las cinco acciones ni restringir todo a la administración.

## Actualización 2026-10-20 (altas con actor y cargo, y revisión del prepago; sin commit)

- **Cambio** (sobre 9d50e1d + A, sin commit ni push):
  - Las altas comprueban el permiso del flujo en la lógica (`ReservationBook.canCreate`, matriz en `RumbaapApp.reservationCreationAllowed`) y guardan su actor: `startNormal`, `submitNormal`, `cancelInProcess`, `submitVip` y `createDirect`.
  - Cliente y promotor: sus solicitudes. Administración: la directa. El personal no crea reservas.
  - El trámite solo lo envía o cancela quien lo empezó.
  - Se retiraron las rutas sin actor (`requestNormal`, `completeRequest`, `requestVip`, `seedArrival`). La siembra va en un único `seedDemoNight`, sin actor.
  - Las pantallas pasan la identidad activa. `DirectReservationPage` recibe `actorId`.
  - Detalle en [altas](architecture/admin-reservations-demo.md#actor-y-cargo-de-las-acciones-de-reserva-2026-10-20).
- **Comprobación (ejecutada):** format, analyze y diff-check sin incidencias; afectados en serie 438/438; suite completa en serie **541/541**, una vez.
- **Android:** APK `Downloads\rumbaap-9d50e1d+altas-2026-10-20\rumbaap-9d50e1d+altas-debug.apk`, SHA-256 `cd196e23f9944f82885eb7e9a906c8d8bba9ffd7e1821081ee801f0dd2c2d7d0`; el instalado coincide. **ANDROID VALIDATED:** el actor de las altas R32, R33, R34 y R42 se conserva tras un cierre forzado; el mesero no tiene altas. Detalle en el [plan de QA](qa/plan-validacion-operativa.md#altas-de-reserva-con-actor-y-cargo-2026-10-20-sin-commit).
- **Prepago VIP:** revisión documental y propuesta (P1 un solo acto, P2, P3) en [prepago en dos pasos](proposals/prepago-vip-dos-pasos.md). No se tocó dinero, saldo ni beneficios. Hallazgo: `BarBook.registerPrepaid` no comprueba en la lógica ni el cargo ni el estado de la reserva.
- **Pendiente:**
  - las respuestas a las preguntas del prepago;
  - la ventana de noches por perfil (N5 y N7), que limitan las vistas y no la lógica;
  - la QA en una noche válida;
  - Android físico, API 24 e iOS nativo;
  - la revisión de Juanmi y el commit, si lo aprueba.

## Actualización 2026-10-20 (paquete para Codex y regresión de reservas; sin commit)

- **Paquete de revisión, corte REV-20261020-0402:** `Downloads\rumbaap-revision-codex-2026-10-20\`.
  - `01` diff `9d50e1d -- lib test` (SHA-256 `9082929a…313f`);
  - `02` la propuesta del prepago;
  - `03` la lista de archivos;
  - `04` los puntos señalados: registro del importe, aislamiento de la siembra y ventana de noches.
- **Regresión:** se añadió un solo test, porque los demás casos ya estaban cubiertos: un trámite recuperado tras cargar, incluidos datos anteriores, solo lo envía su creador, y la noche no se siembra encima. Archivo afectado 15/15; suite completa en serie **542/542**.
  - Sin cambios en el código de producción ni defectos reproducidos.
  - Diff aislado: `Downloads\rumbaap-revision-codex-2026-10-20\05-diff-regresion.patch`.
  - Hallazgos pendientes en el [plan de QA](qa/plan-validacion-operativa.md#regresión-de-reservas-2026-10-20-después-del-corte-rev-20261020-0402).

## Actualización 2026-10-20 (corrección C1 de Codex; sin commit)

- **Hallazgo C1:** `startNormal` y `submitVip` excluían el origen administrativo solo con un `assert`. Con los asserts desactivados, `admin-1` + origen admin pasaba `canCreate`.
- **Corrección:** `ReservationBook._authorizeRequestOrigin` rechaza ese origen con `ReservationException(notAllowed)` en ambos métodos, antes de tocar la mesa. `createDirect` sigue permitido a la administración; los flujos del cliente y del promotor, sin cambios. Se actualizó el comentario de `ReservationEvent.actorId`: las altas de usuario sí guardan actor.
- **Prueba nueva** (`reservation_book_test`, grupo «altas»): ambos rechazos dan la excepción de dominio con los asserts activados, sin crear nada, sin ocupar mesa ni consumir número. La directa siguiente recibe `R1`.
- **Comprobación (ejecutada):** format, analyze y diff-check sin incidencias; `test/features/reservations` en serie 322/322; suite completa en serie **547/547**, una vez (542 + los 4 diagnósticos de la auditoría + 1).
- **Sin cambios:** prepago, beneficios, ventanas por perfil y demás hallazgos. Sin APK ni emulador.
- **Diff del bloque:** `Downloads\rumbaap-c1-2026-10-20.patch`.
- **VIP (regla vigente y revisión de Codex):** R7 ya define la reserva directa con el pago validado. P1 sigue siendo la recomendación, pendiente de confirmar. La condición actual «noche no terminada» permite registrar el importe antes de abrir.

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

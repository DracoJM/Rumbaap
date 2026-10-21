# Plan de validación operativa (QA nativa pendiente)

- **Fecha:** 2026-10-20. **Base:** rama `feat/frontend-operations-demo`, HEAD `9d50e1d`, más los cambios sin commit de la corrección del hallazgo 1.
- **Alcance:** preparación de la QA. La matriz se obtuvo **por inspección** de código, tests y documentos. Lo único ejecutado son los tests de la «Evidencia del 2026-10-20»: ni builds, ni la app, ni el emulador.
- **Columna «Respaldo»:** nombra el código y los tests que cubren cada escenario. La suite completa pasó el 2026-10-20 (537/537) en este árbol; no es una prueba nativa.
- **Validación nativa:** `ANDROID VALIDATED` solo con ejecución real en el emulador `Pixel_7` o en un dispositivo. Para iOS sigue `iOS NATIVE VALIDATION PENDING` en todos los escenarios.

## Leyenda

- **C — Regla confirmada:** `VALIDATED` en las reglas de negocio, o aclaración del equipo.
- **P — Restricción del prototipo:** decisión de implementación, pendiente de validar con el cliente.
- **ND — No definido:** `NOT DECIDED`. No se prueba como comportamiento esperado; solo se comprueba que la app no lo inventa.

## Condiciones comunes

- **Noche activa real.** Viernes, sábado o domingo, de 8:30 p. m. a 3:00 a. m. de Colombia. Sin cambiar el reloj del dispositivo y sin un APK con `RUMBAAP_DEMO_NOW`. Fuera de esa ventana solo se pueden probar los casos negativos y los que no dependen de la noche (fila 7).
- **APK y datos.** APK de debug de `9d50e1d`, instalado con `adb install -r` para conservar los datos de la demo. No usar «Reiniciar demostración» sin autorización.
- **Datos ficticios.** Nada personal real. Por ejemplo, la venta C1 «Comprador QA diseno 14» ya existe y se conserva.
- **Antes de arrancar el emulador:** medir la RAM libre. El último dato fue de 2,4 GB libres el 2026-10-20.
- **Identidades de la demo:**
  - Cliente demo A y Cliente demo B
  - Promotor demo
  - Administrador (demostración)
  - Seguridad demo
  - Caja demo
  - Barra demo
  - Mesero/Personal

## Matriz

| # | Escenario | Actor | Precondiciones | Acción real en la interfaz | Resultado esperado | Respaldo (código / test) | Nativo pendiente |
|---|---|---|---|---|---|---|---|
| 1 | Prepago VIP, aprobación y habilitación de cortesías | Cliente o Promotor (solicita); Administración | VIP solicitada en «Pendiente de pago», sin caducidad (C, R2). Para el paso 2, VIP confirmada. | 1) Ficha de la reserva → «Confirmar prepago verificado» → confirmar. 2) Tarjeta de beneficios → «Registrar prepago verificado (2.000.000 COP)» → confirmar. 3) «Emitir cortesías VIP» con nombre (hasta 6). | Tras 1: «Confirmada» y evento «prepago verificado». Tras 2: prepago registrado. Solo entonces se emiten cortesías, sin superar 6 por mesa ni contar dos veces (C). Sin 2 no se ofrece emitir (P). Una VIP directa de Administración nace confirmada (C, R7), pero también necesita el paso 2 para emitir. El paso 1 guarda el actor y solo lo ejecuta Administración (desde el 2026-10-20). | `ReservationBook.markPrepaymentReceived`, `BarBook.registerPrepaid`, `issueVipCourtesies`; `vip_benefits_test` (líneas 105, 126, 139, 147, 357, 402), `admin_page_test` | Android: flujo positivo sin probar. iOS pendiente. |
| 2 | Canje de cortesías en taquilla | Caja | Cortesía emitida y enlazada a una VIP con prueba de aprobación (C). Noche en curso (P). | Personal → Caja → escribir la credencial (o «Lector») → consultar → «Canjear y entregar manilla». | Manilla entregada una vez. Después, puerta y taquilla responden «No canjeable» (C). Sin prueba de aprobación: rechazo «Cortesía VIP sin aprobación…» con incidencia (C). Una revocación posterior no anula una cortesía ya aprobada (C). Barra no canjea manillas (P). | `TicketBook.redeem` (puerta de entrada VIP), `staff_ticket_desks.dart`; `vip_redeem_gate_test`, `ticket_book_test` (líneas 128, 241, 460), `tickets_flow_test` | Android: canje positivo de una cortesía VIP sin probar. Cámara física y iOS pendientes. |
| 3 | Llegada y ocupación de mesa | Mesero (Personal) o Administración | Reserva «Confirmada» de la noche en curso (C, R5 y N6). | Personal → localizar la reserva → «Registrar llegada» → confirmar. También desde la ficha de Administración. | Pasa de «Reservada» a «Ocupada». La apertura no la registra sola, el cierre no desaloja, y leer un QR o entregar una manilla no marca la llegada (C). La liberación de las 11 p. m. es solo informativa: no está implementada (pendiente técnico). Queda quién la registró; otro cargo se rechaza en la lógica (desde el 2026-10-20). | `ReservationBook.markArrival`; `reservation_book_test` (llegada; grupo «actor y cargo»), `admin_page_test:460`, `guest_reservation_test:744` | Android: llegada real en noche activa sin probar. iOS pendiente. |
| 4 | Champaña: petición → salida → entrega | Titular (Cliente) o Mesero; Barra; Mesero | VIP con prueba de aprobación, mesa «Ocupada» y noche en curso (C). | 1) Titular, en su reserva, pide la champaña (o el Mesero registra el pedido verbal). 2) Barra → «Registrar salida de la botella». 3) Mesero → «Confirmar entrega en mesa». | Aprobar no la despacha. Sin la mesa ocupada y sin la petición, no hay salida (C). Cada paso guarda actor y hora; repetirlo no duplica; una botella por reserva (P). No cobra, no descuenta el prepago ni suma ingresos (C). | `BarBook.requestChampagne`, `dispatchChampagne`, `deliverChampagne`, `champagne_view.dart`; `vip_champagne_test`, `vip_champagne_flow_test` | Android: solo está probado el caso negativo fuera de horario (`0b2324b`). El positivo y iOS están pendientes. |
| 5 | Consumo VIP: 2.000.000 de prepago y 2.300.000 de consumo | Barra; Mesero; Administración (consulta) | Prepago registrado (fila 1, paso 2), mesa VIP de la noche en curso (C). | Barra → elegir la mesa VIP → productos hasta 2.300.000 → marcar «Pago presencial de la diferencia recibido» → registrar. Mesero → aceptar el consumo. | El prepago cubre 2.000.000 y solo se cobran 300.000. Nunca se vuelven a cobrar los 2.000.000. Mesero, Cliente y Administración ven prepago, consumido, saldo y excedente (C). Al terminar la noche el saldo se pierde, sin devolución (C). Corregir o anular estas ventas no está permitido (ND). | `BarBook.register` (prepago), `bar_views.dart`; `vip_prepaid_test` (líneas 91, 103, 114, 148, 160, 192) | Android: sin probar. iOS pendiente. |
| 6 | Compra de Barra para un cliente sin cuenta | Barra | Noche en curso (P: Barra solo vende en la noche en curso). | Barra → «Cliente sin cuenta» → con o sin nombre, teléfono y cédula → «Sin mesa» o una mesa → «Pago presencial completo recibido» → registrar. Repetir cambiando de modo. | Sin datos aparece «Cliente sin identificar». El contacto queda sin verificar, separado de la cuenta y guardado en la venta (C). Cambiar de modo descarta el código o el contacto (P). No crea cuenta, derechos ni puntos (C). | `UnverifiedCustomer`, `BarBook.register`; `bar_customer_test` (líneas 57, 81, 102, 118, 200, 222, 245) | Android: el cambio de modo y el foco ya se probaron el 14-oct. Falta la venta registrada en noche activa. iOS pendiente. |
| 7 | Entrega anticipada del lote propio y prevención de duplicados | Promotor (el que vendió); para el rechazo, otro actor | Venta del promotor con nombre, teléfono y cédula (C), pago comprobado, entrada activa con credencial. **Cualquier fecha y hora** (C). | Promotor → Entradas → su venta → «Entregar manilla de mi lote» → confirmar. Repetir. Otro actor intenta lo mismo. | Una entrega por entrada y el contador «Sin entregar: N de M» (P). Repetir responde «No canjeable». Otro actor: «Lote de otro promotor», con incidencia y sin canje (P). La entrega no es el ingreso (C). | `TicketBook.redeem` (`RedeemPoint.promoterLot`), `_PromoterTicket` en `guest_tickets.dart`; `promoter_lot_test` (líneas 109–238) | Android: entrega y no duplicado ya probados con C1 el 14-oct. Falta el rechazo de otro actor en nativo. iOS pendiente. |
| 8 | Cumpleaños con condiciones acordadas por la administración | Cliente, Promotor o Administración (marca); Administración (acuerda) | Reserva normal o VIP vigente (C: pedido real). | Formulario → interruptor «Celebración de cumpleaños» con nombre y notas. Administración → «Confirmar cumpleaños» o «Confirmar condiciones» → «Marcar decoración preparada» si corresponde. Ajustar el acuerdo. | Marcarlo no concede descuentos, entradas ni decoración (C, E1 P7). Solo Administración confirma y prepara, con actor y hora (P). Si se ajusta el acuerdo, queda en el historial y la decoración vuelve a «por revisar» (P). Importe, paquete y ventana: ND. | `ReservationBook.confirmBirthday`, `markDecorationPrepared`, `birthday_widgets.dart`; `birthday_test`, `birthday_flow_test` | Android: QA anterior de `0b2324b` (base distinta). Repetirla en `9d50e1d`. iOS pendiente. |

## Discrepancias detectadas (sin corregir)

1. **Reservas sin actor: CORREGIDO el 2026-10-20 (opción A, autorizada por Juanmi).**
   - **Antes:** «Confirmar prepago verificado», «Registrar llegada», rechazar, revocar y liberar guardaban el evento solo con la hora, y el cargo solo lo comprobaba la vista. Se verificó en el código antes de cambiarlo.
   - **Ahora:** el libro de reservas comprueba el cargo al ejecutar la acción y guarda la identidad activa en el evento. La matriz es la misma: administración todas, y mesero solo la llegada.
   - **Compatibilidad:** los eventos antiguos y la siembra quedan sin actor.
   - **Detalle:** [actor y cargo](../architecture/admin-reservations-demo.md#actor-y-cargo-de-las-acciones-de-reserva-2026-10-20).
   - **Evidencia:** ver «Evidencia del 2026-10-20». Para QA nativa: comprobar en un dispositivo que la llegada registrada por el mesero y el prepago confirmado por la administración se conservan tras cerrar y volver a abrir la app. La interfaz todavía no muestra el actor de las reservas.
2. **Dos pasos de la administración para un mismo prepago.** «Confirmar prepago verificado» (estado de la reserva) y «Registrar prepago verificado (2.000.000 COP)» (importe para Barra) son acciones separadas.
   - La champaña y el canje de cortesías dependen solo del primero.
   - Emitir cortesías y consumir en Barra dependen también del segundo.
   - Así, una VIP confirmada sin importe registrado queda con la champaña habilitada, sin cortesías emitibles y con Barra bloqueada.
   - Es coherente con [beneficios VIP](../business-rules/beneficios-vip.md) («reserva confirmada con su prepago registrado»), pero el resumen de continuidad habla de un solo acto («verifica prepago y aprueba»). La QA debe cubrir ambos pasos.
3. **Texto anterior en las reglas de Barra.** La primera línea de [pedidos de barra](../business-rules/pedidos-barra.md) dice que no hay «beneficios», pero los beneficios VIP ya existen.
4. **Decoración de cumpleaños.** E2 P13 la sitúa antes de la apertura. La app permite marcarla mientras la noche no haya cerrado, sin una restricción horaria. No se inventa ninguna regla: solo se señala.

## Evidencia del 2026-10-20 (corrección del hallazgo 1)

Verificado mediante ejecución en Windows, sobre el árbol con los cambios sin commit:

- **Formato y análisis:** `dart format lib test` no dejó cambios pendientes, `flutter analyze` no encontró problemas y `git diff --check` salió limpio.
- **Tests afectados en serie** (`test/features/reservations`, `benefits`, `bar`, `dashboard` y `test/app`): 434/434.
- **Suite completa en serie** (`flutter test -j 1`), una vez: 537/537. Incluye a los anteriores; no se suman.
- **Tests nuevos:**
  - el actor por acción, sin tocar el creador ni el origen;
  - la matriz de la demo para cada identidad y acción;
  - los rechazos en la lógica sin cambiar el estado ni el historial: titular, creador, promotor, mesero fuera de la llegada, Caja, Seguridad, Barra e identidad desconocida;
  - sin permisos inyectados no se ejecuta nada;
  - la llegada sembrada queda sin actor;
  - la persistencia con actor, y la carga de datos antiguos sin él;
  - el actor por la interfaz: «admin-1» al revocar y registrar la llegada, y «personal-1» en la llegada del mesero.
- **No se hizo:** ni APK, ni emulador, ni QA nativa de este cambio.

## QA nativa Android de A (2026-10-20, ~00:55–01:06, fuera de la noche)

- **Artefacto:** `rumbaap-9d50e1d+A-debug.apk`, SHA-256 `939d64aebd87bef0c47ee23698aee3a6a6aaf70fbc853c589168a62d932ebefa`, compilado desde `9d50e1d` más el parche sin commit (SHA-256 `c26efff8…22f1`).
- **Instalación:** con `adb install -r` en `Pixel_7`, que abrió Juanmi. El instalado tiene el mismo SHA y los datos previos se conservaron.
- **Evidencia:** `C:\Users\draco\Downloads\rumbaap-9d50e1d+A-2026-10-20\` (`entrega.txt`, `qa-nativa\`). El reloj, las reglas y los datos anteriores no se tocaron.
- **ANDROID VALIDATED** (actor leído del estado guardado tras un cierre forzado y la reapertura):
  - revocar R22 → `admin-1`;
  - confirmar el prepago de R23 → `admin-1`, con `createdBy=cliente-a` intacto;
  - rechazar R31 → `admin-1`.
  - En el alta no hay actor, que es lo previsto: pendiente del siguiente bloque.
  - Navegación por los 8 roles: cada cargo ve solo sus secciones.
  - La llegada aparece desactivada con su aviso de horario.
- **Bloqueado por horario:** la llegada y su actor, liberar (requiere la mesa ocupada) y los recorridos positivos de Barra, VIP, cortesías y champaña.
- **Observado en nativo, sin cambios:** el prepago en dos pasos (hallazgo 2). Tras «Confirmar prepago verificado», la champaña aparece habilitada y las cortesías siguen a la espera de registrar el importe.
- **No observable en la interfaz:** el actor (no se muestra) y el rechazo por cargo en la lógica (los cargos sin permiso no ven la acción). Este último está acreditado con los tests.

## Altas de reserva con actor y cargo (2026-10-20, sin commit)

- **Cambio:** iniciar, enviar y cancelar el trámite normal, la solicitud VIP y la reserva directa comprueban el permiso del flujo en la lógica y guardan su actor. La siembra va aparte (`seedDemoNight`). La matriz está en [altas](../architecture/admin-reservations-demo.md#actor-y-cargo-de-las-acciones-de-reserva-2026-10-20).
- **Verificado por ejecución:** `dart format` sin cambios, `flutter analyze` sin problemas y `git diff --check` limpio. Tests afectados en serie: **438/438**. Suite completa en serie, una vez: **541/541**, que los incluye.
- **Tests nuevos o ampliados:**
  - por alta: permitidos y denegados, identidad desconocida y configuración ausente;
  - un alta denegada no crea nada, no ocupa la mesa ni consume número;
  - solo quien empezó el trámite lo envía o lo cancela;
  - la siembra no tiene actor ni creador, solo actúa en una noche vacía y no terminada, y nadie envía su trámite;
  - persistencia del actor del alta, y carga de datos antiguos sin él;
  - pantallas: reserva directa (`admin-1`), trámite del promotor (`promotor-1`) y cancelación del trámite.
- **ANDROID VALIDATED** (APK `rumbaap-9d50e1d+altas-debug.apk`, SHA-256 `cd196e23f9944f82885eb7e9a906c8d8bba9ffd7e1821081ee801f0dd2c2d7d0`; el instalado coincide):
  - reserva directa R32 → `admin-1`;
  - trámite del promotor R33 → `promotor-1` en el inicio y en el envío;
  - trámite cancelado R34 → `cliente-b`;
  - solicitud VIP R42 → `cliente-b`;
  - el mesero no tiene altas;
  - los actores se conservan tras un cierre forzado y la reapertura.
  - Evidencia en `Downloads\rumbaap-9d50e1d+altas-2026-10-20\` (`entrega.txt`, `qa-nativa\`).
- **No observable en la interfaz:** los rechazos por permiso (ningún perfil sin permiso ve la acción). Están acreditados con los tests.

## Regresión de reservas (2026-10-20, después del corte REV-20261020-0402)

- **Contraste con la cobertura existente** (sin duplicar):
  - intentos denegados de altas y transiciones (sin crear, sin ocupar mesa, sin consumir número, sin cambiar estado ni historial): ya cubiertos en `reservation_book_test`, grupos «actor y cargo» y «altas»;
  - envío y cancelación por quien inició el trámite: ya cubiertos, también por pantalla;
  - transiciones repetidas o inválidas: ya cubiertas («operaciones repetidas no duplican efectos», «cancelar solo afecta a un trámite En proceso»);
  - siembra que conserva otras noches: ya cubierta (`demo_reservation_store_test`, A1).
- **Hueco cubierto, un test:** `demo_persistence_test` («un trámite en curso se recupera con su creador…»).
  - **Riesgo:** tras guardar y cargar, incluidos datos anteriores sin actores, el permiso para enviar depende del creador recuperado.
  - **Comprueba:** que solo lo envía quien lo empezó, que el actor del envío se registra y que consultar la noche recuperada no siembra encima.
  - **Reglas:** R14 y R15 y la matriz de altas.
- **Resultados:** el archivo afectado pasó en serie (15/15). Suite completa en serie, una vez: **542/542**. No se compiló APK ni se usó el emulador.
- **Defectos de producción reproducidos:** ninguno.
- **Hallazgos pendientes, por prioridad (por inspección, sin test que los fije):**
  1. `BarBook.registerPrepaid` no comprueba cargo, reserva, estado, mesa/noche ni noche terminada. La vista no revalida tras confirmar (`_registerPrepaid`).
  2. La ventana de noches por perfil (N5) la limita la navegación y no la lógica.
  3. `seedDemoNight` es público, aunque acotado a noches vacías.
  - Detalle en `Downloads\rumbaap-revision-codex-2026-10-20\04-puntos-de-revision.md`.

## Diferencias entre el resumen de continuidad adjunto y el estado local

- **Adjunto releído el 2026-10-20:** `Rumbaap_Continuidad 1.md`, editado el 19-oct, corte RC-20261019-2337, que empieza por «Estado vigente para retomar». Las diferencias de esta sección se refieren al adjunto anterior, `Rumbaap_Continuidad.md`, que empezaba por «Leer primero» («Actualizado al retomar el 14 de octubre»). La versión nueva ya recoge 9d50e1d, 527/103 y el APK vigente.
- **Sección inexistente.** El adjunto no tiene la sección «Estado vigente para retomar»; se usó «Leer primero».
- **HEAD.** El adjunto da como HEAD `491028c`, y la última entrega de código es `1279f61`. El HEAD local es `9d50e1d`: el incremento visual (ADR 0005), que cambió `lib/` y `test/`.
- **Tests.** El adjunto cita 506 tests. El checkpoint registra 527/527 antes del último ajuste y después solo 103/103 de los archivos afectados.
- **APK.** El adjunto presenta los APK de `1279f61` como la entrega actual. Según el checkpoint son históricos; el vigente es `rumbaap-9d50e1d` (SHA-256 `5216a284…`, 177 291 443 B).
- **QA Android.** El adjunto la da como «todavía sin ejecutar». El checkpoint del 14-oct registra QA de navegación, Barra (foco y modo), promotor C1 y persistencia.
- **Emulador.** El APK de `9d50e1d` se reinstaló con `-r` (conserva los datos) en el `Pixel_7` el 2026-10-16. El emulador se abrió por petición expresa el 16 y el 19 de octubre, solo para revisión manual, sin QA registrada.

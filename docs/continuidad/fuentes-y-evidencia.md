# Fuentes y evidencia (detalle de continuidad)

Detalle que NO se carga al retomar. La entrada es [`../continuacion-claude.md`](../continuacion-claude.md); este archivo se consulta por tema. No copia las reglas: las referencia. Si algo difiere, mandan las fuentes canónicas indicadas y las aclaraciones del hilo de trabajo actual sobre champaña, saldo VIP, comprador, entrega de manillas, cumpleaños y Barra. Las manillas físicas transferibles y no nominativas (A8) y el ejemplo de los 300 mil (A7) vienen del contexto maestro de ChatGPT v42 (actualizado el 2026-10-11 19:09, Colombia): son aclaraciones previas, fuente indirecta cuyo mensaje original no se localizó, con verificación documental del 2026-10-12.

## 1. Artefactos y commits

| Qué | Dato |
|---|---|
| Última entrega de CÓDIGO | `1279f61ebe8a35fcb9e8fcba05505e55a6c0c777`, árbol `42215944b125afbc3171fb348fc0d122e4bbdf88`, rama `feat/frontend-operations-demo` (solo local, sin push). |
| Commit de documentación | El que sigue a `1279f61` y solo toca `docs/`. Su hash cambia: se obtiene con `git log --oneline -3`. `lib/`, `test/`, `pubspec.*`, `android/` e `ios/` son idénticos a `1279f61` (se compara con `git rev-parse HEAD:<ruta> 1279f61:<ruta>`). |
| Carpeta de entrega | `C:\Users\draco\Downloads\rumbaap-1279f61\` (`entrega.txt`, debug y release). |
| `rumbaap-1279f61-debug.apk` | 177 289 347 bytes, SHA-256 `0c2d5228689b3eac73d3dd2bcd3ff52553a96664884ea1b30e7ff5bc83819049`. |
| `rumbaap-1279f61-release.apk` | 67 290 550 bytes, SHA-256 `b683a3f9b4bae13a5fb59dc76897b269bb953a940254fa52cddcf4b9c1a66856`. |
| Firma y paquete | `com.rumbaap.app` 1.0.0, firmadas con la clave de debug: sirven para la demostración, no para distribuir. Sin `RUMBAAP_DEMO_NOW`. El debug se compiló antes del commit y desde entonces no cambió código; la release corresponde al árbol `42215944b125`. |
| Entrega anterior | `C:\Users\draco\Downloads\rumbaap-0b2324b\` (debug y profile del commit `0b2324b`) y su QA nativa. No se toca. |
| **Incremento visual actual** | Commit local posterior a `491028c` (su hash se comprueba con `git log --oneline -3`; no se escribe aquí). Fuente de la compilación: `491028c` más el diff de 13 archivos, antes de confirmarlo. Parche archivado: `C:\Users\draco\Downloads\rumbaap-diseno-2026-10-14-d\fuente-diff-sin-commit.patch` (SHA-256 `bac505f50c41acb810efe0866b62966565d8d1d091b3b4b394d74e0bf2f12c3e`; incluye los docs tal como estaban al compilar, no los definitivos). |
| APK del incremento | `rumbaap-diseno-491028c+diff-d-debug.apk`: 177 291 443 B, SHA-256 `5216a2841a90320eab47b37c7205dad44c847fdf3fe9d71e36f5fe3f08421667`; `com.rumbaap.app` 1.0.0, minSdk 24, firma de debug. Compilado con límites temporales de Gradle verificados en la JVM propia (`-Xmx1024m`, metaspace 384m, code cache 128m). Candidatos previos conservados: `rumbaap-diseno-2026-10-14` (`712a1063…`), `-b` (`05201a03…`) y `-c` (`aef90a49…`). Entrega externa: `C:\Users\draco\Downloads\rumbaap-<hash-corto-del-commit>\` (`entrega.txt`). |
| Otros APK y carpetas | Entregas anteriores en `C:\Users\draco\Downloads\` (`rumbaap-<hash>-debug/profile.apk`, `Rumbaap-P25-…`, `Rumbaap-P26-…`). Solo historia. |

## 2. Evidencia aprobada y pendiente

| Evidencia | Estado | Dónde |
|---|---|---|
| `dart format`, `git diff --check`, `flutter analyze` y suite completa 506/506 | Ejecutado (exit 0) antes del commit `1279f61`. Los 31 de `map_interactions_test` (barra inferior) ya están incluidos en los 506; no se suman. Los 142 «acotados» fueron de un bloque previo. | Registro en `entrega.txt` y en el commit. |
| 18 capturas de render de widgets | SOLO render de widget con datos ficticios y reloj inyectado en el montaje del test. No son QA Android. Límites: las etiquetas pintadas con `TextPainter` del mapa (IDs de mesas y VIP) salen como rectángulos Ahem, así que no son fieles al mapa; la barra inferior se desplaza en horizontal de forma intencional cuando no caben las secciones (con Roboto, 5 secciones miden 267 dp frente a 337 disponibles a 393 dp). | `C:\Users\draco\Downloads\rumbaap-qa-widgets-2026-10-12\` |
| QA nativa del bloque `0b2324b` (Android, Pixel_7, 2026-10-12) | Ejecutada y anterior: cumpleaños, persistencia tras `force-stop`, champaña solo con bloqueo fuera de horario. 16 PNG, `logcat.txt`, `emu_out.log`, `emu_err.log`. | `C:\Users\draco\Downloads\rumbaap-0b2324b\qa-nativa-2026-10-12\` |
| QA nativa de navegación de `1279f61` | Ejecutada (solo navegación, no QA funcional): Inicio, mapa cliente, Más, Promotor, Barra y Admin con el APK debug de `1279f61`. | `C:\Users\draco\Downloads\rumbaap-qa-diseno-2026-10-14\02-base-1279f61-*.png` |
| Checks del incremento actual | `dart format`, `flutter analyze` y `git diff --check` sin incidencias. Suite completa **527/527** (una vez) **antes** del último ajuste pequeño (búsqueda de Personal); después, solo `shared_design_test` y `guest_reservation_test`: **103/103**. No son sumables ni hay suite completa posterior. | Esta sección y `continuacion-claude.md` |
| QA nativa del incremento actual (Android, `Pixel_7`) | Ejecutada con el APK final y los intermedios: mapa, mesa abrir/cerrar, Más, Promotor (obligatorios, venta C1, pago, entrega única, persistencia tras `force-stop`), Admin, Barra («Escribir la credencial», cerrar el lector, cliente con/sin cuenta), Personal, 411 dp y 320 dp / texto 2.0, defectos de barra y de búsqueda reprobados. Densidad y `font_scale` restaurados. Datos ficticios; C1 conservada. | `03-nuevo-*`, `04-320-*`, `05-*`, `06-*`, `07-*`, `08-qty-*`, `09-320-fix-*`, `10-320-*`, `11-320-fix-*` y capturas finales, en `C:\Users\draco\Downloads\rumbaap-qa-diseno-2026-10-14\`; registros en `rumbaap-diseno-2026-10-14` y sus sufijos `-b`, `-c`, `-d` |
| Pendientes en dispositivo | Flujo positivo de VIP, cortesías, llegada, consumo y champaña en una noche en curso real; iOS nativo (macOS/Xcode); Android API 24; cámara física (el lector solo se vio con la escena virtual del emulador). | `continuacion-claude.md` |

## 2b. Fuentes primarias del incremento visual (ADR 0005)

- Apple, Meet Liquid Glass (WWDC25): https://developer.apple.com/videos/play/wwdc2025/219/
- Linear, A calmer interface for a product in motion (2026-03-12): https://linear.app/now/behind-the-latest-design-refresh
- Google Design, investigación M3 Expressive: https://design.google/library/expressive-material-design-google-research
- Flutter, accesibilidad y estilo de la interfaz: https://docs.flutter.dev/ui/accessibility/ui-design-and-styling
- Flutter, tipografía: https://docs.flutter.dev/ui/design/text/typography
- Gradle, entorno de compilación (opciones temporales del build): https://docs.gradle.org/current/userguide/build_environment.html

Son principios, no copia ni «Liquid Glass» nativo en Flutter.

## 3. Fuentes externas (fuera del repo, en `C:\Users\draco\Downloads\`)

Se conservan los originales y no se copian aquí. Vigencia: según su fecha de modificación, entre el 2026-10-09 y el 2026-10-12.

| Archivo | Qué es / uso |
|---|---|
| `Plan de entrevista 1 de elicitación – Rumbaap × Sagsa (Borrador editable).docx` y `Plan de entrevista de elicitación – Rumbaap × Sagsa (Borrador editable) (1).docx` | Primera entrevista a Sagsa, diligenciada (73 respuestas escritas bajo las preguntas; el nombre es el de la plantilla). Los dos textos son idénticos. |
| `Plan de entrevista de elicitación – Rumbaap × Sagsa (Borrador editable).docx` | Versión anterior del plan (79 apartados de respuesta, vacíos en las muestras revisadas). No se usa como fuente. |
| `Plan de segunda entrevista de elicitación – Rumbaap × Sagsa (Borrador editable).docx` | Segunda entrevista, diligenciada (74 respuestas). |
| `RUMBAAP_Documento_Maestro_Elicitacion_Requisitos_v1.0.docx` | Documento maestro de elicitación v1.0. No se contrastó en esta revisión. |
| `Plan_cierre_elicitacion_Rumbaap_Sagsa*.docx`, `Historias_y_planeacion_Rumbaap.docx`, `Planeacion_costos_Rumbaap.xlsx`, `Rumbaap Detalles iniciales.pdf`, `Rumbaap_contexto_*.txt`, `Rumbaap_plan_prototipo_navegacion_y_perfiles*.txt` | Material de apoyo. No leído en esta revisión; no se usa como fuente de reglas sin contrastarlo. |

Citas verificadas el 2026-10-12 (solo respuestas necesarias, sin datos personales):
- E1 P6: los cumpleaños se registran en papel. E1 P7: las promociones actuales son solo de cumpleaños.
- E1 P10: hora límite de las 11 p. m. para ocupar la mesa; requisito de consumo de 400 mil; si no llegan a tiempo la mesa se cede. VIP: 2M obligatorio, 6 cortesías (entradas) y una botella con pago anticipado.
- E2 P8: si el mínimo no se alcanza «no importa, es flexible»; «un mínimo aceptable serían 300 mil» fue un ejemplo del entrevistado. No es otro umbral (aclaración previa A7 del contexto maestro, fuente indirecta).
- E2 P9: 2M pagados por adelantado, consumibles se logre o no el consumo; 40 personas máximo en VIP, dos mesas de 20, se pueden tomar ambas o no.
- E2 P13: decoración de cumpleaños en la preparación previa a la apertura.
- E1 P43: la manilla, entregada por el promotor o comprada, permite volver a ingresar. La P44 no tiene respuesta registrada.
- Ubicación de las preguntas: P6, P7 y P10 se numeran dentro de la primera entrevista; P8, P9 y P13 dentro de la segunda.

`docs/elicitation/` sigue vacía: las entrevistas no están copiadas al repo. No se transcribe nada que no esté en el original.

## 4. Fuente → estado

| Tema | Fuente canónica | Estado |
|---|---|---|
| Horario de Sagsa (8:30 p. m.–3:00 a. m.), viernes a domingo y UTC−5 | [reservas-y-noches](../business-rules/reservas-y-noches.md) N1–N3 | VALIDATED con su fuente; es el horario registrado y la configuración actual del calendario, no una imposición nueva. |
| Reserva normal gratis, consumo mínimo de 400.000 COP; 10 min solo en «En proceso»; 11 p. m. sin desalojar | reservas-y-noches (R1 y condiciones de mesa); E1 P10, E2 P8 | VALIDATED; capacidad normal NOT DECIDED. |
| VIP: 2.000.000 COP, hasta 20 por mesa, juntas 40 y 4M | reservas-y-noches; [mapa](../architecture/reservations-venue-map.md); E2 P9 | VALIDATED (E2 P9: 40 personas y dos mesas de 20); la unión transaccional indivisible es un criterio técnico futuro, no implementada. |
| Prepago VIP: solo el excedente; el saldo no usado se pierde al terminar la noche; en cancelación o no llegada, frontera manual confirmada (otra noche por acuerdo directo con la administración, sin devolver, vencer ni trasladar automáticamente) | [pedidos-barra](../business-rules/pedidos-barra.md) | VALIDATED (aprobado por el usuario en el hilo de trabajo; sin fecha individual que conste). |
| 1 champaña y 6 cortesías por mesa VIP, fuera del consumo; derechos tras verificar el prepago y aprobar | [beneficios-vip](../business-rules/beneficios-vip.md) | VALIDATED; la champaña sale solo con la mesa ocupada y petición: Barra registra la salida y el mesero la entrega. |
| Restricción de noche en curso: Caja al canjear cortesías por manillas; Barra solo en ventas y salida de champaña (Barra no canjea manillas) | beneficios-vip (aclaración sobre horarios) | DECISIÓN DE PROTOTIPO: implementación, no condición ratificada. |
| Cumpleaños | [cumpleanos](../business-rules/cumpleanos.md) | VALIDATED (E1 P6, P7; E2 P13); resto, DECISIÓN DE PROTOTIPO; importe y ventana NOT DECIDED. |
| Promotor: nombre, teléfono y cédula; entrega de la manilla de su lote en cualquier momento, sin QR | [entradas](../business-rules/entradas.md) | VALIDATED (pedido de Juanmi); alcance exacto de la excepción, DECISIÓN DE PROTOTIPO. |
| Barra: «Credencial», foco al escribir a mano, cliente sin cuenta, «Sin mesa» | pedidos-barra | VALIDATED (pedido); campos y textos, DECISIÓN DE PROTOTIPO. |
| Sistema visual y mapa | [ADR 0004](../decisions/0004-mapa-unico-noche-de-cristal.md), [ADR 0005](../decisions/0005-sistema-visual-compartido.md), [mapa-noche-de-cristal](../architecture/mapa-noche-de-cristal.md) | Decisión del equipo; el mapa no se tocó. |

## 5. Decisiones abiertas y dónde consultarlas

| Tema | Dónde |
|---|---|
| Backend, base de datos, hosting, autenticación, pagos, analytics, CI/CD, macOS, flavors | `CLAUDE.md` §4 |
| Proveedor de pagos y cobro real; datos personales | reservas-y-noches (sección «Todavía no implementado») |
| Marca y precio de la champaña; efecto de revocar, rechazar, liberar o expirar sobre los beneficios; reposición, caducidad, transferencias y devolución del beneficio | beneficios-vip |
| Corrección de ventas contra el prepago; carta y precios reales; medio y verificación del pago presencial | pedidos-barra |
| Precios y eventos reales; reembolso VIP, grupos y transferencia digital; fórmula de puntos y vinculación de cuentas; cantidad de cortesías fuera del beneficio VIP | entradas |
| Importe, paquete, descuento, entradas gratis y ventana de fechas del cumpleaños; otros cargos que marquen la decoración | cumpleanos |
| Capacidad de la mesa normal; pasos, condiciones y circuito financiero de la cancelación/no-show de la VIP (solo está confirmada la frontera manual); destino de los beneficios no usados al finalizar | reservas-y-noches y beneficios-vip (sin decisión) |
| Fuera de alcance, no se abren por defecto: inventario, comisiones, subpromotores, monedero y traslado de consumos. Sin definir (`NOT DECIDED`): fórmula de puntos y vinculación futura con cuentas | entradas |

## 6. Código y pruebas por tema (31 archivos de test; 506 pruebas en `1279f61` y 527 en la última suite completa del incremento actual)

| Tema | Código | Pruebas |
|---|---|---|
| Reservas y noches | `lib/features/reservations/` | `test/features/reservations/` (reservation_book, night_schedule, store, guest, admin) |
| Mapa | `lib/features/reservations/presentation/map/` | `map_interactions_test`, `venue_map_*`, `shared_map_integration_test` |
| Cumpleaños | `reservation.dart`, `birthday_widgets.dart` | `birthday_test`, `birthday_flow_test` |
| Entradas y Promotor | `lib/features/tickets/` | `ticket_book_test`, `promoter_lot_test`, `tickets_flow_test`, `qr_and_camera_test`, `personal_qr_test` |
| Barra y champaña | `lib/features/bar/` | `bar_book_test`, `bar_customer_test`, `bar_flow_test`, `vip_prepaid_test`, `vip_champagne*_test` |
| Beneficios VIP | `lib/features/benefits/` | `vip_benefits_test`, `vip_redeem_gate_test` |
| Panel y metas | `lib/features/dashboard/` | `dashboard_test`, `night_goals_test` |
| Persistencia | `lib/app/persistence/demo_snapshot.dart` | `app/demo_persistence_test.dart` (snapshots antiguos cargan sin cambios) |
| Diseño compartido | `lib/theme/`, `lib/app/app_theme.dart` | `app/shared_design_test.dart`, `theme/venue_theme_test.dart` |

## 7. Límites y rechazos (sin recetas)

- El arranque del emulador `Pixel_7` fue denegado por el clasificador del modo automático («Interfere With Workloads»). El usuario abre el emulador a mano. No hay vía alternativa ni cambio de permisos.
- El intento de guardar Sonnet como modelo por defecto fue rechazado. No se reintenta; el modelo es Sonnet 5.5 en la sesión.
- Antes de abrir el emulador se mide la RAM; no se promete RAM libre estable ni se borran datos de la app.
- Ramas locales: todas absorbidas por `HEAD` según `git merge-base --is-ancestor` (`build/flutter-app-base`, `feat/admin-map-integration`, `feat/admin-reservations-demo`, `feat/frontend-profiles-reservations-demo`, `feat/noche-de-cristal-admin-map`, `feat/reservations-demo-rules`, `feat/venue-map-availability`, `feat/weekend-nights`, `main`). No se borró ninguna. Existe un worktree temporal desprendido en `10a536e` bajo el directorio temporal del usuario; no se tocó.

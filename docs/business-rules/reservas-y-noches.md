# Reglas de negocio — noches y reservas de mesa

**Fuente:**
- decisiones del equipo (Juanmi) del 2026-10-10, registradas en el [ADR 0002](../decisions/0002-perspectiva-administrador-y-reservas.md), y sus aclaraciones de la tarde del mismo día sobre el promotor (N7, R12, R13);
- condiciones de mesa de la tarea del mapa (`architecture/reservations-venue-map.md`).

Estados: `VALIDATED` (decidido por el equipo), `NOT DECIDED` (pendiente).

## 1. Decisiones del equipo

### Horario y noches

| # | Regla | Estado |
|---|---|---|
| N1 | El establecimiento abre a las **8:30 p. m.** y cierra a las **3:00 a. m.** del día siguiente. | VALIDATED |
| N2 | La hora de referencia es la del establecimiento: Colombia, UTC−5. | VALIDATED |
| N3 | Se opera en las noches del fin de semana: **viernes, sábado y domingo**. | VALIDATED |
| N4 | Las noches se calculan a partir del fin de semana actual, y debe haber forma de seleccionar noches futuras. Más adelante, el promotor podrá añadir eventos. | VALIDATED |
| N5 | **Cliente:** solo ve y reserva las noches del fin de semana de su **semana calendario** en curso (de lunes a domingo). Las noches del fin de semana siguiente se abren el lunes de esa semana (por ejemplo, del 5 al 11 de octubre de 2026 se reservan el 9, 10 y 11; el 16, 17 y 18 se abren el lunes 12). | VALIDATED, pendiente de implementar (vista de cliente) |
| N6 | Una mesa solo puede estar **Ocupada** durante la noche en curso (entre la apertura y el cierre). | VALIDATED |
| N7 | **Promotor:** ve también noches futuras, con el mismo selector de noches que el administrador (M1–M3) y sin un límite temporal nuevo. Eso no le da acciones ni datos del administrador (prepago, llegada, revocar, liberar, reservas ajenas). El cliente mantiene N5. Crear eventos y gestionar promotores siguen fuera de alcance. | VALIDATED (2026-10-10) |

### Reservas

| # | Regla | Estado |
|---|---|---|
| R1 | **Mesa normal**, reserva del cliente: mientras se completa, queda **En proceso** y bloquea la mesa hasta **10 min** (valor editable en el futuro). Al completar el trámite, se **confirma automáticamente** y el cliente queda como titular. Si no se completa, **expira a los 10 min**. Que pasen los 10 min no confirma nada, y una reserva ya confirmada no vence por este temporizador. | VALIDATED |
| R2 | **Mesa VIP solicitada:** la reserva queda **pendiente de pago, sin caducidad**: los 10 min de R1 no aplican a las VIP. Sigue así hasta que el administrador verifique el prepago y la apruebe, o la rechace. Por ahora el pago se marca a mano; se dejará en la app una ruta de pago para el futuro. | VALIDATED (`NOT DECIDED: proveedor de pagos`) |
| R3 | Una solicitud en proceso o pendiente **bloquea la mesa** para otras solicitudes. Solo puede haber una reserva activa por mesa y noche. | VALIDATED |
| R4 | El administrador es la cabeza del negocio y puede **revocar** una reserva ya confirmada automáticamente, con una advertencia previa. | VALIDATED |
| R5 | La **llegada** (de Reservada a Ocupada) se registra cuando el titular, o alguien en su nombre, reclama la mesa. Además del administrador, la usarán otras perspectivas de personal (por ejemplo, el mesero). | VALIDATED |
| R6 | El administrador puede **liberar** una mesa reservada u ocupada, siempre con advertencia y doble confirmación para evitar errores. | VALIDATED |
| R7 | **Reserva directa del administrador:** registra nombre del titular, cédula y teléfono, los tres obligatorios. La cédula y el teléfono solo admiten dígitos, sin validar longitud ni formato. Si la mesa es **VIP**, queda **confirmada directamente**: se asume que el administrador ya validó el pago. | VALIDATED |
| R8 | La cédula es el ID de la cuenta registrada, si existe; si no, es solo un identificador. El teléfono sirve para que el administrador contacte al titular por su cuenta; la app no incluye comunicación. | VALIDATED |
| R9 | **Cliente:** reserva a su nombre o a nombre de otra persona, lo que define el titular. Sus datos salen de su perfil, porque ya inició sesión. | VALIDATED |
| R10 | **Promotor:** registra al titular «por cuenta» (cédula) o «por nombre». Las reservas «por nombre» no se pueden ligar a una cuenta y no generan puntos. | VALIDATED |
| R11 | En esta fase, se entra a la perspectiva de administrador con un selector de demostración, sin seguridad real. | VALIDATED |
| R12 | **Titular en la reserva del promotor:** nombre y teléfono obligatorios; la cédula es **opcional** y puede quedar vacía. Teléfono y cédula, si se escribe, solo admiten dígitos, sin longitud ni formato (como R7). La cédula sirve para buscar con precisión una cuenta registrada y vincular la reserva a ella cuando exista. Nunca se adjudica una reserva a una cuenta por nombre o teléfono, y escribir una cédula no demuestra que haya cuenta. Sin cuenta vinculada, la reserva se conserva por nombre y teléfono, sin puntos. La reserva directa del administrador (R7) no cambia. | VALIDATED (2026-10-10). Búsqueda y vinculación a cuentas: futuro, sin directorio ni autenticación en esta fase. |
| R13 | **Completar el trámite** (promotor): elegir noche y mesa, registrar al titular (R12), revisar un resumen y enviar con el botón final. La app valida los datos y que la mesa siga reservable esa noche (R3). Mesa **normal**: el envío válido la confirma, sin aprobación del administrador; los 10 min solo aplican mientras está En proceso (R1). Mesa **VIP**: el envío la deja Pendiente de pago/verificación, sin caducidad, hasta que el administrador verifica el prepago (R2); la VIP directa del administrador sigue confirmándose al crearla (R7). Completar no es llegar, pagar consumo, validar la cuota ni ganar puntos. Seleccionar una mesa en la consulta no confirma ni inicia por sí solo una reserva. | VALIDATED (2026-10-10) |

#### Decisiones de implementación del prototipo del promotor

Las tomó Juanmi el 2026-10-10 para la demostración. No son una política atribuida a Sagsa ni el resultado de una entrevista.

| # | Decisión | Estado |
|---|---|---|
| R14 | **Inicio del trámite normal del promotor:** el bloqueo de 10 min empieza al pulsar «Reservar esta mesa», tras elegir noche y mesa y comprobar que sigue disponible. Consultar el mapa, seleccionar una mesa o abrir su detalle no la bloquea. El trámite provisional se identifica por noche, mesa, origen y su propio ID, sin datos de relleno; el titular (R12) se exige al enviar. La comprobación y la creación del bloqueo ocurren en la operación del almacén compartido, no solo en la pantalla, y se mantiene una sola reserva o trámite activo por mesa y noche (R3). El plazo cuenta desde el inicio original: volver del resumen, editar los datos o pasar a segundo plano no lo reinicia, y al volver a primer plano se comprueba con el reloj del modelo. El envío final solo confirma si el trámite sigue activo, en la misma mesa y sin vencer. Al vencer, la mesa queda libre y el trámite ya no se puede confirmar: para reintentar hay que iniciar uno nuevo. | VALIDATED (prototipo) |
| R15 | **Abandono del trámite normal:** salir expresamente del recorrido cancela el trámite y libera la mesa, tras una confirmación breve que lo explica. Si el promotor decide seguir, conserva el plazo. Volver del resumen al formulario no es abandonar, y pasar la app a segundo plano tampoco: el plazo sigue contando. Cancelar solo afecta a un trámite normal todavía activo, nunca a una reserva confirmada ni a una VIP ya enviada. Es distinto de revocar (R4) y de liberar (R6), y el promotor no adquiere esas acciones. | VALIDATED (prototipo) |
| R16 | **VIP del promotor:** la solicitud se crea solo al enviar el formulario final válido. Mientras se rellena no hay solicitud ni bloqueo, y abandonar no deja nada pendiente. Al enviar, el almacén vuelve a comprobar la disponibilidad: si otra reserva o solicitud activa ocupa la VIP, informa de que dejó de estar disponible, sin sobrescribir ni asignar otra mesa. El envío válido la deja Pendiente de pago/verificación, bloqueada y sin caducidad (R2); salir después no la cancela. La VIP directa del administrador sigue confirmándose al crearla (R7). | VALIDATED (prototipo) |

Condiciones de mesa ya vigentes:
- **Normal:** reserva sin costo ni prepago; consumo de referencia de 400.000 COP con tolerancia validada por el personal; capacidad `NOT DECIDED`.
- **VIP:** hasta 20 personas y 2.000.000 COP prepagados por mesa.

### Mapa de consulta de esta fase

| # | Regla | Estado |
|---|---|---|
| M1 | La semana *operativa* del mapa cambia el **lunes a las 03:00** (cierre de la noche del domingo), no a medianoche, para que el domingo siga visible hasta su cierre. | VALIDATED para el mapa de consulta. **No modifica** la semana calendario del futuro catálogo del cliente (N5). |
| M2 | El mapa **no ofrece las noches ya terminadas**. | VALIDATED para el mapa de consulta. No impide un historial del administrador. |
| M3 | El mapa **no navega a semanas pasadas**; solo a la semana en curso y a las futuras. | VALIDATED para el mapa de consulta. No impide un historial del administrador. |
| M4 | Se restaura la **animación** del prototipo. Se detiene si el sistema pide reducir el movimiento y se pausa cuando el mapa no está visible o la app está en segundo plano. | VALIDATED |

Propuso M1–M3 Claude y los aprobó el equipo para esta fase. El desplazamiento relativo de semanas del mapa (`weeksAhead`) es solo de consulta: las reservas (Parte 2) quedan ligadas a una noche concreta y nunca cambian de fecha porque avance la semana o cambie el selector.

## 2. Decisiones de implementación (Claude)

No son reglas de negocio. Son formas técnicas de cumplir las reglas anteriores y se pueden cambiar sin cambiar el comportamiento acordado.

| # | Decisión | Motivo |
|---|---|---|
| I1 | Con la pantalla abierta, la consulta se **actualiza sola** al cruzar una apertura o un cierre (temporizador del controlador), y al volver la app del segundo plano. | Que el paso del tiempo no deje visible una noche terminada ni su ocupación (N6, M2). |
| I2 | En el mapa, la reserva pendiente se muestra como **«En proceso»** en mesas normales y **«Pendiente de pago»** en VIP. Ambas en ámbar, con icono y texto propios, también para el lector de pantalla. | Hacer visibles R1 y R2. No implementa la caducidad ni el pago. |
| I3 | La pausa de la animación (M4) usa los mecanismos del SDK: `TickerMode` de las rutas, ciclo de vida de la app y `MediaQuery.disableAnimations`. | Cumplir M4 sin código adicional. |
| I4 | La hora del local se representa como `DateTime` UTC con los campos de la hora de Colombia, y los datos de demostración son deterministas por fecha. | No depender de la zona horaria del dispositivo; resultados reproducibles. |
| I5 | El **rechazo** de una VIP pendiente de pago deja la reserva en estado *revocada*, con un evento «rechazada» en el historial que la distingue de una revocación. | Respetar los 7 estados acordados sin añadir uno nuevo. |
| I6 | La expiración a los 10 min (R1) se aplica al consultar o al operar, y se registra con el **instante exacto** de vencimiento, no con el de la consulta. | Exactitud sin temporizadores en el dominio. |
| I7 | No se crean reservas en una noche ya terminada. | Coherente con N6 y M2. |
| I8 | Las operaciones no válidas o repetidas fallan sin modificar la reserva ni duplicar eventos en el historial. | Trazabilidad e idempotencia. |
| I9 | El almacén de demostración siembra reservas ficticias la primera vez que se consulta una noche, con las mismas reglas que una reserva real. No siembra una noche que ya tiene historial. | Datos de demostración coherentes con las reglas, sin sustituir ni chocar con operaciones reales. |
| I10 | El mapa vuelve a consultar cuando vence una reserva en proceso (`refreshAt`), que se calcula antes que los estados de las mesas. | Que una mesa expirada no quede en ámbar, aunque venza durante la consulta. |
| I11 | El almacén avisa tras cada operación de una vista. Las vistas abiertas vuelven a consultar la misma noche y mantienen los datos anteriores mientras llega la respuesta. Durante ese intervalo, las acciones sobre mesas quedan desactivadas. | Que consulta pública, mapa, listas y detalle reflejen el cambio sin reiniciar la app y sin mostrar la noche como desconocida. |
| I12 | En la vista del administrador, mapa, pendientes, reservas y panel de mesa salen de una misma consulta (estados más reservas de la noche). La consulta pública no recibe datos personales. | Coherencia entre vistas y privacidad (C6). |
| I13 | Cada acción conserva el ID de la reserva (y el formulario, la mesa y la noche). Fija el estado exacto de la reserva al iniciar el recorrido y, tras cada confirmación, comprueba que siga en ese mismo estado. No basta con que la operación lo admita: liberar una Reservada que pasó a Ocupada se detiene y hay que empezar de nuevo con la advertencia de Ocupada. Además, el libro revalida la operación. Si algo cambió, no se aplica nada y se explica. | Evitar acciones sobre otra fecha o sobre una reserva ya modificada. |
| I14 | Confirmar el prepago, rechazar y registrar la llegada piden una confirmación. Revocar lleva la advertencia de R4 y liberar, la doble confirmación de R6. | Evitar errores por un toque accidental en acciones sin «deshacer». |
| I15 | El administrador usa el mismo selector de noches que el mapa (M1–M3). Una reserva se puede abrir por su ID desde las listas y la actividad, también si ya terminó. | No se añadió un navegador de noches pasadas (fuera del encargo). |
| I16 | Las horas se muestran en hora de Colombia; los instantes guardados siguen siendo UTC reales. | N2. |
| I17 | El formulario directo valida a la vista los campos vacíos y los caracteres que no son dígitos (sin filtrarlos en silencio) e ignora los espacios al inicio y al final. | R7 sin inventar longitud ni formato. |
| I18 | La siembra de demostración incluye siempre una VIP pendiente de pago por noche sembrada (si el local tiene mesas VIP). | Poder demostrar la verificación manual del prepago (R2) en cualquier noche. Son datos ficticios; no cambia ninguna regla. |
| I19 | El libro de reservas, el almacén y el mapa están acotados a un local: las mesas de otro local se rechazan y una consulta de otro local se trata como error. | Preparar varios locales sin mezclar datos (ADR 0004). R1–R8 y el horario siguen siendo los confirmados para Sagsa. |
| I20 | Un trámite normal del cliente o del promotor puede no tener titular mientras está En proceso, y seguir sin él si termina Cancelado o Expirado sin enviarse (R14). Enviar, cancelar y expirar son operaciones únicas del libro: si fallan no dejan cambios parciales. | Exigir el titular solo al enviar, sin datos de relleno. |
| I21 | Estado nuevo **Cancelada** para el abandono expreso del trámite normal (R15); no es activo y libera la mesa. | Distinguirlo de revocada, liberada y expirada en el historial. |
| I22 | Cliente que reserva **para otra persona** (R9): nombre y teléfono obligatorios y cédula opcional, con las mismas validaciones que R12, sin vincular cuenta. A su nombre, el titular sale de su perfil ficticio y queda vinculado a su cuenta. | `HYPOTHESIS`: R9 no fija los campos; se aplicó el criterio de R12 a falta de decisión. |

## 3. Todavía no implementado

| Tema | Estado |
|---|---|
| Reglas R1–R8 en el dominio (`ReservationBook`) | Implementadas (Parte 2); las usa la vista del administrador |
| Vista y acciones del administrador, pendientes VIP, reservas y actividad de la noche, diálogos de advertencia y doble confirmación | Implementadas en la Parte 3 (demostración; pendiente de revisión) |
| Historial del administrador de noches ya terminadas | No implementado (M2 oculta las noches terminadas en el selector) |
| Vista del promotor (N7, R12–R16) | Implementada en el prototipo (P23): trámite normal y VIP, resumen, envío, «Mis reservas» |
| Recorrido de reserva del cliente (N5, R9) y vista del mesero | Implementados en el prototipo (P23): cliente con catálogo N5 y reserva a su nombre o de otra persona; personal localiza reservas y registra la llegada (R5) |
| Búsqueda y vinculación de cuentas por cédula (R12) | Prototipo: directorio de cuentas **ficticias** (las identidades de cliente de demostración), vínculo solo por cédula exacta. Directorio real y autenticación: futuro |
| Puntos de beneficio | Fuera de alcance (futuro) |
| Cobro real, ruta de pago en la app y reembolsos | `NOT DECIDED` (proveedor de pagos) |
| Autenticación y perfiles reales | `NOT DECIDED` |
| Liberación automática por falta de llegada a las 11 p. m. (normal) | Solo informativa; no implementada |
| Unión transaccional de las dos VIP | Fuera de alcance |
| Persistencia y datos compartidos (backend) | `NOT DECIDED` |
| Política de tratamiento de datos personales | `NOT DECIDED` |
| Eventos añadidos por el promotor | Futuro (N4) |

# Reglas de negocio — noches y reservas de mesa

**Fuente:**
- decisiones del equipo (Juanmi) del 2026-10-10, registradas en el [ADR 0002](../decisions/0002-perspectiva-administrador-y-reservas.md);
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

## 3. Todavía no implementado

| Tema | Estado |
|---|---|
| Reglas R1–R8 en el dominio (`ReservationBook`) | Implementadas en la Parte 2; sin vista que las use todavía |
| Vista y acciones del administrador, lista de pendientes VIP y diálogos de advertencia y doble confirmación | Parte 3 del plan |
| Vistas de cliente (incluida N5), promotor y mesero | Fuera de alcance (futuro) |
| Puntos de beneficio | Fuera de alcance (futuro) |
| Cobro real, ruta de pago en la app y reembolsos | `NOT DECIDED` (proveedor de pagos) |
| Autenticación y perfiles reales | `NOT DECIDED` |
| Liberación automática por falta de llegada a las 11 p. m. (normal) | Solo informativa; no implementada |
| Unión transaccional de las dos VIP | Fuera de alcance |
| Persistencia y datos compartidos (backend) | `NOT DECIDED` |
| Política de tratamiento de datos personales | `NOT DECIDED` |
| Eventos añadidos por el promotor | Futuro (N4) |

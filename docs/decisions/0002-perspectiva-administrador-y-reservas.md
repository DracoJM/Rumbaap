# ADR 0002 — Perspectiva de administrador y reglas de reserva

- **Estado:** `VALIDATED` (decisión explícita del equipo, Juanmi)
- **Fecha:** 2026-10-10
- **Reglas de negocio:** [`business-rules/reservas-y-noches.md`](../business-rules/reservas-y-noches.md). Es la fuente canónica de cada regla; aquí solo se resumen.

## Contexto

El mapa de consulta por noche (ADR 0001 y `architecture/reservations-venue-map.md`) era neutral: no tenía sesión, rol ni acciones. Al revisarlo, el equipo pidió construir funciones reales de reserva. También detectó un error en los datos de demostración: había mesas «Ocupadas» en noches futuras.

## Decisiones del equipo

| Tema | Decisión |
|---|---|
| Primera perspectiva | **Administrador**: es la cabeza del negocio y tiene potestad para validar o revocar cualquier reserva. |
| Acceso en esta fase | Selector «Administrador (demostración)», sin seguridad real, hasta que se decida la autenticación (sigue `NOT DECIDED` en `CLAUDE.md`). |
| Datos de esta fase | Almacén en memoria con datos ficticios sembrados, incluidas solicitudes de demostración; no hay persistencia ni backend. |
| Horario | Apertura 8:30 p. m., cierre 3:00 a. m.; hora de Colombia (UTC−5), independiente de la zona horaria del dispositivo. |
| Noches | Fin de semana actual (viernes, sábado, domingo), con forma de seleccionar noches futuras. El cliente solo verá las de su semana calendario (regla N5, futura). |
| Mesa normal | Mientras se completa, queda En proceso y bloquea la mesa hasta 10 min. Al completar el trámite se confirma automáticamente. Si no se completa, expira a los 10 min. Una reserva confirmada no vence por este temporizador. |
| Mesa VIP solicitada | **Pendiente de pago sin caducidad** hasta que el administrador verifique el prepago y la apruebe o rechace. |
| Mesa VIP directa | Si la crea el administrador, queda **confirmada directamente** (ya validó el pago). |
| Revocar y liberar | El administrador puede **revocar** una reserva confirmada **con advertencia**, y **liberar** una mesa reservada u ocupada **con doble confirmación**. |
| Llegada | De Reservada a Ocupada cuando el titular o alguien en su nombre la reclama. También la usará el **mesero** (perspectiva futura); no se ata al rol de administrador. |
| Pagos | Por ahora el prepago VIP se marca a mano. El punto de integración queda marcado en el código como `NOT DECIDED: proveedor de pagos`. |
| Datos personales | La reserva directa registra nombre, cédula y teléfono del titular. La demo usa solo datos claramente ficticios. La política de tratamiento de datos sigue `NOT DECIDED`. |
| Animación | Se restaura la del prototipo `Rumbaap-Demo-Sagsa`. Se pausa cuando el mapa no está visible o la app está en segundo plano, y se detiene si el sistema pide reducir el movimiento. |
| Mapa de consulta | Se aprueban para esta fase los ajustes propuestos por Claude (M1–M3 en las reglas): semana operativa hasta el lunes a las 03:00, ocultar noches terminadas y no navegar a semanas pasadas. No modifican la semana calendario del futuro cliente ni impiden el historial del administrador. |
| Reservas y fechas | Las reservas quedan ligadas a una noche concreta; el desplazamiento de semanas del mapa es solo de consulta. |

## Plan por partes

Cada parte se revisa por separado:

1. **Noches y mapa:** noches del fin de semana en curso y navegación a futuras; hora del local; «Ocupada» solo en la noche en curso; estado pendiente visible; animación restaurada.
2. **Reglas de reserva:** modelo de reserva y reglas R1–R8 en Dart puro con reloj inyectable, sobre el almacén de demostración en memoria.
3. **Vista del administrador:** pantalla basada en la del prototipo, adaptada a estas decisiones, con lista de pendientes (sobre todo VIP con pago por verificar) y acciones con confirmación.

## Decisiones de implementación (Claude)

Están en la sección 2 de las reglas de negocio:
- actualización automática por tiempo y al volver del segundo plano;
- distinción visual «En proceso» / «Pendiente de pago»;
- uso de los mecanismos del SDK para pausar la animación;
- representación de la hora del local.

No son reglas de negocio y no cambian el comportamiento acordado.

## Consecuencias

Lo que queda fuera de estas partes se marca en el código como `PENDIENTE (fuera de alcance)` y se lista en la sección 3 de las reglas de negocio:
- vistas de cliente, promotor y mesero;
- puntos;
- cobro real y ruta de pago;
- autenticación;
- liberación automática de las 11 p. m.;
- unión de las dos VIP;
- persistencia y backend;
- eventos del promotor.

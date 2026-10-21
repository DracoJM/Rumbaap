# Prepago VIP en dos pasos: revisión y propuesta

- **Estado:** revisión documental del 2026-10-20 y propuesta `HYPOTHESIS`. **No cambia código, dinero, saldo ni beneficios.**
- **Origen:** hallazgo 2 del [plan de QA](../qa/plan-validacion-operativa.md), observado también en Android el 2026-10-20 (R23).
- **Base:** HEAD `9d50e1d` más los cambios sin commit de A y de las altas.

## Qué hace cada botón hoy

| | Paso 1: «Confirmar prepago verificado» | Paso 2: «Registrar prepago verificado (2.000.000 COP)» |
|---|---|---|
| Dónde | Acciones de la reserva (`ReservationActions._confirmPrepayment`, `reservation_actions.dart`), solo con la VIP en «Pendiente de pago». | Tarjeta de beneficios de la ficha (`_prepaidSection`, `vip_benefits_view.dart`). Solo con identidad de administración, reserva confirmada u ocupada, sin importe registrado, noche no terminada e importe configurado. |
| Operación | `ReservationBook.markPrepaymentReceived`: «Pendiente de pago» pasa a «Confirmada». Evento `prepaymentMarked` con actor; el libro comprueba el cargo (A). | `BarBook.registerPrepaid`: crea un `VipPrepaid` (reserva, mesa, noche, importe y `registeredBy`), uno por reserva. El importe sale de `TableTerms.prepaidConsumption` (Sagsa: 2.000.000, en `sagsa_config.dart`). |
| Reserva VIP directa (R7) | No aplica: nace confirmada (`createDirect`, evento `createdDirect`). | Hace falta igualmente. |

## Qué habilita cada paso

| Derecho u operación | Depende de | Evidencia (código / test) |
|---|---|---|
| Champaña: petición, salida y entrega | Solo el paso 1, o una VIP directa: `hasVipApprovalEvidence` busca `prepaymentMarked` o `createdDirect` en el historial. Además, mesa ocupada y noche en curso. | `BarBook._champagneReservation`, `champagne_view.dart`; `vip_champagne_test` («mesa normal, VIP sin aprobación…») |
| Canje de cortesías (puerta y taquilla) | Solo el paso 1 o una VIP directa (`vipCourtesyCheckFor`). | `vip_redeem_gate_test` |
| Emitir las 6 cortesías | Los pasos 1 y 2: `VipBenefits.state` es `active` solo con la reserva confirmada u ocupada **y** el importe registrado; si no, queda en `prepaidNotRegistered`. | `issueVipCourtesies`; `vip_benefits_test` («aprobada sin prepago registrado no emite; tras registrarlo sí») |
| Consumo en Barra contra el prepago, saldo y excedente | Solo el paso 2: sin importe, `BarBook.register` rechaza con `vipPrepaidPending`. El saldo se calcula a partir de las ventas (`balanceOf`). | `vip_prepaid_test` (1.500.000, 2.300.000 → 300.000, repetición, cierre) |
| Panel: ingresos asociados a la noche | El importe del paso 2 (`prepaidAmount`) más lo cobrado en Barra. «Reservas VIP con el prepago verificado» cuenta el paso 1; «sin importe» cuenta las confirmadas sin paso 2. | `dashboard_page.dart`; `dashboard_test` |

## Contraste con las reglas confirmadas

- **Confirmado:** la administración verifica el prepago y aprueba la reserva, y eso habilita los derechos (6 cortesías y 1 champaña) sin despachar la botella. Ver [beneficios VIP](../business-rules/beneficios-vip.md) y [pedidos y barra](../business-rules/pedidos-barra.md).
- **El código separa lo que la regla trata como un solo acto:**
  1. Con solo el paso 1, la champaña y el canje de cortesías quedan habilitados, pero no se pueden **emitir** cortesías y Barra no consume contra el prepago.
  2. Una VIP directa (R7) presupone el pago validado, pero también necesita el paso 2 para emitir y para consumir.
  3. El panel puede mostrar una VIP «con prepago verificado» y sin importe, y los ingresos de la noche no incluyen ese prepago hasta el paso 2.
- **Huecos del paso 2 en la lógica:** `BarBook.registerPrepaid` guarda quién lo hizo, pero no comprueba el cargo ni el estado de la reserva. Solo la vista lo limita a la administración y a reservas confirmadas u ocupadas. Es el mismo tipo de hueco que A y las altas corrigieron en reservas.

## Propuesta revisable (no implementada)

| Opción | Qué cambia | Efecto |
|---|---|---|
| **P1. Un solo acto** (recomendada si la respuesta a la pregunta 1 es «sí») | «Confirmar prepago verificado» confirma la reserva y registra el importe configurado en una sola operación. En la VIP directa, el importe se registra al crearla. | Se ajusta a la regla tal como está redactada. Necesita una operación que toque dos libros a la vez (reservas y Barra), o un registro del prepago en la reserva. Hay que decidir qué pasa con los datos ya guardados en paso 1 sin paso 2 (¿se muestran como pendientes de registro, sin inventar el importe?). |
| **P2. Dos pasos con dependencias coherentes** | Emitir cortesías depende solo de la aprobación (como el canje y la champaña). El paso 2 queda solo para el consumo en Barra y el saldo. | Cambio menor. Mantiene la separación entre aprobar y registrar el dinero. |
| **P3. Sin cambios** | Solo se documenta y se explica mejor en la interfaz. | No resuelve la diferencia con la regla. |

En cualquier opción, además: que el registro del importe compruebe el cargo y el estado de la reserva en la lógica, y guarde el actor como ya hace con `registeredBy`.

## Preguntas imprescindibles

1. **Para el administrador:** cuando verifica el prepago y aprueba la VIP, ¿quedan registrados en ese mismo acto los 2.000.000 como saldo de consumo de la mesa? ¿O el registro del dinero es un paso aparte, hecho por otra persona o en otro momento?
2. **Para el administrador:** en una VIP creada directamente por la administración (pago ya validado), ¿el saldo de 2.000.000 debe quedar disponible desde la creación?
3. **Para Juanmi:** si el administrador separa los dos pasos, ¿la emisión de cortesías depende de la aprobación (P2) o también del registro del dinero (como hoy)?

No se preguntan de nuevo las cantidades (6 cortesías y 1 botella por mesa), el excedente (2.300.000 → 300.000) ni la pérdida del saldo no usado: están confirmados.

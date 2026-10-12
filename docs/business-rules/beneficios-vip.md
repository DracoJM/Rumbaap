# Beneficios de las reservas VIP (prototipo)

- **Código:** `lib/features/benefits/` (`VipBenefits`, `issueVipCourtesies`, `VipBenefitsCard`).
- **Leyenda:** `VALIDATED` (confirmado por el equipo), `NOT DECIDED`.

| Regla | Estado |
|---|---|
| Por cada mesa VIP: 6 entradas de cortesía (se canjean por manillas en taquilla) y 1 botella de champaña, adicionales al consumo prepagado. Quien reserva las dos zonas VIP tiene dos reservas: 12 cortesías y 2 botellas. | VALIDATED (aclaración de Juanmi, 2026-10-09; tipo de botella: champaña, aclaración del usuario 2026-10-12) |
| Las cortesías se emiten por el circuito de cortesías existente: la administración las autoriza con nombre y motivo, se activan sin pago y se canjean en taquilla. Quedan enlazadas a la reserva y se cuentan una vez contra su derecho, en cualquier estado. Una cortesía general (sin reserva) no consume el beneficio. | VALIDATED (circuito de cortesías) |
| La botella no cuenta en el consumo de la mesa. | VALIDATED |
| Marca y precio de la botella de champaña; quién la entrega, cuándo y cómo se registra la entrega. La app la muestra pero no la marca como entregada. | NOT DECIDED |
| Las 6 cortesías de cada mesa se activan solo cuando la administración verifica el prepago Y aprueba la reserva (reserva confirmada con su prepago registrado); taquilla entrega las manillas. La regla se aplica al CANJEAR: consulta de puerta, confirmación de ingreso y canje de una cortesía enlazada a una reserva VIP (también credenciales ya emitidas) exigen prueba de aprobación y verificación en el historial de la reserva: «prepago verificado» o reserva VIP directa de la administración (R7: pago validado). Sin prueba se rechaza y requiere revisión de la administración. La falta de importe registrado no significa «sin pagar» ni crea un saldo. Una revocación posterior no cancela cortesías ya aprobadas (su efecto sigue NOT DECIDED). Cortesías generales: sin cambios. | VALIDATED (aprobado por el usuario, 2026-10-12) |
| Efecto de revocar, rechazar, liberar o dejar expirar la reserva sobre el beneficio. La app no emite más y conserva lo emitido. | NOT DECIDED |
| Reponer una cortesía anulada, caducidad, transferencias y devoluciones del beneficio. | NOT DECIDED |
| Qué tipo de entrada se usa si el local tiene varios. Con uno solo, se usa ese. | NOT DECIDED |

- **Quién ve qué:**
  - Administración: en la ficha de la reserva ve el derecho, las cortesías emitidas con nombre y estado, y emite hasta el derecho. En el panel, el indicador «Reservas VIP con beneficios» lista las reservas VIP de la noche o del período.
  - Titular: en su reserva ve los recuentos (emitidas, canjeadas, por emitir) y la botella, sin nombres ni acciones.
- **Trazabilidad:** cada cortesía emitida guarda el actor, la hora y el motivo «Beneficio VIP · reserva R…». El enlace con la reserva se guarda en el estado local de forma compatible: los datos anteriores cargan como cortesías generales.
- **Fuera de alcance:** puntos, niveles, cobro real e inventario.

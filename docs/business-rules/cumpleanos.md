# Celebración de cumpleaños en reservas (prototipo)

- **Código:** `BirthdayCelebration` en `lib/features/reservations/domain/reservation.dart`; `ReservationBook.confirmBirthday` y `markDecorationPrepared`; vista en `lib/features/reservations/presentation/birthday_widgets.dart`.
- **Leyenda:** `VALIDATED` (dato confirmado: entrevistas o pedido real del usuario), `DECISIÓN DE PROTOTIPO` (decisión de implementación del equipo, autorizada para desarrollar y pendiente de validar con el cliente), `NOT DECIDED`.

## Fuentes (entrevistas originales)

- **E1, pregunta 6:** hoy los cumpleaños se registran en papel.
- **E1, pregunta 7:** las promociones actuales son solo de cumpleaños.
- **E2, pregunta 13:** la decoración de cumpleaños es preparación antes de la apertura, si corresponde.
- Las entrevistas NO definen importe, paquete, descuento fijo, entradas gratis ni ventana de fechas.

## Datos confirmados

| Dato | Estado |
|---|---|
| Hoy los cumpleaños se registran en papel. | VALIDATED (E1 P6) |
| Las promociones actuales son solo de cumpleaños. | VALIDATED (E1 P7) |
| La decoración de cumpleaños es preparación antes de la apertura, si corresponde. | VALIDATED (E2 P13) |
| Incluir la celebración de cumpleaños en las reservas. | VALIDATED (pedido real del usuario) |
| Importe, paquete, descuento fijo, entradas gratis y ventana de fechas. | NOT DECIDED (no los definen las entrevistas) |

## Decisiones del prototipo

Instrucciones del equipo para el desarrollo; no son respuestas del entrevistado ni del cliente.

| Decisión | Estado |
|---|---|
| El cumpleaños es un atributo opcional de una reserva normal o VIP, no un tipo de mesa ni una disponibilidad aparte; la reserva sigue las mismas reglas de aprobación, disponibilidad, hora límite y prepago VIP. | DECISIÓN DE PROTOTIPO |
| Campos: nombre de quien cumple años y notas opcionales; no se pide fecha de nacimiento, edad ni documentos nuevos. | DECISIÓN DE PROTOTIPO |
| Marcar el cumpleaños no promete promoción ni decoración: la administración confirma a mano condiciones y si requiere decoración; la app no aplica descuentos, cortesías ni cobros automáticos. | DECISIÓN DE PROTOTIPO (coherente con E1 P7) |
| Estados: solicitado/pendiente, confirmado, decoración por preparar, por revisar otra vez y preparada. | DECISIÓN DE PROTOTIPO |
| Solo la administración marca la decoración preparada, con actor y hora, si el acuerdo vigente la requiere; se valida en el dominio. Otros cargos: NOT DECIDED. | DECISIÓN DE PROTOTIPO |
| La administración puede ajustar condiciones y decoración mientras la reserva siga vigente y la noche no haya cerrado; el acuerdo anterior y su preparación quedan en el historial y una decoración preparada vuelve a «por revisar». | DECISIÓN DE PROTOTIPO |

## Interfaz

| Elemento | Estado |
|---|---|
| Interruptor «Celebración de cumpleaños» con nombre y notas en los formularios de cliente, promotor y administración (normal y VIP). | DECISIÓN DE PROTOTIPO |
| Seguimiento del cliente, ficha de la administración (confirmar/ajustar, marcar preparada), sección «Cumpleaños de esta noche» por mesa y estado corto en las listas de administración y en las llegadas del personal. | DECISIÓN DE PROTOTIPO |

## Persistencia

El cumpleaños se guarda dentro de cada reserva (clave opcional `birthday`, con `previous` para el historial de acuerdos). Las reservas guardadas antes no la tienen y cargan sin cambios.

# Reservas — mapa y consulta de disponibilidad por noche

- **Estado:** consulta de solo lectura con **datos de demostración**. Partes 1 y 2 del plan del [ADR 0002](../decisions/0002-perspectiva-administrador-y-reservas.md): noches por fin de semana, hora del local y reservas en memoria. La vista del administrador (Parte 3) está en [admin-reservations-demo.md](admin-reservations-demo.md).
- **Base:** [ADR 0001](../decisions/0001-base-app-flutter.md) y [reglas de noches y reservas](../business-rules/reservas-y-noches.md). Este documento no cambia ninguna decisión aprobada.

## Qué hace

Desde el inicio se abre «Mapa y disponibilidad». La persona elige una noche, ve el estado de cada mesa en el plano y toca una mesa, o la elige en la lista «Elegir mesa», para ver sus datos públicos: ID, tipo, ubicación, noche consultada, estado, capacidad y condiciones conocidas.

No reserva, no paga, no cancela, no une mesas VIP y no valida consumo. No muestra clientes ni información privada de reservas.

## Estructura (`lib/features/reservations/`)

| Archivo | Responsabilidad |
|---|---|
| `domain/venue_table.dart` | Mesas físicas: ID, tipo y zona. Sin `dart:ui` ni coordenadas. |
| `domain/night_schedule.dart` | Reloj inyectable (`Clock`), hora del local (UTC−5), `Night` (apertura 20:30, cierre 03:00) y `NightSchedule` (noches del fin de semana por semana operativa). |
| `domain/night_availability.dart` | `TableAvailability` (Disponible, En proceso, Reservada, Ocupada), `NightAvailability` y el contrato `NightAvailabilityRepository.availabilityFor(Night)`. |
| `domain/reservation.dart` | Modelo de reserva: noche concreta, mesa, titular, procedencia, estado (en proceso, pendiente de pago, reservada, ocupada, revocada, liberada, expirada) e historial de eventos. |
| `domain/reservation_book.dart` | `ReservationBook`: reglas R1–R8 en memoria con reloj inyectable (exclusividad mesa+noche, expiración a los 10 min, prepago VIP manual, rechazo, reserva directa, llegada, revocar, liberar). |
| `data/demo_reservation_store.dart` | `DemoReservationStore`: un único `ReservationBook` por ejecución, con reservas ficticias sembradas; implementa `NightAvailabilityRepository` para el mapa y avisa de los cambios (`ChangeNotifier`). |
| `presentation/venue_map_controller.dart` | `ChangeNotifier` con el fin de semana, la noche, la consulta y la mesa seleccionada. Escucha los cambios del almacén. |
| `presentation/venue_map_parts.dart` | Piezas de la pantalla compartidas con la vista del administrador. |
| `presentation/venue_geometry.dart` | Coordenadas del plano ilustrativo (1000 × 1100), rotación y abertura de muebles. |
| `presentation/venue_painter.dart`, `table_furniture_painter.dart`, `table_widget.dart`, `venue_map.dart` | Dibujo del recinto y de las mesas, zoom y desplazamiento. El mapa recibe estados, selección y callback. |
| `presentation/table_presentation.dart` | Texto, icono y color de cada estado (incluidos «En proceso» y «Pendiente de pago»), etiquetas de tipo, zona y noche. |
| `presentation/table_picker.dart` | Lista «Elegir mesa»: las 22 mesas con su estado, en filas de al menos 48 px y con etiquetas para lector de pantalla. Lee y selecciona en el mismo controlador que el mapa. |
| `presentation/table_detail.dart`, `venue_map_page.dart` | Detalle de mesa y pantalla completa. |

El tema oscuro con acentos violeta y ámbar está en `lib/app/app_theme.dart`. El almacén se crea una vez en `lib/main.dart` y se pasa por constructor (`RumbaapApp` → inicio → pantallas).

### Noches

- **Por defecto:** se muestran las noches de viernes, sábado y domingo de la semana operativa en curso.
- **Navegación:** con las flechas se pasa a fines de semana futuros.
- **Noche en curso:** se marca «En curso».
- **Origen de las noches:** las define `NightSchedule`, no el repositorio.
- **Hora:** se calcula en hora del local, independientemente de la zona horaria del dispositivo.

Reglas del mapa de consulta (M1–M3 en las [reglas de negocio](../business-rules/reservas-y-noches.md)), propuestas por Claude y aprobadas por el equipo para esta fase:
- **M1, cambio de semana:** la semana operativa cambia el lunes a las 03:00. No aplica al futuro catálogo del cliente, que usa la semana calendario.
- **M2, noches terminadas:** no se ofrecen.
- **M3, semanas pasadas:** no hay navegación a ellas. M2 y M3 no impiden un futuro historial del administrador.
- **`weeksAhead`:** es un desplazamiento relativo y solo de consulta. Las reservas quedan ligadas a una noche concreta.

Implementación (I1 en las reglas): un temporizador del controlador (`NightSchedule.nextChange`) vuelve a calcular las noches y a consultar al cruzar una apertura o un cierre. La página hace lo mismo al volver del segundo plano (`AppLifecycleListener.onResume`). Se conserva la mesa seleccionada si su noche sigue ofrecida. El temporizador y el observador se liberan al salir.

### Estados

- **Pendiente:** en una mesa normal se muestra «En proceso»; en una VIP, «Pendiente de pago». Comparten el ámbar, con icono y texto propios.
- **Animación:** las mesas pendientes «respiran» con la animación del mapa.

### Comportamiento del controlador

- **Cambio de noche:** limpia la selección y los datos anteriores antes de consultar.
- **Respuestas tardías:** cada consulta lleva un número y solo la más reciente puede publicar su resultado. Una respuesta tardía de otra noche, sea éxito o error, se descarta.
- **Respuesta de otra noche:** si el `nightId` de la respuesta no coincide con la noche pedida, se trata como error.
- **Carga, error o mesa sin dato:** el mapa la muestra como «Sin información». Nunca la presenta como disponible ni reutiliza datos de otra noche.
- **Datos que vencen solos:** si la respuesta trae `refreshAt` (por ejemplo, el vencimiento de una reserva en proceso), el controlador vuelve a consultar en ese instante. El almacén calcula `refreshAt` antes que los estados: si una reserva vence mientras se construye la respuesta, la mesa puede llegar como pendiente, pero con un `refreshAt` (aunque ya pasado) que obliga a volver a consultar de inmediato.
- **Cambios de datos (I11):** cuando el almacén avisa de una operación, se vuelve a consultar la misma noche manteniendo los datos y la mesa seleccionada hasta la respuesta. Una consulta abierta, también la pública, muestra el cambio sin reiniciar la app.
- **Bloqueo por solicitud pendiente:** resuelto por R1–R3. La normal en proceso bloquea su mesa y noche hasta 10 min; la VIP solicitada la bloquea sin ese límite hasta que el administrador decida.

### Selección de mesa

- **Dos formas de seleccionar:** tocar la mesa en el mapa o elegirla en la lista «Elegir mesa». Ambas llevan a la misma selección y al mismo detalle.
- **Por qué la lista:** con el plano completo a la vista, las mesas normales quedan pequeñas en el teléfono (unos 28 px lógicos). Las áreas táctiles del mapa no se amplían, para no solaparse.
- **Desde el mapa,** tocar la mesa ya seleccionada la deselecciona. **Desde la lista,** elegirla de nuevo la mantiene seleccionada.

### Diseño adaptable

- **Detalle en hoja inferior:** cuando el ancho es menor de 600 px lógicos y la pantalla está en vertical. La hoja va dentro de la pantalla y ocupa como máximo la mitad del alto.
- **Detalle en panel lateral:** cuando el ancho es de 600 px o más, o la pantalla está en horizontal. Así un teléfono pequeño en horizontal no deja el mapa sin altura.
- **Noches:** se muestran en un `Wrap` y quedan siempre a la vista, también con el panel abierto.
- **«Elegir mesa»:** va en la cabecera, junto a la leyenda, sin tapar el mapa ni los controles de zoom.
- **Leyenda:** se desplaza en horizontal cuando no cabe.
- **Controles de zoom:** se colocan en fila si el área del mapa mide menos de 220 px de alto.

## Almacén de demostración

`DemoReservationStore` (Parte 2) sustituye al adaptador aleatorio anterior.
- **Fuente única:** guarda un único `ReservationBook` por ejecución de la app y deriva los estados del mapa de las reservas activas:
  - en proceso o pendiente de pago → «En proceso» o «Pendiente de pago»;
  - confirmada → «Reservada»;
  - ocupada → «Ocupada».
- **Siembra:** la primera vez que se consulta una noche siembra reservas ficticias, aplicando las mismas reglas que una reserva real y eligiendo las mismas mesas para la misma fecha. No siembra noches terminadas ni noches que ya tienen historial (por ejemplo, reservas creadas antes de consultarlas): así nunca choca con operaciones reales ni rellena una mesa revocada o liberada. Solo hay llegadas sembradas si la noche está en curso.
- **Latencia:** simula 350 ms para que la carga sea visible.
- **Memoria:** navegar conserva las reservas y los cambios; cerrar la app los pierde. **No** comparte datos entre dispositivos ni refleja la operación real.
- La pantalla muestra siempre «Datos de demostración».
- Las operaciones de las vistas pasan por `perform`, que avisa a quienes escuchan. Los vencimientos no avisan: cada consulta los anuncia con `refreshAt`.
- Para conectar datos compartidos hará falta otra implementación del almacén, con las mismas consultas y avisos; la decisión de backend sigue `NOT DECIDED`.

## Procedencia y límites del plano

- Geometría, painters y paleta adaptados del prototipo separado `Rumbaap-Demo-Sagsa`.
- Respecto a la demo:
  - Por decisión del equipo (M4) se restauraron la iluminación animada, el pulso de las mesas pendientes y el efecto al pasar el ratón. Se detiene si el sistema pide reducir el movimiento y se pausa cuando el mapa no está visible o la app está en segundo plano. Para ello usa los mecanismos del SDK (I3).
  - Se quitó la fuente incluida.
  - No se copiaron `DemoController`, `ReservationLedger`, formularios, selector de roles ni acciones.
- Las medidas 1000 × 1100 son ilustrativas; no son metros ni un plano arquitectónico.
- Los IDs M01–M20 y VIP 1/VIP 2 se conservan por continuidad del desarrollo. **No** son la numeración física oficial confirmada por el establecimiento.

## Textos de condiciones mostrados

Proceden de las instrucciones del equipo para esta tarea:

- **Mesa normal:**
  - Capacidad «Por confirmar».
  - Reserva sin costo ni prepago.
  - Consumo de referencia de 400.000 COP con tolerancia validada por el personal.
  - Confirmación automática al completar la reserva (regla R1). Es información sobre la regla aprobada; el formulario del cliente no está construido.
- **Mesa VIP:**
  - Hasta 20 personas.
  - Consumo prepagado de 2.000.000 COP por mesa.
  - Las dos juntas: hasta 40 personas y 4.000.000 COP, como dos mesas.

## Pendiente

| Tema | Estado |
|---|---|
| Fuente de datos compartida (backend) | NOT DECIDED |
| Capacidad de las mesas normales | NOT DECIDED |
| Numeración física oficial de mesas | NOT DECIDED |
| Compilación y ejecución nativas en iOS | Pendiente de macOS/Xcode |

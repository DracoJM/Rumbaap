# Reservas — mapa y consulta de disponibilidad por noche

- **Estado:** implementación inicial, consulta de solo lectura con **datos de demostración**.
- **Base:** [ADR 0001](../decisions/0001-base-app-flutter.md). Este documento no cambia ninguna decisión aprobada.

## Qué hace

Desde el inicio se abre «Mapa y disponibilidad». La persona elige una noche, ve el estado de cada mesa en el plano y toca una mesa, o la elige en la lista «Elegir mesa», para ver sus datos públicos: ID, tipo, ubicación, noche consultada, estado, capacidad y condiciones conocidas.

No reserva, no paga, no cancela, no une mesas VIP y no valida consumo. No muestra clientes ni información privada de reservas.

## Estructura (`lib/features/reservations/`)

| Archivo | Responsabilidad |
|---|---|
| `domain/venue_table.dart` | Mesas físicas: ID, tipo y zona. Sin `dart:ui` ni coordenadas. |
| `domain/night_availability.dart` | `Night`, `TableAvailability` (Disponible, Reservada, Ocupada), `NightAvailability` y el contrato `NightAvailabilityRepository`. |
| `data/demo_night_availability_repository.dart` | Adaptador de desarrollo con dos noches ficticias. |
| `presentation/venue_map_controller.dart` | `ChangeNotifier` con la noche, la consulta y la mesa seleccionada. |
| `presentation/venue_geometry.dart` | Coordenadas del plano ilustrativo (1000 × 1100), rotación y abertura de muebles. |
| `presentation/venue_painter.dart`, `table_furniture_painter.dart`, `table_widget.dart`, `venue_map.dart` | Dibujo del recinto y de las mesas, zoom y desplazamiento. El mapa recibe estados, selección y callback. |
| `presentation/table_presentation.dart` | Texto, icono y color de cada estado; etiquetas de tipo y zona. |
| `presentation/table_picker.dart` | Lista «Elegir mesa»: las 22 mesas con su estado, en filas de al menos 48 px y con etiquetas para lector de pantalla. Lee y selecciona en el mismo controlador que el mapa. |
| `presentation/table_detail.dart`, `venue_map_page.dart` | Detalle de mesa y pantalla completa. |

El tema oscuro con acentos violeta y ámbar está en `lib/app/app_theme.dart`. La dependencia del repositorio se crea en `lib/main.dart` y se pasa por constructor hasta la pantalla.

### Comportamiento del controlador

- **Cambio de noche:** limpia la selección y los datos anteriores antes de consultar.
- **Respuestas tardías:** cada consulta lleva un número y solo la más reciente puede publicar su resultado. Una respuesta tardía de otra noche, sea éxito o error, se descarta.
- **Respuesta de otra noche:** si el `nightId` de la respuesta no coincide con la noche pedida, se trata como error.
- **Carga, error o mesa sin dato:** el mapa la muestra como «Sin información». Nunca la presenta como disponible ni reutiliza datos de otra noche.

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

## Adaptador de demostración

`DemoNightAvailabilityRepository` contiene dos noches ficticias, «Viernes 16 de octubre» y «Sábado 17 de octubre», con estados distintos para varias mesas. Simula 350 ms de latencia para que la carga sea visible.

- Vive en la memoria del dispositivo. **No** comparte disponibilidad entre dispositivos ni refleja la operación real.
- La pantalla muestra siempre «Datos de demostración».
- Para conectar datos compartidos basta con otra implementación de `NightAvailabilityRepository` inyectada en `lib/main.dart`; la presentación no cambia.

## Procedencia y límites del plano

- Geometría, painters y paleta adaptados del prototipo separado `Rumbaap-Demo-Sagsa`.
- Respecto a la demo:
  - Se quitó la animación continua de iluminación, el estado «Solicitud pendiente», el hover y la fuente incluida.
  - No se copiaron `DemoController`, `ReservationLedger`, formularios, selector de roles ni acciones.
- Las medidas 1000 × 1100 son ilustrativas; no son metros ni un plano arquitectónico.
- Los IDs M01–M20 y VIP 1/VIP 2 se conservan por continuidad del desarrollo. **No** son la numeración física oficial confirmada por el establecimiento.

## Textos de condiciones mostrados

Proceden de las instrucciones del equipo para esta tarea:

- **Mesa normal:**
  - Capacidad «Por confirmar».
  - Reserva sin costo ni prepago.
  - Consumo de referencia de 400.000 COP con tolerancia validada por el personal.
  - Reserva sujeta a confirmación. El texto no asigna la confirmación a ningún rol ni decide entre aprobación administrativa y automática.
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
| Política de bloqueo de mesa por solicitud pendiente | NOT DECIDED (fuera de esta consulta) |
| Compilación y ejecución nativas en iOS | Pendiente de macOS/Xcode |

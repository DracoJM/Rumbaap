# Mapa único «Noche de cristal» v7 y configuración por local

- **Estado:** implementado con **datos de demostración**, según el [ADR 0004](../decisions/0004-mapa-unico-noche-de-cristal.md) (P22/P22.1).
- **Perspectivas:** consulta pública ([reservations-venue-map.md](reservations-venue-map.md)) y administrador ([admin-reservations-demo.md](admin-reservations-demo.md)). Las dos usan el mismo componente y el mismo almacén.

## Componentes compartidos (`lib/features/reservations/presentation/map/`)

| Archivo | Responsabilidad |
|---|---|
| `crystal_venue_map.dart` | `CrystalVenueMap`: el único mapa. Recibe estados, selección, filtro y toque, y lee el local de `VenueScope`. El fondo común (gradiente lineal tenue) es `AppBackground`, en `lib/theme/app_background.dart`. |
| `crystal_map_scaffold.dart` | Pantalla común. Contiene: volver; aviso de datos ficticios; «Buscar mesa»; navegador de noche (flechas y deslizamiento); resumen por estado con filtro; plano; y la ficha y la barra que aporta cada perspectiva. |
| `crystal_layout.dart` | `CrystalLayout` y `TablePlacement`: lienzo, posiciones, zonas táctiles y elementos opcionales del recinto (tarima VIP, pista, barra, cabina DJ, acceso, esquinas). `FurnitureSpec`: medidas del mueble por tipo de mesa. |
| `venue_static_painters.dart`, `venue_light_painters.dart` | Capas fijas y capas animadas, calculadas a partir de la distribución. |
| `crystal_table.dart`, `status_icon.dart` | Mesa (sofá en U, disco, número, icono) e iconos de estado. |
| `table_sheet.dart`, `glass.dart`, `glass_tab_bar.dart` | Ficha de cristal (`TableSheet` con `SheetAction`), panel de cristal y barra inferior. |

## Configuración por local (`lib/features/venues/`)

- **`venue_config.dart`:**
  - `VenueConfig` reúne el local (`Venue`: id, nombre, mesas y zonas), su `VenueTheme`, su `CrystalLayout` y sus condiciones por tipo de mesa (`TableTerms`).
  - `VenueScope` la hace disponible a toda la interfaz; va por encima del `Navigator`.
- **`sagsa/`:** mesas y zonas (`sagsa_venue.dart`), distribución v7 (`sagsa_layout.dart`) y configuración con condiciones (`sagsa_config.dart`). El tema está en `lib/theme/venues/sagsa.dart`.
- **Uso de la configuración:**
  - `RumbaapApp(config:)` recibe la configuración y crea el almacén del mismo local.
  - El tema de la app (`AppTheme.build`) sale del `VenueTheme`.
  - `AppColors` solo tiene neutros y semánticos comunes.

### Límite entre locales

- **Datos separados por local:**
  - `ReservationBook(venue:)` y `DemoReservationStore(venue:)` pertenecen a un único local y rechazan mesas de otro (`unknownTable`).
  - Las respuestas llevan `venueId`. `VenueMapController(venue:)` trata como error una respuesta de otro local, igual que una de otra noche.
  - Los IDs de mesa solo son únicos dentro de su local.
- **Pendiente (fuera de alcance):**
  - Las reglas R1–R8 y el horario (`NightSchedule`) son los confirmados para Sagsa y siguen en el código. Se parametrizarán cuando exista otro local con reglas propias.
  - No hay backend multiempresa, selector de local ni editor de planos.

## Rendimiento

- **Un solo reloj:** un `Ticker` (`MapClock`) alimenta todas las animaciones. Las capas animadas son `CustomPainter` con `repaint: clock`, cada una en su `RepaintBoundary`; las capas fijas y las mesas no repintan.
- **Qué se anima:** solo giro, escala, desplazamiento y opacidad. El desenfoque es fijo.
- **Cristal:** ficha y barra usan `BackdropFilter.grouped` dentro de un `BackdropGroup`, en la ranura inferior del `Scaffold` con `extendBody`. Así el plano se ve detrás y los avisos flotantes aparecen encima de la ficha.
- **Sin estiramiento de overscroll en el cristal (P24):** en Android 12+ el estiramiento envuelve el contenido desplazable en una capa con filtro de imagen, y un `BackdropFilter` dentro de esa capa pierde el fondo: la ficha se veía transparente al arrastrarla hasta su borde. Ficha y barra desactivan solo ese efecto (`ScrollConfiguration` con `overscroll: false`); el desplazamiento se conserva. Reproducido y verificado en el emulador Android (capturas antes, durante y después); en iOS no hay estiramiento, pero la validación nativa sigue pendiente.
- **Reducir movimiento:** con `MediaQuery.disableAnimations` no se arranca el ticker. `TickerMode` lo pausa cuando otra pantalla tapa el mapa.

## Diseño adaptable

- **Teléfono en vertical:** el plano se escala al ancho, hasta 560 px, y se desplaza en vertical. Su margen inferior deja el final del plano por encima de la ficha. La ficha ocupa como mucho el 42 % del alto, para que siempre quede una franja del plano por la que desplazarse.
- **600 px o más, u horizontal:** ficha y barra van en una columna lateral.
- **Zonas táctiles del plano:** franja de 58 × 44 unidades del lienzo por mesa normal y 72 × 58 por VIP, contiguas y sin solaparse. El plano se escala al ancho (`FittedBox`), así que en pantalla miden 58 × 44 × escala:
  - 320 de ancho: unos 43 × 33 dp (por debajo de 48 dp);
  - 360: unos 49 × 37 dp;
  - 411: unos 56 × 43 dp.

  El plano es un gráfico denso y sus franjas no se declaran como áreas de 48 dp. La alternativa accesible es «Buscar mesa» (botón de lupa arriba a la derecha, siempre a la vista; P24): una búsqueda real por número, nombre, zona o estado, con filas de al menos 48 dp. No repite el plano como listado completo: sin texto no muestra filas. Elegir un resultado, o pulsar la tecla de buscar con un solo resultado, selecciona la mesa en el mapa y abre su ficha.
- **Controles:** volver, «Buscar mesa», flechas de noche, chips del resumen, acciones y botones de la ficha y pestañas miden al menos 48 × 48 dp; un test los mide en 320 × 568.
- **Texto ampliado (200 %):** la interfaz usa la escala de texto del sistema sin límite propio; nada se reduce, se oculta ni se recorta con «…». Verificado en tests y en el emulador Android con 320 × 568 dp y fuente al 200 %.
  - **Barra inferior:** con el tamaño normal es la fila única de v7. Si las cinco secciones no caben sin partir palabras (`GlassTabBar.itemWidthFor`), sigue en una fila que se desplaza en horizontal; no crece en filas sobre el plano.
  - **Cabecera:** la fila superior (volver, aviso de datos ficticios y «Buscar mesa») queda fija. Con texto grande, la noche y el resumen se desplazan junto con el plano; sobre las listas, la cabecera ocupa como mucho el 40 % del alto.
  - **Ficha cerrada:** la mesa y su estado ocupan las líneas que necesiten y la acción pasa a su propia fila, a lo ancho.
  - **Alto de ficha y barra:** juntas no pasan del 80 % de la pantalla; la ficha cede alto y se desplaza.
  - **Listas:** las de Reservas dejan libre el alto de la barra, así su última fila se ve y se toca. Los segmentos van en una fila desplazable.
  - **«Buscar mesa»:** es una sola lista desplazable, campo de búsqueda incluido; el estado de cada fila va bajo la zona, sin recortarse.

## Cobertura de tests de estas interacciones

`test/features/reservations/map_interactions_test.dart` sustituye la cobertura de la antigua pantalla de demostración con el componente actual:
- **Noche:** deslizar sobre la fecha cambia de noche y no retrocede antes de la primera.
- **Filtro:** el chip del resumen atenúa las demás mesas a 0,2, anuncia `toggled` y se quita, sin cambiar estados ni reservas.
- **Animación:** las luces avanzan sin reconstruir el mapa ni las mesas.
- **Ficha abierta:** el final del plano es alcanzable en el teléfono, en consulta y en administración.
- **Activación semántica:** `SemanticsAction.tap` real sobre una VIP, sobre la acción de la ficha y sobre las pestañas Mapa y Reservas. Las secciones en desarrollo no publican `tap` y están deshabilitadas.
- **Texto al 200 %:** escala efectiva 2,0 y etiquetas sin partir en la barra y la ficha; estado legible en «Buscar mesa»; final de las listas por encima de la barra.
- **Tamaños táctiles:** medidos en 320 × 568.

## Pendiente

- **Fuentes:** Sora y Figtree no están incluidas (decisión de recursos); se usa la fuente del sistema.
- **iOS:** `iOS NATIVE VALIDATION PENDING`. El cristal y el rendimiento deben medirse en un iPhone.
- **Módulos sin construir:** Entradas, Pedidos y Más.

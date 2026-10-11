# Mapa único «Noche de cristal» v7 y configuración por local

- **Estado:** implementado con **datos de demostración**, según el [ADR 0004](../decisions/0004-mapa-unico-noche-de-cristal.md) (P22/P22.1).
- **Perspectivas:** consulta pública ([reservations-venue-map.md](reservations-venue-map.md)) y administrador ([admin-reservations-demo.md](admin-reservations-demo.md)). Las dos usan el mismo componente y el mismo almacén.

## Componentes compartidos (`lib/features/reservations/presentation/map/`)

| Archivo | Responsabilidad |
|---|---|
| `crystal_venue_map.dart` | `CrystalVenueMap`: el único mapa. Recibe estados, selección, filtro y toque, y lee el local de `VenueScope`. También contiene el fondo ambiental. |
| `crystal_map_scaffold.dart` | Pantalla común. Contiene: volver; aviso de datos ficticios; «Elegir mesa»; navegador de noche (flechas y deslizamiento); resumen por estado con filtro; plano; y la ficha y la barra que aporta cada perspectiva. |
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
- **Reducir movimiento:** con `MediaQuery.disableAnimations` no se arranca el ticker. `TickerMode` lo pausa cuando otra pantalla tapa el mapa.

## Diseño adaptable

- **Teléfono en vertical:** el plano se escala al ancho, hasta 560 px, y se desplaza en vertical. Su margen inferior deja el final del plano por encima de la ficha. La ficha ocupa como mucho el 42 % del alto, para que siempre quede una franja del plano por la que desplazarse.
- **600 px o más, u horizontal:** ficha y barra van en una columna lateral.
- **Zonas táctiles del plano:** franja de 58 × 44 unidades del lienzo por mesa normal y 72 × 58 por VIP, contiguas y sin solaparse. El plano se escala al ancho (`FittedBox`), así que en pantalla miden 58 × 44 × escala:
  - 320 de ancho: unos 43 × 33 dp (por debajo de 48 dp);
  - 360: unos 49 × 37 dp;
  - 411: unos 56 × 43 dp.

  El plano es un gráfico denso y sus franjas no se declaran como áreas de 48 dp. La alternativa accesible es «Elegir mesa» (botón de lista arriba a la derecha, siempre a la vista), con filas de al menos 48 dp.
- **Controles:** volver, «Elegir mesa», flechas de noche, chips del resumen, acciones y botones de la ficha y pestañas miden al menos 48 × 48 dp; un test los mide en 320 × 568.
- **Texto ampliado:** la barra inferior usa la escala de texto del sistema sin límite propio.
  - Si a esa escala las cinco secciones no caben sin partir palabras, pasa a varias filas (`GlassTabBar.columnsFor`); con el tamaño normal es la fila única de v7.
  - Con texto grande, la cabecera ocupa como mucho la mitad del alto y se desplaza.
  - La ficha cede alto a la barra. Ficha y barra juntas no pasan del 80 % de la pantalla; si no caben, se desplazan.
  - Los segmentos de Reservas van en una fila desplazable y «Elegir mesa» es una sola lista desplazable.

## Pendiente

- **Fuentes:** Sora y Figtree no están incluidas (decisión de recursos); se usa la fuente del sistema.
- **iOS:** `iOS NATIVE VALIDATION PENDING`. El cristal y el rendimiento deben medirse en un iPhone.
- **Módulos sin construir:** Entradas, Pedidos y Más.

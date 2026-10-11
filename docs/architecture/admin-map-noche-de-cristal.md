# Mapa del administrador — «Noche de cristal» v7

- **Estado:** implementación de la maqueta aprobada, con **datos de demostración** ficticios. Solo la sección «Mapa» funciona.
- **Base:** [ADR 0001](../decisions/0001-base-app-flutter.md). No cambia ninguna decisión aprobada ni el mapa de consulta existente ([reservations-venue-map.md](reservations-venue-map.md)).

## Qué hace

Desde el inicio, «Mapa del administrador» abre una pantalla sin título con:

- **Navegador de noche:** flechas a los lados de la fecha («Dom 11 oct», «Noche desde las 22:00»). Deslizar en horizontal sobre la fecha también cambia de noche, a partir de 30 px.
- **Resumen por estado:** chips desplazables con icono, conteo y nombre. Solo aparecen los estados presentes. Tocar uno atenúa las demás mesas a 0,2; tocarlo otra vez quita el filtro. Si la nueva noche no tiene mesas en el estado filtrado, el filtro se quita.
- **Plano:** lienzo lógico de 400 × 622 escalado al ancho, con un máximo de 560 px. Si no cabe en alto, se desplaza en vertical; el margen inferior deja ver el final del plano por encima de la ficha.
- **Ficha flotante de cristal:** mesa seleccionada (al entrar, M07). Cerrada muestra icono, «Mesa M07», estado, acción corta y flecha. Abierta añade la descripción y la acción completa a lo ancho.
- **Barra inferior de cristal:** Mapa, Reservas, Entradas, Pedidos, Más. Solo Mapa tiene pantalla.

Los botones de acción de la ficha y las secciones de la barra que no son Mapa todavía no hacen nada (`NOT DECIDED`).

## Estructura

| Archivo | Responsabilidad |
|---|---|
| `lib/theme/venue_theme.dart` | `VenueTheme` (`ThemeExtension`): marca, mobiliario e intensidad de luces de un local. |
| `lib/theme/status_colors.dart` | `StatusColors` (`ThemeExtension`): colores de estado comunes. El pago VIP pendiente usa el dorado VIP del local. |
| `lib/theme/night_neutrals.dart` | Neutros comunes: texto, cristal y superficies oscuras. |
| `lib/theme/venues/sagsa.dart` | Tema de Sagsa. Agregar un local es agregar un archivo aquí. |
| `features/admin_map/domain/admin_table_status.dart` | Estados del administrador: disponible, reservada, en proceso, ocupada, pago VIP pendiente, sin información. |
| `features/admin_map/data/demo_admin_nights.dart` | Datos ficticios. La noche base (11 oct 2026) reproduce la maqueta; las demás salen de una semilla fija por noche. |
| `features/admin_map/presentation/admin_map_controller.dart` | `ChangeNotifier`: noche, filtro, mesa y ficha. |
| `crystal_map_geometry.dart` | Coordenadas del lienzo 400 × 622 y zonas táctiles. Reutiliza `VenueTables` y `VenueGeometry.openingOf`. |
| `venue_static_painters.dart`, `venue_light_painters.dart` | Capas fijas y capas animadas del plano. |
| `crystal_table.dart`, `status_icon.dart` | Mesa (sofá en U, disco, número, icono) e iconos de estado. |
| `crystal_venue_map.dart`, `glass.dart`, `table_sheet.dart`, `glass_tab_bar.dart`, `admin_map_page.dart` | Plano, cristal, ficha, barra y pantalla. |

Los temas se registran en `AppTheme.build()`. El resto de la app sigue usando `AppColors`.

## Rendimiento

- **Un solo reloj:** un `Ticker` (`MapClock`) alimenta todas las animaciones. Las capas animadas son `CustomPainter` con `repaint: clock` en su propio `RepaintBoundary`, así que cada fotograma repinta solo esas capas, sin reconstruir widgets. Las capas fijas, las mesas y las luces de fondo no repintan.
- **Qué se anima:** solo giro, escala, desplazamiento y opacidad de formas sencillas. El fondo ambiental mueve con `Transform` imágenes fijas.
- **Desenfoque:** fijo, nunca animado. Ficha y barra usan `BackdropFilter.grouped` dentro de un `BackdropGroup`, para compartir una sola lectura del fondo por fotograma.
- **Reducir movimiento:** con `MediaQuery.disableAnimations` activo no se arranca el ticker y las capas muestran un estado fijo.

## Zonas táctiles

- **Mesas normales:** cada una ocupa su franja completa de 58 × 44 unidades lógicas, contigua con la vecina y sin solaparse.
- **Mesas VIP:** 72 × 58 unidades.
- **Cambio de escala:** con el plano escalado a 360 px de ancho, una franja normal mide unos 52 × 40 px.

## Pendiente de decidir o validar

- **Acciones:** qué hacen los botones de la ficha y las secciones Reservas, Entradas, Pedidos y Más.
- **Tipografías Sora y Figtree:** la maqueta las usa, pero no están incluidas. Incluir fuentes es una decisión de dependencias o recursos; hoy se usa la del sistema.
- **«incluye 6 entradas de cortesía»:** el texto de la ficha VIP sale de la maqueta; falta confirmarlo como condición comercial.
- **iOS:** `iOS NATIVE VALIDATION PENDING`. El cristal (`BackdropFilter`) y el rendimiento deben medirse en un iPhone real.

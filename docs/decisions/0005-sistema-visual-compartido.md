# ADR 0005 — Sistema visual compartido (nota de diseño)

- **Estado:** decisión de prototipo, pedida por Juanmi (2026-10-12); pendiente de validar con el cliente.
- **No cambia:** el mapa de mesas ([ADR 0004](0004-mapa-unico-noche-de-cristal.md)): geometría, posiciones, mobiliario, zonas táctiles, luminarias útiles y painters estáticos. Tampoco las reglas de negocio.

## Referencias (principios, no copia ni «Liquid Glass» nativo en Flutter)

| Fuente | Principio | Aplicación |
|---|---|---|
| Apple, [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) (WWDC25) | Vidrio para la navegación y no para el contenido; sin vidrio sobre vidrio; legibilidad y accesibilidad primero. | `GlassPanel` (con `BackdropFilter.grouped`) queda en la barra de navegación y la ficha de mesa. Compras, formularios e importes usan superficies de relleno estable (`AppColors.surface`), sin capas borrosas anidadas. |
| Linear, [A calmer interface for a product in motion](https://linear.app/now/behind-the-latest-design-refresh) (2026-03-12) | Menos ruido, jerarquía de acciones, neutros poco saturados, bordes discretos y posiciones consistentes. | Grafito frío, bordes de 1 px, sombras nulas, un solo acento (azul/lila) para la acción principal y la selección; botones secundarios con borde fino. Se quitaron las mayúsculas con espaciado. |
| Google Design, [investigación M3 Expressive](https://design.google/library/expressive-material-design-google-research) | Destacar la tarea principal con tamaño, color y contención; conservar patrones y etiquetas; priorizar contraste y objetivos táctiles. | Botones y campos de 48 dp de alto mínimo, jerarquía tipográfica clara, secciones con título, textos secundarios con contraste AA. |

## Qué cambió

- **Fondo.** Las «bolas» luminosas salían de dos sitios: `AmbientBackground` (tres manchas animadas con `RadialGradient`, en `crystal_venue_map.dart`, usadas por `CrystalMapScaffold`) y el `RadialGradient` del selector de perfiles (`home_page.dart`). Se eliminaron. Ahora `AppBackground` (`lib/theme/app_background.dart`) pinta un gradiente LINEAL tenue; el resto de las pantallas usa el color plano del local. Se retiró `VenueTheme.ambientIntensity`.
- **Tokens** (`lib/app/app_theme.dart`): `AppColors` (grafito frío, texto casi blanco y secundario AA), `AppSpace` (8/12/16/24; margen 16 o 20 según ancho) y `AppRadius` (tarjetas 20, controles 14).
- **Tipografía.** Fuente del sistema; título 26–28, sección 18–20, cuerpo 15–16 y ayuda 13–14. Escala con el texto del usuario.
- **Componentes.** Temas de botones, campos, tarjetas, diálogos, segmentados y avisos; las superficies translúcidas de tarjetas se sustituyeron por rellenos estables.
- **Textos.** En administración, los títulos de una noche elegida dicen «de la noche seleccionada» (p. ej. «Cumpleaños de la noche seleccionada»), porque puede ser una noche futura.
- **Sin cambios:** estados de mesa (color más icono y texto), distintivo VIP, glass de navegación y animaciones del plano.

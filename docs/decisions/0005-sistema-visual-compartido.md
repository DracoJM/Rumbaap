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

## Revisión visual tras la captura nativa de `1279f61` (2026-10-14)

Origen: capturas por ADB de Inicio, mapa cliente, Perfil, Promotor, Barra y Admin en `Pixel_7` con el APK debug de `1279f61` (solo navegación; evidencia en `Downloads\rumbaap-qa-diseno-2026-10-14\`). Es una revisión visual hecha por el equipo técnico, no una validación de diseño con el cliente. Las fuentes de dirección son las mismas de la tabla anterior más las guías de accesibilidad y tipografía de Flutter ([UI y estilo](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [tipografía](https://docs.flutter.dev/ui/design/text/typography)); no se añaden dependencias ni fuentes.

Cambios (sin tocar reglas, permisos, modelos, ventas, entregas, noches ni callbacks; mapa y glass de la ficha de mesa intactos):

- **Barra de cristal** (`glass_tab_bar.dart`): las secciones miden lo mismo (la más alta) y alinean icono y etiqueta arriba. El cliente muestra «Reservas» (una línea) y el lector de pantalla sigue anunciando «Mis reservas» (`GlassTab.semanticLabel`; la clave `tab-Mis reservas` se conserva con `GlassTab.id`). Con texto grande sigue desplazándose en horizontal sin reducir el texto. El relleno inferior del plano ya lo da `extendBody` y la barra de una línea es más baja.
- **Promotor** (`guest_tickets.dart`): hueco entre el título «Entrada general» y la etiqueta flotante «Noche» que crece con el tamaño del texto.
- **Más** (`session_panel.dart`): identidad y aviso en una tarjeta; «Cambiar identidad» pasa a botón secundario (`OutlinedButton`, 52 dp). No se añaden datos.
- **Admin** (`admin_page.dart`): el selector Pendientes/Reservas/Actividad ocupa el ancho disponible si los tres caben; si no, se desplaza sin reducir ni partir el texto. La selección se conserva.
- **Avisos**: en Admin, «Mesas normales en proceso» tiene un solo bloque (la regla de los 10 min y el estado vacío juntos). En Barra, fuera de noche hay un solo bloque ámbar con «no se registran ventas» y la explicación de que las mesas con reserva se habilitan durante la noche (8:30 p. m. – 3:00 a. m., hora de Colombia); junto al selector «Sin mesa» queda una ayuda breve («No hay una noche en curso.») o, en noche sin reservas, «No hay mesas con reserva confirmada para esta noche.».
- **Aviso de datos ficticios** (`DemoDataTag`): tono neutro (`textMuted`) en lugar de ámbar; las advertencias y errores operativos conservan su énfasis.

Pruebas: `test/app/shared_design_test.dart` (barra, promotor, Más, Admin, también 320 dp y 200 %) y `test/features/bar/bar_customer_test.dart`. Estado: `iOS SHARED CODE VALIDATED` cuando pase la suite; `iOS NATIVE VALIDATION PENDING`; en Android, la navegación de `1279f61` está capturada pero estos cambios aún no se han instalado ni revisado en el emulador. La QA funcional (formularios con teclado real, entrega de manillas, persistencia, noche activa) sigue pendiente.

### Defectos nativos a 320 dp / texto al 200 % (2026-10-14)

Observados en `Pixel_7` con densidad 540 (320 dp) y `font_scale` 2.0; evidencia en `Downloads\rumbaap-qa-diseno-2026-10-14\04-320-*.png`.

- **Sección activa fuera de vista** (`glass_tab_bar.dart`). Causa: cuando las secciones no caben, la fila se desplaza en horizontal, pero nada llevaba la seleccionada a la vista al cambiar de pantalla. Corrección: `GlassTabBar` pasa a `StatefulWidget` con su `ScrollController` (liberado en `dispose`) y, al entrar, al cambiar la sección seleccionada o al cambiar el ancho disponible o la escala de texto, desplaza **solo esa fila** hasta dejar la sección entera a la vista (animación de 250 ms; sin animación si el sistema las desactiva). Calcula el destino con la medida fija de cada sección y no usa `Scrollable.ensureVisible`, que movería también los contenedores que la rodean. Sin cambio de selección o de medidas no vuelve a desplazar, así que el desplazamiento manual se respeta y no hay bucles de reconstrucción. Etiquetas, claves, semántica, callbacks, vidrio y relleno del plano no cambian.
- **Etiqueta de búsqueda cortada en Actividad** (`activity_log.dart`). Causa: era una etiqueta de una sola línea («Buscar por mesa, ID de reserva o titular»), que se corta con texto ampliado. Corrección: etiqueta «Buscar» y los criterios en el texto de ayuda («Por mesa, ID de reserva o titular», hasta 3 líneas). El filtro busca lo mismo. El campo de búsqueda de Personal (`staff_page.dart`) reprodujo el mismo recorte («Buscar por m…») en `Pixel_7` a 320 dp / 200 % y se corrigió con el mismo patrón («Buscar» + ayuda «Por mesa, titular o ID de reserva»); sus callbacks no cambian.
- **«+» de Personas.** Aclarado: no era un defecto del control. El fallo de la primera prueba nativa vino de un selector mío (`Una entrada m*` coincidía también con «Una entrada menos», deshabilitado con cantidad 1). Con coincidencia exacta y bounds recientes, 1 → 2 → 1 funciona.
- Regresiones en `test/app/shared_design_test.dart`: la sección activa queda entera a la vista al pasar a «Más» (parcialmente cortada) en 320 dp / 200 %, el desplazamiento manual se respeta, y la etiqueta «Buscar» de Actividad no se corta. La primera falla sin la lógica de revelado.

---
name: rumbaap-flutter-ui
description: Criterio de UI/UX para Rumbaap (Flutter). Úsala en tareas que cambien pantallas, el mapa de mesas, el estilo Noche contemporánea, la navegación entre perfiles o la accesibilidad de la app. Aplica el diseño a las decisiones y al código vigentes, sin cambiar reglas de negocio.
---

# UI/UX de Rumbaap en Flutter

`CLAUDE.md` manda sobre esta skill. Si usas también `frontend-design`, esta skill la acota. En Rumbaap la dirección visual ya está elegida: no se proponen estéticas alternativas ni se toman riesgos de estilo no pedidos.

## 1. Antes de tocar nada

1. Lee solo las decisiones que afecten a la tarea y enlázalas en tu plan o informe, en lugar de copiar el contexto maestro:
   - Reglas de noches, reservas y mapa: `docs/business-rules/reservas-y-noches.md`.
   - Arquitectura, estado y versiones mínimas: `docs/decisions/0001-base-app-flutter.md`.
   - Perspectiva del administrador: `docs/decisions/0002-perspectiva-administrador-y-reservas.md`.
   - Dirección visual: `docs/decisions/0003-direccion-visual-noche-contemporanea.md`.
   - Mapa y vista del administrador: `docs/architecture/`.
   - Plan vigente: `docs/propuesta-siguiente-incremento.md`.
2. Distingue en lo que escribas:
   - **aprobado:** `VALIDATED` o ADR;
   - **propuesto:** `HYPOTHESIS`, o una propuesta tuya o de Juanmi todavía sin aprobar;
   - **pendiente:** `NOT DECIDED`.
   Lo que no esté aprobado no se implementa como si lo estuviera.
3. Textos visibles, comportamiento ante errores y qué ve cada perfil son decisiones de producto (CLAUDE.md §3). Si la tarea no los fija, pregunta.

## 2. Código y arquitectura

- Flutter/Dart con la estructura `lib/app` y `lib/features/<función>/{domain,data,presentation}`. Estado con `ChangeNotifier` y `ListenableBuilder`; estado local con `StatefulWidget`.
- No añadas paquetes, incluidas fuentes de Google Fonts o librerías de iconos o animación, ni cambies de framework. Usa el SDK, `Icons` y las fuentes disponibles.
- Reutiliza antes de crear:
  - **Tema:** `lib/app/app_theme.dart`.
  - **Estados de mesa** (etiqueta, icono y color): `table_presentation.dart`.
  - **Piezas comunes del mapa:** `venue_map_parts.dart`.
  - **Widgets del administrador:** `presentation/admin/admin_widgets.dart`.
  - **Datos de demostración:** `DemoReservationStore` y sus fakes de test (`test/features/reservations/fakes.dart`).
- Los colores y las medidas nuevas van como tokens con nombre en un único lugar, no dispersos por los widgets.

## 3. Noche contemporánea (ADR 0003)

- **Acabado:** grafito frío, líneas limpias, tapicería azul gris, metal sutil y luces azul/violeta. Sombras y brillos con moderación.
- **Un sistema coherente:** paleta, tipografía, escala de espaciado, superficies, iconos y jerarquía de acciones (una principal por pantalla; las destructivas, diferenciadas y con su confirmación aprobada).
- **Estados:** Disponible, En proceso, Pago VIP, Reservada, Ocupada y Sin información conservan su significado, siempre con color, icono y etiqueta. Nunca dependen solo del color.

## 4. El mapa

Se dibuja de forma nativa con `CustomPainter` (`venue_painter.dart`, `table_furniture_painter.dart`) sobre `venue_geometry.dart`. Nunca es una imagen o foto estática. Las referencias SVG o PNG son solo guía.

- **Disposición fija.** No cambian:
  - las 22 mesas, con sus IDs y centros;
  - la barra, el DJ, las escaleras y el acceso;
  - las mesas normales.
- **Única excepción: el dibujo VIP.**
  - El mobiliario VIP se dibuja a escala ×0,75 alrededor del mismo centro: 138 en lugar de 184.
  - La tarima visible pasa de 216 a 162 de alto, con el ancho y el borde superior (y = 20) intactos.
- **Accesos, capacidad y precios.** La caja lógica y táctil VIP sigue en 184. La capacidad y el precio no cambian: 20 personas y 2.000.000 COP de prepago por VIP.
- **Animación.** Se mantienen las luces del DJ y la animación de selección y estados. Se pausan fuera de pantalla y en segundo plano (`TickerMode`, ciclo de vida) y respetan `MediaQuery.disableAnimationsOf` (M4).
- **Un solo mapa y un solo almacén.** Un único componente de mapa y una única fuente de datos para todos los perfiles; nunca un mapa con datos o reglas propios. Cada perfil muestra solo sus acciones y los datos que tiene permitidos. La consulta pública (cliente) nunca muestra titulares, cédulas ni teléfonos.

## 5. Reglas que el diseño no toca

Una mejora visual no cambia:
- la confirmación de la mesa normal (R1, R13);
- el plazo de 10 min, que solo cuenta mientras la reserva está En proceso;
- la verificación del prepago VIP (R2) ni la confirmación directa del administrador (R7);
- la exclusividad por mesa y noche (R3);
- las noches de cada perfil (N5, N7, M1–M3);
- los permisos, el aforo ni los precios.

Si un diseño parece exigir cambiar algo de esto, detente y pregunta.

## 6. Verificación

- **Revisión de la interfaz:**
  - móvil pequeño (320×568), horizontal y texto al 200 %, sin desbordes;
  - áreas táctiles de al menos 48 dp;
  - contraste suficiente de texto y estados;
  - estados con etiqueta legible;
  - activación de cada acción desde el árbol semántico (`tester.semantics` o `SemanticsAction.tap`).
- **Tests de widgets** con `variant: TargetPlatformVariant.mobile()`, sin red, sin hora real (usa el `Clock` inyectable) y sin aleatoriedad.
- **Checks del código cambiado:** `dart format .`, `flutter analyze` y `flutter test`. Compila un APK debug cuando corresponda (CLAUDE.md §12).
- **En la app:** instala en el emulador, recorre la pantalla y compara las capturas con la referencia del brief. Di que es una comparación visual, no una validación de diseño.
- **iOS:** una captura de Android no acredita iOS. Usa las etiquetas de CLAUDE.md §9 (`iOS SHARED CODE VALIDATED`, `iOS NATIVE VALIDATION PENDING`).
- **Informe:** separa lo verificado mediante ejecución, lo inferido por inspección y lo pendiente. Sin commit hasta que haya aprobación humana.

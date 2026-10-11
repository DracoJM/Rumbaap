---
name: rumbaap-flutter-ui
description: Criterio de UI/UX para Rumbaap (Flutter). Úsala en tareas que cambien pantallas, el mapa de mesas, el estilo «Noche de cristal» v7, la navegación entre perfiles o la accesibilidad de la app. Aplica el diseño a las decisiones y al código vigentes, sin cambiar reglas de negocio.
---

# UI/UX de Rumbaap en Flutter

`CLAUDE.md` manda sobre esta skill. Si usas también `frontend-design`, esta skill la acota. En Rumbaap la dirección visual ya está elegida: no se proponen estéticas alternativas ni se toman riesgos de estilo no pedidos.

## 1. Antes de tocar nada

1. Lee solo las decisiones que afecten a la tarea y enlázalas en tu plan o informe, en lugar de copiar el contexto maestro:
   - Reglas de noches, reservas y mapa: `docs/business-rules/reservas-y-noches.md`.
   - Arquitectura, estado y versiones mínimas: `docs/decisions/0001-base-app-flutter.md`.
   - Perspectiva del administrador: `docs/decisions/0002-perspectiva-administrador-y-reservas.md`.
   - Dirección visual y mapa único: `docs/decisions/0004-mapa-unico-noche-de-cristal.md` (sustituye al ADR 0003).
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
  - **Tema:** `VenueTheme` del local (`lib/theme/`), `StatusColors` para estados, `NightNeutrals` para cristal y neutros, y `lib/app/app_theme.dart`.
  - **Estados de mesa** (etiqueta y color): `table_presentation.dart`; iconos en `presentation/map/status_icon.dart`.
  - **Piezas comunes del mapa:** `presentation/map/` (mapa, pantalla común, ficha y barra de cristal).
  - **Configuración del local** (mesas, zonas, distribución, condiciones): `lib/features/venues/`.
  - **Widgets del administrador:** `presentation/admin/admin_widgets.dart`.
  - **Datos de demostración:** `DemoReservationStore` y sus fakes de test (`test/features/reservations/fakes.dart`).
- Los colores y las medidas nuevas van como tokens con nombre en un único lugar, no dispersos por los widgets.

## 3. Noche de cristal v7 (ADR 0004)

- **Acabado:** fondo oscuro con luces ambientales suaves, superficies de cristal (desenfoque fijo, nunca animado), mobiliario y marca del `VenueTheme` del local. Regla 60-30-10: el color de marca no indica estados.
- **Un sistema coherente:** paleta, tipografía, escala de espaciado, superficies, iconos y jerarquía de acciones (una principal por ficha; las destructivas, diferenciadas y con su confirmación aprobada).
- **Estados:** Disponible, En proceso, Pendiente de pago (Pago VIP), Reservada, Ocupada y Sin información conservan su significado, siempre con color (`StatusColors`, comunes a todos los locales), icono y etiqueta. Nunca dependen solo del color.
- **Pendiente de desarrollo:** lo que no existe se muestra como «En desarrollo» y sin acción; nunca se simula una operación.

## 4. El mapa

Se dibuja de forma nativa con `CustomPainter` en `presentation/map/`, a partir del `CrystalLayout` del local. Nunca es una imagen o foto estática. Las referencias SVG o PNG son solo guía.

- **Un solo mapa.** `CrystalVenueMap` es el único componente gráfico del mapa, compartido por todas las perspectivas. No se copia ni se crea un mapa por perfil, y no se reintroduce el plano antiguo.
- **Configuración del local.** Mesas, zonas, posiciones, zonas táctiles, elementos del recinto, tema y condiciones vienen de `VenueConfig`. El componente no asume 22 mesas ni datos de Sagsa.
- **Sagsa (v7).** Lienzo de 400 × 622, 10 mesas por costado (x 30 y 370, desde y 140 cada 44, franja táctil de 58 × 44), tarima VIP de 192 × 68 con dos VIP. Se mantienen las proporciones VIP de v7; la reducción «un cuarto menos» del ADR 0003 ya no aplica.
- **Capacidad y precios.** Son condiciones del local (20 personas y 2.000.000 COP por VIP en Sagsa), no reglas generales.
- **Animación.** Un solo reloj y capas en `RepaintBoundary`; solo giro, escala, desplazamiento y opacidad. Se pausa fuera de pantalla y en segundo plano (`TickerMode`, ciclo de vida) y respeta `MediaQuery.disableAnimationsOf` (M4).
- **Un solo almacén y datos por local.** Una única fuente de datos por local para todos los perfiles; cada perfil muestra solo sus acciones y los datos permitidos. La consulta pública (cliente) nunca muestra titulares, cédulas ni teléfonos.

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

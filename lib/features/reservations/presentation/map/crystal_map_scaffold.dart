import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../../../../theme/venue_theme.dart';
import '../../../venues/venue_config.dart';
import '../../domain/night_schedule.dart';
import '../../domain/venue_table.dart';
import '../table_picker.dart';
import '../table_presentation.dart';
import '../venue_map_controller.dart';
import '../venue_map_parts.dart';
import 'crystal_venue_map.dart';
import 'map_clock.dart';
import 'status_icon.dart';

/// Pantalla «Noche de cristal» v7 común a todas las perspectivas: fondo
/// ambiental, noche, resumen por estado con filtro, plano y, encima, la ficha
/// y la barra que aporta cada perspectiva.
///
/// Es solo presentación: lee del [VenueMapController] que recibe y no sabe
/// de reservas ni de permisos.
class CrystalMapScaffold extends StatefulWidget {
  const CrystalMapScaffold({
    super.key,
    required this.controller,
    required this.demoLabel,
    required this.sheetBuilder,
    this.bottomBar,
    this.body,
    this.showNight = true,
  });

  /// Ancho a partir del cual la ficha va en una columna lateral (tableta u
  /// horizontal), para que no tape el plano.
  static const sidePanelBreakpoint = 600.0;

  /// Ancho máximo del plano: escalarlo a todo el ancho de una tableta lo
  /// haría mucho más alto que la pantalla.
  static const maxMapWidth = 560.0;

  /// Alto máximo de la ficha en el teléfono, como parte de la pantalla: deja
  /// a la vista una franja del plano por la que desplazarse hasta su final.
  static const sheetMaxShare = 0.42;

  final VenueMapController controller;

  /// Aviso de datos ficticios, siempre visible.
  final String demoLabel;

  /// Ficha de la mesa seleccionada; devuelve `null` si no hay ficha.
  final Widget? Function(BuildContext context, bool animate) sheetBuilder;
  final Widget? bottomBar;

  /// Sustituye al plano (por ejemplo, las listas del administrador). La
  /// noche sigue arriba.
  final Widget? body;

  /// Muestra la noche arriba; `false` en secciones que no dependen de ella
  /// (por ejemplo «Mis reservas», de todas las noches).
  final bool showNight;

  @override
  State<CrystalMapScaffold> createState() => _CrystalMapScaffoldState();
}

class _CrystalMapScaffoldState extends State<CrystalMapScaffold>
    with SingleTickerProviderStateMixin {
  final _clock = MapClock();
  late final _ticker = createTicker(_clock.tick);
  TableMapStatus? _filter;
  int _lastDelta = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con «reducir movimiento» del sistema no hay ticker: cero fotogramas.
    // TickerMode lo pausa cuando otra pantalla tapa esta.
    final animate = !MediaQuery.disableAnimationsOf(context);
    _clock.animating = animate;
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  TableMapStatus _statusOf(VenueTable table) => TableMapStatus.from(
    widget.controller.availabilityOf(table.id),
    table: table,
  );

  void _showNight(int delta) {
    _lastDelta = delta;
    widget.controller.showAdjacentNight(delta);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _layout(context),
    );
  }

  Widget _layout(BuildContext context) {
    final c = widget.controller;
    final venue = VenueScope.of(context).venue;
    final counts = <TableMapStatus, int>{
      for (final status in TableMapStatus.values)
        status: venue.tables.where((t) => _statusOf(t) == status).length,
    }..removeWhere((_, n) => n == 0);
    // Un filtro sin mesas en la noche mostrada no tiene chip para quitarlo.
    final filter = counts.containsKey(_filter) ? _filter : null;
    final size = MediaQuery.sizeOf(context);
    final wide =
        size.width >= CrystalMapScaffold.sidePanelBreakpoint ||
        size.width > size.height;
    final sheet = widget.sheetBuilder(context, _clock.animating);

    // La fila superior (volver, aviso y «Buscar mesa») siempre queda fija y a
    // la vista: es el acceso a la alternativa accesible al plano.
    final topBar = _TopBar(
      demoLabel: widget.demoLabel,
      onPickTable: widget.body == null
          ? () => showTableSearch(context, c)
          : null,
    );
    final headerItems = <Widget>[
      if (widget.showNight)
        _NightNavigator(
          night: c.night,
          venueNow: c.venueNow,
          canGoBack: c.hasPreviousNight,
          canGoForward: c.hasNextNight,
          direction: _lastDelta,
          animate: _clock.animating,
          onChange: _showNight,
        ),
      if (widget.body == null)
        _StatusSummary(
          counts: counts,
          filter: filter,
          onToggle: (s) => setState(() => _filter = filter == s ? null : s),
        ),
      if (c.availabilityStatus == LoadStatus.failed)
        InlineError(onRetry: c.retry),
    ];
    // Con texto grande la cabecera crece mucho. Sobre el plano, se desplaza
    // junto con él en lugar de quedar fija y tapar media pantalla; sobre las
    // listas ocupa como mucho la mitad del alto y se desplaza.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final headerInMap = largeText && widget.body == null;
    final header = <Widget>[
      if (headerInMap)
        topBar
      else
        ConstrainedBox(
          // Sobre las listas, con texto grande, toda la cabecera cabe en el
          // 40 % del alto y se desplaza, para dejar sitio a la lista.
          constraints: BoxConstraints(
            maxHeight: size.height * (widget.body != null ? 0.4 : 0.5),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [topBar, ...headerItems],
            ),
          ),
        ),
    ];

    Widget mapArea(double bottomPadding) {
      final body = widget.body;
      if (body != null) return body;
      return Stack(
        children: [
          SingleChildScrollView(
            // Deja ver el final del plano por encima de la ficha.
            padding: EdgeInsets.only(bottom: bottomPadding + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (headerInMap) ...headerItems,
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: CrystalMapScaffold.maxMapWidth,
                      ),
                      child: CrystalVenueMap(
                        statusOf: _statusOf,
                        selectedTableId: c.selectedTableId,
                        onTableTap: c.toggleTable,
                        clock: _clock,
                        isDimmed: filter == null
                            ? null
                            : (t) => _statusOf(t) != filter,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (c.availabilityStatus == LoadStatus.loading || c.isRefreshing)
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: LoadingPill()),
            ),
        ],
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bar = widget.bottomBar;
    final background = VenueTheme.of(context).background;

    if (wide) {
      return Scaffold(
        backgroundColor: background,
        body: Stack(
          children: [
            Positioned.fill(child: AmbientBackground(clock: _clock)),
            SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...header,
                        Expanded(child: mapArea(0)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: (size.width * 0.45).clamp(240, 380),
                    child: _NoStretch(
                      child: BackdropGroup(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(child: sheet),
                              ),
                              if (bar != null) ...[
                                const SizedBox(height: 8),
                                // Con texto grande la barra puede necesitar
                                // más alto del que queda: se desplaza.
                                Flexible(
                                  child: SingleChildScrollView(child: bar),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Ficha y barra van en la ranura inferior con extendBody: el plano se ve
    // detrás del cristal, su relleno inferior las deja libres y los avisos
    // flotantes aparecen encima en lugar de taparlas.
    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: AmbientBackground(clock: _clock)),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...header,
                Expanded(
                  child: Builder(
                    builder: (context) =>
                        mapArea(MediaQuery.paddingOf(context).bottom),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: sheet == null && bar == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              // Ficha y barra comparten una sola lectura del fondo.
              child: _NoStretch(
                child: BackdropGroup(
                  // Con texto grande la barra crece: la ficha cede el alto que
                  // falte y se desplaza dentro de su espacio, así ficha y barra
                  // nunca tapan toda la pantalla.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: size.height * 0.8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (sheet != null)
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    size.height *
                                    CrystalMapScaffold.sheetMaxShare,
                              ),
                              child: SingleChildScrollView(child: sheet),
                            ),
                          ),
                        if (bar != null) ...[
                          const SizedBox(height: 8),
                          // Con texto muy grande la barra puede necesitar más
                          // alto del disponible: entonces se desplaza.
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: bar,
                            ),
                          ),
                        ],
                        SizedBox(height: bottomInset > 0 ? bottomInset : 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Sin estiramiento de overscroll para el contenido de cristal.
///
/// En Android 12+ el estiramiento envuelve el contenido desplazable en una
/// capa con filtro de imagen; un [BackdropFilter] dentro de esa capa pierde
/// el fondo y el cristal se ve transparente mientras dura el estiramiento
/// (al arrastrar la ficha hasta su borde). El desplazamiento se conserva; solo
/// se quita el efecto de borde.
class _NoStretch extends StatelessWidget {
  const _NoStretch({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
    child: child,
  );
}

/// Volver, aviso de datos ficticios y búsqueda accesible de mesas.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.demoLabel, required this.onPickTable});

  final String demoLabel;
  final VoidCallback? onPickTable;

  @override
  Widget build(BuildContext context) {
    final glass = IconButton.styleFrom(
      foregroundColor: NightNeutrals.white,
      backgroundColor: NightNeutrals.glass(0.08),
      side: BorderSide(color: NightNeutrals.glass(0.14)),
      fixedSize: const Size.square(40),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) BackButton(style: glass),
          const SizedBox(width: 4),
          Expanded(child: DemoDataTag(text: demoLabel)),
          if (onPickTable != null)
            IconButton(
              tooltip: 'Buscar mesa',
              style: glass,
              onPressed: onPickTable,
              icon: const Icon(Icons.search_rounded, size: 22),
            ),
        ],
      ),
    );
  }
}

/// Noche mostrada con flechas; deslizar sobre la fecha también cambia. Pasa
/// de una noche a la siguiente y, al terminar el fin de semana, al
/// siguiente.
class _NightNavigator extends StatefulWidget {
  const _NightNavigator({
    required this.night,
    required this.venueNow,
    required this.canGoBack,
    required this.canGoForward,
    required this.direction,
    required this.animate,
    required this.onChange,
  });

  final Night? night;
  final DateTime venueNow;
  final bool canGoBack;
  final bool canGoForward;
  final int direction;
  final bool animate;
  final ValueChanged<int> onChange;

  @override
  State<_NightNavigator> createState() => _NightNavigatorState();
}

class _NightNavigatorState extends State<_NightNavigator> {
  static const _swipeThreshold = 30.0;
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final label = night == null
        ? 'Sin noches'
        : night.isInProgress(widget.venueNow)
        ? '${night.shortLabel} · En curso'
        : night.shortLabel;
    final sub = night == null
        ? 'No hay noches para consultar en este fin de semana.'
        : '${night.scheduleLabel} (hora de Colombia)';
    final current = ValueKey(night?.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Noche anterior',
            onPressed: widget.canGoBack ? () => widget.onChange(-1) : null,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _drag = 0,
              onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
              onHorizontalDragEnd: (_) {
                if (_drag < -_swipeThreshold && widget.canGoForward) {
                  widget.onChange(1);
                }
                if (_drag > _swipeThreshold && widget.canGoBack) {
                  widget.onChange(-1);
                }
                _drag = 0;
              },
              child: Semantics(
                liveRegion: true,
                label: '$label, $sub',
                excludeSemantics: true,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: widget.animate
                        ? const Duration(milliseconds: 180)
                        : Duration.zero,
                    transitionBuilder: (child, animation) {
                      // La noche nueva entra por el lado hacia el que se
                      // avanza y la anterior sale por el contrario.
                      final incoming = child.key == current;
                      final sign = incoming
                          ? widget.direction
                          : -widget.direction;
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: Offset(0.12 * sign, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      key: current,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: NightNeutrals.white,
                          ),
                        ),
                        Text(
                          sub,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: NightNeutrals.glass(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Noche siguiente',
            onPressed: widget.canGoForward ? () => widget.onChange(1) : null,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: NightNeutrals.white,
        disabledForegroundColor: NightNeutrals.glass(0.3),
        backgroundColor: NightNeutrals.glass(0.08),
        disabledBackgroundColor: NightNeutrals.glass(0.03),
        side: BorderSide(color: NightNeutrals.glass(0.14)),
        fixedSize: const Size.square(40),
      ),
    );
  }
}

/// Conteo de mesas por estado. Tocar un estado deja resaltadas solo esas
/// mesas; tocarlo otra vez quita el filtro.
class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.counts,
    required this.filter,
    required this.onToggle,
  });

  final Map<TableMapStatus, int> counts;
  final TableMapStatus? filter;
  final ValueChanged<TableMapStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    return Semantics(
      container: true,
      label: 'Resumen de la noche, toca un estado para filtrar',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final MapEntry(key: status, value: n) in counts.entries)
              _StatusChip(
                key: ValueKey('status-chip-${status.name}'),
                status: status,
                count: n,
                color: status.colorIn(colors),
                pressed: status == filter,
                onTap: () => onToggle(status),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.status,
    required this.count,
    required this.color,
    required this.pressed,
    required this.onTap,
  });

  final TableMapStatus status;
  final int count;
  final Color color;
  final bool pressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: pressed,
      label: '$count ${status.summaryLabel}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Franja táctil de 48 de alto alrededor del chip visible.
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: NightNeutrals.glass(pressed ? 0.18 : 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: pressed ? color : NightNeutrals.glass(0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusIcon(status: status, size: 17),
                const SizedBox(width: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$count ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: NightNeutrals.white,
                        ),
                      ),
                      TextSpan(text: status.summaryLabel),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: NightNeutrals.glass(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

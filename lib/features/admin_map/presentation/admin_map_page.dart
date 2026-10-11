import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../theme/night_neutrals.dart';
import '../../../theme/status_colors.dart';
import '../../../theme/venue_theme.dart';
import '../domain/admin_table_status.dart';
import 'admin_map_controller.dart';
import 'admin_map_labels.dart';
import 'crystal_venue_map.dart';
import 'glass_tab_bar.dart';
import 'map_clock.dart';
import 'status_icon.dart';
import 'table_sheet.dart';

/// Mapa del administrador («Noche de cristal» v7) con datos ficticios.
class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  /// Ancho máximo del plano: en tabletas, escalarlo a todo el ancho lo
  /// haría mucho más alto que la pantalla.
  static const maxMapWidth = 560.0;

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage>
    with SingleTickerProviderStateMixin {
  final _controller = AdminMapController();
  final _clock = MapClock();
  late final Ticker _ticker = createTicker(_clock.tick);
  double _overlayHeight = 0;
  int _lastDelta = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con «reducir movimiento» del sistema no hay ticker: cero fotogramas.
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
    _controller.dispose();
    super.dispose();
  }

  void _showNight(int delta) {
    _lastDelta = delta;
    _controller.showNight(delta);
  }

  @override
  Widget build(BuildContext context) {
    final venue = VenueTheme.of(context);
    return Scaffold(
      backgroundColor: venue.background,
      body: Stack(
        children: [
          Positioned.fill(child: AmbientBackground(clock: _clock)),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _layout(context),
          ),
        ],
      ),
    );
  }

  Widget _layout(BuildContext context) {
    final c = _controller;
    final animate = _clock.animating;
    final table = c.selectedTable;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NightNavigator(
                date: c.nightDate,
                offset: c.nightOffset,
                direction: _lastDelta,
                animate: animate,
                onChange: _showNight,
              ),
              _StatusSummary(
                counts: c.counts,
                filter: c.filter,
                onToggle: c.toggleFilter,
              ),
              Expanded(
                child: SingleChildScrollView(
                  // Deja ver el final del plano por encima de la ficha.
                  padding: EdgeInsets.fromLTRB(12, 6, 12, _overlayHeight + 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AdminMapPage.maxMapWidth,
                      ),
                      child: CrystalVenueMap(controller: c, clock: _clock),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 0,
          child: _SizeReporter(
            onSize: (size) {
              if (!mounted) return;
              if ((size.height - _overlayHeight).abs() < 0.5) return;
              setState(() => _overlayHeight = size.height);
            },
            // Ficha y barra comparten una sola lectura del fondo.
            child: BackdropGroup(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TableSheet(
                        key: const ValueKey('table-sheet'),
                        table: table,
                        status: c.statusOf(table.id),
                        expanded: c.sheetExpanded,
                        animate: animate,
                        onToggle: c.toggleSheet,
                        // NOT DECIDED: destino de las acciones de la ficha.
                        onAction: () {},
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const GlassTabBar(),
                      ),
                      SizedBox(height: bottomInset > 0 ? bottomInset : 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fecha de la noche con flechas; deslizar sobre la fecha también cambia.
class _NightNavigator extends StatefulWidget {
  const _NightNavigator({
    required this.date,
    required this.offset,
    required this.direction,
    required this.animate,
    required this.onChange,
  });

  final DateTime date;
  final int offset;
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
    final label = NightLabels.short(widget.date);
    final current = ValueKey(widget.offset);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Noche anterior',
            onPressed: () => widget.onChange(-1),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _drag = 0,
              onHorizontalDragUpdate: (d) => _drag += d.delta.dx,
              onHorizontalDragEnd: (_) {
                if (_drag.abs() > _swipeThreshold) {
                  widget.onChange(_drag < 0 ? 1 : -1);
                }
                _drag = 0;
              },
              child: Semantics(
                liveRegion: true,
                label: '$label, ${NightLabels.opening}',
                excludeSemantics: true,
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: widget.animate
                        ? const Duration(milliseconds: 180)
                        : Duration.zero,
                    transitionBuilder: (child, animation) {
                      // La fecha nueva entra por el lado hacia el que se
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
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: NightNeutrals.white,
                          ),
                        ),
                        Text(
                          NightLabels.opening,
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
            onPressed: () => widget.onChange(1),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: NightNeutrals.white,
        backgroundColor: NightNeutrals.glass(0.08),
        side: BorderSide(color: NightNeutrals.glass(0.14)),
        fixedSize: const Size.square(38),
        minimumSize: const Size.square(38),
        tapTargetSize: MaterialTapTargetSize.padded,
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

  final Map<AdminTableStatus, int> counts;
  final AdminTableStatus? filter;
  final ValueChanged<AdminTableStatus> onToggle;

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

  final AdminTableStatus status;
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
        // Franja táctil de 44 de alto alrededor del chip visible.
        child: Padding(
          padding: const EdgeInsets.only(right: 6, top: 5, bottom: 5),
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
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

/// Informa del tamaño de su hijo tras cada layout que lo cambie.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    final reported = size;
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(reported));
  }
}

import 'package:flutter/material.dart';

import '../../../theme/status_colors.dart';
import '../../../theme/venue_theme.dart';
import '../../reservations/domain/venue_table.dart';
import 'admin_map_controller.dart';
import 'admin_map_labels.dart';
import 'crystal_map_geometry.dart';
import 'crystal_table.dart';
import 'map_clock.dart';
import 'venue_light_painters.dart';
import 'venue_static_painters.dart';

/// Plano del administrador en su lienzo lógico de 400 × 622, escalado al
/// ancho disponible.
///
/// Las capas fijas y las animadas van separadas en RepaintBoundary: cada
/// fotograma solo repinta las capas de luces, nunca el plano ni las mesas.
class CrystalVenueMap extends StatelessWidget {
  const CrystalVenueMap({
    super.key,
    required this.controller,
    required this.clock,
  });

  final AdminMapController controller;
  final MapClock clock;

  @override
  Widget build(BuildContext context) {
    final theme = VenueTheme.of(context);
    final colors = StatusColors.of(context);
    Widget layer(CustomPainter painter) => Positioned.fill(
      child: RepaintBoundary(child: CustomPaint(painter: painter)),
    );

    final selected = controller.selectedTable;
    final selectedColor = controller.statusOf(selected.id).colorIn(colors);
    final ringSpec = FurnitureSpec.of(selected);
    final ringBox = (ringSpec.outer + 1.5) * 2 * 1.4;

    final canvas = SizedBox.fromSize(
      size: CrystalMapGeometry.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          layer(VenueBasePainter(theme)),
          layer(FloorLightsPainter(theme, clock)),
          layer(BarPainter(theme)),
          layer(BeamsPainter(theme, clock)),
          layer(BoothPainter(theme)),
          layer(BoothLightsPainter(theme, clock)),
          Positioned.fromRect(
            rect: Rect.fromCenter(
              center: CrystalMapGeometry.centerOf(selected),
              width: ringBox,
              height: ringBox,
            ),
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SelectionRingPainter(
                    clock: clock,
                    color: selectedColor,
                    spec: ringSpec,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final table in VenueTables.all)
                    Positioned.fromRect(
                      rect: CrystalMapGeometry.hitRectOf(table),
                      child: CrystalTable(
                        key: ValueKey('crystal-table-${table.id}'),
                        table: table,
                        status: controller.statusOf(table.id),
                        color: controller.statusOf(table.id).colorIn(colors),
                        selected: table.id == selected.id,
                        dimmed: controller.isDimmed(table.id),
                        animate: clock.animating,
                        onTap: () => controller.selectTable(table.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label:
          'Mapa de reservas: 20 mesas, 2 VIP, barra central, pista y '
          'cabina de DJ',
      child: AspectRatio(
        aspectRatio:
            CrystalMapGeometry.size.width / CrystalMapGeometry.size.height,
        child: FittedBox(child: canvas),
      ),
    );
  }
}

/// Tres manchas de luz que se desplazan lentamente detrás de la pantalla.
/// Cada una es una imagen fija en su RepaintBoundary; solo cambia su
/// transformación.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.clock});

  final MapClock clock;

  @override
  Widget build(BuildContext context) {
    final theme = VenueTheme.of(context);
    final amb = theme.ambientIntensity;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth * 1.4;
          final h = constraints.maxHeight * 1.4;
          final origin = Offset(
            -constraints.maxWidth * 0.2,
            -constraints.maxHeight * 0.2,
          );
          return ClipRect(
            child: Stack(
              children: [
                _blob(
                  rect: Rect.fromLTWH(0.05 * w, 0.1 * h, 0.6 * w, 0.3 * h),
                  origin: origin,
                  color: theme.primary.withValues(alpha: amb),
                  period: 24,
                  drift: const Offset(0.1, 0.05),
                  scaleTo: 1.08,
                  reverse: false,
                ),
                _blob(
                  rect: Rect.fromLTWH(0.5 * w, 0.45 * h, 0.5 * w, 0.28 * h),
                  origin: origin,
                  color: theme.tertiary.withValues(alpha: amb * 0.6),
                  period: 30,
                  drift: const Offset(-0.12, -0.06),
                  scaleTo: 0.94,
                  reverse: false,
                ),
                _blob(
                  rect: Rect.fromLTWH(0.2 * w, 0.65 * h, 0.7 * w, 0.3 * h),
                  origin: origin,
                  color: theme.secondary.withValues(alpha: amb * 0.8),
                  period: 34,
                  drift: const Offset(0.1, 0.05),
                  scaleTo: 1.08,
                  reverse: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _blob({
    required Rect rect,
    required Offset origin,
    required Color color,
    required double period,
    required Offset drift,
    required double scaleTo,
    required bool reverse,
  }) {
    final shifted = rect.shift(origin);
    return Positioned.fromRect(
      rect: shifted,
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, child) {
          var p = clock.animating ? pingPong(clock.seconds, period) : 0.0;
          if (reverse && clock.animating) p = 1 - p;
          final scale = 1 + (scaleTo - 1) * p;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(
                drift.dx * rect.width * p,
                drift.dy * rect.height * p,
                0,
                1,
              )
              ..scaleByDouble(scale, scale, 1, 1),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: CustomPaint(painter: _BlobPainter(color)),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Degradado circular estirado a la elipse de la caja.
    final r = size.shortestSide / 2;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 2 / r, size.height / 2 / r);
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawOval(
      circle,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(circle),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color;
}

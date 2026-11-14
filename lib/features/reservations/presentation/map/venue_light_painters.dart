import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/venue_theme.dart';
import 'canvas_helpers.dart';
import 'crystal_layout.dart';
import 'map_clock.dart';
import 'venue_static_painters.dart';

/// Capas animadas del plano. Solo cambian giro, escala, desplazamiento u
/// opacidad de formas sencillas, sin desenfoques; repintan con [MapClock]
/// sin reconstruir widgets. Sin animación muestran un estado fijo.
abstract class _LightPainter extends CustomPainter {
  _LightPainter(this.theme, this.layout, this.clock) : super(repaint: clock);

  final VenueTheme theme;
  final CrystalLayout layout;
  final MapClock clock;

  double get t => clock.seconds;
  bool get on => clock.animating;

  @override
  bool shouldRepaint(covariant _LightPainter old) =>
      old.theme != theme || old.layout != layout || old.clock != clock;
}

/// Conos de los bafles, destellos de las esquinas y baldosas de la pista.
class FloorLightsPainter extends _LightPainter {
  FloorLightsPainter(super.theme, super.layout, super.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final th = theme;
    if (layout.cornerSpeakers) _corners(canvas);
    if (layout.danceFloor == null || !on) return;
    final peak = th.lightIntensity * 0.35;
    for (var k = 0; k < layout.litTiles.length; k++) {
      final (row, col) = layout.litTiles[k];
      final alpha = peak * pingPong(t + k * 0.6, 2.4);
      if (alpha < 0.002) continue;
      final color = k % 3 == 0 ? th.secondary : th.primary;
      canvas.drawRRect(
        tileRect(layout, row, col),
        fill(color.withValues(alpha: alpha)),
      );
    }
  }

  void _corners(Canvas canvas) {
    final th = theme;
    final cone = on ? 1 + 0.06 * pingPong(t, 0.48) : 1.0;
    for (final mirrored in const [false, true]) {
      canvas.save();
      if (mirrored) {
        canvas.translate(layout.size.width, 0);
        canvas.scale(-1, 1);
      }
      canvas.save();
      canvas.translate(40, 61);
      canvas.scale(cone);
      canvas.drawCircle(Offset.zero, 10.5, fill(NightNeutrals.speakerCone));
      canvas.drawCircle(
        Offset.zero,
        10.5,
        stroke(NightNeutrals.glass(0.25), 1),
      );
      canvas.drawCircle(
        Offset.zero,
        6.5,
        stroke(th.primary.withValues(alpha: 0.45), 1),
      );
      canvas.drawCircle(
        Offset.zero,
        2.6,
        fill(th.primary.withValues(alpha: 0.8)),
      );
      canvas.restore();
      for (var i = 0; i < 2; i++) {
        final glow = on ? 0.2 + 0.4 * pingPong(t - i * 0.8, 0.8) : 0.4;
        canvas.drawCircle(
          Offset(72.0 + i * 10, 34.0 + i * 14),
          1.4,
          fill((i == 0 ? th.vip : th.primary).withValues(alpha: glow)),
        );
      }
      canvas.restore();
    }
  }
}

/// Dos haces de luz que salen de la cabina del DJ.
class BeamsPainter extends _LightPainter {
  BeamsPainter(super.theme, super.layout, super.clock);

  static const _deg = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final booth = layout.djBooth;
    if (booth == null) return;
    final left = on ? -18 + 24 * pingPong(t, 10) : 0.0;
    final right = on ? 18 - 24 * pingPong(t, 9) : 0.0;
    // Salen del borde superior de la cabina y suben 212 unidades.
    final base = Offset(booth.center.dx, booth.top + 2);
    Offset at(double dx, double dy) => base.translate(dx, dy);
    _beam(
      canvas,
      [at(-30, 0), at(-90, -212), at(-28, -212)],
      at(-59, 0),
      left * _deg,
      theme.primary,
    );
    _beam(
      canvas,
      [at(30, 0), at(28, -212), at(90, -212)],
      at(59, 0),
      right * _deg,
      theme.secondary,
    );
  }

  void _beam(
    Canvas canvas,
    List<Offset> points,
    Offset pivot,
    double angle,
    Color color,
  ) {
    final path = Path()..addPolygon(points, true);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: theme.lightIntensity),
          ],
        ).createShader(path.getBounds()),
    );
    canvas.restore();
  }
}

/// Tira LED, platos girando y ecualizador de la cabina.
class BoothLightsPainter extends _LightPainter {
  BoothLightsPainter(super.theme, super.layout, super.clock);

  static const _eqDurations = [0.8, 0.6, 0.95, 0.7, 0.85];
  static const _eqDelays = [0.0, 0.35, 0.15, 0.5, 0.25];

  @override
  void paint(Canvas canvas, Size size) {
    final th = theme;
    final booth = layout.djBooth;
    if (booth == null) return;
    _led(canvas, booth);

    final spin = on ? loopPhase(t, 1.8) * 2 * math.pi : 0.0;
    for (final center in platterCenters(booth)) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(spin);
      canvas.drawCircle(Offset.zero, 11, fill(NightNeutrals.platterVinyl));
      final groove = stroke(NightNeutrals.glass(0.08), 1);
      canvas.drawCircle(Offset.zero, 8.2, groove);
      canvas.drawCircle(Offset.zero, 5.6, groove);
      canvas.drawCircle(Offset.zero, 3.2, fill(th.primary));
      canvas.drawRRect(
        rounded(const Rect.fromLTWH(-0.8, -10, 1.6, 4.4), 0.8),
        fill(NightNeutrals.white),
      );
      canvas.restore();
    }

    for (var i = 0; i < 5; i++) {
      final scale = on
          ? 0.25 + 0.75 * pingPong(t - _eqDelays[i], _eqDurations[i])
          : 0.6;
      final height = 20 * scale;
      canvas.drawRRect(
        rounded(
          Rect.fromLTWH(
            booth.center.dx - 9.5 + i * 4,
            booth.top + 36 - height,
            2.6,
            height,
          ),
          1.2,
        ),
        fill(Color.lerp(th.primary, th.secondary, i / 4)!),
      );
    }
  }

  void _led(Canvas canvas, Rect booth) {
    final start = booth.left + 10;
    final end = booth.right - 10;
    final y = booth.top + 1;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          theme.primary.withValues(alpha: 0.8),
          theme.secondary.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromLTRB(start, y - 1, end, y + 1));
    // Guiones de 20 con huecos de 4 que avanzan 20 unidades por segundo.
    final shift = on ? (t * 20) % 24 : 0.0;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(start - 1, y - 3, end + 1, y + 3));
    for (var x = start - 24 + shift; x < end; x += 24) {
      final a = math.max(x, start);
      final b = math.min(x + 20, end);
      if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
    }
    canvas.restore();
  }
}

/// Anillo que late alrededor de la mesa seleccionada, centrado en el origen.
class SelectionRingPainter extends CustomPainter {
  SelectionRingPainter({
    required this.clock,
    required this.color,
    required this.spec,
  }) : super(repaint: clock);

  final MapClock clock;
  final Color color;
  final FurnitureSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    var scale = 1.0;
    var opacity = 1.0;
    if (clock.animating) {
      final p = Curves.easeOut.transform(loopPhase(clock.seconds, 1.8));
      scale = 0.95 + 0.4 * p;
      opacity = 0.9 * (1 - p);
    }
    if (opacity <= 0.002) return;
    final half = spec.outer + 1.5;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.drawRRect(
      rounded(Rect.fromLTRB(-half, -half, half, half), spec.corner + 3),
      stroke(color.withValues(alpha: opacity), 1.6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SelectionRingPainter old) =>
      old.clock != clock || old.color != color || old.spec != spec;
}

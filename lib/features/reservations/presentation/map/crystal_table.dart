import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/venue_theme.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';
import 'canvas_helpers.dart';
import 'crystal_layout.dart';
import 'status_icon.dart';

/// Mesa del plano: sofá en U, disco de cristal, número e icono de estado.
/// Su tamaño es la zona táctil completa ([TablePlacement.hitRect]);
/// el dibujo puede sobresalir de ella.
class CrystalTable extends StatelessWidget {
  const CrystalTable({
    super.key,
    required this.table,
    required this.placement,
    required this.status,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.animate,
    required this.onTap,
  });

  final VenueTable table;
  final TablePlacement placement;
  final TableMapStatus status;
  final Color color;
  final bool selected;
  final bool dimmed;
  final bool animate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hit = placement.hitRect;
    final center = placement.center - hit.topLeft;
    return Semantics(
      button: true,
      selected: selected,
      label: '${table.displayName}, ${status.label}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: dimmed ? 0.2 : 1,
          duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
          child: CustomPaint(
            size: hit.size,
            painter: CrystalTablePainter(
              table: table,
              placement: placement,
              status: status,
              color: color,
              center: center,
              theme: VenueTheme.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class CrystalTablePainter extends CustomPainter {
  const CrystalTablePainter({
    required this.table,
    required this.placement,
    required this.status,
    required this.color,
    required this.center,
    required this.theme,
  });

  final VenueTable table;
  final TablePlacement placement;
  final TableMapStatus status;
  final Color color;
  final Offset center;
  final VenueTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final spec = FurnitureSpec.of(table);
    final paths = _FurniturePaths.of(spec);
    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.save();
    canvas.rotate(placement.rotation);
    _furniture(canvas, spec, paths);
    canvas.restore();

    final d = spec.disc;
    final disc = Rect.fromCircle(center: Offset.zero, radius: d);
    canvas.drawCircle(
      Offset.zero,
      d,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.5,
          colors: [
            NightNeutrals.glass(0.34),
            NightNeutrals.discMid,
            NightNeutrals.discEdge,
          ],
          stops: const [0, 0.6, 1],
        ).createShader(disc),
    );
    canvas.drawCircle(Offset.zero, d, stroke(color, 1.6));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-d * 0.3, -d * 0.42),
        width: d * 0.76,
        height: d * 0.4,
      ),
      fill(NightNeutrals.glass(0.22)),
    );
    paintLabel(
      canvas,
      placement.label,
      x: 0,
      baseline: table.isVip ? 2.5 : 3,
      size: table.isVip ? 7 : 8.6,
      weight: FontWeight.w700,
      color: NightNeutrals.white,
    );

    canvas.translate(spec.badgeGap * placement.badgeSide, 0);
    canvas.scale(0.82);
    paintStatusBadge(canvas, status, color);
    canvas.restore();
  }

  void _furniture(Canvas canvas, FurnitureSpec spec, _FurniturePaths paths) {
    final t = theme;
    final vip = table.isVip;
    canvas.drawPath(
      paths.back,
      stroke(
        vip ? t.vip.withValues(alpha: 0.4) : t.furnitureBack,
        spec.backWidth,
        cap: StrokeCap.round,
      )..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      paths.backEdge,
      stroke(NightNeutrals.glass(0.22), 0.6, cap: StrokeCap.round),
    );
    final so = spec.seatOffset;
    final seat = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.seatWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: vip
            ? [
                mix(t.vip, 0.8, NightNeutrals.white),
                mix(t.vip, 0.78, NightNeutrals.black),
                mix(t.vip, 0.45, NightNeutrals.black),
              ]
            : [
                mix(t.furniture, 0.72, NightNeutrals.white),
                t.furniture,
                mix(t.furniture, 0.62, NightNeutrals.black),
              ],
        stops: vip ? const [0, 0.5, 1] : const [0, 0.55, 1],
      ).createShader(Rect.fromLTRB(-so, -so, spec.armLength, so));
    canvas.drawPath(paths.cushions, seat);
    canvas.drawPath(paths.cushionEdges, stroke(NightNeutrals.glass(0.2), 0.5));
  }

  @override
  bool shouldRepaint(CrystalTablePainter old) =>
      old.status != status ||
      old.color != color ||
      old.table != table ||
      old.placement != placement ||
      old.center != center ||
      old.theme != theme;
}

/// Trazos del mueble en orientación base (abertura hacia +x), calculados
/// una vez por tipo de mesa.
class _FurniturePaths {
  _FurniturePaths(FurnitureSpec s)
    : back = _u(s.backOffset, s.armLength, s.corner + 2),
      backEdge = _u(
        s.backOffset + s.backWidth / 2 - 0.3,
        s.armLength,
        s.corner + 2.6,
      ),
      cushions = _dashed(_u(s.seatOffset, s.armLength, s.corner), s.cushions),
      cushionEdges = _dashed(
        _u(s.seatOffset + s.seatWidth / 2 - 0.6, s.armLength, s.corner + 0.6),
        s.cushions,
      );

  final Path back;
  final Path backEdge;
  final Path cushions;
  final Path cushionEdges;

  static final _cache = <FurnitureSpec, _FurniturePaths>{};

  static _FurniturePaths of(FurnitureSpec spec) =>
      _cache.putIfAbsent(spec, () => _FurniturePaths(spec));

  /// U rectangular con esquinas redondeadas, abierta hacia +x.
  static Path _u(double o, double arm, double c) => Path()
    ..moveTo(arm, -o)
    ..lineTo(-o + c, -o)
    ..quadraticBezierTo(-o, -o, -o, -o + c)
    ..lineTo(-o, o - c)
    ..quadraticBezierTo(-o, o, -o + c, o)
    ..lineTo(arm, o);

  /// Divide el trazo en [n] cojines iguales separados por una junta.
  static Path _dashed(Path path, int n) {
    final out = Path();
    for (final metric in path.computeMetrics()) {
      final unit = metric.length / 100;
      const joint = 1.6;
      final segment = (100 - joint * (n - 1)) / n;
      for (var i = 0; i < n; i++) {
        final start = i * (segment + joint) * unit;
        out.addPath(
          metric.extractPath(start, start + segment * unit),
          Offset.zero,
        );
      }
    }
    return out;
  }
}

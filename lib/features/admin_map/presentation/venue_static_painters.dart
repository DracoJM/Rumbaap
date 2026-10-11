import 'package:flutter/rendering.dart';

import '../../../theme/night_neutrals.dart';
import '../../../theme/venue_theme.dart';
import 'canvas_helpers.dart';
import 'crystal_map_geometry.dart';

typedef _G = CrystalMapGeometry;

/// Capas fijas del plano. Se dibujan en el lienzo lógico de 400 × 622 y van
/// cada una en su RepaintBoundary: nunca repintan por las animaciones.
abstract class _VenuePainter extends CustomPainter {
  const _VenuePainter(this.theme);

  final VenueTheme theme;

  @override
  bool shouldRepaint(covariant _VenuePainter old) => old.theme != theme;
}

/// Fondo, tarima VIP, esquinas, paredes y suelo de la pista.
class VenueBasePainter extends _VenuePainter {
  const VenueBasePainter(super.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final w = _G.size.width;
    final h = _G.size.height;
    final outline = rounded(Rect.fromLTWH(1, 1, w - 2, h - 2), 18);
    canvas.drawRRect(outline, fill(t.background.withValues(alpha: 0.7)));
    canvas.save();
    canvas.clipRRect(outline);
    final grid = stroke(NightNeutrals.glass(0.035), 0.5);
    for (var x = 0.25; x < w; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = 0.25; y < h; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
    canvas.restore();
    canvas.drawRRect(outline, stroke(NightNeutrals.glass(0.1), 1));

    _vip(canvas);
    _corner(canvas);
    canvas.save();
    canvas.translate(w, 0);
    canvas.scale(-1, 1);
    _corner(canvas);
    canvas.restore();

    // Paredes laterales con luz: marca primaria al oeste, secundaria al este.
    canvas.drawLine(
      const Offset(6, 116),
      const Offset(6, 560),
      stroke(t.primary.withValues(alpha: 0.22), 1),
    );
    canvas.drawLine(
      const Offset(394, 116),
      const Offset(394, 560),
      stroke(t.secondary.withValues(alpha: 0.22), 1),
    );

    _floor(canvas);
  }

  void _vip(Canvas canvas) {
    final t = theme;
    final deck = rounded(_G.vipDeck, 12);
    canvas.drawRRect(
      deck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.vip.withValues(alpha: 0.14),
            t.vip.withValues(alpha: 0.03),
          ],
        ).createShader(_G.vipDeck),
    );
    canvas.drawRRect(deck, stroke(t.vip.withValues(alpha: 0.4), 1));
    final rail = stroke(
      t.vip.withValues(alpha: 0.75),
      1.8,
      cap: StrokeCap.round,
    );
    canvas.drawLine(const Offset(112, 74), const Offset(180, 74), rail);
    canvas.drawLine(const Offset(220, 74), const Offset(288, 74), rail);
    paintLabel(
      canvas,
      'VIP',
      x: 201.5,
      baseline: 41,
      size: 7,
      letterSpacing: 3,
      weight: FontWeight.w600,
      color: t.vip,
    );
    // Gradas centrales de cuatro escalones.
    for (var i = 0; i < 4; i++) {
      final width = 40.0 + i * 6;
      final step = rounded(
        Rect.fromLTWH(200 - width / 2, 75 + i * 5.4, width, 5.2),
        1.2,
      );
      canvas.drawRRect(step, fill(NightNeutrals.glass(0.1 - i * 0.015)));
      canvas.drawRRect(step, stroke(t.vip.withValues(alpha: 0.35), 0.5));
    }
    paintLabel(
      canvas,
      'SALÓN PRINCIPAL',
      x: 200,
      baseline: 112,
      size: 7,
      letterSpacing: 3,
      color: NightNeutrals.glass(0.45),
    );
  }

  /// Esquina noroccidental: arco de neón y bafle. La nororiental es su
  /// reflejo. El cono que late lo dibuja [FloorLightsPainter].
  void _corner(Canvas canvas) {
    final t = theme;
    canvas.drawPath(
      Path()
        ..moveTo(6, 92)
        ..quadraticBezierTo(6, 6, 92, 6),
      stroke(t.primary.withValues(alpha: 0.45), 1.6, cap: StrokeCap.round),
    );
    final dashed = Path()
      ..moveTo(14, 104)
      ..quadraticBezierTo(14, 14, 104, 14);
    final dash = stroke(NightNeutrals.glass(0.08), 1);
    for (final metric in dashed.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 2), dash);
      }
    }
    canvas.save();
    canvas.translate(40, 30);
    final body = rounded(const Rect.fromLTWH(-15, -4, 30, 58), 6);
    canvas.drawRRect(body, fill(NightNeutrals.speakerBody));
    canvas.drawRRect(body, stroke(NightNeutrals.glass(0.18), 1));
    canvas.drawRRect(
      rounded(const Rect.fromLTWH(-12, -1, 24, 52), 4),
      stroke(NightNeutrals.glass(0.06), 1),
    );
    canvas.drawCircle(const Offset(0, 7), 4.2, fill(NightNeutrals.speakerCone));
    canvas.drawCircle(
      const Offset(0, 7),
      4.2,
      stroke(NightNeutrals.glass(0.25), 1),
    );
    canvas.restore();
  }

  void _floor(Canvas canvas) {
    final floor = rounded(_G.danceFloor, 16);
    final tile = fill(theme.primary.withValues(alpha: 0.05));
    canvas.save();
    canvas.clipRRect(floor);
    for (var r = -1; r <= 12; r++) {
      for (var c = -1; c <= 7; c++) {
        canvas.drawRRect(tileRect(r, c), tile);
      }
    }
    canvas.restore();
    canvas.drawRRect(floor, stroke(NightNeutrals.glass(0.08), 1));
  }
}

/// Baldosa de la pista en la fila y columna dadas, en coordenadas del lienzo.
RRect tileRect(int row, int col) => rounded(
  Rect.fromLTWH(
    _G.tileOrigin.dx + col * _G.tilePitch + 1,
    _G.tileOrigin.dy + row * _G.tilePitch + 1,
    24,
    24,
  ),
  2,
);

/// Rótulo de la pista y barra central con botellas.
class BarPainter extends _VenuePainter {
  const BarPainter(super.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    paintLabel(
      canvas,
      'PISTA',
      x: 200,
      baseline: 508,
      size: 7.5,
      letterSpacing: 4,
      color: NightNeutrals.glass(0.55),
    );
    canvas.drawRRect(
      rounded(_G.bar.inflate(3), 12),
      stroke(t.barMetal.withValues(alpha: 0.12), 4),
    );
    final bar = rounded(_G.bar, 10);
    final dark40 = mix(t.barMetal, 0.4, NightNeutrals.black);
    canvas.drawRRect(
      bar,
      Paint()
        ..shader = LinearGradient(
          colors: [
            t.barMetal,
            dark40,
            mix(t.barMetal, 0.18, NightNeutrals.black),
            dark40,
            t.barMetal,
          ],
          stops: const [0, 0.12, 0.5, 0.88, 1],
        ).createShader(_G.bar),
    );
    canvas.drawRRect(bar, stroke(t.barMetal.withValues(alpha: 0.9), 1));
    canvas.drawRRect(
      rounded(const Rect.fromLTWH(185, 241, 30, 194), 7),
      fill(NightNeutrals.barInset),
    );

    final bottle = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mix(t.tertiary, 0.45, NightNeutrals.white),
          mix(t.tertiary, 0.6, NightNeutrals.black),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 4, 8.5));
    for (final top in const [245.0, 393.0]) {
      for (var i = 0; i < 3; i++) {
        for (final x in const [189.0, 195.0, 205.0, 211.0]) {
          canvas.save();
          canvas.translate(x - 2, top + i * 12);
          canvas.drawRRect(
            rounded(const Rect.fromLTWH(0, 0, 4, 8.5), 1.8),
            bottle,
          );
          canvas.restore();
        }
      }
    }
    const letters = 'BARRA';
    for (var i = 0; i < letters.length; i++) {
      paintLabel(
        canvas,
        letters[i],
        x: 200,
        baseline: 293 + i * 13.0,
        size: 8.5,
        weight: FontWeight.w700,
        color: NightNeutrals.glass(0.85),
      );
    }
    final tap = stroke(t.barMetal, 1);
    canvas.drawCircle(const Offset(209, 371), 2.4, tap);
    canvas.drawCircle(const Offset(209, 380), 2.4, tap);
  }
}

/// Cabina del DJ (sin sus partes animadas) y acceso.
class BoothPainter extends _VenuePainter {
  const BoothPainter(super.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    canvas.drawRRect(
      rounded(_G.djBooth.inflate(3), 13),
      stroke(t.secondary.withValues(alpha: 0.1), 4),
    );
    final booth = rounded(_G.djBooth, 11);
    canvas.drawRRect(booth, fill(NightNeutrals.booth));
    canvas.drawRRect(booth, stroke(NightNeutrals.glass(0.18), 1));
    canvas.drawCircle(const Offset(149, 567), 1.6, fill(t.barMetal));
    canvas.drawCircle(const Offset(251, 567), 1.6, fill(t.barMetal));
    final deck = rounded(const Rect.fromLTWH(149, 570, 102, 34), 7);
    canvas.drawRRect(deck, fill(NightNeutrals.boothDeck));
    canvas.drawRRect(deck, stroke(NightNeutrals.glass(0.12), 1));
    for (final cx in const [171.0, 229.0]) {
      canvas.drawCircle(Offset(cx, 587), 13.5, fill(NightNeutrals.platterBase));
      canvas.drawCircle(
        Offset(cx, 587),
        13.5,
        stroke(NightNeutrals.glass(0.25), 1),
      );
    }
    paintLabel(
      canvas,
      'DJ',
      x: 200,
      baseline: 612,
      size: 5.6,
      letterSpacing: 4,
      weight: FontWeight.w600,
      color: NightNeutrals.glass(0.7),
    );

    final access = rounded(_G.access, 8);
    canvas.drawRRect(access, fill(NightNeutrals.glass(0.06)));
    canvas.drawRRect(access, stroke(NightNeutrals.glass(0.18), 1));
    paintLabel(
      canvas,
      'ACCESO',
      x: 349,
      baseline: 602,
      size: 6.8,
      letterSpacing: 2,
      weight: FontWeight.w600,
      color: NightNeutrals.glass(0.75),
    );
    paintLabel(
      canvas,
      'LOBBY · CAJA',
      x: 349,
      baseline: 612,
      size: 5.8,
      letterSpacing: 0.8,
      color: NightNeutrals.glass(0.5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(297, 614)
        ..lineTo(297, 602)
        ..moveTo(293.5, 605.5)
        ..lineTo(297, 602)
        ..lineTo(300.5, 605.5),
      stroke(NightNeutrals.glass(0.55), 1.2, cap: StrokeCap.round)
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

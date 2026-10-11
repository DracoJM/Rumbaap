import 'package:flutter/rendering.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/venue_theme.dart';
import 'canvas_helpers.dart';
import 'crystal_layout.dart';

/// Capas fijas del plano, dibujadas en el lienzo lógico de [layout]. Cada una
/// va en su RepaintBoundary: nunca repintan por las animaciones. Solo dibujan
/// los elementos que el local declara.
abstract class _VenuePainter extends CustomPainter {
  const _VenuePainter(this.theme, this.layout);

  final VenueTheme theme;
  final CrystalLayout layout;

  @override
  bool shouldRepaint(covariant _VenuePainter old) =>
      old.theme != theme || old.layout != layout;
}

/// Fondo, tarima VIP, esquinas, paredes y suelo de la pista.
class VenueBasePainter extends _VenuePainter {
  const VenueBasePainter(super.theme, super.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final w = layout.size.width;
    final h = layout.size.height;
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

    if (layout.vipDeck case final deck?) _vip(canvas, deck);
    if (layout.hallLabel case (final text, final at)) {
      paintLabel(
        canvas,
        text,
        x: at.dx,
        baseline: at.dy,
        size: 7,
        letterSpacing: 3,
        color: NightNeutrals.glass(0.45),
      );
    }
    if (layout.cornerSpeakers) {
      _corner(canvas);
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
      _corner(canvas);
      canvas.restore();
    }

    // Paredes laterales con luz: marca primaria al oeste, secundaria al este.
    if (layout.sideWalls case (final top, final bottom)) {
      canvas.drawLine(
        Offset(6, top),
        Offset(6, bottom),
        stroke(t.primary.withValues(alpha: 0.22), 1),
      );
      canvas.drawLine(
        Offset(w - 6, top),
        Offset(w - 6, bottom),
        stroke(t.secondary.withValues(alpha: 0.22), 1),
      );
    }

    if (layout.danceFloor case final floor?) _floor(canvas, floor);
  }

  void _vip(Canvas canvas, Rect deckRect) {
    final t = theme;
    final cx = deckRect.center.dx;
    final deck = rounded(deckRect, 12);
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
        ).createShader(deckRect),
    );
    canvas.drawRRect(deck, stroke(t.vip.withValues(alpha: 0.4), 1));
    // Baranda dorada con el hueco de las gradas en el centro.
    final rail = stroke(
      t.vip.withValues(alpha: 0.75),
      1.8,
      cap: StrokeCap.round,
    );
    final y = deckRect.bottom;
    canvas.drawLine(Offset(deckRect.left + 8, y), Offset(cx - 20, y), rail);
    canvas.drawLine(Offset(cx + 20, y), Offset(deckRect.right - 8, y), rail);
    paintLabel(
      canvas,
      'VIP',
      x: cx + 1.5,
      baseline: deckRect.top + 35,
      size: 7,
      letterSpacing: 3,
      weight: FontWeight.w600,
      color: t.vip,
    );
    // Gradas centrales de cuatro escalones.
    for (var i = 0; i < 4; i++) {
      final width = 40.0 + i * 6;
      final step = rounded(
        Rect.fromLTWH(cx - width / 2, y + 1 + i * 5.4, width, 5.2),
        1.2,
      );
      canvas.drawRRect(step, fill(NightNeutrals.glass(0.1 - i * 0.015)));
      canvas.drawRRect(step, stroke(t.vip.withValues(alpha: 0.35), 0.5));
    }
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

  void _floor(Canvas canvas, Rect floorRect) {
    final floor = rounded(floorRect, 16);
    final tile = fill(theme.primary.withValues(alpha: 0.05));
    final rows = (floorRect.height / CrystalLayout.tilePitch).ceil();
    final cols = (floorRect.width / CrystalLayout.tilePitch).ceil();
    canvas.save();
    canvas.clipRRect(floor);
    for (var r = -1; r <= rows; r++) {
      for (var c = -1; c <= cols; c++) {
        canvas.drawRRect(tileRect(layout, r, c), tile);
      }
    }
    canvas.restore();
    canvas.drawRRect(floor, stroke(NightNeutrals.glass(0.08), 1));
  }
}

/// Baldosa de la pista en la fila y columna dadas, en coordenadas del lienzo.
RRect tileRect(CrystalLayout layout, int row, int col) {
  final origin = layout.tileOrigin;
  return rounded(
    Rect.fromLTWH(
      origin.dx + col * CrystalLayout.tilePitch,
      origin.dy + row * CrystalLayout.tilePitch,
      24,
      24,
    ),
    2,
  );
}

/// Rótulo de la pista y barra con botellas.
class BarPainter extends _VenuePainter {
  const BarPainter(super.theme, super.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    if (layout.danceFloor case final floor?) {
      paintLabel(
        canvas,
        'PISTA',
        x: floor.center.dx,
        baseline: floor.bottom + 16,
        size: 7.5,
        letterSpacing: 4,
        color: NightNeutrals.glass(0.55),
      );
    }
    final barRect = layout.bar;
    if (barRect == null) return;
    final left = barRect.left;
    final top = barRect.top;
    canvas.drawRRect(
      rounded(barRect.inflate(3), 12),
      stroke(t.barMetal.withValues(alpha: 0.12), 4),
    );
    final bar = rounded(barRect, 10);
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
        ).createShader(barRect),
    );
    canvas.drawRRect(bar, stroke(t.barMetal.withValues(alpha: 0.9), 1));
    canvas.drawRRect(
      rounded(
        Rect.fromLTWH(
          left + 5,
          top + 6,
          barRect.width - 10,
          barRect.height - 12,
        ),
        7,
      ),
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
    // Dos estantes de botellas, arriba y abajo de la barra.
    for (final shelf in [top + 10, barRect.bottom - 48]) {
      for (var i = 0; i < 3; i++) {
        for (final dx in const [9.0, 15.0, 25.0, 31.0]) {
          canvas.save();
          canvas.translate(left + dx - 2, shelf + i * 12);
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
        x: barRect.center.dx,
        baseline: top + 58 + i * 13.0,
        size: 8.5,
        weight: FontWeight.w700,
        color: NightNeutrals.glass(0.85),
      );
    }
    final tap = stroke(t.barMetal, 1);
    canvas.drawCircle(Offset(left + 29, top + 136), 2.4, tap);
    canvas.drawCircle(Offset(left + 29, top + 145), 2.4, tap);
  }
}

/// Cabina del DJ (sin sus partes animadas) y acceso.
class BoothPainter extends _VenuePainter {
  const BoothPainter(super.theme, super.layout);

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    if (layout.djBooth case final b?) {
      canvas.drawRRect(
        rounded(b.inflate(3), 13),
        stroke(t.secondary.withValues(alpha: 0.1), 4),
      );
      final booth = rounded(b, 11);
      canvas.drawRRect(booth, fill(NightNeutrals.booth));
      canvas.drawRRect(booth, stroke(NightNeutrals.glass(0.18), 1));
      canvas.drawCircle(Offset(b.left + 7, b.top + 7), 1.6, fill(t.barMetal));
      canvas.drawCircle(Offset(b.right - 7, b.top + 7), 1.6, fill(t.barMetal));
      final deck = rounded(
        Rect.fromLTWH(b.left + 7, b.top + 10, b.width - 14, 34),
        7,
      );
      canvas.drawRRect(deck, fill(NightNeutrals.boothDeck));
      canvas.drawRRect(deck, stroke(NightNeutrals.glass(0.12), 1));
      for (final center in platterCenters(b)) {
        canvas.drawCircle(center, 13.5, fill(NightNeutrals.platterBase));
        canvas.drawCircle(center, 13.5, stroke(NightNeutrals.glass(0.25), 1));
      }
      paintLabel(
        canvas,
        'DJ',
        x: b.center.dx,
        baseline: b.top + 52,
        size: 5.6,
        letterSpacing: 4,
        weight: FontWeight.w600,
        color: NightNeutrals.glass(0.7),
      );
    }

    if (layout.access case final a?) {
      final access = rounded(a, 8);
      canvas.drawRRect(access, fill(NightNeutrals.glass(0.06)));
      canvas.drawRRect(access, stroke(NightNeutrals.glass(0.18), 1));
      paintLabel(
        canvas,
        'ACCESO',
        x: a.center.dx,
        baseline: a.top + 12,
        size: 6.8,
        letterSpacing: 2,
        weight: FontWeight.w600,
        color: NightNeutrals.glass(0.75),
      );
      paintLabel(
        canvas,
        'LOBBY · CAJA',
        x: a.center.dx,
        baseline: a.top + 22,
        size: 5.8,
        letterSpacing: 0.8,
        color: NightNeutrals.glass(0.5),
      );
      final x = a.left - 9;
      canvas.drawPath(
        Path()
          ..moveTo(x, a.bottom - 3)
          ..lineTo(x, a.top + 12)
          ..moveTo(x - 3.5, a.top + 15.5)
          ..lineTo(x, a.top + 12)
          ..lineTo(x + 3.5, a.top + 15.5),
        stroke(NightNeutrals.glass(0.55), 1.2, cap: StrokeCap.round)
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }
}

/// Centros de los dos platos de la cabina [booth].
List<Offset> platterCenters(Rect booth) => [
  Offset(booth.left + 29, booth.top + 27),
  Offset(booth.right - 29, booth.top + 27),
];

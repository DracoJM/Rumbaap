import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import 'venue_geometry.dart';

/// Dibuja el recinto estático: suelo, iluminación, muros, tarima VIP,
/// barra, escenario y acceso. Las mesas se dibujan aparte porque son
/// interactivas. Adaptado del prototipo de demostración Rumbaap × Sagsa.
class VenuePainter extends CustomPainter {
  const VenuePainter();

  static const _hall = VenueGeometry.hall;

  @override
  void paint(Canvas canvas, Size size) {
    // Fase de iluminación fija: a diferencia de la demo, el plano no se anima
    // de forma continua, para ahorrar batería en el teléfono.
    const t = 0.0;
    _paintShell(canvas, size);
    _paintFloor(canvas);
    _paintAmbientLight(canvas, t);
    _paintWallSconces(canvas);
    _paintVipDeck(canvas);
    _paintBar(canvas, t);
    _paintStage(canvas, t);
    _paintAccess(canvas);
    _paintPlants(canvas);
    _paintWalls(canvas);
  }

  // ---------------------------------------------------------------- shell

  void _paintShell(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF09080C),
    );
  }

  void _paintFloor(Canvas canvas) {
    canvas.drawRect(
      _hall,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.1),
          radius: 0.9,
          colors: [Color(0xFF1A1522), AppColors.floor],
        ).createShader(_hall),
    );
    // Baldosas muy sutiles para dar textura al piso.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    for (var x = _hall.left; x < _hall.right; x += 40) {
      canvas.drawLine(Offset(x, _hall.top), Offset(x, _hall.bottom), grid);
    }
    for (var y = _hall.top; y < _hall.bottom; y += 40) {
      canvas.drawLine(Offset(_hall.left, y), Offset(_hall.right, y), grid);
    }
  }

  void _paintAmbientLight(Canvas canvas, double t) {
    canvas.save();
    canvas.clipRect(_hall);

    // Haces violeta que bajan desde la tarima VIP hacia la pista.
    void beam(Offset from, Offset to, double width, double alpha) {
      final dir = to - from;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx + normal.dx * width, to.dy + normal.dy * width)
        ..lineTo(to.dx - normal.dx * width, to.dy - normal.dy * width)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.violet.withValues(alpha: alpha),
              AppColors.violet.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromPoints(from, to))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    final sway = math.sin(t * math.pi * 2) * 30;
    beam(const Offset(220, 240), Offset(330 + sway, 760), 80, 0.34);
    beam(const Offset(780, 240), Offset(690 - sway, 760), 80, 0.34);
    beam(const Offset(380, 940), Offset(250 - sway, 560), 70, 0.26);
    beam(const Offset(620, 940), Offset(750 + sway, 560), 70, 0.26);

    // Charcos de luz violeta sobre la pista.
    void glow(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final breathe = 0.85 + 0.15 * math.sin(t * math.pi * 2);
    glow(const Offset(290, 560), 200, AppColors.violet, 0.26 * breathe);
    glow(const Offset(720, 470), 190, AppColors.violet, 0.24 * breathe);
    glow(const Offset(300, 860), 180, AppColors.violet, 0.2);
    glow(const Offset(700, 860), 190, AppColors.violet, 0.22 * breathe);
    glow(const Offset(500, 1000), 240, AppColors.violet, 0.28);

    // Franjas ámbar junto a las paredes de las mesas.
    for (final x in [_hall.left, _hall.right]) {
      final r = Rect.fromLTRB(x - 160, _hall.top, x + 160, _hall.bottom);
      canvas.drawRect(
        r,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.5,
            colors: [
              AppColors.amber.withValues(alpha: 0.13),
              AppColors.amber.withValues(alpha: 0),
            ],
          ).createShader(r),
      );
    }
    glow(const Offset(500, 90), 380, AppColors.amber, 0.14);
    canvas.restore();
  }

  void _paintWallSconces(Canvas canvas) {
    for (var i = 0; i <= 10; i++) {
      final y = VenueGeometry.firstRowY + VenueGeometry.rowPitch * (i - 0.5);
      for (final x in [_hall.left + 6, _hall.right - 6]) {
        final c = Offset(x, y);
        _lamp(canvas, c, 34, 0.5);
      }
    }
  }

  // -------------------------------------------------------------- VIP deck

  void _paintVipDeck(Canvas canvas) {
    final deck = VenueGeometry.vipDeck;
    final shape = RRect.fromRectAndCorners(
      deck,
      bottomLeft: const Radius.circular(36),
      bottomRight: const Radius.circular(36),
    );
    // Sombra proyectada: la tarima se percibe elevada.
    canvas.drawRRect(
      shape.shift(const Offset(0, 14)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D1823), Color(0xFF241C24)],
        ).createShader(deck),
    );
    // Tablones de madera oscura.
    final plank = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var y = deck.top + 14; y < deck.bottom; y += 14) {
      canvas.drawLine(
        Offset(deck.left + 8, y),
        Offset(deck.right - 8, y),
        plank,
      );
    }
    _neonOutline(canvas, Path()..addRRect(shape.deflate(4)), AppColors.amber);

    // Escalera central.
    final stairs = VenueGeometry.vipStairs;
    canvas.drawRect(stairs, Paint()..color = const Color(0xFF18141C));
    for (var i = 0; i < 6; i++) {
      final y = stairs.top + i * stairs.height / 6;
      final r = Rect.fromLTWH(stairs.left, y, stairs.width, stairs.height / 6);
      canvas.drawRect(
        r.deflate(1),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF2A2230), Colors.black, i / 8)!,
              const Color(0xFF141016),
            ],
          ).createShader(r),
      );
      canvas.drawLine(
        r.topLeft + const Offset(6, 0),
        r.topRight - const Offset(6, 0),
        Paint()
          ..color = AppColors.amber.withValues(alpha: 0.22)
          ..strokeWidth = 1.2,
      );
    }

    // Puffs frente a cada mesa VIP, sobre el borde de la tarima.
    for (final cx in VenueGeometry.vipX) {
      for (final dx in [-46.0, 0.0, 46.0]) {
        final c = Offset(cx + dx, deck.bottom - 18);
        canvas.drawCircle(
          c + const Offset(0, 3),
          11,
          Paint()
            ..color = Colors.black54
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          c,
          10,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [AppColors.upholstery, AppColors.upholsteryShade],
            ).createShader(Rect.fromCircle(center: c, radius: 10)),
        );
      }
    }

    _label(
      canvas,
      'ZONA VIP',
      Offset(500, deck.top + 26),
      15,
      AppColors.violetBright,
    );
  }

  // ------------------------------------------------------------------ bar

  void _paintBar(Canvas canvas, double t) {
    final bar = VenueGeometry.bar;
    final outer = RRect.fromRectAndRadius(bar, const Radius.circular(40));

    // Taburetes a ambos lados.
    final stoolPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFF8C7766), Color(0xFF3F342C)],
      ).createShader(const Rect.fromLTWH(-9, -9, 18, 18));
    for (var y = bar.top + 46; y < bar.bottom - 30; y += 34) {
      for (final x in [bar.left - 22, bar.right + 22]) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawCircle(
          const Offset(0, 3),
          10,
          Paint()
            ..color = Colors.black54
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-9, -9, 18, 18),
            const Radius.circular(5),
          ),
          stoolPaint,
        );
        canvas.restore();
      }
    }

    canvas.drawRRect(
      outer.shift(const Offset(0, 12)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // Mostrador.
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF241B16), Color(0xFF15100E), Color(0xFF241B16)],
        ).createShader(bar),
    );
    _neonOutline(canvas, Path()..addRRect(outer.deflate(3)), AppColors.amber);

    // Zona interior del bartender.
    final well = RRect.fromRectAndRadius(
      bar.deflate(22),
      const Radius.circular(24),
    );
    canvas.drawRRect(well, Paint()..color = const Color(0xFF0B090C));
    canvas.drawRRect(
      well,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.amber.withValues(alpha: 0.25),
    );

    // Estanterías de botellas retroiluminadas.
    final rnd = math.Random(7);
    for (final shelf in [
      Rect.fromLTRB(
        bar.center.dx - 12,
        bar.top + 50,
        bar.center.dx + 12,
        bar.top + 190,
      ),
      Rect.fromLTRB(
        bar.center.dx - 12,
        bar.bottom - 190,
        bar.center.dx + 12,
        bar.bottom - 50,
      ),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(shelf.inflate(4), const Radius.circular(4)),
        Paint()
          ..color = AppColors.violet.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawRect(shelf, Paint()..color = const Color(0xFF1A1630));
      for (var y = shelf.top + 4; y < shelf.bottom - 6; y += 9) {
        for (final x in [shelf.left + 6, shelf.right - 6]) {
          final hue = rnd.nextDouble();
          final color = HSVColor.fromAHSV(
            1,
            220 + hue * 80,
            0.55,
            0.65 + 0.3 * math.sin((t + hue) * math.pi * 2).abs(),
          ).toColor();
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
    }

    _label(canvas, 'BARRA', bar.center, 15, AppColors.text);
  }

  // ---------------------------------------------------------------- stage

  void _paintStage(Canvas canvas, double t) {
    final stage = VenueGeometry.djStage;
    final shape = RRect.fromRectAndCorners(
      stage,
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
    );
    final intensity = 0.55 + 0.25 * math.sin(t * math.pi * 4);
    canvas.drawRRect(
      shape.inflate(18),
      Paint()
        ..color = AppColors.violet.withValues(alpha: 0.32 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1726), Color(0xFF0F0C14)],
        ).createShader(stage),
    );
    _neonOutline(canvas, Path()..addRRect(shape.deflate(3)), AppColors.violet);

    // Cabina con dos platos y mezcladora.
    final booth = Rect.fromCenter(
      center: Offset(stage.center.dx, stage.top + 56),
      width: 190,
      height: 54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        booth.shift(const Offset(0, 6)),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.black
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(booth, const Radius.circular(8)),
      Paint()..color = const Color(0xFF221D2A),
    );
    for (final dx in [-58.0, 58.0]) {
      final c = booth.center + Offset(dx, 0);
      canvas.drawCircle(c, 20, Paint()..color = const Color(0xFF0D0B10));
      canvas.drawCircle(
        c,
        20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.violetBright.withValues(alpha: 0.7),
      );
      canvas.drawCircle(c, 4, Paint()..color = AppColors.violetBright);
    }
    final mixer = Rect.fromCenter(center: booth.center, width: 44, height: 40);
    canvas.drawRect(mixer, Paint()..color = const Color(0xFF2E2838));
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(mixer.left + 6 + i * 9, mixer.top + 8, 4, 24),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF60A5FA),
            AppColors.violetBright,
            i / 3,
          )!.withValues(alpha: 0.5 + 0.5 * ((t * 3 + i * 0.3) % 1)),
      );
    }
    // Parlantes.
    for (final x in [stage.left + 32, stage.right - 32]) {
      final r = Rect.fromCenter(
        center: Offset(x, stage.top + 40),
        width: 40,
        height: 40,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = const Color(0xFF151218),
      );
      canvas.drawCircle(r.center, 12, Paint()..color = const Color(0xFF26212C));
      canvas.drawCircle(r.center, 4, Paint()..color = const Color(0xFF0A090C));
    }
    _label(
      canvas,
      'ESCENARIO DJ',
      Offset(stage.center.dx, stage.bottom - 38),
      15,
      AppColors.violetBright,
    );
  }

  // --------------------------------------------------------------- access

  void _paintAccess(Canvas canvas) {
    final a = VenueGeometry.access;
    canvas.drawRect(
      a,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.05),
            AppColors.amber.withValues(alpha: 0.22),
          ],
        ).createShader(a),
    );
    canvas.drawLine(
      a.topLeft,
      a.bottomLeft,
      Paint()
        ..color = AppColors.amber
        ..strokeWidth = 3,
    );
    _label(canvas, 'LOBBY / CAJA  →', a.center, 14, AppColors.amberSoft);
  }

  // --------------------------------------------------------------- plants

  void _paintPlants(Canvas canvas) {
    const spots = [
      Offset(205, 46),
      Offset(405, 50),
      Offset(595, 50),
      Offset(795, 46),
      Offset(52, 1046),
      Offset(160, 1052),
      Offset(310, 1050),
      Offset(690, 1050),
      Offset(800, 990),
      Offset(130, 40),
      Offset(870, 40),
    ];
    for (var i = 0; i < spots.length; i++) {
      _plant(canvas, spots[i], 22, i * 0.7);
    }
  }

  void _plant(Canvas canvas, Offset c, double r, double seed) {
    canvas.drawCircle(
      c + const Offset(0, 4),
      r * 0.8,
      Paint()
        ..color = Colors.black54
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    for (var i = 0; i < 9; i++) {
      final angle = seed + i * math.pi * 2 / 9;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final leaf = Rect.fromLTWH(r * 0.1, -r * 0.18, r, r * 0.36);
      canvas.drawOval(
        leaf,
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.plant,
              Color.lerp(AppColors.plant, const Color(0xFF6E9A4F), 0.5)!,
            ],
          ).createShader(leaf),
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.22, Paint()..color = const Color(0xFF1F3A22));
  }

  // ---------------------------------------------------------------- walls

  void _paintWalls(Canvas canvas) {
    final wall = Paint()
      ..color = AppColors.wall
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    final a = VenueGeometry.access;
    final h = _hall.inflate(7);
    // Muro perimetral con abertura en el acceso sur-oriental.
    final path = Path()
      ..moveTo(a.left, h.bottom)
      ..lineTo(h.left, h.bottom)
      ..lineTo(h.left, h.top)
      ..lineTo(h.right, h.top)
      ..lineTo(h.right, a.top);
    canvas.drawPath(path, wall);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.amber.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // -------------------------------------------------------------- helpers

  void _neonOutline(Canvas canvas, Path path, Color color) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Color.lerp(color, Colors.white, 0.35)!,
    );
  }

  void _lamp(Canvas canvas, Offset c, double radius, double alpha) {
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.amber.withValues(alpha: alpha),
            AppColors.amber.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
    canvas.drawCircle(c, 2.4, Paint()..color = AppColors.amberSoft);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w500,
          letterSpacing: 2.4,
          color: color,
          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(VenuePainter oldDelegate) => false;
}

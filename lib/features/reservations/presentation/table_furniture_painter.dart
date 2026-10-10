import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_presentation.dart';

/// Sofá envolvente + tablero redondo con lámpara, visto desde arriba.
/// Adaptado del prototipo de demostración Rumbaap × Sagsa.
///
/// Se dibuja en orientación base (abertura hacia el sur) y se gira con
/// [rotation]. [emphasis] (0–1) intensifica el brillo al seleccionar.
class TableFurniturePainter extends CustomPainter {
  const TableFurniturePainter({
    required this.kind,
    required this.rotation,
    required this.status,
    required this.emphasis,
    required this.selected,
  });

  final TableKind kind;
  final double rotation;
  final TableMapStatus status;
  final double emphasis;
  final bool selected;

  bool get _vip => kind == TableKind.vip;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final sofaRadius = s * (_vip ? 0.36 : 0.37);
    final sofaWidth = s * (_vip ? 0.13 : 0.16);
    final tableRadius = s * (_vip ? 0.2 : 0.22);
    // Herradura de tres lados para las regulares, media luna para VIP.
    final sweep = _vip ? math.pi * 1.12 : math.pi * 1.42;

    // Halo del estado sobre el piso.
    final halo = s * (0.5 + 0.06 * emphasis);
    canvas.drawCircle(
      c,
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            status.color.withValues(alpha: 0.18 + 0.2 * emphasis),
            status.color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: halo)),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);

    final arcRect = Rect.fromCircle(center: Offset.zero, radius: sofaRadius);
    final start = -math.pi / 2 - sweep / 2;

    // Sombra del sofá: da sensación de volumen.
    canvas.drawArc(
      arcRect.shift(const Offset(0, 4)),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = sofaWidth + 4
        ..color = Colors.black.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Tapizado con degradado radial (respaldo más oscuro).
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = sofaWidth
        ..shader =
            RadialGradient(
              colors: const [
                AppColors.upholstery,
                AppColors.upholstery,
                AppColors.upholsteryShade,
              ],
              stops: [
                0,
                (sofaRadius - sofaWidth / 2) / (sofaRadius + sofaWidth / 2),
                1,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset.zero,
                radius: sofaRadius + sofaWidth / 2,
              ),
            ),
    );
    // Costuras de los cojines.
    final seams = _vip ? 9 : 6;
    final seam = Paint()
      ..color = AppColors.upholsteryShade.withValues(alpha: 0.8)
      ..strokeWidth = 1;
    for (var i = 1; i < seams; i++) {
      final a = start + sweep * i / seams;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        dir * (sofaRadius - sofaWidth / 2 + 1),
        dir * (sofaRadius + sofaWidth / 2 - 1),
        seam,
      );
    }
    canvas.restore();

    // Tablero (no se rota: es redondo).
    canvas.drawCircle(
      c + const Offset(0, 3),
      tableRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      tableRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            Color.lerp(AppColors.tabletop, AppColors.amber, 0.22)!,
            AppColors.tabletop,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: tableRadius)),
    );
    // Anillo de estado alrededor del tablero.
    canvas.drawCircle(
      c,
      tableRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _vip ? 3.5 : 2.6
        ..color = status.color.withValues(alpha: 0.75 + 0.25 * emphasis),
    );

    if (selected) {
      final ring = sofaRadius + sofaWidth / 2 + 6;
      canvas.drawCircle(
        c,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = AppColors.violet.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        c,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.violetBright,
      );
    }
  }

  @override
  bool shouldRepaint(TableFurniturePainter old) =>
      old.status != status ||
      old.emphasis != emphasis ||
      old.selected != selected ||
      old.rotation != rotation ||
      old.kind != kind;
}

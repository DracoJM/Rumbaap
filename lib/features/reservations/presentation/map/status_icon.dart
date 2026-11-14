import 'package:flutter/widgets.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../table_presentation.dart';
import 'canvas_helpers.dart';

/// Icono de estado: círculo oscuro con borde y pictograma del color del
/// estado. El mismo dibujo se usa en el plano y en los chips, así que el
/// estado no depende solo del color.
void paintStatusBadge(Canvas canvas, TableMapStatus status, Color color) {
  canvas.drawCircle(Offset.zero, 6.6, fill(NightNeutrals.badge));
  canvas.drawCircle(Offset.zero, 6.6, stroke(color, 1.1));
  Paint line(double w) =>
      stroke(color, w, cap: StrokeCap.round)..strokeJoin = StrokeJoin.round;
  switch (status) {
    case TableMapStatus.available:
      canvas.drawPath(
        Path()
          ..moveTo(-3.2, 0.2)
          ..lineTo(-1.1, 2.4)
          ..lineTo(3.2, -2),
        line(1.6),
      );
    case TableMapStatus.reserved:
      canvas.drawRRect(
        rounded(const Rect.fromLTWH(-3.4, -2.8, 6.8, 6), 1),
        line(1.3),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-3.4, -0.6)
          ..lineTo(3.4, -0.6)
          ..moveTo(-1.6, -4)
          ..lineTo(-1.6, -2)
          ..moveTo(1.6, -4)
          ..lineTo(1.6, -2),
        line(1.3),
      );
    case TableMapStatus.pending:
      canvas.drawPath(
        Path()
          ..moveTo(-2.8, -3.6)
          ..lineTo(2.8, -3.6)
          ..moveTo(-2.8, 3.6)
          ..lineTo(2.8, 3.6)
          ..moveTo(-2.2, -3.6)
          ..cubicTo(-2.2, -1, 2.2, -1.8, 2.2, 0)
          ..cubicTo(2.2, 1.8, -2.2, 1, -2.2, 3.6),
        line(1.3),
      );
    case TableMapStatus.occupied:
      canvas.drawCircle(const Offset(-1.4, -1.4), 1.6, line(1.2));
      canvas.drawCircle(const Offset(2.1, -0.8), 1.2, line(1.1));
      canvas.drawPath(
        Path()
          ..moveTo(-4.2, 3.4)
          ..cubicTo(-3.8, 1.6, -2.8, 0.8, -1.4, 0.8)
          ..cubicTo(0, 0.8, 1, 1.6, 1.4, 3.4)
          ..moveTo(1.4, 1)
          ..cubicTo(2.8, 1, 3.8, 1.7, 4.2, 3.4),
        line(1.2),
      );
    case TableMapStatus.pendingPayment:
      canvas.drawRRect(
        rounded(const Rect.fromLTWH(-3.8, -2.6, 7.6, 5.2), 1),
        line(1.3),
      );
      canvas.drawLine(
        const Offset(-3.8, -0.6),
        const Offset(3.8, -0.6),
        stroke(color, 1.3),
      );
    case TableMapStatus.unknown:
      paintLabel(
        canvas,
        '?',
        x: 0,
        baseline: 2.8,
        size: 7.5,
        weight: FontWeight.w700,
        color: color,
      );
  }
}

/// Icono de estado como widget, para la interfaz fuera del plano.
class StatusIcon extends StatelessWidget {
  const StatusIcon({super.key, required this.status, this.size = 16});

  final TableMapStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(StatusColors.of(context));
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StatusIconPainter(status, color),
      ),
    );
  }
}

class _StatusIconPainter extends CustomPainter {
  const _StatusIconPainter(this.status, this.color);

  final TableMapStatus status;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    // El dibujo ocupa un cuadro de 16 unidades centrado en el origen.
    canvas.scale(size.shortestSide / 16);
    paintStatusBadge(canvas, status, color);
  }

  @override
  bool shouldRepaint(_StatusIconPainter old) =>
      old.status != status || old.color != color;
}

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Mezcla [color] al [amount] (0–1) con [other], como `color-mix` de CSS.
Color mix(Color color, double amount, Color other) =>
    Color.lerp(other, color, amount)!;

Paint fill(Color color) => Paint()..color = color;

Paint stroke(Color color, double width, {StrokeCap cap = StrokeCap.butt}) =>
    Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap;

/// Texto del plano con la línea base en [baseline], centrado en [x]. No
/// escala con el tamaño de texto del sistema: el plano entero ya se escala.
void paintLabel(
  Canvas canvas,
  String text, {
  required double x,
  required double baseline,
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        height: 1,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final ascent = painter.computeDistanceToActualBaseline(
    ui.TextBaseline.alphabetic,
  );
  painter.paint(canvas, Offset(x - painter.width / 2, baseline - ascent));
  painter.dispose();
}

/// Rectángulo redondeado de [rect] con radio [r].
RRect rounded(Rect rect, double r) =>
    RRect.fromRectAndRadius(rect, Radius.circular(r));

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';

/// Superficie de cristal: desenfoque fijo del fondo con saturación, velo
/// claro y borde con reflejo superior.
///
/// Usa [BackdropFilter.grouped]: dentro de un [BackdropGroup] todas las
/// superficies comparten una sola lectura del fondo por fotograma. El
/// desenfoque nunca se anima.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.radius,
    required this.child,
    this.blur = 22,
    this.saturation = 1.7,
    this.tint = const [0.17, 0.05],
    this.borderAlpha = 0.2,
    this.highlightAlpha = 0.4,
  });

  final double radius;
  final double blur;
  final double saturation;

  /// Opacidad del velo blanco al inicio y al final del degradado.
  final List<double> tint;
  final double borderAlpha;
  final double highlightAlpha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter.grouped(
        filter: ui.ImageFilter.compose(
          outer: ui.ImageFilter.blur(sigmaX: blur / 2, sigmaY: blur / 2),
          inner: ColorFilter.matrix(_saturate(saturation)),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: LinearGradient(
              begin: const Alignment(-0.35, -1),
              end: const Alignment(0.35, 1),
              colors: [
                NightNeutrals.glass(tint[0]),
                NightNeutrals.glass(tint[1]),
              ],
            ),
            border: Border.all(color: NightNeutrals.glass(borderAlpha)),
          ),
          // Reflejo de 1 px en el canto superior, fuera de las esquinas.
          child: Stack(
            children: [
              child,
              Positioned(
                top: 0,
                left: radius * 0.6,
                right: radius * 0.6,
                height: 1,
                child: ColoredBox(color: NightNeutrals.glass(highlightAlpha)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Matriz de saturación estándar (luminancia Rec. 709).
  static List<double> _saturate(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    return [
      r * i + s, g * i, b * i, 0, 0, //
      r * i, g * i + s, b * i, 0, 0, //
      r * i, g * i, b * i + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

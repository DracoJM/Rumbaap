import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Reloj único de las luces del mapa. Un solo ticker alimenta todas las
/// capas animadas: cada una lee [seconds] y repinta solo su capa.
class MapClock extends ChangeNotifier {
  double _seconds = 0;
  bool _animating = false;

  double get seconds => _seconds;

  /// `false` con «reducir movimiento» activo: las capas muestran un estado
  /// fijo en lugar de un fotograma congelado a medias.
  bool get animating => _animating;

  set animating(bool value) {
    if (_animating == value) return;
    _animating = value;
    if (!value) _seconds = 0;
    notifyListeners();
  }

  void tick(Duration elapsed) {
    _seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
  }
}

/// Ida y vuelta (`alternate` de CSS) entre 0 y 1 con [curve].
double pingPong(double t, double period, [Curve curve = Curves.easeInOut]) {
  final phase = (t / period) % 2;
  return curve.transform(phase < 1 ? phase : 2 - phase);
}

/// Fase lineal entre 0 y 1 que se repite cada [period].
double loopPhase(double t, double period) => (t / period) % 1;

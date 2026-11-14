import 'package:flutter/painting.dart';

/// Neutros de la dirección «Noche de cristal», iguales en todas las
/// discotecas: texto, cristal y superficies oscuras del mobiliario. Los
/// colores de marca viven en [VenueTheme] y los de estado en [StatusColors].
abstract final class NightNeutrals {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const foreground = Color(0xFFF2F1F7);

  /// Fondo de los iconos de estado.
  static const badge = Color(0xFF0E0D18);

  /// Reflejo y sombra del cristal de las mesas.
  static const discMid = Color(0xBF282646);
  static const discEdge = Color(0xF20E0D1A);

  static const speakerBody = Color(0xFF121119);
  static const speakerCone = Color(0xFF0A0912);
  static const barInset = Color(0xBF0A0C16);
  static const booth = Color(0xEB141224);
  static const boothDeck = Color(0xFF0B0A14);
  static const platterBase = Color(0xFF15131F);
  static const platterVinyl = Color(0xFF0C0B12);

  /// Botón principal claro sobre cristal.
  static const ctaTop = Color(0xF5FFFFFF);
  static const ctaBottom = Color(0xDBE6E4F5);
  static const ctaInk = Color(0xFF14121F);
  static const vipCtaInk = Color(0xFF1B1408);

  /// Blanco con la opacidad indicada, para trazos y velos sobre oscuro.
  static Color glass(double alpha) => white.withValues(alpha: alpha);
}

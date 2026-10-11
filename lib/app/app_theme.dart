import 'package:flutter/material.dart';

import '../theme/status_colors.dart';
import '../theme/venue_theme.dart';

/// Neutros y colores semánticos de la interfaz, comunes a todos los locales
/// y armonizados con «Noche de cristal» v7. La marca de cada local (primario,
/// dorado VIP, mobiliario) viene de su [VenueTheme], nunca de aquí.
abstract final class AppColors {
  static const background = Color(0xFF0A0A12);
  static const surface = Color(0xFF13131D);
  static const surfaceRaised = Color(0xFF1B1B28);
  static const border = Color(0xFF2A2A39);
  static const borderStrong = Color(0xFF3A3A4C);

  /// Avisos y advertencias (mismo tono que «En proceso»).
  static const amber = Color(0xFFE5C06A);
  static const amberSoft = Color(0xFFF0D898);

  static const text = Color(0xFFF2F1F7);
  static const textMuted = Color(0xFFA3A2B5);
  static const textFaint = Color(0xFF75748A);

  static const danger = Color(0xFFF08A8A);
}

abstract final class AppTheme {
  /// Tema de la app para el local [venue]: su marca define el color
  /// principal y el fondo; los estados de mesa salen de [StatusColors].
  static ThemeData build(VenueTheme venue) {
    final scheme = ColorScheme.fromSeed(
      seedColor: venue.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: venue.primary,
      onPrimary: Colors.white,
      secondary: venue.vip,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: venue.background,
    );
    final text = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    return base.copyWith(
      extensions: [venue, StatusColors.forVenue(venue)],
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: venue.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceRaised,
        selectedColor: venue.primary.withValues(alpha: 0.35),
        side: const BorderSide(color: AppColors.borderStrong),
        labelStyle: const TextStyle(color: AppColors.text),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: TextStyle(color: AppColors.text),
      ),
    );
  }
}

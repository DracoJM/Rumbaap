import 'package:flutter/material.dart';

import '../theme/status_colors.dart';
import '../theme/venue_theme.dart';

/// Neutros y colores semánticos de la interfaz, comunes a todos los locales
/// y armonizados con «Noche de cristal» v7. La marca de cada local (primario,
/// dorado VIP, mobiliario) viene de su [VenueTheme], nunca de aquí.
abstract final class AppColors {
  /// Grafito frío: fondo, superficies un poco elevadas y bordes finos.
  static const background = Color(0xFF0B0D13);
  static const surface = Color(0xFF12151D);
  static const surfaceRaised = Color(0xFF1A1E28);
  static const border = Color(0xFF272C39);
  static const borderStrong = Color(0xFF363C4D);

  /// Avisos y advertencias (mismo tono que «En proceso»).
  static const amber = Color(0xFFE5C06A);
  static const amberSoft = Color(0xFFF0D898);

  /// Texto principal casi blanco; secundario y ayuda con contraste AA sobre
  /// las superficies de arriba.
  static const text = Color(0xFFF3F4F8);
  static const textMuted = Color(0xFFAEB4C4);
  static const textFaint = Color(0xFF8991A6);

  static const danger = Color(0xFFF08A8A);
}

/// Espaciado común (múltiplos de 4): separación entre elementos y secciones.
abstract final class AppSpace {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;

  /// Margen horizontal de pantalla: 16 en teléfonos estrechos y 20 desde
  /// 400 dp.
  static double gutter(double width) => width >= 400 ? 20 : 16;
}

/// Radios comunes: tarjetas, y campos y botones.
abstract final class AppRadius {
  static const card = 20.0;
  static const control = 14.0;
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
    // Jerarquía: título 26–28, sección 18–20, cuerpo 15–16, ayuda 13–14.
    // Fuente del sistema; escala con el texto del usuario.
    final text = base.textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: const TextStyle(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: const TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.4),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.4),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textMuted,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: const TextStyle(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      extensions: [venue, StatusColors.forVenue(venue)],
      textTheme: text,
      // Acento azul/lila solo en la acción principal y la selección; la
      // secundaria queda quieta, con borde fino.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: controlShape,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 14,
        ),
        border: field(AppColors.border),
        enabledBorder: field(AppColors.border),
        focusedBorder: field(venue.primary, 1.6),
        errorBorder: field(AppColors.danger),
        focusedErrorBorder: field(AppColors.danger, 1.6),
        helperStyle: text.bodySmall,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppSpace.xs),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 8,
        iconColor: AppColors.textMuted,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: controlShape,
          side: const BorderSide(color: AppColors.borderStrong),
          selectedBackgroundColor: venue.primary.withValues(alpha: 0.28),
          selectedForegroundColor: AppColors.text,
          foregroundColor: AppColors.textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: venue.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleMedium,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: controlShape,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/status_colors.dart';
import '../theme/venues/sagsa.dart';

/// Paleta nocturna: grafito, violeta de interfaz y ámbar ambiental.
/// Adaptada del prototipo de demostración Rumbaap × Sagsa.
abstract final class AppColors {
  static const background = Color(0xFF0B0A10);
  static const surface = Color(0xFF14121B);
  static const surfaceRaised = Color(0xFF1C1925);
  static const border = Color(0xFF2E2A39);
  static const borderStrong = Color(0xFF3D3849);

  static const violet = Color(0xFF8B5CF6);
  static const violetBright = Color(0xFFA78BFA);

  static const amber = Color(0xFFF5A84A);
  static const amberSoft = Color(0xFFFFCB8A);

  static const text = Color(0xFFF4EFE8);
  static const textMuted = Color(0xFFA9A3B3);
  static const textFaint = Color(0xFF6F6880);

  static const floor = Color(0xFF110E16);
  static const wall = Color(0xFF1E1A24);
  static const upholstery = Color(0xFFC9AE96);
  static const upholsteryShade = Color(0xFF7A6553);
  static const tabletop = Color(0xFF1B1714);
  static const plant = Color(0xFF2F5A34);

  static const danger = Color(0xFFF87171);
}

abstract final class AppTheme {
  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: AppColors.violet,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
    );
    final text = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    return base.copyWith(
      // Tema del local para las pantallas «Noche de cristal». Hoy solo hay
      // un local; el resto de la app sigue con la paleta de AppColors.
      extensions: [sagsaTheme, StatusColors.forVenue(sagsaTheme)],
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
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
        selectedColor: AppColors.violet.withValues(alpha: 0.35),
        side: const BorderSide(color: AppColors.borderStrong),
        labelStyle: const TextStyle(color: AppColors.text),
      ),
    );
  }
}

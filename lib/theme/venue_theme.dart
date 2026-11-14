import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Identidad visual de una discoteca: marca, mobiliario e intensidad de luces.
///
/// Los colores de marca nunca indican el estado de una mesa; para eso está
/// [StatusColors], compartido por todos los locales. Agregar una discoteca
/// es agregar una instancia en `lib/theme/venues/`, sin tocar pantallas.
@immutable
class VenueTheme extends ThemeExtension<VenueTheme> {
  const VenueTheme({
    required this.name,
    required this.background,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.vip,
    required this.furniture,
    required this.furnitureBack,
    required this.barMetal,
    required this.lightIntensity,
  });

  final String name;
  final Color background;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color vip;
  final Color furniture;
  final Color furnitureBack;
  final Color barMetal;

  /// Haces, pista y neón del plano, de 0 a 1.
  final double lightIntensity;

  static VenueTheme of(BuildContext context) =>
      Theme.of(context).extension<VenueTheme>()!;

  @override
  VenueTheme copyWith({
    String? name,
    Color? background,
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? vip,
    Color? furniture,
    Color? furnitureBack,
    Color? barMetal,
    double? lightIntensity,
  }) => VenueTheme(
    name: name ?? this.name,
    background: background ?? this.background,
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    tertiary: tertiary ?? this.tertiary,
    vip: vip ?? this.vip,
    furniture: furniture ?? this.furniture,
    furnitureBack: furnitureBack ?? this.furnitureBack,
    barMetal: barMetal ?? this.barMetal,
    lightIntensity: lightIntensity ?? this.lightIntensity,
  );

  @override
  VenueTheme lerp(VenueTheme? other, double t) {
    if (other == null) return this;
    return VenueTheme(
      name: t < 0.5 ? name : other.name,
      background: Color.lerp(background, other.background, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      vip: Color.lerp(vip, other.vip, t)!,
      furniture: Color.lerp(furniture, other.furniture, t)!,
      furnitureBack: Color.lerp(furnitureBack, other.furnitureBack, t)!,
      barMetal: Color.lerp(barMetal, other.barMetal, t)!,
      lightIntensity: lerpDouble(lightIntensity, other.lightIntensity, t)!,
    );
  }
}

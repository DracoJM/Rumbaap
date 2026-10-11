import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app_theme.dart';
import 'package:rumbaap/theme/status_colors.dart';
import 'package:rumbaap/theme/venue_theme.dart';
import 'package:rumbaap/theme/venues/sagsa.dart';

void main() {
  test('el tema de Sagsa tiene los valores aprobados', () {
    expect(sagsaTheme.name, 'Sagsa');
    expect(sagsaTheme.background, const Color(0xFF08080F));
    expect(sagsaTheme.primary, const Color(0xFF8B7CF6));
    expect(sagsaTheme.secondary, const Color(0xFFD9679E));
    expect(sagsaTheme.tertiary, const Color(0xFF4FB6CC));
    expect(sagsaTheme.vip, const Color(0xFFD9BC84));
    expect(sagsaTheme.furniture, const Color(0xFF4A5778));
    expect(sagsaTheme.furnitureBack, const Color(0xFF1F263A));
    expect(sagsaTheme.barMetal, const Color(0xFF5C6E98));
    expect(sagsaTheme.ambientIntensity, 0.35);
    expect(sagsaTheme.lightIntensity, 0.32);
  });

  test('los estados son comunes y el pago VIP usa el dorado del local', () {
    final colors = StatusColors.forVenue(sagsaTheme);
    expect(colors.available, const Color(0xFF6FCF9F));
    expect(colors.reserved, const Color(0xFF82A8E8));
    expect(colors.inProgress, const Color(0xFFE5C06A));
    expect(colors.occupied, const Color(0xFFD987B0));
    expect(colors.unknown, const Color(0xFF8A8A9C));
    expect(colors.vipPaymentPending, sagsaTheme.vip);

    final other = sagsaTheme.copyWith(vip: const Color(0xFFE6C68E));
    final otherColors = StatusColors.forVenue(other);
    expect(otherColors.vipPaymentPending, const Color(0xFFE6C68E));
    expect(otherColors.available, colors.available);
  });

  test('lerp en los extremos devuelve cada tema', () {
    final other = sagsaTheme.copyWith(
      name: 'Otro',
      primary: const Color(0xFF2FB8A6),
      lightIntensity: 0.3,
    );
    expect(sagsaTheme.lerp(other, 0).primary, sagsaTheme.primary);
    expect(sagsaTheme.lerp(other, 1).primary, other.primary);
    expect(sagsaTheme.lerp(other, 1).name, 'Otro');
    expect(sagsaTheme.lerp(other, 1).lightIntensity, 0.3);
    expect(sagsaTheme.lerp(null, 0.5), same(sagsaTheme));
  });

  test('el tema de la app registra el tema del local y sus estados', () {
    final theme = AppTheme.build(sagsaTheme);
    expect(theme.extension<VenueTheme>(), same(sagsaTheme));
    expect(theme.extension<StatusColors>()!.vipPaymentPending, sagsaTheme.vip);
  });
}

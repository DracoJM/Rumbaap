import 'dart:math' as math;
import 'dart:ui';

import '../../reservations/presentation/map/crystal_layout.dart';
import 'sagsa_venue.dart';

/// Distribución aprobada de Sagsa en «Noche de cristal» v7: lienzo de
/// 400 × 622, norte arriba. Ilustrativa: no son metros.
abstract final class SagsaLayout {
  static const westX = 30.0;
  static const eastX = 370.0;
  static const firstRowY = 140.0;
  static const rowPitch = 44.0;

  static final layout = CrystalLayout(
    size: const Size(400, 622),
    placements: {
      'VIP 1': _vip(const Offset(158, 38), badgeSide: -1, label: 'VIP1'),
      'VIP 2': _vip(const Offset(242, 38), badgeSide: 1, label: 'VIP2'),
      for (final (i, t)
          in sagsaVenue.tables.where((t) => t.zone == SagsaZones.west).indexed)
        t.id: _side(i, west: true, label: t.id.substring(1)),
      for (final (i, t)
          in sagsaVenue.tables.where((t) => t.zone == SagsaZones.east).indexed)
        t.id: _side(i, west: false, label: t.id.substring(1)),
    },
    vipDeck: const Rect.fromLTWH(104, 6, 192, 68),
    hallLabel: ('SALÓN PRINCIPAL', const Offset(200, 112)),
    danceFloor: const Rect.fromLTWH(105, 172, 190, 320),
    litTiles: const [
      (0, 1),
      (2, 5),
      (4, 0),
      (5, 6),
      (7, 1),
      (8, 5),
      (10, 0),
      (11, 4),
    ],
    bar: const Rect.fromLTWH(180, 235, 40, 206),
    djBooth: const Rect.fromLTWH(142, 560, 116, 56),
    access: const Rect.fromLTWH(306, 590, 86, 27),
    cornerSpeakers: true,
    sideWalls: (116, 560),
  );

  /// Mesa normal: su zona táctil es la franja completa (58 × 44), contigua
  /// con la vecina y sin solaparse.
  static TablePlacement _side(
    int index, {
    required bool west,
    required String label,
  }) {
    final center = Offset(west ? westX : eastX, firstRowY + rowPitch * index);
    return TablePlacement(
      center: center,
      rotation: west ? 0 : math.pi,
      hitRect: Rect.fromLTWH(
        center.dx - (west ? 24 : 34),
        center.dy - rowPitch / 2,
        58,
        rowPitch,
      ),
      badgeSide: west ? 1 : -1,
      label: label,
    );
  }

  /// Mesa VIP: sofá abierto hacia el salón (sur), icono hacia fuera.
  static TablePlacement _vip(
    Offset center, {
    required double badgeSide,
    required String label,
  }) => TablePlacement(
    center: center,
    rotation: math.pi / 2,
    hitRect: Rect.fromLTWH(center.dx - 36, center.dy - 30, 72, 58),
    badgeSide: badgeSide,
    label: label,
  );
}

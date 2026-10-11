import 'dart:math' as math;
import 'dart:ui';

import '../../reservations/domain/venue_table.dart';
import '../../reservations/presentation/venue_geometry.dart';

/// Plano del mapa del administrador («Noche de cristal» v7) en un lienzo
/// lógico de 400 × 622, norte arriba. Ilustrativo: no son metros.
///
/// Las mesas y sus zonas vienen de [VenueTables]; la orientación de los
/// sofás reutiliza [VenueGeometry.openingOf] para que ambos mapas coincidan.
abstract final class CrystalMapGeometry {
  static const Size size = Size(400, 622);

  static const double westX = 30;
  static const double eastX = 370;
  static const double firstRowY = 140;
  static const double rowPitch = 44;
  static const List<Offset> vipCenters = [Offset(158, 38), Offset(242, 38)];

  static const Rect vipDeck = Rect.fromLTWH(104, 6, 192, 68);
  static const Rect danceFloor = Rect.fromLTWH(105, 172, 190, 320);
  static const Rect bar = Rect.fromLTWH(180, 235, 40, 206);
  static const Rect djBooth = Rect.fromLTWH(142, 560, 116, 56);
  static const Rect access = Rect.fromLTWH(306, 590, 86, 27);

  /// Origen de la cuadrícula de baldosas de la pista y su paso.
  static const Offset tileOrigin = Offset(109, 176);
  static const double tilePitch = 26;

  /// Baldosas que se encienden: (fila, columna).
  static const List<(int, int)> litTiles = [
    (0, 1),
    (2, 5),
    (4, 0),
    (5, 6),
    (7, 1),
    (8, 5),
    (10, 0),
    (11, 4),
  ];

  static Offset centerOf(VenueTable table) {
    final index = VenueTables.inZone(table.zone).indexOf(table);
    return switch (table.zone) {
      TableZone.vip => vipCenters[index],
      TableZone.west => Offset(westX, firstRowY + rowPitch * index),
      TableZone.east => Offset(eastX, firstRowY + rowPitch * index),
    };
  }

  /// Ángulo del mueble: en orientación base la abertura del sofá mira a +x.
  static double rotationOf(VenueTable table) {
    final o = VenueGeometry.openingOf(table);
    return math.atan2(o.dy, o.dx);
  }

  /// Zona táctil en coordenadas del lienzo. Las normales ocupan su franja
  /// completa (58 × 44) para no solaparse con la vecina.
  static Rect hitRectOf(VenueTable table) {
    final c = centerOf(table);
    return switch (table.zone) {
      TableZone.vip => Rect.fromLTWH(c.dx - 36, c.dy - 30, 72, 58),
      TableZone.west => Rect.fromLTWH(c.dx - 24, c.dy - rowPitch / 2, 58, 44),
      TableZone.east => Rect.fromLTWH(c.dx - 34, c.dy - rowPitch / 2, 58, 44),
    };
  }
}

/// Medidas del mueble de una mesa, en unidades del lienzo.
class FurnitureSpec {
  const FurnitureSpec._({
    required this.disc,
    required this.clearance,
    required this.seatWidth,
    required this.backWidth,
    required this.armLength,
    required this.corner,
    required this.cushions,
  });

  static const regular = FurnitureSpec._(
    disc: 10,
    clearance: 2,
    seatWidth: 4.6,
    backWidth: 2.3,
    armLength: 6,
    corner: 5.5,
    cushions: 3,
  );

  static const vip = FurnitureSpec._(
    disc: 12.5,
    clearance: 2.5,
    seatWidth: 5.5,
    backWidth: 3,
    armLength: 8,
    corner: 7,
    cushions: 4,
  );

  static FurnitureSpec of(VenueTable table) => table.isVip ? vip : regular;

  final double disc;
  final double clearance;
  final double seatWidth;
  final double backWidth;
  final double armLength;
  final double corner;
  final int cushions;

  double get seatOffset => disc + clearance + seatWidth / 2;
  double get backOffset => seatOffset + seatWidth / 2 + backWidth / 2;
  double get outer => backOffset + backWidth / 2;
}

import 'dart:math' as math;
import 'dart:ui';

import '../domain/venue_table.dart';

/// Plano ilustrativo en unidades lógicas (1000 × 1100), norte arriba.
///
/// Las medidas son aproximadas y solo buscan que el recinto sea reconocible;
/// no son metros ni un plano arquitectónico. Adaptado del prototipo de
/// demostración Rumbaap × Sagsa.
abstract final class VenueGeometry {
  static const Size size = Size(1000, 1100);

  /// Muros interiores del salón principal.
  static const Rect hall = Rect.fromLTRB(20, 20, 980, 1080);

  /// Tarima VIP elevada sobre la pared norte.
  static const Rect vipDeck = Rect.fromLTRB(180, 20, 820, 236);

  /// Escalera de acceso a la tarima VIP.
  static const Rect vipStairs = Rect.fromLTRB(452, 150, 548, 236);

  /// Barra central, alargada de norte a sur.
  static const Rect bar = Rect.fromLTRB(436, 330, 564, 800);

  /// Escenario del DJ sobre la pared sur.
  static const Rect djStage = Rect.fromLTRB(340, 930, 660, 1080);

  /// Acceso a lobby y caja, esquina sur-oriental.
  static const Rect access = Rect.fromLTRB(830, 1016, 980, 1080);

  static const double westX = 84;
  static const double eastX = 916;
  static const double firstRowY = 126;
  static const double rowPitch = 92;
  static const List<double> vipX = [330, 670];
  static const double vipY = 112;

  /// Lado del cuadro que ocupa el mueble (sofá + mesa).
  static const double regularBox = 92;
  static const double vipBox = 184;

  static Offset centerOf(VenueTable table) {
    final index = VenueTables.inZone(table.zone).indexOf(table);
    return switch (table.zone) {
      TableZone.vip => Offset(vipX[index], vipY),
      TableZone.west => Offset(westX, firstRowY + rowPitch * index),
      TableZone.east => Offset(eastX, firstRowY + rowPitch * index),
    };
  }

  static double boxOf(VenueTable table) => table.isVip ? vipBox : regularBox;

  static Rect boundsOf(VenueTable table) => Rect.fromCenter(
    center: centerOf(table),
    width: boxOf(table),
    height: boxOf(table),
  );

  /// Rotación del mueble. En orientación base la abertura del sofá mira al
  /// sur; las mesas laterales giran para abrirse hacia el interior.
  static double rotationOf(VenueTable table) => switch (table.zone) {
    TableZone.vip => 0,
    TableZone.west => -math.pi / 2,
    TableZone.east => math.pi / 2,
  };

  /// Vector unitario hacia donde mira la abertura del sofá.
  static Offset openingOf(VenueTable table) {
    final angle = rotationOf(table) + math.pi / 2;
    return Offset(math.cos(angle), math.sin(angle));
  }
}

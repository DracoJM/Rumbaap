import 'package:flutter/painting.dart';

import '../../domain/venue_table.dart';

/// Distribución de un local para el mapa «Noche de cristal» (v7), en un
/// lienzo lógico que se escala al ancho disponible. La define la
/// configuración de cada local (`lib/features/venues/`); el componente del
/// mapa no conoce cuántas mesas hay ni dónde están.
///
/// Los elementos del recinto son opcionales: un local sin barra o sin
/// cabina de DJ simplemente no los declara.
class CrystalLayout {
  const CrystalLayout({
    required this.size,
    required this.placements,
    this.vipDeck,
    this.hallLabel,
    this.danceFloor,
    this.litTiles = const [],
    this.bar,
    this.djBooth,
    this.access,
    this.cornerSpeakers = false,
    this.sideWalls,
  });

  final Size size;

  /// Posición de cada mesa del local, por ID de mesa.
  final Map<String, TablePlacement> placements;

  /// Tarima VIP con baranda y gradas centrales.
  final Rect? vipDeck;

  /// Rótulo del salón y la línea base donde va.
  final (String, Offset)? hallLabel;

  /// Pista con baldosas de 24 cada 26 unidades.
  final Rect? danceFloor;

  /// Baldosas de la pista que se encienden: (fila, columna).
  final List<(int, int)> litTiles;
  final Rect? bar;

  /// Cabina del DJ, con platos, ecualizador, tira LED y dos haces de luz.
  final Rect? djBooth;
  final Rect? access;

  /// Arcos de neón y bafles en las esquinas superiores.
  final bool cornerSpeakers;

  /// Tramo vertical (desde, hasta) de las paredes laterales con luz.
  final (double, double)? sideWalls;

  static const tilePitch = 26.0;

  TablePlacement? placementOf(String tableId) => placements[tableId];

  /// Esquina superior izquierda de la baldosa (fila 0, columna 0).
  Offset get tileOrigin => danceFloor!.topLeft + const Offset(4, 4);
}

/// Dónde y cómo se dibuja una mesa en el lienzo.
class TablePlacement {
  const TablePlacement({
    required this.center,
    required this.rotation,
    required this.hitRect,
    required this.badgeSide,
    required this.label,
  });

  final Offset center;

  /// Ángulo del mueble: en orientación base la abertura del sofá mira a +x.
  final double rotation;

  /// Zona táctil en coordenadas del lienzo; no debe solaparse con otra.
  final Rect hitRect;

  /// Lado del icono de estado respecto al centro: 1 a la derecha, -1 a la
  /// izquierda.
  final double badgeSide;

  /// Texto dentro del disco de la mesa, por ejemplo «07».
  final String label;
}

/// Medidas del mueble según el tipo de mesa, en unidades del lienzo.
class FurnitureSpec {
  const FurnitureSpec._({
    required this.disc,
    required this.clearance,
    required this.seatWidth,
    required this.backWidth,
    required this.armLength,
    required this.corner,
    required this.cushions,
    required this.badgeMargin,
  });

  static const regular = FurnitureSpec._(
    disc: 10,
    clearance: 2,
    seatWidth: 4.6,
    backWidth: 2.3,
    armLength: 6,
    corner: 5.5,
    cushions: 3,
    badgeMargin: 5,
  );

  static const vip = FurnitureSpec._(
    disc: 12.5,
    clearance: 2.5,
    seatWidth: 5.5,
    backWidth: 3,
    armLength: 8,
    corner: 7,
    cushions: 4,
    badgeMargin: 7,
  );

  static FurnitureSpec of(VenueTable table) => table.isVip ? vip : regular;

  final double disc;
  final double clearance;
  final double seatWidth;
  final double backWidth;
  final double armLength;
  final double corner;
  final int cushions;

  /// Separación entre el respaldo y el icono de estado.
  final double badgeMargin;

  double get seatOffset => disc + clearance + seatWidth / 2;
  double get backOffset => seatOffset + seatWidth / 2 + backWidth / 2;
  double get outer => backOffset + backWidth / 2;

  /// Distancia del icono de estado al centro de la mesa.
  double get badgeGap => outer + badgeMargin;
}

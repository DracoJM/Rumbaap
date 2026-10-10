import 'package:flutter/material.dart';

import '../domain/night_availability.dart';
import '../domain/venue_table.dart';

/// Estado tal como lo muestra el mapa. [unknown] cubre carga, error y datos
/// faltantes: nunca se presenta como disponible.
enum TableMapStatus {
  available('Disponible', Icons.check_circle_rounded, Color(0xFF34D399)),
  reserved('Reservada', Icons.event_rounded, Color(0xFF60A5FA)),
  occupied('Ocupada', Icons.groups_rounded, Color(0xFFF472B6)),
  unknown('Sin información', Icons.help_outline_rounded, Color(0xFF8A839A));

  const TableMapStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static TableMapStatus from(TableAvailability? availability) =>
      switch (availability) {
        TableAvailability.available => available,
        TableAvailability.reserved => reserved,
        TableAvailability.occupied => occupied,
        null => unknown,
      };
}

extension VenueTableLabels on VenueTable {
  String get displayName => isVip ? id : 'Mesa $id';

  String get kindLabel => isVip ? 'Mesa VIP' : 'Mesa normal';

  String get zoneLabel => switch (zone) {
    TableZone.west => 'Lado occidental',
    TableZone.east => 'Lado oriental',
    TableZone.vip => 'Zona VIP elevada · norte',
  };
}

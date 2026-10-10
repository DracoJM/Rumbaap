import 'package:flutter/material.dart';

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/venue_table.dart';

/// Estado tal como lo muestra el mapa. [unknown] cubre carga, error y datos
/// faltantes: nunca se presenta como disponible.
///
/// Una reserva pendiente se muestra distinto según la mesa: en una normal está
/// «En proceso» (regla R1) y en una VIP, «Pendiente de pago» (regla R2).
/// Comparten el color ámbar; la distinción es visual y textual. Aquí no se
/// implementa la caducidad ni el pago.
enum TableMapStatus {
  available('Disponible', Icons.check_circle_rounded, Color(0xFF34D399)),
  pending('En proceso', Icons.hourglass_top_rounded, Color(0xFFFBBF24)),
  pendingPayment(
    'Pendiente de pago',
    Icons.payments_outlined,
    Color(0xFFFBBF24),
  ),
  reserved('Reservada', Icons.event_rounded, Color(0xFF60A5FA)),
  occupied('Ocupada', Icons.groups_rounded, Color(0xFFF472B6)),
  unknown('Sin información', Icons.help_outline_rounded, Color(0xFF8A839A));

  const TableMapStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static TableMapStatus from(
    TableAvailability? availability, {
    required VenueTable table,
  }) => switch (availability) {
    TableAvailability.available => available,
    TableAvailability.pending => table.isVip ? pendingPayment : pending,
    TableAvailability.reserved => reserved,
    TableAvailability.occupied => occupied,
    null => unknown,
  };

  /// Las reservas pendientes «respiran» en el mapa para llamar la atención.
  bool get isPending => this == pending || this == pendingPayment;
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

const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

extension NightLabels on Night {
  /// «Viernes 16 de octubre».
  String get label =>
      '${_weekdays[date.weekday - 1]} ${date.day} de ${_months[date.month - 1]}';

  /// «Vie 16 oct».
  String get shortLabel =>
      '${_weekdays[date.weekday - 1].substring(0, 3)} ${date.day} '
      '${_months[date.month - 1].substring(0, 3)}';
}

import 'package:flutter/material.dart';

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/venue_table.dart';
import '../../../theme/status_colors.dart';

/// Estado tal como lo muestra el mapa. [unknown] cubre carga, error y datos
/// faltantes: nunca se presenta como disponible.
///
/// Una reserva pendiente se muestra distinto según la mesa: en una normal está
/// «En proceso» (regla R1) y en una VIP, «Pendiente de pago» (regla R2). Aquí
/// no se implementa la caducidad ni el pago. Los colores salen de
/// [StatusColors] y los iconos de `map/status_icon.dart`: nunca dependen solo
/// del color.
enum TableMapStatus {
  available('Disponible', 'Disponibles'),
  pending('En proceso', 'En proceso'),
  pendingPayment('Pendiente de pago', 'Pago VIP'),
  reserved('Reservada', 'Reservadas'),
  occupied('Ocupada', 'Ocupadas'),
  unknown('Sin información', 'Sin info');

  const TableMapStatus(this.label, this.summaryLabel);

  final String label;

  /// Nombre en plural del resumen por estado.
  final String summaryLabel;

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

  bool get isPending => this == pending || this == pendingPayment;

  Color colorIn(StatusColors colors) => switch (this) {
    available => colors.available,
    pending => colors.inProgress,
    pendingPayment => colors.vipPaymentPending,
    reserved => colors.reserved,
    occupied => colors.occupied,
    unknown => colors.unknown,
  };
}

extension VenueTableLabels on VenueTable {
  String get displayName => isVip ? id : 'Mesa $id';

  String get kindLabel => isVip ? 'Mesa VIP' : 'Mesa normal';

  String get zoneLabel => zone.label;
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

  /// «8:30 p. m. – 3:00 a. m.», horario del local (hora de Colombia).
  String get scheduleLabel => '$opensLabel – ${_wallTime(closesAt)}';

  /// «8:30 p. m.».
  String get opensLabel => _wallTime(opensAt);
}

/// Hora del local de un instante real: «3:00 p. m.».
String venueTimeLabel(DateTime instant) => _wallTime(VenueTime.of(instant));

/// Fecha y hora del local de un instante real: «mié 7 oct, 3:00 p. m.».
String venueDateTimeLabel(DateTime instant) {
  final t = VenueTime.of(instant);
  return '${_weekdays[t.weekday - 1].substring(0, 3).toLowerCase()} '
      '${t.day} ${_months[t.month - 1].substring(0, 3)}, ${_wallTime(t)}';
}

/// [wall] ya está en hora del local (campos de un `DateTime` UTC).
String _wallTime(DateTime wall) {
  final h = wall.hour % 12 == 0 ? 12 : wall.hour % 12;
  final m = wall.minute.toString().padLeft(2, '0');
  return '$h:$m ${wall.hour < 12 ? 'a. m.' : 'p. m.'}';
}

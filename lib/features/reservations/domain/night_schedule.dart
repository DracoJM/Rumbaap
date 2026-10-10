/// Horario del establecimiento y noches que se pueden consultar.
/// Reglas N1–N6 de `docs/business-rules/reservas-y-noches.md`.
library;

/// Fuente de la hora actual; inyectable para que los tests no dependan de
/// la hora real.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();

/// Hora del establecimiento (Colombia, UTC−5 todo el año, sin horario de
/// verano). Se representa como un `DateTime` UTC cuyos campos son la hora
/// local del establecimiento, para no depender de la zona horaria del
/// dispositivo.
abstract final class VenueTime {
  static const utcOffset = Duration(hours: -5);

  static DateTime of(DateTime instant) => instant.toUtc().add(utcOffset);
}

/// Una noche de operación, identificada por la fecha en que abre.
class Night {
  Night(DateTime date) : date = DateTime.utc(date.year, date.month, date.day);

  /// Fecha de apertura, en hora del establecimiento.
  final DateTime date;

  String get id => '${date.year}-${_two(date.month)}-${_two(date.day)}';

  DateTime get opensAt => date.add(NightSchedule.opening);
  DateTime get closesAt => date.add(NightSchedule.closing);

  /// [venueNow] en hora del establecimiento (ver [VenueTime]).
  bool isInProgress(DateTime venueNow) =>
      !venueNow.isBefore(opensAt) && venueNow.isBefore(closesAt);

  bool hasEnded(DateTime venueNow) => !venueNow.isBefore(closesAt);

  @override
  bool operator ==(Object other) => other is Night && other.date == date;

  @override
  int get hashCode => date.hashCode;

  static String _two(int n) => n.toString().padLeft(2, '0');
}

abstract final class NightSchedule {
  /// Apertura a las 8:30 p. m.
  static const opening = Duration(hours: 20, minutes: 30);

  /// Cierre a las 3:00 a. m. del día siguiente.
  static const closing = Duration(days: 1, hours: 3);

  static const weekendDays = [
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  /// Lunes de la semana *operativa* de este mapa de consulta.
  ///
  /// Regla M1 del mapa de consulta: la semana cambia el lunes a las 03:00,
  /// cierre de la noche del domingo, y no a medianoche, para que la noche del
  /// domingo siga visible hasta que cierra. No aplica al futuro catálogo del
  /// cliente, que usa la semana calendario (regla N5).
  static DateTime currentWeekStart(DateTime venueNow) {
    final shifted = venueNow.subtract(const Duration(hours: 3));
    final day = DateTime.utc(shifted.year, shifted.month, shifted.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Noches de fin de semana de la semana operativa [weeksAhead] (0 = la
  /// en curso) para este mapa de consulta.
  ///
  /// Regla M2 del mapa de consulta: no incluye las noches ya terminadas. No
  /// impide un futuro historial del administrador.
  ///
  /// PENDIENTE (fuera de alcance): el catálogo del cliente (regla N5) se
  /// calculará con la semana calendario de lunes a domingo, sin reutilizar
  /// el desfase de 03:00 de [currentWeekStart].
  static List<Night> weekendNights(DateTime venueNow, {int weeksAhead = 0}) {
    assert(weeksAhead >= 0);
    return _weekend(
      currentWeekStart(venueNow).add(Duration(days: 7 * weeksAhead)),
    ).where((night) => !night.hasEnded(venueNow)).toList(growable: false);
  }

  /// Próximo instante en que cambia lo que muestra la consulta: una apertura
  /// (empieza una noche en curso) o un cierre (termina una noche, o la
  /// semana operativa al cerrar el domingo).
  static DateTime nextChange(DateTime venueNow) {
    final monday = currentWeekStart(venueNow);
    final candidates = [
      for (final night in [
        ..._weekend(monday),
        ..._weekend(monday.add(const Duration(days: 7))),
      ]) ...[night.opensAt, night.closesAt],
    ].where((t) => t.isAfter(venueNow));
    return candidates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  static List<Night> _weekend(DateTime monday) => [
    for (final weekday in weekendDays)
      Night(monday.add(Duration(days: weekday - DateTime.monday))),
  ];
}

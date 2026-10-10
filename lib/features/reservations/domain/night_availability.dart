import 'night_schedule.dart';

/// Estado de lectura de una mesa en una noche. Las transiciones entre
/// estados no pertenecen a esta consulta.
enum TableAvailability {
  available,

  /// Reserva en proceso (mesa normal) o pendiente de pago (VIP): la mesa
  /// queda bloqueada (regla R3).
  pending,
  reserved,

  /// Solo posible durante la noche en curso (regla N6).
  occupied,
}

/// Estados de las mesas en una noche concreta.
class NightAvailability {
  NightAvailability({
    required this.nightId,
    required Map<String, TableAvailability> byTableId,
    this.refreshAt,
  }) : _byTableId = Map.unmodifiable(byTableId);

  final String nightId;

  /// Instante real en que estos datos dejan de ser válidos sin intervención
  /// de nadie (p. ej. vence una reserva en proceso, R1). `null` si no hay.
  final DateTime? refreshAt;
  final Map<String, TableAvailability> _byTableId;

  /// `null` si no hay información de esa mesa: nunca se asume disponible.
  TableAvailability? statusOf(String tableId) => _byTableId[tableId];
}

/// Contrato de consulta de disponibilidad por noche. Hoy lo implementa un
/// adaptador de demostración; un adaptador con datos compartidos podrá
/// sustituirlo sin cambiar la presentación.
///
/// Las noches que se pueden consultar las define [NightSchedule], no el
/// repositorio.
abstract interface class NightAvailabilityRepository {
  Future<NightAvailability> availabilityFor(Night night);
}

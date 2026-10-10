/// Estado de lectura de una mesa en una noche. Las transiciones entre
/// estados no pertenecen a esta consulta.
enum TableAvailability { available, reserved, occupied }

/// Noche o evento que se puede consultar.
class Night {
  const Night({required this.id, required this.label});

  final String id;

  /// Texto para mostrar, por ejemplo «Viernes 16 de octubre».
  final String label;
}

/// Estados de las mesas en una noche concreta.
class NightAvailability {
  NightAvailability({
    required this.nightId,
    required Map<String, TableAvailability> byTableId,
  }) : _byTableId = Map.unmodifiable(byTableId);

  final String nightId;
  final Map<String, TableAvailability> _byTableId;

  /// `null` si no hay información de esa mesa: nunca se asume disponible.
  TableAvailability? statusOf(String tableId) => _byTableId[tableId];
}

/// Contrato de consulta de disponibilidad por noche. Hoy lo implementa un
/// adaptador de demostración; un adaptador con datos compartidos podrá
/// sustituirlo sin cambiar la presentación.
abstract interface class NightAvailabilityRepository {
  Future<List<Night>> listNights();

  Future<NightAvailability> availabilityFor(String nightId);
}

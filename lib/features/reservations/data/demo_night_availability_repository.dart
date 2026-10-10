import '../domain/night_availability.dart';
import '../domain/venue_table.dart';

/// Adaptador de desarrollo con DATOS DE DEMOSTRACIÓN ficticios.
///
/// Vive en memoria de este dispositivo: no comparte disponibilidad entre
/// dispositivos ni refleja la operación real del establecimiento.
class DemoNightAvailabilityRepository implements NightAvailabilityRepository {
  DemoNightAvailabilityRepository({
    this.latency = const Duration(milliseconds: 350),
  });

  /// Retardo simulado para que la carga sea visible durante el desarrollo.
  final Duration latency;

  static const _nights = [
    Night(id: 'demo-2026-10-16', label: 'Viernes 16 de octubre'),
    Night(id: 'demo-2026-10-17', label: 'Sábado 17 de octubre'),
  ];

  static const _reserved = {
    'demo-2026-10-16': {'VIP 1', 'M03', 'M05', 'M12', 'M18'},
    'demo-2026-10-17': {'VIP 2', 'M01', 'M02', 'M09', 'M14', 'M15', 'M20'},
  };

  static const _occupied = {
    'demo-2026-10-16': {'M07', 'M16'},
    'demo-2026-10-17': {'VIP 1', 'M05', 'M11'},
  };

  @override
  Future<List<Night>> listNights() async {
    await Future<void>.delayed(latency);
    return List.unmodifiable(_nights);
  }

  @override
  Future<NightAvailability> availabilityFor(String nightId) async {
    await Future<void>.delayed(latency);
    final reserved = _reserved[nightId];
    final occupied = _occupied[nightId];
    if (reserved == null || occupied == null) {
      throw StateError('Noche de demostración desconocida: $nightId');
    }
    return NightAvailability(
      nightId: nightId,
      byTableId: {
        for (final table in VenueTables.all)
          table.id: occupied.contains(table.id)
              ? TableAvailability.occupied
              : reserved.contains(table.id)
              ? TableAvailability.reserved
              : TableAvailability.available,
      },
    );
  }
}

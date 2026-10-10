import 'dart:math' as math;

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/venue_table.dart';

/// Adaptador de desarrollo con DATOS DE DEMOSTRACIÓN ficticios.
///
/// Vive en memoria de este dispositivo: no comparte disponibilidad entre
/// dispositivos ni refleja la operación real del establecimiento.
/// PENDIENTE (fuera de alcance): persistencia y datos compartidos (backend).
class DemoNightAvailabilityRepository implements NightAvailabilityRepository {
  DemoNightAvailabilityRepository({
    this.latency = const Duration(milliseconds: 350),
    Clock clock = systemClock,
  }) : _clock = clock;

  /// Retardo simulado para que la carga sea visible durante el desarrollo.
  final Duration latency;
  final Clock _clock;

  @override
  Future<NightAvailability> availabilityFor(Night night) async {
    await Future<void>.delayed(latency);
    final inProgress = night.isInProgress(VenueTime.of(_clock()));
    // Semilla por fecha: la misma noche muestra siempre los mismos datos.
    final random = math.Random(
      night.date.year * 10000 + night.date.month * 100 + night.date.day,
    );
    return NightAvailability(
      nightId: night.id,
      byTableId: {
        for (final table in VenueTables.all)
          table.id: _demoStatus(random.nextDouble(), inProgress: inProgress),
      },
    );
  }

  static TableAvailability _demoStatus(double r, {required bool inProgress}) {
    if (r < 0.08) return TableAvailability.pending;
    if (r < 0.35) {
      // Solo en la noche en curso puede haber mesas ocupadas (regla N6).
      return inProgress && r < 0.22
          ? TableAvailability.occupied
          : TableAvailability.reserved;
    }
    return TableAvailability.available;
  }
}

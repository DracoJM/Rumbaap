import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/data/demo_night_availability_repository.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';

import 'fakes.dart';

void main() {
  DemoNightAvailabilityRepository at(DateTime instant) =>
      DemoNightAvailabilityRepository(
        latency: Duration.zero,
        clock: () => instant,
      );

  Future<List<TableAvailability?>> statuses(
    DemoNightAvailabilityRepository repository,
    Night night,
  ) async {
    final result = await repository.availabilityFor(night);
    expect(result.nightId, night.id);
    return [for (final t in VenueTables.all) result.statusOf(t.id)];
  }

  test('cubre las 22 mesas y la misma noche da siempre lo mismo', () async {
    final repository = at(fixedClock());
    final night = Night(DateTime.utc(2026, 10, 16));
    final first = await statuses(repository, night);
    expect(first, everyElement(isNotNull));
    expect(await statuses(repository, night), first);
  });

  test('noches distintas tienen estados distintos', () async {
    final repository = at(fixedClock());
    expect(
      await statuses(repository, Night(DateTime.utc(2026, 10, 16))),
      isNot(await statuses(repository, Night(DateTime.utc(2026, 10, 17)))),
    );
  });

  test('en noches futuras no hay mesas ocupadas', () async {
    final repository = at(fixedClock());
    for (var day = 9; day <= 31; day++) {
      final night = Night(DateTime.utc(2026, 10, day));
      expect(
        await statuses(repository, night),
        isNot(contains(TableAvailability.occupied)),
        reason: night.id,
      );
    }
  });

  test('solo la noche en curso puede tener mesas ocupadas', () async {
    final friday = Night(DateTime.utc(2026, 10, 9));
    // Viernes 9 a las 11 p. m. en el local: noche en curso.
    final during = await statuses(at(venueInstant(2026, 10, 9, 23)), friday);
    final before = await statuses(at(venueInstant(2026, 10, 9, 18)), friday);
    expect(during, contains(TableAvailability.occupied));
    expect(before, isNot(contains(TableAvailability.occupied)));
  });
}

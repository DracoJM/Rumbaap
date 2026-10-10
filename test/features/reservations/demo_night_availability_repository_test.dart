import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/data/demo_night_availability_repository.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';

void main() {
  final repository = DemoNightAvailabilityRepository(latency: Duration.zero);

  test('ofrece dos noches distintas', () async {
    final nights = await repository.listNights();
    expect(nights, hasLength(2));
    expect(nights.map((n) => n.id).toSet(), hasLength(2));
  });

  test('cada noche cubre las 22 mesas y alguna mesa difiere', () async {
    final nights = await repository.listNights();
    final first = await repository.availabilityFor(nights[0].id);
    final second = await repository.availabilityFor(nights[1].id);

    expect(first.nightId, nights[0].id);
    expect(second.nightId, nights[1].id);
    for (final table in VenueTables.all) {
      expect(first.statusOf(table.id), isNotNull);
      expect(second.statusOf(table.id), isNotNull);
    }
    expect(
      VenueTables.all.any((t) => first.statusOf(t.id) != second.statusOf(t.id)),
      isTrue,
    );
  });

  test('una noche desconocida es un error', () {
    expect(repository.availabilityFor('no-existe'), throwsStateError);
  });
}

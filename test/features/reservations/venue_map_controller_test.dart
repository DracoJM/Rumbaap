import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/presentation/venue_map_controller.dart';

import 'fakes.dart';

void main() {
  late ControlledRepository repository;
  late VenueMapController controller;

  setUp(() async {
    repository = ControlledRepository();
    controller = VenueMapController(
      repository,
      venue: sagsaVenue,
      clock: fixedClock,
    );
    controller.start();
    await pumpEventQueue();
  });

  tearDown(() => controller.dispose());

  test('muestra el fin de semana en curso y consulta su primera noche', () {
    expect(controller.weeksAhead, 0);
    expect(controller.nights.map((n) => n.id), [
      '2026-10-09',
      '2026-10-10',
      '2026-10-11',
    ]);
    expect(controller.night?.id, nightA);
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('dos noches conservan estados independientes', () async {
    repository
        .request(nightA)
        .complete(availability(nightA, {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);

    controller.selectNight(nightB);
    repository
        .request(nightB)
        .complete(availability(nightB, {'M01': TableAvailability.occupied}));
    await pumpEventQueue();
    expect(controller.night?.id, nightB);
    expect(controller.availabilityOf('M01'), TableAvailability.occupied);

    controller.selectNight(nightA);
    repository
        .request(nightA, nth: 1)
        .complete(availability(nightA, {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('cambiar de noche limpia la selección y los datos anteriores', () async {
    repository
        .request(nightA)
        .complete(availability(nightA, {'M05': TableAvailability.available}));
    await pumpEventQueue();
    controller.toggleTable('M05');
    expect(controller.selectedTableId, 'M05');

    controller.selectNight(nightB);
    expect(controller.selectedTableId, isNull);
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M05'), isNull);
  });

  test('una respuesta tardía no sobrescribe la noche actual', () async {
    controller.selectNight(nightB);
    // Llega la respuesta de la noche A después de haber cambiado a B.
    repository
        .request(nightA)
        .complete(availability(nightA, {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.night?.id, nightB);
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M01'), isNull);

    repository
        .request(nightB)
        .complete(availability(nightB, {'M01': TableAvailability.occupied}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.occupied);
  });

  test('un error tardío de otra noche no afecta a la actual', () async {
    controller.selectNight(nightB);
    repository
        .request(nightB)
        .complete(availability(nightB, {'M01': TableAvailability.reserved}));
    repository.request(nightA).completeError(Exception('red'));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.ready);
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('si falla la consulta no se usan datos de otra noche', () async {
    repository
        .request(nightA)
        .complete(availability(nightA, {'M01': TableAvailability.available}));
    await pumpEventQueue();

    controller.selectNight(nightB);
    repository.request(nightB).completeError(Exception('sin conexión'));
    await pumpEventQueue();

    expect(controller.night?.id, nightB);
    expect(controller.availabilityStatus, LoadStatus.failed);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('una respuesta etiquetada con otra noche se trata como error', () async {
    repository
        .request(nightA)
        .complete(availability(nightB, {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.failed);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('una mesa sin dato queda sin información, no disponible', () async {
    repository
        .request(nightA)
        .complete(availability(nightA, {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M02'), isNull);
  });

  test('reintentar vuelve a consultar la noche actual', () async {
    repository.request(nightA).completeError(Exception('red'));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.failed);

    controller.retry();
    repository
        .request(nightA, nth: 1)
        .complete(availability(nightA, {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.ready);
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('seleccionar y deseleccionar no cambia la disponibilidad', () async {
    repository
        .request(nightA)
        .complete(availability(nightA, {'M01': TableAvailability.reserved}));
    await pumpEventQueue();

    controller.toggleTable('M01');
    expect(controller.selectedTableId, 'M01');
    controller.toggleTable('M01');
    expect(controller.selectedTableId, isNull);
    controller.toggleTable('VIP 2');
    controller.clearSelection();
    expect(controller.selectedTableId, isNull);
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('ignora IDs de mesa inexistentes', () {
    controller.toggleTable('M99');
    expect(controller.selectedTableId, isNull);
  });

  test(
    'navegar a fines de semana futuros limpia selección y consulta',
    () async {
      controller.toggleTable('M01');

      // Se cambia de semana antes de que responda la consulta de la noche A.
      controller.showWeek(1);
      expect(controller.weeksAhead, 1);
      expect(controller.nights.map((n) => n.id), [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
      ]);
      expect(controller.night?.id, '2026-10-16');
      expect(controller.selectedTableId, isNull);
      expect(controller.availabilityOf('M01'), isNull);

      // La respuesta tardía de la semana anterior no contamina la nueva.
      repository
          .request(nightA)
          .complete(availability(nightA, {'M01': TableAvailability.reserved}));
      repository
          .request('2026-10-16')
          .complete(
            availability('2026-10-16', {'M01': TableAvailability.available}),
          );
      await pumpEventQueue();
      expect(controller.availabilityOf('M01'), TableAvailability.available);
    },
  );

  test('no se navega a fines de semana pasados', () {
    controller.showWeek(-1);
    expect(controller.weeksAhead, 0);
    expect(controller.night?.id, nightA);
  });

  group('paso del tiempo', () {
    late DateTime now;
    late ControlledRepository repo;
    late VenueMapController c;

    void startAt(DateTime instant) {
      now = instant;
      repo = ControlledRepository();
      c = VenueMapController(repo, venue: sagsaVenue, clock: () => now)
        ..start();
    }

    tearDown(() => c.dispose());

    test('al cerrar la noche en curso no conserva su ocupación', () async {
      startAt(venueInstant(2026, 10, 9, 23));
      repo
          .request(nightA)
          .complete(availability(nightA, {'M01': TableAvailability.occupied}));
      await pumpEventQueue();
      expect(c.availabilityOf('M01'), TableAvailability.occupied);

      now = venueInstant(2026, 10, 10, 3);
      c.refresh();
      expect(c.nights.map((n) => n.id), [nightB, '2026-10-11']);
      expect(c.night?.id, nightB);
      expect(c.availabilityOf('M01'), isNull);
    });

    test(
      'al abrir vuelve a consultar la misma noche y conserva la mesa',
      () async {
        startAt(venueInstant(2026, 10, 9, 20));
        repo
            .request(nightA)
            .complete(
              availability(nightA, {'M01': TableAvailability.reserved}),
            );
        await pumpEventQueue();
        c.toggleTable('M01');

        now = venueInstant(2026, 10, 9, 20, 30);
        c.refresh();
        expect(c.night?.id, nightA);
        expect(c.selectedTableId, 'M01');
        expect(c.availabilityStatus, LoadStatus.loading);

        repo
            .request(nightA, nth: 1)
            .complete(
              availability(nightA, {'M01': TableAvailability.occupied}),
            );
        await pumpEventQueue();
        expect(c.availabilityOf('M01'), TableAvailability.occupied);
      },
    );

    test('una respuesta anterior al refresco no la sobrescribe', () async {
      startAt(venueInstant(2026, 10, 9, 23));
      c.refresh();
      repo
          .request(nightA, nth: 1)
          .complete(availability(nightA, {'M01': TableAvailability.available}));
      repo
          .request(nightA)
          .complete(availability(nightA, {'M01': TableAvailability.occupied}));
      await pumpEventQueue();
      expect(c.availabilityOf('M01'), TableAvailability.available);
    });
  });

  group('cambios de datos', () {
    late ChangeNotifier changes;
    late ControlledRepository repo;
    late VenueMapController c;

    setUp(() async {
      changes = ChangeNotifier();
      repo = ControlledRepository();
      c = VenueMapController(
        repo,
        venue: sagsaVenue,
        clock: fixedClock,
        changes: changes,
      )..start();
      repo
          .request(nightA)
          .complete(availability(nightA, {'M01': TableAvailability.available}));
      await pumpEventQueue();
      c.toggleTable('M01');
    });

    tearDown(() {
      c.dispose();
      changes.dispose();
    });

    test('vuelve a consultar conservando los datos y la mesa hasta que '
        'llega la respuesta', () async {
      changes.notifyListeners();
      expect(c.isRefreshing, isTrue);
      expect(c.availabilityOf('M01'), TableAvailability.available);
      expect(c.selectedTableId, 'M01');

      repo
          .request(nightA, nth: 1)
          .complete(availability(nightA, {'M01': TableAvailability.reserved}));
      await pumpEventQueue();
      expect(c.isRefreshing, isFalse);
      expect(c.availabilityOf('M01'), TableAvailability.reserved);
      expect(c.selectedTableId, 'M01');
    });

    test(
      'una respuesta anterior a un nuevo cambio no la sobrescribe',
      () async {
        changes.notifyListeners();
        changes.notifyListeners();
        repo
            .request(nightA, nth: 2)
            .complete(
              availability(nightA, {'M01': TableAvailability.reserved}),
            );
        repo
            .request(nightA, nth: 1)
            .complete(availability(nightA, {'M01': TableAvailability.pending}));
        await pumpEventQueue();
        expect(c.availabilityOf('M01'), TableAvailability.reserved);
      },
    );

    test('al cambiar de noche se descarta la recarga de la anterior', () async {
      changes.notifyListeners();
      c.selectNight(nightB);
      repo
          .request(nightA, nth: 1)
          .complete(availability(nightA, {'M01': TableAvailability.reserved}));
      await pumpEventQueue();
      expect(c.night?.id, nightB);
      expect(c.availabilityStatus, LoadStatus.loading);
      expect(c.isRefreshing, isFalse);
    });

    test('al disponerse deja de escuchar los cambios', () async {
      final queries = repo.pending.length;
      c.dispose();
      changes.notifyListeners();
      expect(repo.pending, hasLength(queries));
      // tearDown vuelve a llamar a dispose: se sustituye por uno nuevo.
      c = VenueMapController(repo, venue: sagsaVenue, clock: fixedClock);
    });
  });
}

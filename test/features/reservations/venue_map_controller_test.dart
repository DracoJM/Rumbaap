import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/presentation/venue_map_controller.dart';

import 'fakes.dart';

void main() {
  late ControlledRepository repository;
  late VenueMapController controller;

  setUp(() async {
    repository = ControlledRepository();
    controller = VenueMapController(repository);
    controller.loadNights();
    await pumpEventQueue();
  });

  tearDown(() => controller.dispose());

  test('carga las noches y consulta la primera', () {
    expect(controller.nightsStatus, LoadStatus.ready);
    expect(controller.nights.map((n) => n.id), ['a', 'b']);
    expect(controller.night?.id, 'a');
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('dos noches conservan estados independientes', () async {
    repository
        .request('a')
        .complete(availability('a', {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);

    controller.selectNight('b');
    repository
        .request('b')
        .complete(availability('b', {'M01': TableAvailability.occupied}));
    await pumpEventQueue();
    expect(controller.night?.id, 'b');
    expect(controller.availabilityOf('M01'), TableAvailability.occupied);

    controller.selectNight('a');
    repository
        .request('a', nth: 1)
        .complete(availability('a', {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('cambiar de noche limpia la selección y los datos anteriores', () async {
    repository
        .request('a')
        .complete(availability('a', {'M05': TableAvailability.available}));
    await pumpEventQueue();
    controller.toggleTable('M05');
    expect(controller.selectedTableId, 'M05');

    controller.selectNight('b');
    expect(controller.selectedTableId, isNull);
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M05'), isNull);
  });

  test('una respuesta tardía no sobrescribe la noche actual', () async {
    controller.selectNight('b');
    // Llega la respuesta de la noche A después de haber cambiado a B.
    repository
        .request('a')
        .complete(availability('a', {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.night?.id, 'b');
    expect(controller.availabilityStatus, LoadStatus.loading);
    expect(controller.availabilityOf('M01'), isNull);

    repository
        .request('b')
        .complete(availability('b', {'M01': TableAvailability.occupied}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M01'), TableAvailability.occupied);
  });

  test('un error tardío de otra noche no afecta a la actual', () async {
    controller.selectNight('b');
    repository
        .request('b')
        .complete(availability('b', {'M01': TableAvailability.reserved}));
    repository.request('a').completeError(Exception('red'));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.ready);
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('si falla la consulta no se usan datos de otra noche', () async {
    repository
        .request('a')
        .complete(availability('a', {'M01': TableAvailability.available}));
    await pumpEventQueue();

    controller.selectNight('b');
    repository.request('b').completeError(Exception('sin conexión'));
    await pumpEventQueue();

    expect(controller.night?.id, 'b');
    expect(controller.availabilityStatus, LoadStatus.failed);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('una respuesta etiquetada con otra noche se trata como error', () async {
    repository
        .request('a')
        .complete(availability('b', {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.failed);
    expect(controller.availabilityOf('M01'), isNull);
  });

  test('una mesa sin dato queda sin información, no disponible', () async {
    repository
        .request('a')
        .complete(availability('a', {'M01': TableAvailability.available}));
    await pumpEventQueue();
    expect(controller.availabilityOf('M02'), isNull);
  });

  test('reintentar vuelve a consultar la noche actual', () async {
    repository.request('a').completeError(Exception('red'));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.failed);

    controller.retry();
    repository
        .request('a', nth: 1)
        .complete(availability('a', {'M01': TableAvailability.reserved}));
    await pumpEventQueue();
    expect(controller.availabilityStatus, LoadStatus.ready);
    expect(controller.availabilityOf('M01'), TableAvailability.reserved);
  });

  test('seleccionar y deseleccionar no cambia la disponibilidad', () async {
    repository
        .request('a')
        .complete(availability('a', {'M01': TableAvailability.reserved}));
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

  test('si fallan las noches lo informa sin elegir ninguna', () async {
    final failing = _FailingNights();
    final c = VenueMapController(failing);
    addTearDown(c.dispose);
    await c.loadNights();
    expect(c.nightsStatus, LoadStatus.failed);
    expect(c.night, isNull);
  });
}

class _FailingNights extends ControlledRepository {
  @override
  Future<List<Night>> listNights() async => throw Exception('sin conexión');
}

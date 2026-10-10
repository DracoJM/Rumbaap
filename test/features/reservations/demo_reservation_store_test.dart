import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';

import 'fakes.dart';

void main() {
  DemoReservationStore storeAt(DateTime instant) =>
      DemoReservationStore(latency: Duration.zero, clock: () => instant);

  Future<List<TableAvailability?>> statuses(
    DemoReservationStore store,
    Night night,
  ) async {
    final result = await store.availabilityFor(night);
    expect(result.nightId, night.id);
    return [for (final t in VenueTables.all) result.statusOf(t.id)];
  }

  final friday = Night(DateTime.utc(2026, 10, 9));

  test('cubre las 22 mesas y la misma fecha siembra lo mismo', () async {
    final night = Night(DateTime.utc(2026, 10, 16));
    final a = await statuses(storeAt(fixedClock()), night);
    expect(a, everyElement(isNotNull));
    expect(await statuses(storeAt(fixedClock()), night), a);
  });

  test('noches distintas tienen estados distintos', () async {
    final store = storeAt(fixedClock());
    expect(
      await statuses(store, Night(DateTime.utc(2026, 10, 16))),
      isNot(await statuses(store, Night(DateTime.utc(2026, 10, 17)))),
    );
  });

  test('en noches futuras no hay mesas ocupadas', () async {
    final store = storeAt(fixedClock());
    for (var day = 9; day <= 31; day++) {
      final night = Night(DateTime.utc(2026, 10, day));
      expect(
        await statuses(store, night),
        isNot(contains(TableAvailability.occupied)),
        reason: night.id,
      );
    }
  });

  test('solo la noche en curso puede tener llegadas sembradas', () async {
    final during = await statuses(
      storeAt(venueInstant(2026, 10, 9, 23)),
      friday,
    );
    expect(during, contains(TableAvailability.occupied));
  });

  test('el mapa lee la misma fuente que las operaciones de reserva', () async {
    final store = storeAt(fixedClock());
    await store.availabilityFor(friday);
    final free = VenueTables.all.firstWhere(
      (t) => store.book.activeFor(friday, t.id) == null,
    );
    store.book.createDirect(
      night: friday,
      tableId: free.id,
      holder: const ReservationHolder(
        name: 'Titular demo X',
        idNumber: '0',
        phone: '0',
      ),
    );
    final after = await store.availabilityFor(friday);
    expect(after.statusOf(free.id), TableAvailability.reserved);
  });

  test(
    'VIP pendiente de pago y normal en proceso se ven como pendiente',
    () async {
      final store = storeAt(fixedClock());
      final pending = (await statuses(
        store,
        friday,
      )).where((s) => s == TableAvailability.pending);
      // La siembra deja al menos la normal en proceso.
      expect(pending, isNotEmpty);
      final inProcess = store.book
          .forNight(friday)
          .where((r) => r.status == ReservationStatus.inProcess);
      expect(inProcess, hasLength(1));
    },
  );

  test('refreshAt anuncia el vencimiento de la reserva en proceso', () async {
    var now = fixedClock();
    final store = DemoReservationStore(
      latency: Duration.zero,
      clock: () => now,
    );
    final first = await store.availabilityFor(friday);
    expect(first.refreshAt, now.add(const Duration(minutes: 10)));
    final table = store.book
        .forNight(friday)
        .firstWhere((r) => r.status == ReservationStatus.inProcess)
        .tableId;
    expect(first.statusOf(table), TableAvailability.pending);

    now = now.add(const Duration(minutes: 10));
    final after = await store.availabilityFor(friday);
    expect(after.statusOf(table), TableAvailability.available);
    expect(after.refreshAt, isNull);
  });

  test('volver a consultar no vuelve a sembrar ni pierde cambios', () async {
    final store = storeAt(fixedClock());
    await store.availabilityFor(friday);
    final count = store.book.forNight(friday).length;
    final r = store.book
        .forNight(friday)
        .firstWhere((r) => r.status == ReservationStatus.confirmed);
    store.book.revoke(r.id);
    await store.availabilityFor(friday);
    expect(store.book.forNight(friday), hasLength(count));
    expect(store.book.byId(r.id)!.status, ReservationStatus.revoked);
  });

  group('siembra con actividad previa (A1)', () {
    // Texto para comparar el historial completo por valor.
    String events(Reservation r) =>
        [for (final e in r.history) '${e.type.name}@${e.at}'].join(', ');

    test('reservas creadas antes de la primera consulta se conservan y la '
        'siembra no rellena sus mesas', () async {
      final store = storeAt(fixedClock());
      final night = Night(DateTime.utc(2026, 10, 16));
      final normals = VenueTables.all.where((t) => !t.isVip).toList();
      expect(normals, hasLength(20));
      final created = [
        for (final (i, t) in normals.indexed)
          store.book.createDirect(
            night: night,
            tableId: t.id,
            holder: ReservationHolder(
              name: 'Titular previo $i',
              idNumber: '1$i',
              phone: '2$i',
            ),
          ),
      ];
      store.book.revoke(created[0].id);
      store.book.release(created[1].id);
      final before = {
        for (final r in store.book.forNight(night))
          r.id: (r.tableId, r.holder.name, r.status, events(r)),
      };

      final result = await store.availabilityFor(night);
      await store.availabilityFor(night);

      final after = {
        for (final r in store.book.forNight(night))
          r.id: (r.tableId, r.holder.name, r.status, events(r)),
      };
      expect(after, before);
      expect(result.statusOf(normals[0].id), TableAvailability.available);
      expect(result.statusOf(normals[1].id), TableAvailability.available);
      expect(result.statusOf(normals[2].id), TableAvailability.reserved);
    });

    test('una noche nueva sin actividad recibe datos ficticios y no se '
        'vuelve a sembrar', () async {
      final store = storeAt(fixedClock());
      final busy = Night(DateTime.utc(2026, 10, 16));
      final fresh = Night(DateTime.utc(2026, 10, 17));
      store.book.createDirect(
        night: busy,
        tableId: VenueTables.all.first.id,
        holder: const ReservationHolder(
          name: 'Titular previo',
          idNumber: '1',
          phone: '2',
        ),
      );
      await store.availabilityFor(busy);

      final first = await statuses(store, fresh);
      final seeded = store.book.forNight(fresh).length;
      expect(seeded, greaterThan(0));
      // Mismos datos que un almacén sin actividad en otras noches.
      expect(await statuses(storeAt(fixedClock()), fresh), first);
      await store.availabilityFor(fresh);
      expect(store.book.forNight(fresh), hasLength(seeded));
    });
  });

  test('una consulta que cruza el vencimiento nunca deja «pendiente» sin '
      'actualización obligada (A2)', () async {
    // Reloj monotónico que avanza en cada lectura, de modo que la consulta
    // cruza el vencimiento en algún punto. Se prueban varios puntos de
    // partida para no depender del número de lecturas internas.
    for (var offset = 0; offset <= 60; offset++) {
      var now = fixedClock();
      var ticking = false;
      final store = DemoReservationStore(
        latency: Duration.zero,
        clock: () {
          if (ticking) now = now.add(const Duration(milliseconds: 1));
          return now;
        },
      );
      await store.availabilityFor(friday);
      final inProcess = store.book
          .forNight(friday)
          .firstWhere((r) => r.status == ReservationStatus.inProcess);
      final deadline = inProcess.createdAt.add(const Duration(minutes: 10));

      now = deadline.subtract(Duration(milliseconds: offset));
      ticking = true;
      final result = await store.availabilityFor(friday);
      ticking = false;

      if (result.statusOf(inProcess.tableId) == TableAvailability.pending) {
        expect(result.refreshAt, isNotNull, reason: 'offset $offset ms');
        expect(
          result.refreshAt!.isAfter(deadline),
          isFalse,
          reason: 'offset $offset ms',
        );
      }
    }
  });
}

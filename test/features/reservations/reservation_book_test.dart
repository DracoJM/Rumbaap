import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/domain/reservation_book.dart';

import 'fakes.dart';

void main() {
  late DateTime now;
  late ReservationBook book;

  final friday = Night(DateTime.utc(2026, 10, 9));
  final saturday = Night(DateTime.utc(2026, 10, 10));

  const client = ReservationHolder(name: 'Titular demo A', idNumber: '0001');
  const direct = ReservationHolder(
    name: 'Titular demo B',
    idNumber: '0002',
    phone: '0003',
  );

  setUp(() {
    // Miércoles 7 de octubre, 3:00 p. m. en el local.
    now = wednesdayAfternoon;
    book = ReservationBook(venue: sagsaVenue, clock: () => now);
  });

  Reservation requestNormal(Night night, String table) => book.requestNormal(
    night: night,
    tableId: table,
    holder: client,
    origin: ReservationOrigin.client,
  );

  Reservation requestVip(Night night, String table) => book.requestVip(
    night: night,
    tableId: table,
    holder: client,
    origin: ReservationOrigin.promoter,
  );

  Matcher throwsReservation(ReservationError error) => throwsA(
    isA<ReservationException>().having((e) => e.error, 'error', error),
  );

  group('exclusividad por mesa y noche (R3)', () {
    test('una reserva activa bloquea esa mesa en esa noche', () {
      requestNormal(friday, 'M01');
      expect(
        () => requestNormal(friday, 'M01'),
        throwsReservation(ReservationError.tableTaken),
      );
      expect(
        () => book.createDirect(night: friday, tableId: 'M01', holder: direct),
        throwsReservation(ReservationError.tableTaken),
      );
    });

    test('no afecta a otras mesas ni a otras noches', () {
      requestNormal(friday, 'M01');
      requestVip(friday, 'VIP 1');
      expect(requestNormal(friday, 'M02').status, ReservationStatus.inProcess);
      expect(
        requestNormal(saturday, 'M01').status,
        ReservationStatus.inProcess,
      );
      expect(
        requestVip(saturday, 'VIP 1').status,
        ReservationStatus.pendingPayment,
      );
      expect(book.activeFor(friday, 'M01')!.night, friday);
      expect(book.activeFor(saturday, 'M01')!.night, saturday);
    });

    test('una reserva terminada libera la mesa para otra solicitud', () {
      final r = book.createDirect(
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      book.revoke(r.id);
      expect(requestNormal(friday, 'M01').status, ReservationStatus.inProcess);
    });

    test('el tipo de mesa debe corresponder a la operación', () {
      expect(
        () => requestNormal(friday, 'VIP 1'),
        throwsReservation(ReservationError.wrongTableKind),
      );
      expect(
        () => requestVip(friday, 'M01'),
        throwsReservation(ReservationError.wrongTableKind),
      );
      expect(
        () => requestNormal(friday, 'M99'),
        throwsReservation(ReservationError.unknownTable),
      );
    });

    test('no se reserva en una noche terminada', () {
      now = venueInstant(2026, 10, 10, 3);
      expect(
        () => requestNormal(friday, 'M01'),
        throwsReservation(ReservationError.nightEnded),
      );
    });
  });

  group('mesa normal en proceso (R1)', () {
    test('sigue en proceso y bloqueando justo antes de los 10 min', () {
      final r = requestNormal(friday, 'M01');
      now = now.add(const Duration(minutes: 10) - const Duration(seconds: 1));
      expect(book.byId(r.id)!.status, ReservationStatus.inProcess);
      expect(
        () => requestNormal(friday, 'M01'),
        throwsReservation(ReservationError.tableTaken),
      );
    });

    test('expira exactamente a los 10 min si sigue incompleta', () {
      final r = requestNormal(friday, 'M01');
      now = now.add(ReservationBook.inProcessTimeout);
      final expired = book.byId(r.id)!;
      expect(expired.status, ReservationStatus.expired);
      expect(expired.history.last.type, ReservationEventType.expired);
      expect(
        expired.history.last.at,
        r.createdAt.add(ReservationBook.inProcessTimeout),
      );
      expect(book.activeFor(friday, 'M01'), isNull);
      expect(
        () => book.completeRequest(r.id),
        throwsReservation(ReservationError.invalidTransition),
      );
    });

    test('al completarse se confirma y ya no vence por el temporizador', () {
      final r = requestNormal(friday, 'M01');
      now = now.add(const Duration(minutes: 9));
      expect(book.completeRequest(r.id).status, ReservationStatus.confirmed);
      now = now.add(const Duration(days: 1));
      expect(book.byId(r.id)!.status, ReservationStatus.confirmed);
    });

    test('que pasen 10 min no confirma la reserva', () {
      final r = requestNormal(friday, 'M01');
      now = now.add(const Duration(minutes: 30));
      expect(book.byId(r.id)!.status, isNot(ReservationStatus.confirmed));
    });

    test('nextExpiry indica cuándo vence la primera en proceso', () {
      expect(book.nextExpiry(friday), isNull);
      final r = requestNormal(friday, 'M01');
      expect(
        book.nextExpiry(friday),
        r.createdAt.add(ReservationBook.inProcessTimeout),
      );
      expect(book.nextExpiry(saturday), isNull);
    });
  });

  group('mesa VIP (R2, R7)', () {
    test('la solicitada sigue pendiente de pago pasados 10 min y días', () {
      final r = requestVip(friday, 'VIP 1');
      now = now.add(const Duration(minutes: 10));
      expect(book.byId(r.id)!.status, ReservationStatus.pendingPayment);
      now = now.add(const Duration(days: 2));
      expect(book.byId(r.id)!.status, ReservationStatus.pendingPayment);
      expect(book.nextExpiry(friday), isNull);
    });

    test('el prepago marcado a mano la confirma', () {
      final r = requestVip(friday, 'VIP 1');
      final confirmed = book.markPrepaymentReceived(r.id);
      expect(confirmed.status, ReservationStatus.confirmed);
      expect(confirmed.history.map((e) => e.type), [
        ReservationEventType.requested,
        ReservationEventType.prepaymentMarked,
      ]);
    });

    test('el rechazo la anula y libera la mesa, con traza de rechazo', () {
      final r = requestVip(friday, 'VIP 1');
      final rejected = book.rejectRequest(r.id);
      expect(rejected.status, ReservationStatus.revoked);
      expect(rejected.history.last.type, ReservationEventType.rejected);
      expect(book.activeFor(friday, 'VIP 1'), isNull);
    });

    test('la directa del administrador queda confirmada desde el inicio', () {
      final r = book.createDirect(
        night: friday,
        tableId: 'VIP 2',
        holder: direct,
      );
      expect(r.status, ReservationStatus.confirmed);
      expect(r.origin, ReservationOrigin.admin);
      expect(r.history.single.type, ReservationEventType.createdDirect);
      expect(
        () => book.markPrepaymentReceived(r.id),
        throwsReservation(ReservationError.invalidTransition),
      );
    });
  });

  group('titular de la reserva directa (R7)', () {
    void expectInvalid(ReservationHolder holder) => expect(
      () => book.createDirect(night: friday, tableId: 'M01', holder: holder),
      throwsReservation(ReservationError.invalidHolder),
    );

    test('nombre, cédula y teléfono son obligatorios', () {
      expectInvalid(
        const ReservationHolder(name: ' ', idNumber: '1', phone: '2'),
      );
      expectInvalid(const ReservationHolder(name: 'A', phone: '2'));
      expectInvalid(const ReservationHolder(name: 'A', idNumber: '1'));
    });

    test('cédula y teléfono solo admiten dígitos, sin límite de longitud', () {
      expectInvalid(
        const ReservationHolder(name: 'A', idNumber: '1.0', phone: '2'),
      );
      expectInvalid(
        const ReservationHolder(name: 'A', idNumber: '1', phone: '+57'),
      );
      expect(
        book
            .createDirect(
              night: friday,
              tableId: 'M01',
              holder: const ReservationHolder(
                name: 'A',
                idNumber: '1',
                phone: '2',
              ),
            )
            .status,
        ReservationStatus.confirmed,
      );
      expect(book.activeFor(friday, 'M01'), isNotNull);
    });
  });

  group('llegada (R5, N6)', () {
    late Reservation reserved;

    setUp(() {
      reserved = book.createDirect(
        night: friday,
        tableId: 'M05',
        holder: direct,
      );
    });

    test('fuera del horario de la noche no se registra', () {
      for (final instant in [
        wednesdayAfternoon,
        venueInstant(2026, 10, 9, 20, 29),
        venueInstant(2026, 10, 10, 3),
      ]) {
        now = instant;
        expect(
          () => book.markArrival(reserved.id),
          throwsReservation(ReservationError.outsideNight),
        );
      }
      expect(book.byId(reserved.id)!.status, ReservationStatus.confirmed);
    });

    test('dentro del horario pasa de reservada a ocupada', () {
      now = venueInstant(2026, 10, 9, 20, 30);
      expect(book.markArrival(reserved.id).status, ReservationStatus.seated);
    });

    test('la apertura no registra la llegada sola', () {
      now = venueInstant(2026, 10, 9, 23);
      expect(book.byId(reserved.id)!.status, ReservationStatus.confirmed);
    });

    test('solo una reserva confirmada puede registrar llegada', () {
      now = venueInstant(2026, 10, 9, 23);
      final vip = requestVip(friday, 'VIP 1');
      expect(
        () => book.markArrival(vip.id),
        throwsReservation(ReservationError.invalidTransition),
      );
    });

    test('el cierre no desaloja: la ocupada se conserva en el historial', () {
      now = venueInstant(2026, 10, 9, 23);
      book.markArrival(reserved.id);
      now = venueInstant(2026, 10, 12, 12);
      expect(book.byId(reserved.id)!.status, ReservationStatus.seated);
      expect(book.forNight(friday).map((r) => r.id), contains(reserved.id));
    });
  });

  group('revocar y liberar (R4, R6)', () {
    test('revocar anula una reservada; no aplica a una ocupada', () {
      final r = book.createDirect(
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      expect(book.revoke(r.id).status, ReservationStatus.revoked);

      now = venueInstant(2026, 10, 9, 23);
      final seated = book.markArrival(
        book.createDirect(night: friday, tableId: 'M02', holder: direct).id,
      );
      expect(
        () => book.revoke(seated.id),
        throwsReservation(ReservationError.invalidTransition),
      );
    });

    test('liberar aplica a reservadas y ocupadas', () {
      now = venueInstant(2026, 10, 9, 23);
      final reserved = book.createDirect(
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      final seated = book.markArrival(
        book.createDirect(night: friday, tableId: 'M02', holder: direct).id,
      );
      expect(book.release(reserved.id).status, ReservationStatus.released);
      expect(book.release(seated.id).status, ReservationStatus.released);
      expect(book.activeFor(friday, 'M01'), isNull);
      expect(book.activeFor(friday, 'M02'), isNull);
    });
  });

  group('operaciones repetidas no duplican efectos', () {
    test('repetir una transición falla y no añade eventos', () {
      now = venueInstant(2026, 10, 9, 23);
      final r = book.createDirect(
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      book.markArrival(r.id);
      expect(
        () => book.markArrival(r.id),
        throwsReservation(ReservationError.invalidTransition),
      );
      book.release(r.id);
      expect(
        () => book.release(r.id),
        throwsReservation(ReservationError.invalidTransition),
      );
      expect(book.byId(r.id)!.history.map((e) => e.type), [
        ReservationEventType.createdDirect,
        ReservationEventType.arrived,
        ReservationEventType.released,
      ]);
    });

    test('repetir prepago o rechazo no cambia el resultado', () {
      final a = requestVip(friday, 'VIP 1');
      book.markPrepaymentReceived(a.id);
      expect(
        () => book.markPrepaymentReceived(a.id),
        throwsReservation(ReservationError.invalidTransition),
      );
      expect(
        () => book.rejectRequest(a.id),
        throwsReservation(ReservationError.invalidTransition),
      );
      expect(book.byId(a.id)!.status, ReservationStatus.confirmed);
      expect(book.byId(a.id)!.history, hasLength(2));
    });

    test('una reserva inexistente se informa', () {
      expect(
        () => book.revoke('R999'),
        throwsReservation(ReservationError.notFound),
      );
    });
  });

  test('las reservas conservan su noche cuando la noche ya terminó', () {
    final r = book.createDirect(night: friday, tableId: 'M01', holder: direct);
    now = venueInstant(2026, 10, 20, 12);
    expect(book.forNight(friday).single.id, r.id);
    expect(book.byId(r.id)!.night, friday);
  });
}

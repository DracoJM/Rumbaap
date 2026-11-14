import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
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

  // Titular de solicitud con los datos que exige R12 (nombre y teléfono).
  const client = ReservationHolder(
    name: 'Titular demo A',
    idNumber: '0001',
    phone: '0000000001',
  );
  const direct = ReservationHolder(
    name: 'Titular demo B',
    idNumber: '0002',
    phone: '0003',
  );

  setUp(() {
    // Miércoles 7 de octubre, 3:00 p. m. en el local.
    now = wednesdayAfternoon;
    book = ReservationBook(venue: sagsaVenue, clock: () => now);
    allowDemoReservationActions(book);
  });

  /// Trámite normal En proceso del cliente demo A (R14).
  Reservation requestNormal(Night night, String table) => book.startNormal(
    night: night,
    tableId: table,
    origin: ReservationOrigin.client,
    actorId: 'cliente-a',
  );

  /// Envío del trámite por quien lo empezó.
  Reservation complete(Reservation r) =>
      book.submitNormal(r.id, holder: client, actorId: 'cliente-a');

  Reservation requestVip(Night night, String table) => book.submitVip(
    night: night,
    tableId: table,
    holder: client,
    origin: ReservationOrigin.promoter,
    actorId: 'promotor-1',
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
        () => book.createDirect(
          actorId: 'admin-1',
          night: friday,
          tableId: 'M01',
          holder: direct,
        ),
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
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      book.revoke(r.id, actorId: 'admin-1');
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
      // Mismo error que el envío del trámite (submitNormal): ya venció.
      expect(() => complete(r), throwsReservation(ReservationError.expired));
    });

    test('al completarse se confirma y ya no vence por el temporizador', () {
      final r = requestNormal(friday, 'M01');
      now = now.add(const Duration(minutes: 9));
      expect(complete(r).status, ReservationStatus.confirmed);
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
      final confirmed = book.markPrepaymentReceived(r.id, actorId: 'admin-1');
      expect(confirmed.status, ReservationStatus.confirmed);
      expect(confirmed.history.map((e) => e.type), [
        ReservationEventType.requested,
        ReservationEventType.prepaymentMarked,
      ]);
    });

    test('el rechazo la anula y libera la mesa, con traza de rechazo', () {
      final r = requestVip(friday, 'VIP 1');
      final rejected = book.rejectRequest(r.id, actorId: 'admin-1');
      expect(rejected.status, ReservationStatus.revoked);
      expect(rejected.history.last.type, ReservationEventType.rejected);
      expect(book.activeFor(friday, 'VIP 1'), isNull);
    });

    test('la directa del administrador queda confirmada desde el inicio', () {
      final r = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'VIP 2',
        holder: direct,
      );
      expect(r.status, ReservationStatus.confirmed);
      expect(r.origin, ReservationOrigin.admin);
      expect(r.history.single.type, ReservationEventType.createdDirect);
      expect(
        () => book.markPrepaymentReceived(r.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
    });
  });

  group('titular de la reserva directa (R7)', () {
    void expectInvalid(ReservationHolder holder) => expect(
      () => book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: holder,
      ),
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
              actorId: 'admin-1',
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
        actorId: 'admin-1',
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
          () => book.markArrival(reserved.id, actorId: 'admin-1'),
          throwsReservation(ReservationError.outsideNight),
        );
      }
      expect(book.byId(reserved.id)!.status, ReservationStatus.confirmed);
    });

    test('dentro del horario pasa de reservada a ocupada', () {
      now = venueInstant(2026, 10, 9, 20, 30);
      expect(
        book.markArrival(reserved.id, actorId: 'admin-1').status,
        ReservationStatus.seated,
      );
    });

    test('la apertura no registra la llegada sola', () {
      now = venueInstant(2026, 10, 9, 23);
      expect(book.byId(reserved.id)!.status, ReservationStatus.confirmed);
    });

    test('solo una reserva confirmada puede registrar llegada', () {
      now = venueInstant(2026, 10, 9, 23);
      final vip = requestVip(friday, 'VIP 1');
      expect(
        () => book.markArrival(vip.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
    });

    test('el cierre no desaloja: la ocupada se conserva en el historial', () {
      now = venueInstant(2026, 10, 9, 23);
      book.markArrival(reserved.id, actorId: 'admin-1');
      now = venueInstant(2026, 10, 12, 12);
      expect(book.byId(reserved.id)!.status, ReservationStatus.seated);
      expect(book.forNight(friday).map((r) => r.id), contains(reserved.id));
    });
  });

  group('revocar y liberar (R4, R6)', () {
    test('revocar anula una reservada; no aplica a una ocupada', () {
      final r = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      expect(
        book.revoke(r.id, actorId: 'admin-1').status,
        ReservationStatus.revoked,
      );

      now = venueInstant(2026, 10, 9, 23);
      final seated = book.markArrival(
        book
            .createDirect(
              actorId: 'admin-1',
              night: friday,
              tableId: 'M02',
              holder: direct,
            )
            .id,
        actorId: 'admin-1',
      );
      expect(
        () => book.revoke(seated.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
    });

    test('liberar aplica a reservadas y ocupadas', () {
      now = venueInstant(2026, 10, 9, 23);
      final reserved = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      final seated = book.markArrival(
        book
            .createDirect(
              actorId: 'admin-1',
              night: friday,
              tableId: 'M02',
              holder: direct,
            )
            .id,
        actorId: 'admin-1',
      );
      expect(
        book.release(reserved.id, actorId: 'admin-1').status,
        ReservationStatus.released,
      );
      expect(
        book.release(seated.id, actorId: 'admin-1').status,
        ReservationStatus.released,
      );
      expect(book.activeFor(friday, 'M01'), isNull);
      expect(book.activeFor(friday, 'M02'), isNull);
    });
  });

  group('operaciones repetidas no duplican efectos', () {
    test('repetir una transición falla y no añade eventos', () {
      now = venueInstant(2026, 10, 9, 23);
      final r = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      book.markArrival(r.id, actorId: 'admin-1');
      expect(
        () => book.markArrival(r.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
      book.release(r.id, actorId: 'admin-1');
      expect(
        () => book.release(r.id, actorId: 'admin-1'),
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
      book.markPrepaymentReceived(a.id, actorId: 'admin-1');
      expect(
        () => book.markPrepaymentReceived(a.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
      expect(
        () => book.rejectRequest(a.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.invalidTransition),
      );
      expect(book.byId(a.id)!.status, ReservationStatus.confirmed);
      expect(book.byId(a.id)!.history, hasLength(2));
    });

    test('una reserva inexistente se informa', () {
      expect(
        () => book.revoke('R999', actorId: 'admin-1'),
        throwsReservation(ReservationError.notFound),
      );
    });
  });

  test('las reservas conservan su noche cuando la noche ya terminó', () {
    final r = book.createDirect(
      actorId: 'admin-1',
      night: friday,
      tableId: 'M01',
      holder: direct,
    );
    now = venueInstant(2026, 10, 20, 12);
    expect(book.forNight(friday).single.id, r.id);
    expect(book.byId(r.id)!.night, friday);
  });

  group('actor y cargo de las acciones de reserva', () {
    String? lastActor(String id) => book.byId(id)!.history.last.actorId;

    test('cada acción guarda la identidad que la ejecuta, sin cambiar el '
        'creador, el origen ni los eventos anteriores', () {
      final vip = book.submitVip(
        night: friday,
        tableId: 'VIP 1',
        holder: client,
        origin: ReservationOrigin.client,
        actorId: 'cliente-a',
      );
      book.markPrepaymentReceived(vip.id, actorId: 'admin-1');
      final rejected = requestVip(friday, 'VIP 2');
      book.rejectRequest(rejected.id, actorId: 'admin-1');
      final revoked = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      book.revoke(revoked.id, actorId: 'admin-1');
      now = venueInstant(2026, 10, 9, 22);
      final seated = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M02',
        holder: direct,
      );
      book.markArrival(seated.id, actorId: 'personal-1');
      expect(lastActor(seated.id), 'personal-1');
      book.release(seated.id, actorId: 'admin-1');

      final v = book.byId(vip.id)!;
      expect(v.history.map((e) => (e.type, e.actorId)), [
        (ReservationEventType.requested, 'cliente-a'),
        (ReservationEventType.prepaymentMarked, 'admin-1'),
      ]);
      expect(v.createdBy, 'cliente-a');
      expect(v.origin, ReservationOrigin.client);
      expect(lastActor(rejected.id), 'admin-1');
      expect(lastActor(revoked.id), 'admin-1');
      expect(book.byId(seated.id)!.history.map((e) => (e.type, e.actorId)), [
        (ReservationEventType.createdDirect, 'admin-1'),
        (ReservationEventType.arrived, 'personal-1'),
        (ReservationEventType.released, 'admin-1'),
      ]);
    });

    test('matriz de la demo: la administración todas; el mesero solo la '
        'llegada; nadie más', () {
      for (final i in DemoIdentities.all) {
        for (final a in ReservationAction.values) {
          final expected =
              i.profile == DemoProfile.admin ||
              (i.staffRole == StaffRole.waiter &&
                  a == ReservationAction.arrival);
          expect(
            RumbaapApp.reservationActionAllowed(i.id, a),
            expected,
            reason: '${i.id} · ${a.name}',
          );
        }
      }
      expect(
        RumbaapApp.reservationActionAllowed(
          'desconocido',
          ReservationAction.arrival,
        ),
        isFalse,
      );
    });

    test('denegado en la lógica: no cambia el estado ni añade eventos, '
        'tampoco al titular ni a quien la creó', () {
      final vip = book.submitVip(
        night: friday,
        tableId: 'VIP 1',
        holder: client,
        origin: ReservationOrigin.client,
        actorId: 'cliente-a',
      );
      now = venueInstant(2026, 10, 9, 22);
      final reserved = book.createDirect(
        actorId: 'admin-1',
        night: friday,
        tableId: 'M01',
        holder: direct,
      );
      final denied = <(String, void Function())>[
        (
          'cliente-a',
          () => book.markPrepaymentReceived(vip.id, actorId: 'cliente-a'),
        ),
        ('cliente-a', () => book.rejectRequest(vip.id, actorId: 'cliente-a')),
        (
          'promotor-1',
          () => book.markPrepaymentReceived(vip.id, actorId: 'promotor-1'),
        ),
        (
          'personal-1',
          () => book.markPrepaymentReceived(vip.id, actorId: 'personal-1'),
        ),
        ('personal-1', () => book.rejectRequest(vip.id, actorId: 'personal-1')),
        ('personal-1', () => book.revoke(reserved.id, actorId: 'personal-1')),
        ('personal-1', () => book.release(reserved.id, actorId: 'personal-1')),
        ('caja-1', () => book.markArrival(reserved.id, actorId: 'caja-1')),
        (
          'seguridad-1',
          () => book.markArrival(reserved.id, actorId: 'seguridad-1'),
        ),
        ('barra-1', () => book.markArrival(reserved.id, actorId: 'barra-1')),
        (
          'cliente-a',
          () => book.markArrival(reserved.id, actorId: 'cliente-a'),
        ),
        ('desconocido', () => book.revoke(reserved.id, actorId: 'desconocido')),
      ];
      for (final (who, call) in denied) {
        expect(
          call,
          throwsReservation(ReservationError.notAllowed),
          reason: who,
        );
      }
      expect(book.byId(vip.id)!.status, ReservationStatus.pendingPayment);
      expect(book.byId(vip.id)!.history, hasLength(1));
      expect(book.byId(reserved.id)!.status, ReservationStatus.confirmed);
      expect(book.byId(reserved.id)!.history, hasLength(1));
    });

    test('sin permisos inyectados nadie crea ni ejecuta nada', () {
      final bare = ReservationBook(venue: sagsaVenue, clock: () => now);
      expect(
        () => bare.createDirect(
          night: friday,
          tableId: 'M01',
          holder: direct,
          actorId: 'admin-1',
        ),
        throwsReservation(ReservationError.notAllowed),
      );
      expect(
        () => bare.startNormal(
          night: friday,
          tableId: 'M02',
          origin: ReservationOrigin.client,
          actorId: 'cliente-a',
        ),
        throwsReservation(ReservationError.notAllowed),
      );
      expect(bare.forNight(friday), isEmpty);
      bare.canCreate = RumbaapApp.reservationCreationAllowed;
      final r = bare.createDirect(
        night: friday,
        tableId: 'M01',
        holder: direct,
        actorId: 'admin-1',
      );
      expect(
        () => bare.revoke(r.id, actorId: 'admin-1'),
        throwsReservation(ReservationError.notAllowed),
      );
      expect(bare.byId(r.id)!.status, ReservationStatus.confirmed);
    });
  });

  group('altas: actor, creador y titular', () {
    List<(ReservationEventType, String?)> events(String id) => [
      for (final e in book.byId(id)!.history) (e.type, e.actorId),
    ];

    test('cada alta guarda quién la hizo; creador y titular van aparte', () {
      final draft = book.startNormal(
        night: friday,
        tableId: 'M01',
        origin: ReservationOrigin.promoter,
        actorId: 'promotor-1',
      );
      expect(draft.holder, isNull);
      book.submitNormal(draft.id, holder: client, actorId: 'promotor-1');
      final n = book.byId(draft.id)!;
      expect(events(n.id), [
        (ReservationEventType.requested, 'promotor-1'),
        (ReservationEventType.completed, 'promotor-1'),
      ]);
      expect(n.createdBy, 'promotor-1');
      expect(n.holder!.name, client.name);

      final vip = book.submitVip(
        night: friday,
        tableId: 'VIP 1',
        holder: direct,
        origin: ReservationOrigin.client,
        actorId: 'cliente-b',
      );
      expect(events(vip.id), [(ReservationEventType.requested, 'cliente-b')]);
      expect(vip.createdBy, 'cliente-b');
      expect(vip.holder!.name, direct.name);

      final d = book.createDirect(
        night: friday,
        tableId: 'M02',
        holder: direct,
        actorId: 'admin-1',
      );
      expect(events(d.id), [(ReservationEventType.createdDirect, 'admin-1')]);
      expect(d.createdBy, isNull);
      expect(d.origin, ReservationOrigin.admin);

      final c = book.startNormal(
        night: friday,
        tableId: 'M03',
        origin: ReservationOrigin.client,
        actorId: 'cliente-a',
      );
      book.cancelInProcess(c.id, actorId: 'cliente-a');
      expect(events(c.id).last, (ReservationEventType.cancelled, 'cliente-a'));
    });

    test('matriz de altas por flujo: cliente y promotor sus solicitudes, la '
        'administración la directa; el personal no crea', () {
      for (final i in DemoIdentities.all) {
        for (final o in ReservationOrigin.values) {
          final expected = switch ((i.profile, o)) {
            (DemoProfile.client, ReservationOrigin.client) ||
            (DemoProfile.promoter, ReservationOrigin.promoter) ||
            (DemoProfile.admin, ReservationOrigin.admin) => true,
            _ => false,
          };
          expect(
            RumbaapApp.reservationCreationAllowed(i.id, o),
            expected,
            reason: '${i.id} · ${o.name}',
          );
        }
      }
      for (final o in ReservationOrigin.values) {
        expect(
          RumbaapApp.reservationCreationAllowed('desconocido', o),
          isFalse,
        );
      }
    });

    // C1: el origen administrativo solo entra por createDirect. Antes se
    // excluía con un assert, que desaparece en las compilaciones sin
    // asserts; ahora es una excepción de dominio en cualquier modo.
    test('las solicitudes no admiten el origen administrativo, ni para la '
        'administración: no crean nada, no ocupan mesa ni consumen número', () {
      final denied = <(String, Reservation Function())>[
        (
          'trámite normal',
          () => book.startNormal(
            night: friday,
            tableId: 'M01',
            origin: ReservationOrigin.admin,
            actorId: 'admin-1',
          ),
        ),
        (
          'solicitud VIP',
          () => book.submitVip(
            night: friday,
            tableId: 'VIP 1',
            holder: direct,
            origin: ReservationOrigin.admin,
            actorId: 'admin-1',
          ),
        ),
      ];
      for (final (what, call) in denied) {
        expect(
          call,
          throwsReservation(ReservationError.notAllowed),
          reason: what,
        );
      }
      expect(book.forNight(friday), isEmpty);
      expect(book.activeFor(friday, 'M01'), isNull);
      expect(book.activeFor(friday, 'VIP 1'), isNull);
      // La reserva directa sigue permitida y recibe el primer número.
      final d = book.createDirect(
        night: friday,
        tableId: 'VIP 1',
        holder: direct,
        actorId: 'admin-1',
      );
      expect(d.id, 'R1');
      expect(d.origin, ReservationOrigin.admin);
    });

    test('un alta denegada no crea nada ni ocupa la mesa', () {
      final denied = <(String, void Function())>[
        (
          'promotor-1 como cliente',
          () => book.startNormal(
            night: friday,
            tableId: 'M01',
            origin: ReservationOrigin.client,
            actorId: 'promotor-1',
          ),
        ),
        (
          'mesero',
          () => book.startNormal(
            night: friday,
            tableId: 'M01',
            origin: ReservationOrigin.client,
            actorId: 'personal-1',
          ),
        ),
        (
          'cliente como promotor',
          () => book.submitVip(
            night: friday,
            tableId: 'VIP 1',
            holder: client,
            origin: ReservationOrigin.promoter,
            actorId: 'cliente-a',
          ),
        ),
        (
          'administración como cliente',
          () => book.submitVip(
            night: friday,
            tableId: 'VIP 1',
            holder: client,
            origin: ReservationOrigin.client,
            actorId: 'admin-1',
          ),
        ),
        for (final who in ['promotor-1', 'cliente-a', 'caja-1', 'desconocido'])
          (
            'directa por $who',
            () => book.createDirect(
              night: friday,
              tableId: 'M01',
              holder: direct,
              actorId: who,
            ),
          ),
      ];
      for (final (who, call) in denied) {
        expect(
          call,
          throwsReservation(ReservationError.notAllowed),
          reason: who,
        );
      }
      expect(book.forNight(friday), isEmpty);
      expect(book.activeFor(friday, 'M01'), isNull);
      // Ningún número de reserva se consumió.
      expect(
        book
            .createDirect(
              night: friday,
              tableId: 'M01',
              holder: direct,
              actorId: 'admin-1',
            )
            .id,
        'R1',
      );
    });

    test('el trámite normal solo lo envía o cancela quien lo empezó', () {
      final r = requestNormal(friday, 'M01');
      for (final who in ['cliente-b', 'promotor-1', 'admin-1']) {
        expect(
          () => book.submitNormal(r.id, holder: client, actorId: who),
          throwsReservation(ReservationError.notAllowed),
          reason: who,
        );
        expect(
          () => book.cancelInProcess(r.id, actorId: who),
          throwsReservation(ReservationError.notAllowed),
          reason: who,
        );
      }
      expect(book.byId(r.id)!.status, ReservationStatus.inProcess);
      expect(book.byId(r.id)!.history, hasLength(1));
      expect(complete(r).status, ReservationStatus.confirmed);
    });

    test('la siembra no es un alta: solo rellena una noche vacía y sin '
        'terminar, sin actor ni creador', () {
      now = venueInstant(2026, 10, 9, 22);
      book.seedDemoNight(friday);
      final seeded = book.forNight(friday);
      expect(seeded, hasLength(7));
      expect(
        seeded.expand((r) => r.history).map((e) => e.actorId),
        everyElement(isNull),
      );
      expect(seeded.map((r) => r.createdBy), everyElement(isNull));
      expect(
        seeded.where((r) => r.status == ReservationStatus.seated),
        hasLength(2),
      );
      book.seedDemoNight(friday);
      expect(book.forNight(friday), hasLength(7));
      // El trámite sembrado no tiene creador: nadie lo envía; vence solo.
      final draft = seeded.singleWhere(
        (r) => r.status == ReservationStatus.inProcess,
      );
      expect(
        () => book.submitNormal(draft.id, holder: client, actorId: 'cliente-a'),
        throwsReservation(ReservationError.notAllowed),
      );

      book.createDirect(
        night: saturday,
        tableId: 'M01',
        holder: direct,
        actorId: 'admin-1',
      );
      book.seedDemoNight(saturday);
      expect(book.forNight(saturday), hasLength(1));

      now = venueInstant(2026, 10, 12, 12);
      final sunday = Night(DateTime.utc(2026, 10, 11));
      book.seedDemoNight(sunday);
      expect(book.forNight(sunday), isEmpty);
    });
  });
}

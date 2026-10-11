import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/domain/reservation_book.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_labels.dart';
import 'package:rumbaap/features/reservations/presentation/guest/guest_home_page.dart';
import 'package:rumbaap/features/reservations/presentation/guest/reservation_flow_page.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_map_scaffold.dart';
import 'package:rumbaap/features/reservations/presentation/staff/staff_page.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_table.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/reservations/presentation/venue_map_controller.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
const _holder = ReservationHolder(name: 'Titular demo P', phone: '3001112233');

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  group('libro: trámite del cliente y del promotor (R13–R16)', () {
    late _Clock clock;
    late ReservationBook book;
    setUp(() {
      clock = _Clock(fixedClock());
      book = ReservationBook(venue: sagsaVenue, clock: clock.call);
    });

    test('normal: iniciar bloquea sin titular; enviar lo confirma', () {
      final r = book.startNormal(
        night: _friday,
        tableId: 'M01',
        origin: ReservationOrigin.promoter,
        createdBy: 'promotor-1',
      );
      expect(r.status, ReservationStatus.inProcess);
      expect(r.holder, isNull);
      expect(book.activeFor(_friday, 'M01')?.id, r.id);
      expect(
        () => book.startNormal(
          night: _friday,
          tableId: 'M01',
          origin: ReservationOrigin.client,
        ),
        throwsA(isA<ReservationException>()),
      );

      final done = book.submitNormal(r.id, holder: _holder);
      expect(done.status, ReservationStatus.confirmed);
      expect(done.holder!.name, 'Titular demo P');
      expect(done.history.map((e) => e.type), [
        ReservationEventType.requested,
        ReservationEventType.completed,
      ]);
      expect(book.createdBy('promotor-1').single.id, r.id);
    });

    test('enviar con titular no válido no cambia nada (sin efectos '
        'parciales)', () {
      final r = book.startNormal(
        night: _friday,
        tableId: 'M02',
        origin: ReservationOrigin.promoter,
      );
      for (final bad in const [
        ReservationHolder(name: ' ', phone: '1'),
        ReservationHolder(name: 'X', phone: '300 1'),
        ReservationHolder(name: 'X', phone: '1', idNumber: '1.2'),
      ]) {
        expect(
          () => book.submitNormal(r.id, holder: bad),
          throwsA(
            isA<ReservationException>().having(
              (e) => e.error,
              'error',
              ReservationError.invalidHolder,
            ),
          ),
        );
      }
      final after = book.byId(r.id)!;
      expect(after.status, ReservationStatus.inProcess);
      expect(after.holder, isNull);
      expect(after.history, hasLength(1));
    });

    test(
      'vencido a los 10 min: no se puede confirmar y la mesa queda libre',
      () {
        final r = book.startNormal(
          night: _friday,
          tableId: 'M03',
          origin: ReservationOrigin.client,
        );
        clock.now = clock.now.add(ReservationBook.inProcessTimeout);
        expect(
          () => book.submitNormal(r.id, holder: _holder),
          throwsA(
            isA<ReservationException>().having(
              (e) => e.error,
              'error',
              ReservationError.expired,
            ),
          ),
        );
        expect(book.byId(r.id)!.status, ReservationStatus.expired);
        expect(book.byId(r.id)!.holder, isNull);
        expect(book.activeFor(_friday, 'M03'), isNull);
      },
    );

    test('cancelar solo afecta a un trámite En proceso', () {
      final r = book.startNormal(
        night: _friday,
        tableId: 'M04',
        origin: ReservationOrigin.promoter,
      );
      final cancelled = book.cancelInProcess(r.id);
      expect(cancelled.status, ReservationStatus.cancelled);
      expect(cancelled.holder, isNull);
      expect(book.activeFor(_friday, 'M04'), isNull);
      expect(
        () => book.submitNormal(r.id, holder: _holder),
        throwsA(isA<ReservationException>()),
      );

      final confirmed = book.submitNormal(
        book
            .startNormal(
              night: _friday,
              tableId: 'M04',
              origin: ReservationOrigin.promoter,
            )
            .id,
        holder: _holder,
      );
      expect(
        () => book.cancelInProcess(confirmed.id),
        throwsA(isA<ReservationException>()),
      );
      expect(book.byId(confirmed.id)!.status, ReservationStatus.confirmed);
    });

    test('VIP: la solicitud nace al enviar, pendiente y sin caducidad; otra '
        'solicitud sobre la misma VIP se rechaza sin sobrescribir', () {
      final vip = book.submitVip(
        night: _friday,
        tableId: 'VIP 1',
        holder: _holder,
        origin: ReservationOrigin.promoter,
        createdBy: 'promotor-1',
        linkedAccountId: 'cliente-a',
      );
      expect(vip.status, ReservationStatus.pendingPayment);
      expect(vip.linkedAccountId, 'cliente-a');
      clock.now = clock.now.add(const Duration(days: 1));
      expect(book.byId(vip.id)!.status, ReservationStatus.pendingPayment);
      expect(
        () => book.submitVip(
          night: _friday,
          tableId: 'VIP 1',
          holder: _holder,
          origin: ReservationOrigin.client,
        ),
        throwsA(
          isA<ReservationException>().having(
            (e) => e.error,
            'error',
            ReservationError.tableTaken,
          ),
        ),
      );
      expect(book.activeFor(_friday, 'VIP 1')!.id, vip.id);
    });

    test('la cuenta ficticia se vincula solo por cédula exacta', () {
      expect(DemoIdentities.accountByIdNumber('1000000001')?.id, 'cliente-a');
      expect(DemoIdentities.accountByIdNumber('100000000'), isNull);
      expect(DemoIdentities.accountByIdNumber(''), isNull);
      expect(DemoIdentities.accountByIdNumber(null), isNull);
    });
  });

  test('un trámite normal iniciado a las 02:55 no se confirma si se envía a '
      'las 03:00, con la noche ya cerrada (I7), y no cambia nada', () {
    final clock = _Clock(venueInstant(2026, 10, 10, 2, 55));
    final book = ReservationBook(venue: sagsaVenue, clock: clock.call);
    final r = book.startNormal(
      night: _friday,
      tableId: 'M01',
      origin: ReservationOrigin.client,
      createdBy: 'cliente-a',
    );
    clock.now = venueInstant(2026, 10, 10, 3);
    expect(
      () => book.submitNormal(r.id, holder: _holder),
      throwsA(
        isA<ReservationException>().having(
          (e) => e.error,
          'error',
          ReservationError.nightEnded,
        ),
      ),
    );
    final after = book.byId(r.id)!;
    expect(after.status, ReservationStatus.inProcess);
    expect(after.holder, isNull);
    expect(after.history.length, r.history.length);
  });

  test('proyección propia: cada identidad recibe del almacén solo lo que '
      'creó; la cuenta vinculada no convierte al cliente en creador', () {
    final store = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: fixedClock,
    );
    final free = sagsaVenue.tables
        .where((t) => !t.isVip && store.book.activeFor(_friday, t.id) == null)
        .map((t) => t.id)
        .toList();
    final byPromoter = store.perform((b) {
      final r = b.startNormal(
        night: _friday,
        tableId: free[0],
        origin: ReservationOrigin.promoter,
        createdBy: 'promotor-1',
      );
      return b.submitNormal(
        r.id,
        holder: const ReservationHolder(
          name: 'Cliente demo A',
          phone: '3000000001',
          idNumber: '1000000001',
        ),
        linkedAccountId: 'cliente-a',
      );
    });
    final byClientA = store.perform(
      (b) => b.startNormal(
        night: _friday,
        tableId: free[1],
        origin: ReservationOrigin.client,
        createdBy: 'cliente-a',
      ),
    );
    expect(byPromoter.createdBy, 'promotor-1');
    expect(byPromoter.linkedAccountId, 'cliente-a');
    expect(store.ownReservations('promotor-1').map((r) => r.id), [
      byPromoter.id,
    ]);
    expect(store.ownReservations('cliente-a').map((r) => r.id), [byClientA.id]);
    expect(store.ownReservations('cliente-b'), isEmpty);
    // Los datos sembrados no pertenecen a ninguna identidad.
    expect(store.ownReservations('admin-1'), isEmpty);
  });

  group('rutas antiguas y adjudicación a cuenta', () {
    test('completeRequest no confirma un trámite sin titular ni con la noche '
        'cerrada, y no cambia nada', () {
      final clock = _Clock(venueInstant(2026, 10, 10, 2, 55));
      final book = ReservationBook(venue: sagsaVenue, clock: clock.call);
      final noHolder = book.startNormal(
        night: _friday,
        tableId: 'M01',
        origin: ReservationOrigin.client,
      );
      expect(
        () => book.completeRequest(noHolder.id),
        throwsA(
          isA<ReservationException>().having(
            (e) => e.error,
            'error',
            ReservationError.invalidHolder,
          ),
        ),
      );
      expect(book.byId(noHolder.id)!.status, ReservationStatus.inProcess);

      final legacy = book.requestNormal(
        night: _friday,
        tableId: 'M02',
        holder: _holder,
        origin: ReservationOrigin.client,
      );
      clock.now = venueInstant(2026, 10, 10, 3);
      expect(
        () => book.completeRequest(legacy.id),
        throwsA(
          isA<ReservationException>().having(
            (e) => e.error,
            'error',
            ReservationError.nightEnded,
          ),
        ),
      );
      expect(book.byId(legacy.id)!.status, ReservationStatus.inProcess);
    });

    test('requestVip y requestNormal antiguos rechazan un titular no '
        'válido', () {
      final book = ReservationBook(venue: sagsaVenue, clock: fixedClock);
      const bad = ReservationHolder(name: ' ', phone: 'abc');
      expect(
        () => book.requestVip(
          night: _friday,
          tableId: 'VIP2',
          holder: bad,
          origin: ReservationOrigin.client,
        ),
        throwsA(isA<ReservationException>()),
      );
      expect(
        () => book.requestNormal(
          night: _friday,
          tableId: 'M03',
          holder: bad,
          origin: ReservationOrigin.client,
        ),
        throwsA(isA<ReservationException>()),
      );
      expect(book.forNight(_friday), isEmpty);
    });

    test('el cliente ve lo que creó y lo adjudicado a su cuenta, sin '
        'duplicados; cada promotor solo lo suyo', () {
      final store = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: fixedClock,
      );
      final free = sagsaVenue.tables
          .where((t) => !t.isVip && store.book.activeFor(_friday, t.id) == null)
          .map((t) => t.id)
          .toList();
      const holderA = ReservationHolder(
        name: 'Titular escrito A',
        phone: '3000000001',
        idNumber: '1000000001',
      );
      const holderB = ReservationHolder(
        name: 'Titular escrito B',
        phone: '3000000002',
        idNumber: '1000000002',
      );
      Reservation normal(
        int i,
        String creator,
        ReservationHolder h, {
        String? linked,
        ReservationOrigin? origin,
      }) {
        return store.perform((b) {
          final r = b.startNormal(
            night: _friday,
            tableId: free[i],
            origin: origin ?? ReservationOrigin.promoter,
            createdBy: creator,
          );
          return b.submitNormal(r.id, holder: h, linkedAccountId: linked);
        });
      }

      final byP1 = normal(0, 'promotor-1', holderA, linked: 'cliente-a');
      final byP2 = normal(1, 'promotor-2', holderB, linked: 'cliente-b');
      final ownA = normal(
        2,
        'cliente-a',
        holderA,
        linked: 'cliente-a',
        origin: ReservationOrigin.client,
      );
      final aForB = normal(
        3,
        'cliente-a',
        holderB,
        linked: 'cliente-b',
        origin: ReservationOrigin.client,
      );
      final direct = store.perform(
        (b) => b.createDirect(
          night: _friday,
          tableId: free[4],
          holder: holderB,
          linkedAccountId: 'cliente-b',
        ),
      );

      List<String> ids(String id, {bool linked = false}) => [
        for (final r in store.ownReservations(id, includeLinked: linked)) r.id,
      ]..sort();
      expect(
        ids('cliente-a', linked: true),
        [byP1.id, ownA.id, aForB.id]..sort(),
      );
      expect(
        ids('cliente-b', linked: true),
        [byP2.id, aForB.id, direct.id]..sort(),
      );
      expect(ids('promotor-1'), [byP1.id]);
      expect(ids('promotor-2'), [byP2.id]);
      // La adjudicación no cambia quién la creó.
      expect(store.book.byId(byP1.id)!.createdBy, 'promotor-1');
      expect(store.book.byId(direct.id)!.origin, ReservationOrigin.admin);
    });
  });

  group('catálogo de noches del cliente (N5)', () {
    test('semana calendario: del lunes 5 al domingo 11 se ofrecen 9, 10 y '
        '11', () {
      final nights = NightSchedule.calendarWeekendNights(
        VenueTime.of(venueInstant(2026, 10, 5, 10)),
      );
      expect(nights.map((n) => n.id), [
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
      ]);
    });

    test('el lunes 12 a las 00:30 ya se abre el fin de semana siguiente, '
        'aunque M1 mantenga el domingo para el mapa operativo', () {
      final now = VenueTime.of(venueInstant(2026, 10, 12, 0, 30));
      expect(NightSchedule.calendarWeekendNights(now).map((n) => n.id), [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
      ]);
      expect(
        NightSchedule.weekendNights(now).map((n) => n.id),
        contains('2026-10-11'),
      );
      // El domingo a las 23:00 el próximo cambio del catálogo es el lunes a
      // las 00:00, antes del cierre de las 03:00.
      expect(
        NightSchedule.nextCalendarChange(
          VenueTime.of(venueInstant(2026, 10, 11, 23)),
        ),
        DateTime.utc(2026, 10, 12),
      );
    });
  });

  group('recorridos en la app', () {
    Future<DemoReservationStore> pumpApp(
      WidgetTester tester, {
      DateTime Function() clock = fixedClock,
    }) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final store = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: clock,
      );
      await tester.pumpWidget(
        RumbaapApp(config: sagsaConfig, store: store, clock: clock),
      );
      return store;
    }

    Future<void> enter(WidgetTester tester, String id) async {
      final card = find.byKey(ValueKey('identity-$id'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String tableId) async {
      final table = find.byKey(ValueKey('table-$tableId'));
      await tester.ensureVisible(table);
      await tester.pumpAndSettle();
      await tester.tap(table, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    String freeNormal(DemoReservationStore store) => sagsaVenue.tables
        .firstWhere(
          (t) => !t.isVip && store.book.activeFor(_friday, t.id) == null,
        )
        .id;

    testWidgets('promotor: elige mesa, registra titular, revisa y envía; queda '
        'confirmada y el administrador la ve', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, 'promotor-1');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      expect(find.byType(ReservationFlowPage), findsOneWidget);
      // R14: el trámite ya bloquea la mesa, sin titular.
      final started = store.book.activeFor(_friday, tableId)!;
      expect(started.status, ReservationStatus.inProcess);
      expect(started.holder, isNull);

      await tapKey(tester, 'flow-review');
      expect(find.text('Escribe el nombre del titular.'), findsOneWidget);
      expect(find.text('Escribe el teléfono.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('flow-name')),
        'Titular demo P',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-phone')),
        '3001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-id')),
        '1000000001',
      );
      await tapKey(tester, 'flow-review');
      expect(
        find.text('Cuenta encontrada: se vinculará al enviar'),
        findsOneWidget,
      );
      expect(find.textContaining('Cliente demo A'), findsNothing);
      await tapKey(tester, 'flow-submit');
      expect(find.byKey(const ValueKey('flow-done')), findsOneWidget);
      final done = store.book.byId(started.id)!;
      expect(done.status, ReservationStatus.confirmed);
      expect(done.linkedAccountId, 'cliente-a');
      expect(done.createdBy, 'promotor-1');

      await tapKey(tester, 'flow-show-mine');
      expect(find.byKey(ValueKey('mine-${done.id}')), findsOneWidget);

      // El administrador ve la reserva en su mapa con el titular.
      Navigator.of(
        tester.element(find.byKey(ValueKey('mine-${done.id}'))),
      ).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
      await enter(tester, 'admin-1');
      expect(find.byType(AdminPage), findsOneWidget);
      expect(
        tester
            .widget<CrystalTable>(find.byKey(ValueKey('table-$tableId')))
            .status,
        TableMapStatus.reserved,
      );
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('entrada y trámite con texto al 200 % en móvil pequeño, sin '
        'desbordes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await pumpApp(tester);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await enter(tester, 'promotor-1');
      final tableId = freeNormal(store);
      final picker = find.byTooltip('Elegir mesa');
      await tester.tap(picker);
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('picker-$tableId'));
      final list = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      for (var i = 0; i < 120 && row.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(list.first, const Offset(0, -150));
        await tester.pumpAndSettle();
      }
      await tester.tap(row.hitTestable());
      await tester.pumpAndSettle();
      await tapKey(tester, 'sheet-action');
      expect(tester.takeException(), isNull);
      final flowList = find
          .descendant(
            of: find.byType(ReservationFlowPage),
            matching: find.byType(Scrollable),
          )
          .first;
      for (final key in ['flow-name', 'flow-phone']) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          100,
          scrollable: flowList,
        );
        await tester.enterText(find.byKey(ValueKey(key)), '1');
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('flow-review')),
        100,
        scrollable: flowList,
      );
      await tapKey(tester, 'flow-review');
      // Pasó al resumen: el formulario ya no está.
      expect(find.byKey(const ValueKey('flow-review')), findsNothing);
      expect(find.byKey(const ValueKey('flow-name')), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets(
      'cliente: VIP a su nombre crea la solicitud solo al enviar',
      (tester) async {
        final store = await pumpApp(tester);
        await enter(tester, 'cliente-b');
        // Deja libre una VIP para el recorrido.
        final vip = sagsaVenue.tables.firstWhere(
          (t) => t.isVip && store.book.activeFor(_friday, t.id) == null,
        );
        await pick(tester, vip.id);
        await tapKey(tester, 'sheet-action');
        expect(store.book.activeFor(_friday, vip.id), isNull);
        await tapKey(tester, 'flow-review');
        expect(find.text('Cuenta vinculada: Cliente demo B'), findsOneWidget);
        await tapKey(tester, 'flow-submit');
        final r = store.book.activeFor(_friday, vip.id)!;
        expect(r.status, ReservationStatus.pendingPayment);
        expect(r.holder!.name, 'Cliente demo B');
        expect(r.origin, ReservationOrigin.client);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('salir del trámite normal pide confirmar; seguir conserva el '
        'plazo y salir lo cancela y libera la mesa', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, 'cliente-a');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      final r = store.book.activeFor(_friday, tableId)!;

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir del trámite?'), findsOneWidget);
      await tapKey(tester, 'leave-cancel');
      expect(find.byType(ReservationFlowPage), findsOneWidget);
      expect(store.book.byId(r.id)!.status, ReservationStatus.inProcess);
      expect(store.book.byId(r.id)!.createdAt, r.createdAt);

      // Segundo plano no cancela.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(store.book.byId(r.id)!.status, ReservationStatus.inProcess);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tapKey(tester, 'leave-confirm');
      expect(find.byType(ReservationFlowPage), findsNothing);
      expect(store.book.byId(r.id)!.status, ReservationStatus.cancelled);
      expect(store.book.activeFor(_friday, tableId), isNull);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets(
      'si el trámite vence con el resumen abierto, no se confirma',
      (tester) async {
        final clock = _Clock(fixedClock());
        final store = await pumpApp(tester, clock: clock.call);
        await enter(tester, 'cliente-a');
        final tableId = freeNormal(store);
        await pick(tester, tableId);
        await tapKey(tester, 'sheet-action');
        await tapKey(tester, 'flow-review');
        clock.now = clock.now.add(ReservationBook.inProcessTimeout);
        await tapKey(tester, 'flow-submit');
        expect(find.byKey(const ValueKey('flow-expired')), findsOneWidget);
        expect(store.book.activeFor(_friday, tableId), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('cambiar de identidad vuelve a la entrada sin la pila ni los '
        'formularios de la sesión anterior', (tester) async {
      await pumpApp(tester);
      await enter(tester, 'promotor-1');
      await tapKey(tester, 'tab-Más');
      expect(find.text('Promotor demo'), findsOneWidget);
      await tapKey(tester, 'switch-identity');
      expect(find.byKey(const ValueKey('identity-admin-1')), findsOneWidget);
      expect(find.byType(AdminPage), findsNothing);
      expect(find.text('Promotor demo'), findsOneWidget); // solo en la lista
      expect(find.byType(ReservationFlowPage), findsNothing);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('el cliente no ve titulares ajenos en «Mis reservas» ni '
        'acciones administrativas', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Mis reservas');
      expect(find.textContaining('Titular demo'), findsNothing);
      expect(store.book.forNight(_friday), isNotEmpty);
      for (final key in ['action-revoke', 'action-release', 'create-direct']) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('personal: localiza una reserva y registra la llegada solo en '
        'la noche en curso', (tester) async {
      final clock = _Clock(venueInstant(2026, 10, 9, 23));
      final store = await pumpApp(tester, clock: clock.call);
      await enter(tester, 'personal-1');
      final r = store.book
          .forNight(_friday)
          .firstWhere((r) => r.status == ReservationStatus.confirmed);
      await tester.enterText(find.byKey(const ValueKey('staff-search')), r.id);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('staff-${r.id}')), findsOneWidget);
      for (final key in ['action-revoke', 'action-release']) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      await tapKey(tester, 'staff-arrive-${r.id}');
      await tapKey(tester, 'dialog-confirm');
      expect(store.book.byId(r.id)!.status, ReservationStatus.seated);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets(
      'personal: antes de abrir la llegada está desactivada',
      (tester) async {
        final store = await pumpApp(tester);
        await enter(tester, 'personal-1');
        final r = store.book
            .forNight(_friday)
            .firstWhere((r) => r.status == ReservationStatus.confirmed);
        final button = tester.widget<ButtonStyleButton>(
          find.byKey(ValueKey('staff-arrive-${r.id}')),
        );
        expect(button.onPressed, isNull);
        expect(store.book.byId(r.id)!.status, ReservationStatus.confirmed);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    VenueMapController mapOf(WidgetTester tester) => tester
        .widget<CrystalMapScaffold>(find.byType(CrystalMapScaffold))
        .controller;

    Future<void> backToEntry(WidgetTester tester) async {
      Navigator.of(
        tester.element(find.byType(CrystalMapScaffold)),
      ).popUntil((r) => r.isFirst);
      await tester.pumpAndSettle();
    }

    testWidgets('lunes 02:00 (Colombia): el cliente ya aplica N5 (semana '
        'siguiente) y el administrador mantiene el domingo (M1); el '
        'promotor puede pasar a semanas futuras y el cliente no', (
      tester,
    ) async {
      await pumpApp(tester, clock: () => venueInstant(2026, 10, 12, 2));
      await enter(tester, 'cliente-a');
      final client = mapOf(tester);
      expect(client.nights.map((n) => n.id), [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
      ]);
      expect(client.nights.map((n) => n.id), isNot(contains('2026-10-11')));
      client.showWeek(1).ignore();
      await tester.pumpAndSettle();
      expect(client.nights.first.id, '2026-10-16');
      await backToEntry(tester);

      await enter(tester, 'admin-1');
      expect(mapOf(tester).nights.map((n) => n.id), contains('2026-10-11'));
      await backToEntry(tester);

      await enter(tester, 'promotor-1');
      final promoter = mapOf(tester);
      expect(promoter.nights.map((n) => n.id), contains('2026-10-11'));
      promoter.showWeek(1).ignore();
      await tester.pumpAndSettle();
      expect(promoter.nights.map((n) => n.id), contains('2026-10-16'));
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('con la app abierta, el catálogo del cliente cambia al '
        'llegar el lunes 00:00 sin reiniciar', (tester) async {
      final clock = _Clock(
        venueInstant(2026, 10, 11, 23, 59).add(const Duration(seconds: 30)),
      );
      await pumpApp(tester, clock: clock.call);
      await enter(tester, 'cliente-a');
      final client = mapOf(tester);
      expect(client.nights.map((n) => n.id), ['2026-10-11']);
      clock.now = clock.now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(client.nights.map((n) => n.id), [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
      ]);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('todas las perspectivas usan la misma instancia del almacén; '
        'lo creado persiste al cambiar de identidad y no se muestra a otra', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await enter(tester, 'cliente-a');
      final guest = tester.widget<GuestHomePage>(find.byType(GuestHomePage));
      expect(identical(guest.store, store), isTrue);
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      await tapKey(tester, 'flow-review');
      await tapKey(tester, 'flow-submit');
      final mine = store.book.activeFor(_friday, tableId)!;
      expect(mine.status, ReservationStatus.confirmed);
      expect(mine.createdBy, 'cliente-a');
      await tapKey(tester, 'flow-show-mine');
      await backToEntry(tester);

      await enter(tester, 'cliente-b');
      await tapKey(tester, 'tab-Mis reservas');
      expect(find.byKey(ValueKey('mine-${mine.id}')), findsNothing);
      await tapKey(tester, 'tab-Mapa');
      // Ficha pública de la mesa de A y de una sembrada: sin titulares.
      final seeded = store.book
          .forNight(_friday)
          .firstWhere((r) => r.status == ReservationStatus.confirmed);
      for (final id in [tableId, seeded.tableId]) {
        await pick(tester, id);
        expect(find.textContaining('Cliente demo A'), findsNothing);
        expect(find.textContaining('3000000001'), findsNothing);
        expect(find.textContaining('Titular demo'), findsNothing);
        for (final key in [
          'action-revoke',
          'action-release',
          'create-direct',
        ]) {
          expect(find.byKey(ValueKey(key)), findsNothing);
        }
      }
      await backToEntry(tester);

      await enter(tester, 'personal-1');
      final staff = tester.widget<StaffPage>(find.byType(StaffPage));
      expect(identical(staff.store, store), isTrue);
      await backToEntry(tester);

      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Mis reservas');
      expect(find.byKey(ValueKey('mine-${mine.id}')), findsOneWidget);
      expect(store.book.byId(mine.id)!.status, ReservationStatus.confirmed);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('cambiar de identidad desde el trámite pide confirmar: seguir '
        'conserva formulario y plazo; aceptar cancela y limpia la pila', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await enter(tester, 'promotor-1');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      final r = store.book.activeFor(_friday, tableId)!;
      await tester.enterText(
        find.byKey(const ValueKey('flow-name')),
        'Titular escrito',
      );

      await tapKey(tester, 'flow-switch-identity');
      expect(find.text('¿Salir del trámite?'), findsOneWidget);
      await tapKey(tester, 'leave-cancel');
      expect(find.byType(ReservationFlowPage), findsOneWidget);
      expect(find.text('Titular escrito'), findsOneWidget);
      expect(store.book.byId(r.id)!.status, ReservationStatus.inProcess);
      expect(store.book.byId(r.id)!.createdAt, r.createdAt);

      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
      expect(store.book.byId(r.id)!.status, ReservationStatus.inProcess);
      expect(find.text('Titular escrito'), findsOneWidget);

      await tapKey(tester, 'flow-switch-identity');
      await tapKey(tester, 'leave-confirm');
      expect(find.byType(ReservationFlowPage), findsNothing);
      expect(find.byType(GuestHomePage), findsNothing);
      expect(find.byKey(const ValueKey('identity-admin-1')), findsOneWidget);
      expect(store.book.byId(r.id)!.status, ReservationStatus.cancelled);
      expect(store.book.activeFor(_friday, tableId), isNull);

      await enter(tester, 'promotor-1');
      expect(find.byType(ReservationFlowPage), findsNothing);
      expect(find.text('Titular escrito'), findsNothing);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets(
      'una VIP enviada no se cancela al cambiar de identidad',
      (tester) async {
        final store = await pumpApp(tester);
        await enter(tester, 'cliente-b');
        final vip = sagsaVenue.tables.firstWhere(
          (t) => t.isVip && store.book.activeFor(_friday, t.id) == null,
        );
        await pick(tester, vip.id);
        await tapKey(tester, 'sheet-action');
        await tapKey(tester, 'flow-review');
        await tapKey(tester, 'flow-submit');
        final r = store.book.activeFor(_friday, vip.id)!;
        await tapKey(tester, 'flow-switch-identity');
        expect(find.text('¿Salir del trámite?'), findsNothing);
        expect(find.byKey(const ValueKey('identity-admin-1')), findsOneWidget);
        expect(store.book.byId(r.id)!.status, ReservationStatus.pendingPayment);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('el cliente vinculado ve la reserva del promotor en «Mis '
        'reservas» y su ficha de solo lectura se actualiza en vivo', (
      tester,
    ) async {
      final store = await pumpApp(tester);
      await enter(tester, 'promotor-1');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      await tester.enterText(
        find.byKey(const ValueKey('flow-name')),
        'Titular escrito',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-phone')),
        '3001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-id')),
        '1000000001',
      );
      await tapKey(tester, 'flow-review');
      await tapKey(tester, 'flow-submit');
      final r = store.book.activeFor(_friday, tableId)!;
      expect(r.linkedAccountId, 'cliente-a');
      expect(r.createdBy, 'promotor-1');
      await tapKey(tester, 'flow-show-mine');
      await backToEntry(tester);

      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Mis reservas');
      await tapKey(tester, 'mine-${r.id}');
      expect(find.byKey(ValueKey('mine-detail-${r.id}')), findsOneWidget);
      expect(find.text('Reservada'), findsOneWidget);
      expect(find.text('Sagsa'), findsOneWidget);
      expect(find.text('Titular escrito'), findsOneWidget);
      expect(find.text('Vinculada a tu cuenta'), findsOneWidget);
      for (final key in [
        'action-revoke',
        'action-release',
        'action-arrive',
        'create-direct',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expect(find.byType(FilledButton), findsNothing);

      // Un cambio en el almacén se refleja sin volver a abrir la ficha.
      String statusShown() => tester
          .widget<Text>(find.byKey(const ValueKey('mine-detail-status')))
          .data!;
      expect(statusShown(), 'Reservada');
      store.perform((b) => b.revoke(r.id));
      await tester.pumpAndSettle();
      expect(statusShown(), store.book.byId(r.id)!.statusLabel);
      expect(statusShown(), isNot('Reservada'));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('mine-${r.id}')), findsOneWidget);
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('el cliente que reserva para otra persona vincula por cédula '
        'exacta sin ver los datos de esa cuenta', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, 'cliente-a');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      await tester.tap(find.text('Otra persona'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('flow-name')),
        'Titular escrito',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-phone')),
        '3001112233',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-id')),
        '1000000002',
      );
      await tapKey(tester, 'flow-review');
      expect(
        find.text('Cuenta encontrada: se vinculará al enviar'),
        findsOneWidget,
      );
      expect(find.textContaining('Cliente demo B'), findsNothing);
      expect(find.textContaining('3000000002'), findsNothing);
      await tapKey(tester, 'flow-submit');
      final r = store.book.activeFor(_friday, tableId)!;
      expect(r.linkedAccountId, 'cliente-b');
      expect(r.createdBy, 'cliente-a');
      expect(r.holder!.name, 'Titular escrito');
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('el segundo plano no reinicia el plazo: el trámite vence a su '
        'hora original', (tester) async {
      final clock = _Clock(fixedClock());
      final store = await pumpApp(tester, clock: clock.call);
      await enter(tester, 'cliente-a');
      final tableId = freeNormal(store);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      clock.now = clock.now.add(const Duration(minutes: 9));
      for (final s in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('flow-expired')), findsNothing);
      clock.now = clock.now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-expired')), findsOneWidget);
      expect(store.book.activeFor(_friday, tableId), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.mobile());
  });
}

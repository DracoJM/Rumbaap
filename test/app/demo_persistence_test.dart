import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/app/persistence/demo_bootstrap.dart';
import 'package:rumbaap/app/persistence/demo_persistence.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/dashboard/domain/night_goals.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../features/reservations/fakes.dart';

/// Almacenamiento en memoria que puede fallar o tardar, para probar la
/// persistencia sin el plugin.
class _MemoryStorage implements DemoStorage {
  final data = <String, String>{};
  bool failReads = false;
  bool failWrites = false;
  Duration writeDelay = Duration.zero;
  int writes = 0;
  int concurrent = 0;
  int maxConcurrent = 0;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('lectura fallida');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    try {
      if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
      if (failWrites) throw StateError('escritura fallida');
      data[key] = value;
      writes++;
    } finally {
      concurrent--;
    }
  }

  @override
  Future<void> remove(String key) async => data.remove(key);
}

final _friday = Night(DateTime.utc(2026, 10, 9));
final _tonight = venueInstant(2026, 10, 9, 22);
final _key = demoStorageKey(sagsaVenue.id);

(DemoReservationStore, DemoTicketStore, DemoBarStore) _stores() => (
  DemoReservationStore(
    venue: sagsaVenue,
    latency: Duration.zero,
    clock: () => _tonight,
  ),
  DemoTicketStore(
    venueId: sagsaVenue.id,
    venueTag: sagsaConfig.ticketTag,
    clock: () => _tonight,
    latency: Duration.zero,
  ),
  DemoBarStore(
    venue: sagsaVenue,
    menu: sagsaConfig.menu,
    clock: () => _tonight,
  ),
);

String _encode(DemoReservationStore r, DemoTicketStore t, DemoBarStore b) =>
    encodeDemoSnapshot(
      config: sagsaConfig,
      reservations: r,
      tickets: t,
      bar: b,
      savedAt: _tonight,
    );

void main() {
  group('formato guardado (ida y vuelta)', () {
    test('conserva reserva, canje, credencial retirada, incidencias, actores '
        'y resultados por operación; no regenera credenciales', () async {
      final (r, t, b) = _stores();
      final res = r.perform((b) {
        final s = b.startNormal(
          night: _friday,
          tableId: 'M01',
          origin: ReservationOrigin.client,
          createdBy: 'cliente-a',
        );
        return b.submitNormal(
          s.id,
          holder: const ReservationHolder(name: 'Titular demo', phone: '1'),
        );
      });
      final p = t.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 2,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      t.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
      final [used, other] = t.book.ticketsOf(p.id);
      final usedCode = used.credential!;
      await t.redeem(
        usedCode,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
        requestId: 'op-1',
      );
      final oldOther = other.credential!;
      t.perform(
        (b) => b.replaceCredential(other.id, actorId: 'cliente-a', reason: 'x'),
      );
      await t.doorCheck('nada', actorId: 'seguridad-1');

      final sale = b.perform(
        (x) => x.register(
          quantities: {'coctel': 2},
          paidInFull: true,
          actorId: 'barra-1',
          reservationId: res.id,
          tableId: res.tableId,
          accountId: 'cliente-a',
        ),
      );
      b.perform(
        (x) => x.adjust(
          sale.id,
          quantities: {'coctel': 1},
          actorId: 'caja-1',
          reason: 'De más',
        ),
      );
      b.perform(
        (x) => x.acceptConsumption(
          reservationId: res.id,
          tableId: res.tableId,
          night: _friday,
          actorId: 'personal-1',
        ),
      );
      final raw = _encode(r, t, b);
      final (r2, t2, b2) = _stores();
      decodeDemoSnapshot(
        raw,
        config: sagsaConfig,
        reservations: r2,
        tickets: t2,
        bar: b2,
      );

      expect(r2.book.byId(res.id)!.status, ReservationStatus.confirmed);
      final restoredSale = b2.book.saleById(sale.id)!;
      expect(restoredSale.total, 35000);
      expect(restoredSale.corrections.single.actorId, 'caja-1');
      expect(b2.book.salesOfAccount('cliente-a').single.id, sale.id);
      expect(b2.book.acceptanceFor(res.id)!.acceptedBy, 'personal-1');
      expect(r2.ownReservations('cliente-a').map((x) => x.id), [res.id]);
      final restoredOther = t2.book.ticketById(other.id)!;
      expect(restoredOther.credential, t.book.ticketById(other.id)!.credential);
      expect(t2.book.ticketById(used.id)!.status, TicketStatus.redeemed);
      expect(t2.book.incidents, hasLength(1));
      expect(
        t2.book
            .ticketById(used.id)!
            .history
            .firstWhere((e) => e.type == TicketEventType.redeemed)
            .actorId,
        'caja-1',
      );

      // Tras reabrir: el canjeado sigue sin servir, la retirada tampoco.
      expect(
        t2.book.doorCheck(usedCode, actorId: 'seguridad-1').reason,
        RejectReason.redeemed,
      );
      expect(
        t2.book.doorCheck(oldOther, actorId: 'seguridad-1').reason,
        RejectReason.retiredCredential,
      );
      // El mismo identificador de operación no vuelve a canjear.
      final replay = await t2.redeem(
        usedCode,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
        requestId: 'op-1',
      );
      expect(replay.outcome, CheckOutcome.redeemedNow);
      expect(
        t2.book
            .ticketById(used.id)!
            .history
            .where((e) => e.type == TicketEventType.redeemed),
        hasLength(1),
      );
      // Una venta nueva no reutiliza ninguna credencial anterior.
      final p2 = t2.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-b',
          ownerId: 'cliente-b',
        ),
      );
      t2.perform((b) => b.simulatePayment(p2.id, actorId: 'cliente-b'));
      final fresh = t2.book.ticketsOf(p2.id).single;
      expect([
        usedCode,
        oldOther,
        restoredOther.credential,
      ], isNot(contains(fresh.credential)));
      expect(fresh.id, isNot(anyOf(used.id, other.id)));
    });

    test('datos dañados, de otra versión o de otro local se rechazan sin '
        'aplicar nada', () {
      for (final (raw, incompatible) in [
        ('{no es json', false),
        (jsonEncode({'format': 99, 'venueId': 'sagsa'}), true),
        (jsonEncode({'format': demoSnapshotFormat, 'venueId': 'otro'}), true),
        (jsonEncode({'format': demoSnapshotFormat, 'venueId': 'sagsa'}), false),
      ]) {
        final (r, t, b) = _stores();
        expect(
          () => decodeDemoSnapshot(
            raw,
            config: sagsaConfig,
            reservations: r,
            tickets: t,
            bar: b,
          ),
          throwsA(
            isA<DemoDataException>().having(
              (e) => e.incompatible,
              'incompatible',
              incompatible,
            ),
          ),
        );
        expect(t.book.tickets, isEmpty);
        expect(r.book.exportState().reservations, isEmpty);
      }
    });

    test('una entrada canjeada sin hora de canje no se carga (no se adivina '
        'ni se reactiva)', () async {
      final (r, t, b) = _stores();
      final p = t.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      t.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
      await t.redeem(
        t.book.ticketsOf(p.id).single.credential!,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
        requestId: 'x',
      );
      final json = jsonDecode(_encode(r, t, b)) as Map<String, Object?>;
      ((json['tickets']! as Map)['tickets']! as List).cast<Map>().single.remove(
        'redeemedAt',
      );
      final (r2, t2, b2) = _stores();
      expect(
        () => decodeDemoSnapshot(
          jsonEncode(json),
          config: sagsaConfig,
          reservations: r2,
          tickets: t2,
          bar: b2,
        ),
        throwsA(isA<DemoDataException>()),
      );
      expect(t2.book.tickets, isEmpty);
    });
  });

  group('escrituras', () {
    test('en serie y siempre con el estado más reciente al final', () async {
      final storage = _MemoryStorage()
        ..writeDelay = const Duration(milliseconds: 5);
      var version = 0;
      final p = DemoPersistence(
        storage: storage,
        key: 'k',
        encode: () => 'v$version',
      );
      for (var i = 1; i <= 5; i++) {
        version = i;
        p.markDirty();
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await p.flush();
      expect(storage.maxConcurrent, 1);
      expect(storage.data['k'], 'v5');
    });

    test('un fallo se informa y reintentar lo resuelve', () async {
      final storage = _MemoryStorage()..failWrites = true;
      final p = DemoPersistence(storage: storage, key: 'k', encode: () => 'x');
      p.markDirty();
      await p.flush();
      expect(p.error, isNotNull);
      storage.failWrites = false;
      await p.retry();
      await p.flush();
      expect(p.error, isNull);
      expect(storage.data['k'], 'x');
    });
  });

  group('cierre y reapertura de la app', () {
    Future<void> boot(WidgetTester tester, _MemoryStorage storage) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        DemoBootstrap(
          config: sagsaConfig,
          storage: storage,
          clock: () => _tonight,
          reservationLatency: Duration.zero,
          ticketLatency: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
    }

    RumbaapApp app(WidgetTester tester) =>
        tester.widget<RumbaapApp>(find.byType(RumbaapApp));

    Future<void> close(WidgetTester tester) async {
      await tester.runAsync(() => app(tester).persistence!.flush());
      await tester.pumpWidget(const SizedBox());
    }

    testWidgets('lo creado sobrevive a cerrar y abrir; cambiar de identidad '
        'no borra nada', (tester) async {
      final storage = _MemoryStorage();
      await boot(tester, storage);
      expect(find.byKey(const ValueKey('identity-cliente-a')), findsOneWidget);
      final a = app(tester);
      final res = a.store.perform((b) {
        final s = b.startNormal(
          night: _friday,
          tableId: 'M02',
          origin: ReservationOrigin.client,
          createdBy: 'cliente-a',
        );
        return b.submitNormal(
          s.id,
          holder: const ReservationHolder(name: 'Titular demo', phone: '1'),
        );
      });
      final p = a.tickets.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      a.tickets.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
      final code = a.tickets.book.ticketsOf(p.id).single.credential!;
      await tester.runAsync(
        () => a.tickets.redeem(
          code,
          actorId: 'caja-1',
          point: RedeemPoint.boxOffice,
          requestId: 'op',
        ),
      );
      // Cambiar de identidad (entrar y volver) no toca los datos.
      await tester.tap(find.byKey(const ValueKey('identity-cliente-b')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await close(tester);

      await boot(tester, storage);
      final b = app(tester);
      expect(b.store.book.byId(res.id)!.status, ReservationStatus.confirmed);
      expect(b.tickets.ticketsOf('cliente-a').single.credential, code);
      expect(
        b.tickets.book.doorCheck(code, actorId: 'seguridad-1').reason,
        RejectReason.redeemed,
      );
    });

    testWidgets('una meta de una noche sin movimientos sobrevive a cerrar y '
        'abrir', (tester) async {
      final storage = _MemoryStorage();
      final empty = Night(DateTime.utc(2026, 10, 23));
      await boot(tester, storage);
      tester
          .widget<RumbaapApp>(find.byType(RumbaapApp))
          .goals
          .perform(
            (b) => b.set(empty, GoalMetric.ticketIncome, 9000, actorId: 'a1'),
          );
      await close(tester);
      await boot(tester, storage);
      final restored = tester
          .widget<RumbaapApp>(find.byType(RumbaapApp))
          .goals
          .book
          .goalFor(empty, GoalMetric.ticketIncome);
      expect(restored?.target, 9000);
    });

    testWidgets('datos dañados: se explica, no se reemplazan y no se ofrecen '
        'acciones hasta decidir', (tester) async {
      final storage = _MemoryStorage()..data[_key] = '{dañado';
      await boot(tester, storage);
      expect(find.byKey(const ValueKey('demo-load-error')), findsOneWidget);
      expect(find.byType(RumbaapApp), findsNothing);
      expect(storage.data[_key], '{dañado');

      await tester.tap(find.byKey(const ValueKey('demo-reset-from-error')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog-cancel')));
      await tester.pumpAndSettle();
      expect(storage.data[_key], '{dañado');

      await tester.tap(find.byKey(const ValueKey('demo-reset-from-error')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(RumbaapApp), findsOneWidget);
    });

    testWidgets('error de lectura: se informa y se puede reintentar', (
      tester,
    ) async {
      final storage = _MemoryStorage()..failReads = true;
      await boot(tester, storage);
      expect(find.byKey(const ValueKey('demo-load-error')), findsOneWidget);
      storage.failReads = false;
      await tester.tap(find.byKey(const ValueKey('demo-retry')));
      await tester.pumpAndSettle();
      expect(find.byType(RumbaapApp), findsOneWidget);
    });

    testWidgets('«Reiniciar demostración» pide confirmación y borra solo los '
        'datos de este local', (tester) async {
      final storage = _MemoryStorage()..data['rumbaap.demo.v1.otro'] = 'otro';
      await boot(tester, storage);
      final a = app(tester);
      final p = a.tickets.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      await tester.runAsync(() => a.persistence!.flush());
      expect(storage.data.containsKey(_key), isTrue);

      final reset = find.byKey(const ValueKey('demo-reset'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => app(tester).persistence!.flush());

      expect(app(tester).tickets.book.purchaseById(p.id), isNull);
      expect(storage.data['rumbaap.demo.v1.otro'], 'otro');
    });

    testWidgets('un fallo al guardar muestra el aviso con «Reintentar»', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await boot(tester, storage);
      storage.failWrites = true;
      app(tester).tickets.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      await tester.runAsync(() => app(tester).persistence!.flush());
      await tester.pump();
      expect(find.byKey(const ValueKey('save-error')), findsOneWidget);
      storage.failWrites = false;
      await tester.tap(find.byKey(const ValueKey('save-retry')));
      await tester.runAsync(() => app(tester).persistence!.flush());
      await tester.pump();
      expect(find.byKey(const ValueKey('save-error')), findsNothing);
    });
  });

  test('cada local guarda en su propia clave', () {
    expect(demoStorageKey('sagsa'), isNot(demoStorageKey('otro')));
  });
}

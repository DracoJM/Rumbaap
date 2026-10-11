import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_table.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));

const _phone = Size(411, 914);

/// Reloj que el test puede adelantar.
class _Clock {
  _Clock(this.now);

  DateTime now;
  DateTime call() => now;
}

/// Monta la app en tamaño de teléfono, con «reducir movimiento» (la
/// animación es infinita) y abre la vista del administrador desde el inicio.
Future<DemoReservationStore> _openAdmin(
  WidgetTester tester, {
  _Clock? clock,
  DemoReservationStore? store,
  Size size = _phone,
}) async {
  final c = clock ?? _Clock(fixedClock());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final s =
      store ??
      DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: c.call,
      );
  await tester.pumpWidget(
    RumbaapApp(config: sagsaConfig, store: s, clock: c.call),
  );
  await tester.ensureVisible(find.text('Administrador (demostración)'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Administrador (demostración)'));
  await tester.pumpAndSettle();
  return s;
}

TableMapStatus _statusOf(WidgetTester tester, String id) =>
    tester.widget<CrystalTable>(find.byKey(ValueKey('table-$id'))).status;

/// Abre el detalle de la ficha v7 si está cerrada.
Future<void> _expandSheet(WidgetTester tester) async {
  final more = find.bySemanticsLabel('Ver detalle de la mesa');
  if (more.evaluate().isEmpty) return;
  await tester.tap(more);
  await tester.pumpAndSettle();
}

/// Abre una sección de la barra inferior («Mapa» o «Reservas»).
Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('tab-$label')));
  await tester.pumpAndSettle();
}

/// Abre una lista de la sección Reservas: «Pendientes», «Reservas» o
/// «Actividad».
Future<void> _list(WidgetTester tester, String label) async {
  if (find.byType(SegmentedButton<AdminList>).evaluate().isEmpty) {
    await _tab(tester, 'Reservas');
  }
  final segment = find.descendant(
    of: find.byType(SegmentedButton<AdminList>),
    matching: find.text(label),
  );
  // La fila de segmentos se desplaza en horizontal si no cabe.
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

/// Selecciona la mesa desde «Elegir mesa», como lo haría la persona, y abre
/// su ficha.
Future<void> _pick(WidgetTester tester, String id) async {
  await tester.tap(find.byTooltip('Elegir mesa'));
  await tester.pumpAndSettle();
  final row = find.byKey(ValueKey('picker-$id'));
  await tester.scrollUntilVisible(
    row,
    80,
    scrollable: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  await _expandSheet(tester);
}

/// Toca [finder] tras desplazarlo a la vista. Antes retira el aviso del
/// resultado anterior, como haría quien espera a que desaparezca.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  for (final m in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    m.removeCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _dialog(WidgetTester tester, {required bool confirm}) async {
  await tester.tap(
    find.byKey(ValueKey(confirm ? 'dialog-confirm' : 'dialog-cancel')),
  );
  await tester.pumpAndSettle();
}

String _freeNormal(DemoReservationStore store, Night night) => sagsaVenue.tables
    .firstWhere((t) => !t.isVip && store.book.activeFor(night, t.id) == null)
    .id;

Reservation _first(
  DemoReservationStore store,
  Night night,
  ReservationStatus status,
) => store.book.forNight(night).firstWhere((r) => r.status == status);

/// Asegura una VIP pendiente de pago en la noche, como la dejaría un cliente.
Future<Reservation> _pendingVip(
  WidgetTester tester,
  DemoReservationStore store,
  Night night,
) async {
  final existing = store.book
      .forNight(night)
      .where((r) => r.status == ReservationStatus.pendingPayment)
      .firstOrNull;
  if (existing != null) return existing;
  final table = sagsaVenue.tables.firstWhere(
    (t) => t.isVip && store.book.activeFor(night, t.id) == null,
  );
  final r = store.perform(
    (b) => b.requestVip(
      night: night,
      tableId: table.id,
      holder: const ReservationHolder(
        name: 'Titular demo VIP',
        idNumber: '0000000099',
        phone: '0000000099',
      ),
      origin: ReservationOrigin.client,
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

Future<void> _fillForm(
  WidgetTester tester, {
  String name = 'Titular demo nuevo',
  String id = '0000000042',
  String phone = '0000000042',
}) async {
  await tester.enterText(find.byKey(const ValueKey('field-name')), name);
  await tester.enterText(find.byKey(const ValueKey('field-id')), id);
  await tester.enterText(find.byKey(const ValueKey('field-phone')), phone);
  await tester.pump();
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('navegación', () {
    testWidgets(
      'inicio → mapa → atrás → administrador → atrás con el botón del sistema',
      (tester) async {
        final clock = _Clock(fixedClock());
        final store = DemoReservationStore(
          venue: sagsaVenue,
          latency: Duration.zero,
          clock: clock.call,
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(
          RumbaapApp(config: sagsaConfig, store: store, clock: clock.call),
        );
        expect(find.textContaining('datos ficticios'), findsOneWidget);
        expect(find.textContaining('autenticación'), findsOneWidget);

        await tester.ensureVisible(find.text('Cliente demo A'));

        await tester.pumpAndSettle();

        await tester.tap(find.text('Cliente demo A'));
        await tester.pumpAndSettle();
        expect(find.byType(CrystalTable), findsNWidgets(22));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Administrador (demostración)'));

        await tester.pumpAndSettle();

        await tester.tap(find.text('Administrador (demostración)'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminPage), findsOneWidget);
        expect(
          find.text('Datos ficticios · sin autenticación real'),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AdminPage), findsNothing);
        expect(find.text('Administrador (demostración)'), findsOneWidget);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('muestra la noche con el horario del local', (tester) async {
      await _openAdmin(tester);
      expect(find.text('Vie 9 oct'), findsOneWidget);
      expect(
        find.text('8:30 p. m. – 3:00 a. m. (hora de Colombia)'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Noche siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Sáb 10 oct'), findsOneWidget);
    });
  });

  group('reserva directa', () {
    testWidgets('normal: valida campos, crea una sola reserva confirmada y la '
        'muestra en mapa y panel', (tester) async {
      final store = await _openAdmin(tester);
      final tableId = _freeNormal(store, _friday);
      final before = store.book.forNight(_friday).length;

      await _pick(tester, tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('create-direct')));
      expect(find.text('Reserva directa'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('form-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre del titular.'), findsOneWidget);
      expect(find.text('Escribe la cédula.'), findsOneWidget);
      expect(find.text('Escribe el teléfono.'), findsOneWidget);

      await _fillForm(tester, id: '12.345', phone: '300 000');
      await tester.tap(find.byKey(const ValueKey('form-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Usa solo dígitos, sin puntos, espacios ni guiones.'),
        findsNWidgets(2),
      );
      expect(store.book.forNight(_friday), hasLength(before));

      await _fillForm(tester);
      // Dos toques seguidos no crean dos reservas.
      await tester.tap(find.byKey(const ValueKey('form-submit')));
      await tester.tap(
        find.byKey(const ValueKey('form-submit')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final created = store.book.activeFor(_friday, tableId)!;
      expect(store.book.forNight(_friday), hasLength(before + 1));
      expect(created.status, ReservationStatus.confirmed);
      expect(created.holder!.name, 'Titular demo nuevo');
      expect(created.holder!.idNumber, '0000000042');
      expect(created.history.map((e) => e.type), [
        ReservationEventType.createdDirect,
      ]);
      expect(find.textContaining('Reserva ${created.id} creada'), findsOne);
      expect(_statusOf(tester, tableId), TableMapStatus.reserved);
      expect(find.text('Titular demo nuevo'), findsOneWidget);
    });

    testWidgets('VIP: se explica el prepago y queda confirmada', (
      tester,
    ) async {
      final store = await _openAdmin(tester);
      final vip = sagsaVenue.tables.firstWhere(
        (t) => t.isVip && store.book.activeFor(_friday, t.id) == null,
      );
      await _pick(tester, vip.id);
      await _tapVisible(tester, find.byKey(const ValueKey('create-direct')));
      expect(find.textContaining('verificaste el prepago'), findsOneWidget);
      await _fillForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-submit')));
      await tester.pumpAndSettle();

      final created = store.book.activeFor(_friday, vip.id)!;
      expect(created.status, ReservationStatus.confirmed);
      expect(_statusOf(tester, vip.id), TableMapStatus.reserved);
    });

    testWidgets('cancelar no crea ni modifica reservas', (tester) async {
      final store = await _openAdmin(tester);
      final tableId = _freeNormal(store, _friday);
      final before = store.book.forNight(_friday).length;
      await _pick(tester, tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('create-direct')));
      await _fillForm(tester);
      await tester.tap(find.byKey(const ValueKey('form-cancel')));
      await tester.pumpAndSettle();

      expect(store.book.forNight(_friday), hasLength(before));
      expect(_statusOf(tester, tableId), TableMapStatus.available);
    });

    testWidgets(
      'el formulario conserva su noche: si cierra mientras está abierto, '
      'no crea la reserva en otra fecha',
      (tester) async {
        final clock = _Clock(venueInstant(2026, 10, 10, 2, 50));
        final store = await _openAdmin(tester, clock: clock);
        expect(find.text('Vie 9 oct · En curso'), findsOneWidget);
        final tableId = _freeNormal(store, _friday);
        await _pick(tester, tableId);
        await _tapVisible(tester, find.byKey(const ValueKey('create-direct')));
        await _fillForm(tester);

        // Cruza el cierre de las 03:00 con el formulario abierto.
        clock.now = venueInstant(2026, 10, 10, 3);
        await tester.pump(const Duration(minutes: 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('form-submit')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('form-error')), findsOneWidget);
        expect(find.textContaining('Esa noche ya terminó'), findsOneWidget);
        expect(store.book.activeFor(_friday, tableId), isNull);
        expect(
          store.book
              .forNight(_saturday)
              .where((r) => r.holder!.name == 'Titular demo nuevo'),
          isEmpty,
        );
      },
    );
  });

  group('VIP pendiente de pago', () {
    testWidgets(
      'desde la bandeja se abre la misma reserva; cancelar no cambia nada y '
      'confirmar el prepago la deja reservada',
      (tester) async {
        final store = await _openAdmin(tester);
        final vip = await _pendingVip(tester, store, _friday);

        await _list(tester, 'Pendientes');
        expect(find.text('Pagos VIP por verificar'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('pending-${vip.id}')));
        await tester.pumpAndSettle();
        expect(find.text('Reserva ${vip.id}'), findsOneWidget);
        expect(find.text(vip.holder!.name), findsOneWidget);

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('action-confirm-prepayment')),
        );
        await _dialog(tester, confirm: false);
        expect(
          store.book.byId(vip.id)!.status,
          ReservationStatus.pendingPayment,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('action-confirm-prepayment')),
        );
        await _dialog(tester, confirm: true);
        final after = store.book.byId(vip.id)!;
        expect(after.status, ReservationStatus.confirmed);
        expect(after.history.last.type, ReservationEventType.prepaymentMarked);
        expect(find.text('Prepago marcado como verificado'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('pending-${vip.id}')), findsNothing);
        await _tab(tester, 'Mapa');
        expect(_statusOf(tester, vip.tableId), TableMapStatus.reserved);
      },
    );

    testWidgets('rechazar distingue el evento y libera la mesa', (
      tester,
    ) async {
      final store = await _openAdmin(tester);
      final vip = await _pendingVip(tester, store, _friday);
      await _pick(tester, vip.tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('action-reject')));
      await _dialog(tester, confirm: true);

      final after = store.book.byId(vip.id)!;
      expect(after.status, ReservationStatus.revoked);
      expect(after.history.last.type, ReservationEventType.rejected);
      expect(_statusOf(tester, vip.tableId), TableMapStatus.available);

      // La reserva rechazada sigue consultable desde la mesa.
      await _tapVisible(tester, find.byKey(ValueKey('previous-${vip.id}')));
      expect(find.text('Rechazada'), findsOneWidget);
      expect(find.text('Solicitud rechazada'), findsOneWidget);
    });
  });

  group('llegada', () {
    testWidgets('antes de abrir no se puede marcar y se explica cuándo', (
      tester,
    ) async {
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      await _pick(tester, r.tableId);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Registrar llegada'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('desde las 8:30 p. m. del viernes 9 de octubre'),
        findsOneWidget,
      );
      expect(store.book.byId(r.id)!.status, ReservationStatus.confirmed);
    });

    testWidgets('durante la noche pasa de Reservada a Ocupada', (tester) async {
      final clock = _Clock(venueInstant(2026, 10, 9, 23));
      final store = await _openAdmin(tester, clock: clock);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      await _pick(tester, r.tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('action-arrival')));
      await _dialog(tester, confirm: true);

      expect(store.book.byId(r.id)!.status, ReservationStatus.seated);
      expect(_statusOf(tester, r.tableId), TableMapStatus.occupied);
      expect(find.textContaining('Llegada registrada'), findsWidgets);
    });
  });

  group('revocar y liberar', () {
    testWidgets('revocar: cancelar no cambia nada; confirmar libera la mesa '
        'y conserva la reserva en la actividad', (tester) async {
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      await _pick(tester, r.tableId);

      await _tapVisible(tester, find.byKey(const ValueKey('action-revoke')));
      expect(find.textContaining(r.holder!.name), findsWidgets);
      await _dialog(tester, confirm: false);
      expect(store.book.byId(r.id)!.status, ReservationStatus.confirmed);

      await _tapVisible(tester, find.byKey(const ValueKey('action-revoke')));
      await _dialog(tester, confirm: true);
      expect(store.book.byId(r.id)!.status, ReservationStatus.revoked);
      expect(_statusOf(tester, r.tableId), TableMapStatus.available);
      expect(find.byKey(ValueKey('previous-${r.id}')), findsOneWidget);
    });

    testWidgets('liberar pide doble confirmación y cancelar en cada paso no '
        'cambia nada', (tester) async {
      final clock = _Clock(venueInstant(2026, 10, 9, 23));
      final store = await _openAdmin(tester, clock: clock);
      final r = _first(store, _friday, ReservationStatus.seated);
      await _pick(tester, r.tableId);

      await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
      expect(find.textContaining('OCUPADA'), findsOneWidget);
      await _dialog(tester, confirm: false);
      expect(store.book.byId(r.id)!.status, ReservationStatus.seated);

      await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
      await _dialog(tester, confirm: true);
      expect(find.text('¿Confirmas la liberación?'), findsOneWidget);
      await _dialog(tester, confirm: false);
      expect(store.book.byId(r.id)!.status, ReservationStatus.seated);

      await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
      await _dialog(tester, confirm: true);
      await _dialog(tester, confirm: true);
      final after = store.book.byId(r.id)!;
      expect(after.status, ReservationStatus.released);
      expect(
        after.history.where((e) => e.type == ReservationEventType.released),
        hasLength(1),
      );
      expect(_statusOf(tester, r.tableId), TableMapStatus.available);
    });

    testWidgets('si la reserva cambió con la confirmación abierta, no se '
        'aplica y se explica', (tester) async {
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      await _pick(tester, r.tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('action-revoke')));

      // Otra vista la libera mientras el diálogo sigue abierto.
      store.perform((b) => b.release(r.id));
      await tester.pump();
      await _dialog(tester, confirm: true);

      final after = store.book.byId(r.id)!;
      expect(after.status, ReservationStatus.released);
      expect(
        after.history.map((e) => e.type),
        isNot(contains(ReservationEventType.revoked)),
      );
      expect(find.textContaining('cambió mientras decidías'), findsOneWidget);
    });

    // Liberar admite Reservada y Ocupada (R6), pero el aviso de cada una es
    // distinto: un cambio entre ambas con el diálogo abierto debe detener el
    // recorrido (I13) y obligar a empezarlo con la advertencia correcta.
    void expectStillSeatedAfterArrival(
      WidgetTester tester,
      DemoReservationStore store,
      Reservation r,
    ) {
      final after = store.book.byId(r.id)!;
      expect(after.status, ReservationStatus.seated);
      expect(
        after.history.map((e) => e.type),
        contains(ReservationEventType.arrived),
      );
      expect(
        after.history.map((e) => e.type),
        isNot(contains(ReservationEventType.released)),
      );
      expect(_statusOf(tester, r.tableId), TableMapStatus.occupied);
      expect(find.textContaining('cambió mientras decidías'), findsOneWidget);
      expect(find.text('¿Confirmas la liberación?'), findsNothing);
    }

    testWidgets(
      'liberar: si llega el titular con el primer aviso abierto, se detiene; '
      'después se puede liberar la Ocupada con su propia advertencia',
      (tester) async {
        final clock = _Clock(venueInstant(2026, 10, 9, 23));
        final store = await _openAdmin(tester, clock: clock);
        final r = _first(store, _friday, ReservationStatus.confirmed);
        await _pick(tester, r.tableId);

        await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
        expect(find.textContaining('reserva confirmada'), findsOneWidget);
        store.perform((b) => b.markArrival(r.id));
        await tester.pump();
        await _dialog(tester, confirm: true);
        expectStillSeatedAfterArrival(tester, store, r);

        // Nuevo recorrido sobre la Ocupada: advertencia propia; cancelar no
        // cambia nada y las dos confirmaciones la liberan una sola vez.
        await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
        expect(find.textContaining('OCUPADA'), findsOneWidget);
        await _dialog(tester, confirm: false);
        expect(store.book.byId(r.id)!.status, ReservationStatus.seated);

        await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
        expect(find.textContaining('OCUPADA'), findsOneWidget);
        await _dialog(tester, confirm: true);
        await _dialog(tester, confirm: true);
        final after = store.book.byId(r.id)!;
        expect(after.status, ReservationStatus.released);
        expect(
          after.history.where((e) => e.type == ReservationEventType.released),
          hasLength(1),
        );
        expect(_statusOf(tester, r.tableId), TableMapStatus.available);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'liberar: si llega el titular con la segunda confirmación abierta, no '
      'se libera y se conserva la llegada',
      (tester) async {
        final clock = _Clock(venueInstant(2026, 10, 9, 23));
        final store = await _openAdmin(tester, clock: clock);
        final r = _first(store, _friday, ReservationStatus.confirmed);
        await _pick(tester, r.tableId);

        await _tapVisible(tester, find.byKey(const ValueKey('action-release')));
        expect(find.textContaining('reserva confirmada'), findsOneWidget);
        await _dialog(tester, confirm: true);
        expect(find.text('¿Confirmas la liberación?'), findsOneWidget);
        store.perform((b) => b.markArrival(r.id));
        await tester.pump();
        await _dialog(tester, confirm: true);
        expectStillSeatedAfterArrival(tester, store, r);
      },
      variant: TargetPlatformVariant.mobile(),
    );
  });

  group('pendientes y actividad', () {
    testWidgets('la normal en proceso no tiene aprobación y vence sola en '
        'la vista abierta', (tester) async {
      final clock = _Clock(fixedClock());
      final store = await _openAdmin(tester, clock: clock);
      final r = _first(store, _friday, ReservationStatus.inProcess);
      await _list(tester, 'Pendientes');
      expect(find.byKey(ValueKey('pending-${r.id}')), findsOneWidget);
      expect(find.textContaining('Vence a las 3:10 p. m.'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('pending-${r.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('action-confirm-prepayment')),
        findsNothing,
      );
      expect(find.textContaining('No requiere acción'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      clock.now = clock.now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('pending-${r.id}')), findsNothing);

      await _list(tester, 'Reservas');
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('reservation-${r.id}')),
        80,
        // La lista de la sección, no la fila de segmentos ni la cabecera.
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('reservation-${r.id}')),
          matching: find.textContaining('Expirada'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el detalle abierto de una reserva en proceso muestra su '
        'vencimiento sin otro toque', (tester) async {
      final clock = _Clock(fixedClock());
      final store = await _openAdmin(tester, clock: clock);
      final r = _first(store, _friday, ReservationStatus.inProcess);
      await _list(tester, 'Pendientes');
      await tester.tap(find.byKey(ValueKey('pending-${r.id}')));
      await tester.pumpAndSettle();
      expect(find.text('En proceso'), findsOneWidget);

      clock.now = clock.now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(find.text('Expirada'), findsOneWidget);
      expect(find.text('Expiró sin completarse'), findsOneWidget);
    });

    testWidgets('la actividad de la noche registra la liberación', (
      tester,
    ) async {
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      store.perform((b) => b.release(r.id));
      await tester.pumpAndSettle();

      await _list(tester, 'Actividad');
      expect(find.text('Mesa liberada'), findsOneWidget);
      await tester.tap(find.text('Mesa liberada'));
      await tester.pumpAndSettle();
      expect(find.text('Reserva ${r.id}'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('no es un registro de auditoría'),
        80,
        // La lista de la sección, no la fila de segmentos ni la cabecera.
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    });
  });

  group('consulta pública', () {
    testWidgets('tras crear y liberar en admin, la consulta pública muestra el '
        'resultado sin datos personales', (tester) async {
      final store = await _openAdmin(tester);
      final tableId = _freeNormal(store, _friday);
      await _pick(tester, tableId);
      await _tapVisible(tester, find.byKey(const ValueKey('create-direct')));
      await _fillForm(tester, name: 'Titular demo privado');
      await tester.tap(find.byKey(const ValueKey('form-submit')));
      await tester.pumpAndSettle();
      final released = _first(store, _friday, ReservationStatus.confirmed);
      store.perform((b) => b.release(released.id));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cliente demo A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente demo A'));
      await tester.pumpAndSettle();

      expect(_statusOf(tester, tableId), TableMapStatus.reserved);
      expect(_statusOf(tester, released.tableId), TableMapStatus.available);
      await _pick(tester, tableId);
      expect(find.textContaining('Titular demo'), findsNothing);
      expect(find.textContaining('0000000042'), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Titular|0000000042')), findsNothing);
      semantics.dispose();
    });

    testWidgets('una consulta pública abierta se actualiza al cambiar los '
        'datos', (tester) async {
      final clock = _Clock(fixedClock());
      final store = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: clock.call,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        RumbaapApp(config: sagsaConfig, store: store, clock: clock.call),
      );
      await tester.ensureVisible(find.text('Cliente demo A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cliente demo A'));
      await tester.pumpAndSettle();
      final tableId = _freeNormal(store, _friday);

      store.perform(
        (b) => b.createDirect(
          night: _friday,
          tableId: tableId,
          holder: const ReservationHolder(
            name: 'Titular demo X',
            idNumber: '1',
            phone: '2',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_statusOf(tester, tableId), TableMapStatus.reserved);
    });
  });

  group('accesibilidad y tamaños', () {
    testWidgets('las mesas del mapa admin publican la acción tap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      final node = tester.getSemantics(
        find.byKey(ValueKey('table-${r.tableId}')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, isNot(contains(r.holder!.name)));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      await _expandSheet(tester);
      expect(find.text(r.holder!.name), findsOneWidget);
      semantics.dispose();
    });

    const sizes = <String, Size>{
      'móvil pequeño': Size(320, 568),
      'móvil pequeño horizontal': Size(568, 320),
      'tableta': Size(820, 1180),
    };
    for (final entry in sizes.entries) {
      testWidgets(
        'admin, panel, bandeja y formulario sin errores en ${entry.key}',
        (tester) async {
          final store = await _openAdmin(tester, size: entry.value);
          final r = _first(store, _friday, ReservationStatus.confirmed);
          await _pick(tester, r.tableId);
          expect(find.byKey(const ValueKey('action-revoke')), findsOneWidget);

          await _list(tester, 'Pendientes');
          await _list(tester, 'Reservas');
          await _tab(tester, 'Mapa');

          final free = _freeNormal(store, _friday);
          await _pick(tester, free);
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('create-direct')),
          );
          await _fillForm(tester);
          await _tapVisible(tester, find.byKey(const ValueKey('form-submit')));
          expect(store.book.activeFor(_friday, free), isNotNull);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.mobile(),
      );
    }

    testWidgets('texto ampliado (200 %) en teléfono sin errores', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = await _openAdmin(tester);
      final r = _first(store, _friday, ReservationStatus.confirmed);
      await _pick(tester, r.tableId);
      await _list(tester, 'Pendientes');
      expect(tester.takeException(), isNull);
    });
  });
}

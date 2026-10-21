import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  // Un toque que no llega a su destino falla la prueba.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<DemoReservationStore> pumpApp(
    WidgetTester tester, {
    Size size = const Size(411, 914),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: fixedClock,
    );
    await tester.pumpWidget(
      RumbaapApp(config: sagsaConfig, store: store, clock: fixedClock),
    );
    await tester.runAsync(() => store.availabilityFor(_friday));
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (final dy in [-200.0, 200.0]) {
      for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
        final lists = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (lists.evaluate().isEmpty) return;
        final main = lists.evaluate().reduce((a, b) {
          final sa = a.size!, sb = b.size!;
          return sa.width * sa.height >= sb.width * sb.height ? a : b;
        });
        // Desde arriba de la lista: abajo puede haber una barra flotante.
        final box = main.renderObject! as RenderBox;
        final start = box.localToGlobal(Offset(box.size.width / 2, 24));
        await tester.dragFrom(start, Offset(0, dy));
        await tester.pumpAndSettle();
      }
    }
  }

  /// Toca el control con esa clave tras desplazarlo a la vista. Si el
  /// control es más alto que la pantalla (filas con texto grande), toca el
  /// primer texto visible de la propia fila, con hit test real.
  Future<void> tapKey(WidgetTester tester, String key) async {
    // Antes retira el aviso anterior, como quien espera a que desaparezca.
    for (final m in tester.stateList<ScaffoldMessengerState>(
      find.byType(ScaffoldMessenger),
    )) {
      m.removeCurrentSnackBar();
    }
    await tester.pumpAndSettle();
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    final screen = Offset.zero & tester.view.physicalSize;
    var target = f;
    if (!screen.contains(tester.getCenter(f))) {
      target = find
          .descendant(of: f, matching: find.byType(Text))
          .evaluate()
          .map((e) => find.byElementPredicate((x) => x == e))
          .firstWhere((t) => screen.contains(tester.getCenter(t)));
    }
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String id) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await tapKey(tester, 'identity-$id');
  }

  Future<void> pick(WidgetTester tester, String tableId) async {
    final table = find.byKey(ValueKey('table-$tableId'));
    await tester.ensureVisible(table);
    await tester.pumpAndSettle();
    await tester.tap(table, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  /// La administración busca la mesa y abre su ficha completa.
  Future<void> adminPick(WidgetTester tester, String id) async {
    await tester.tap(find.byTooltip('Buscar mesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('table-search')), id);
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('picker-$id'));
    await tester.scrollUntilVisible(
      row,
      80,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    final more = find.bySemanticsLabel('Ver detalle de la mesa');
    if (more.evaluate().isNotEmpty) {
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
  }

  String freeTable(DemoReservationStore store, {required bool vip}) =>
      sagsaVenue.tables
          .firstWhere(
            (t) =>
                t.isVip == vip && store.book.activeFor(_friday, t.id) == null,
          )
          .id;

  for (final (who, vip) in [
    ('cliente-a', false),
    ('cliente-a', true),
    ('promotor-1', false),
    ('promotor-1', true),
  ]) {
    testWidgets('$who envía una reserva ${vip ? 'VIP' : 'normal'} con '
        'cumpleaños desde el formulario; queda solicitado y la reserva sigue '
        'sus reglas', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, who);
      final tableId = freeTable(store, vip: vip);
      await pick(tester, tableId);
      await tapKey(tester, 'sheet-action');
      if (who == 'promotor-1') {
        await tester.enterText(
          find.byKey(const ValueKey('flow-name')),
          'Titular demo P',
        );
        await tester.enterText(
          find.byKey(const ValueKey('flow-phone')),
          '3001112233',
        );
      }
      await tapKey(tester, 'flow-birthday');
      await tapKey(tester, 'flow-review');
      expect(
        find.text('Escribe el nombre de quien cumple años.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-birthday-name')),
        'Ana',
      );
      await tester.enterText(
        find.byKey(const ValueKey('flow-birthday-notes')),
        'Sorpresa',
      );
      await tapKey(tester, 'flow-review');
      expect(find.textContaining('sin promoción ni decoración'), findsOne);
      await tapKey(tester, 'flow-submit');
      final r = store.book.activeFor(_friday, tableId)!;
      expect(r.birthday!.honoreeName, 'Ana');
      expect(r.birthday!.notes, 'Sorpresa');
      expect(r.birthday!.stage, BirthdayStage.requested);
      expect(
        r.status,
        vip ? ReservationStatus.pendingPayment : ReservationStatus.confirmed,
      );
    });
  }

  testWidgets('cliente sin marcar cumpleaños: la reserva no lo lleva', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await enter(tester, 'cliente-a');
    final tableId = freeTable(store, vip: false);
    await pick(tester, tableId);
    await tapKey(tester, 'sheet-action');
    await tapKey(tester, 'flow-review');
    await tapKey(tester, 'flow-submit');
    expect(store.book.activeFor(_friday, tableId)!.birthday, isNull);
  });

  for (final vip in [false, true]) {
    testWidgets('administración: reserva directa ${vip ? 'VIP' : 'normal'} '
        'con cumpleaños desde el formulario', (tester) async {
      final store = await pumpApp(tester);
      await enter(tester, 'admin-1');
      final tableId = freeTable(store, vip: vip);
      await adminPick(tester, tableId);
      await tapKey(tester, 'create-direct');
      await tester.enterText(find.byKey(const ValueKey('field-name')), 'T');
      await tester.enterText(find.byKey(const ValueKey('field-id')), '42');
      await tester.enterText(find.byKey(const ValueKey('field-phone')), '42');
      await tapKey(tester, 'direct-birthday');
      await tester.enterText(
        find.byKey(const ValueKey('direct-birthday-name')),
        'Luis',
      );
      await tapKey(tester, 'form-submit');
      final r = store.book.activeFor(_friday, tableId)!;
      expect(r.status, ReservationStatus.confirmed);
      expect(r.birthday!.honoreeName, 'Luis');
      expect(r.birthday!.stage, BirthdayStage.requested);
    });
  }

  Reservation seedBirthday(DemoReservationStore store) {
    final started = store.perform(
      (b) => b.startNormal(
        night: _friday,
        tableId: freeTable(store, vip: false),
        origin: ReservationOrigin.client,
        actorId: 'cliente-a',
      ),
    );
    return store.perform(
      (b) => b.submitNormal(
        actorId: 'cliente-a',
        started.id,
        holder: const ReservationHolder(name: 'Titular', phone: '300'),
        birthday: const BirthdayCelebration(honoreeName: 'Ana'),
      ),
    );
  }

  Future<void> confirmTerms(
    WidgetTester tester,
    Reservation r,
    String text, {
    bool toggleDecoration = false,
  }) async {
    await tapKey(tester, 'birthday-confirm-${r.id}');
    await tester.enterText(
      find.byKey(const ValueKey('birthday-conditions')),
      text,
    );
    if (toggleDecoration) {
      await tester.tap(find.byKey(const ValueKey('birthday-decoration')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('el cliente ve el cumpleaños pendiente y sin acciones; la '
      'administración confirma, prepara, ajusta (la decoración vuelve a '
      'revisión con el historial) y lo ve en la lista de la noche', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    final r = seedBirthday(store);

    await enter(tester, 'cliente-a');
    await tapKey(tester, 'tab-Mis reservas');
    await tapKey(tester, 'mine-${r.id}');
    await reveal(tester, find.byKey(ValueKey('birthday-stage-${r.id}')));
    expect(find.textContaining('pendiente de confirmar'), findsWidgets);
    expect(find.byKey(ValueKey('birthday-confirm-${r.id}')), findsNothing);

    await enter(tester, 'admin-1');
    await tapKey(tester, 'tab-Reservas');
    final segment = find.descendant(
      of: find.byType(SegmentedButton<AdminList>),
      matching: find.text('Reservas'),
    );
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
    await tapKey(tester, 'birthday-prep-${r.id}');
    await confirmTerms(tester, r, 'Postre', toggleDecoration: true);
    expect(
      store.book.byId(r.id)!.birthday!.stage,
      BirthdayStage.decorationPending,
    );
    await tapKey(tester, 'birthday-prepared-${r.id}');
    expect(
      store.book.byId(r.id)!.birthday!.stage,
      BirthdayStage.decorationPrepared,
    );

    await confirmTerms(tester, r, 'Postre y globos');
    final b = store.book.byId(r.id)!.birthday!;
    expect(b.terms!.conditions, 'Postre y globos');
    expect(b.decorationNeedsReview, isTrue);
    expect(b.previous.single.decorationPrepared!.actorId, 'admin-1');
    await reveal(tester, find.byKey(ValueKey('birthday-previous-${r.id}-0')));
    expect(find.textContaining('revisar otra vez'), findsWidgets);
    expect(store.book.byId(r.id)!.status, ReservationStatus.confirmed);
  });

  testWidgets('vista estrecha con texto grande: formulario, ficha y diálogo '
      'del cumpleaños sin desbordes', (tester) async {
    final store = await pumpApp(
      tester,
      size: const Size(320, 640),
      textScale: 2,
    );
    final r = seedBirthday(store);
    await enter(tester, 'admin-1');
    await adminPick(tester, freeTable(store, vip: false));
    await tapKey(tester, 'create-direct');
    await tapKey(tester, 'direct-birthday');
    await reveal(tester, find.byKey(const ValueKey('direct-birthday-notes')));
    expect(tester.takeException(), isNull);

    await enter(tester, 'admin-1');
    await tapKey(tester, 'tab-Reservas');
    final segment = find.descendant(
      of: find.byType(SegmentedButton<AdminList>),
      matching: find.text('Reservas'),
    );
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
    // Desde la lista de la noche, tocando dentro de la fila.
    await tapKey(tester, 'birthday-prep-${r.id}');
    await tapKey(tester, 'birthday-confirm-${r.id}');
    expect(find.byKey(const ValueKey('birthday-decoration')), findsOne);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('dialog-cancel')));
    await tester.pumpAndSettle();

    await enter(tester, 'cliente-a');
    await tapKey(tester, 'tab-Mis reservas');
    await tapKey(tester, 'mine-${r.id}');
    await reveal(tester, find.byKey(ValueKey('birthday-stage-${r.id}')));
    expect(tester.takeException(), isNull);
  });
}

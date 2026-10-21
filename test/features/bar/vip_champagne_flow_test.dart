import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/bar/domain/champagne.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  // Un toque que no llega a su destino falla la prueba.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<(DemoReservationStore, DemoBarStore)> pumpApp(
    WidgetTester tester, {
    Size size = const Size(411, 914),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => _tonight,
    );
    final bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => _tonight,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: store,
        tickets: DemoTicketStore(
          venueId: sagsaVenue.id,
          venueTag: sagsaConfig.ticketTag,
          clock: () => _tonight,
          latency: Duration.zero,
        ),
        bar: bar,
        clock: () => _tonight,
      ),
    );
    await tester.runAsync(() => store.availabilityFor(_friday));
    return (store, bar);
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (final dy in [-250.0, 250.0]) {
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

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  for (final (label, size, scale) in [
    ('', const Size(411, 914), 1.0),
    (' (vista estrecha, texto grande)', const Size(320, 640), 2.0),
  ]) {
    testWidgets('el titular la pide con la mesa ocupada, barra registra la '
        'salida y el mesero confirma la entrega con los permisos reales de la '
        'app; administración ve cada estado y no hay venta ni cobro$label', (
      tester,
    ) async {
      final (store, bar) = await pumpApp(tester, size: size, textScale: scale);
      final table = sagsaVenue.tables.firstWhere(
        (t) => t.isVip && store.book.activeFor(_friday, t.id) == null,
      );
      var r = store.perform(
        (b) => b.submitVip(
          night: _friday,
          tableId: table.id,
          holder: const ReservationHolder(name: 'Titular VIP', phone: '300'),
          origin: ReservationOrigin.client,
          actorId: 'cliente-a',
        ),
      );
      store.perform((b) => b.markPrepaymentReceived(r.id, actorId: 'admin-1'));

      // Aprobada y verificada, pero sin ocupar: el cliente no puede pedirla.
      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Mis reservas');
      await tapKey(tester, 'mine-${r.id}');
      await reveal(tester, find.byKey(ValueKey('champagne-${r.id}')));
      expect(textOf(tester, 'champagne-${r.id}'), contains('habilitada'));
      expect(find.byKey(ValueKey('champagne-request-${r.id}')), findsNothing);

      r = store.perform((b) => b.markArrival(r.id, actorId: 'admin-1'));
      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Mis reservas');
      await tapKey(tester, 'mine-${r.id}');
      await tapKey(tester, 'champagne-request-${r.id}');
      expect(bar.book.champagneOf(r.id)!.requestedBy, 'cliente-a');
      expect(tester.takeException(), isNull);

      // El mesero ve la petición, pero la salida es de barra.
      await enter(tester, 'personal-1');
      await tapKey(tester, 'tab-Consumo');
      await tapKey(tester, 'consumption-${r.id}');
      await reveal(tester, find.byKey(ValueKey('champagne-${r.id}')));
      expect(textOf(tester, 'champagne-${r.id}'), contains('pedida'));
      expect(find.byKey(ValueKey('champagne-request-${r.id}')), findsNothing);
      expect(find.byKey(ValueKey('champagne-dispatch-${r.id}')), findsNothing);

      await enter(tester, 'barra-1');
      await tapKey(tester, 'champagne-dispatch-${r.id}');
      expect(bar.book.champagneOf(r.id)!.stage, ChampagneStage.dispatched);
      expect(find.byKey(ValueKey('bar-champagne-${r.id}')), findsNothing);

      await enter(tester, 'personal-1');
      await tapKey(tester, 'tab-Consumo');
      await tapKey(tester, 'consumption-${r.id}');
      await reveal(tester, find.byKey(ValueKey('champagne-${r.id}')));
      expect(textOf(tester, 'champagne-${r.id}'), contains('salió de barra'));
      await tapKey(tester, 'champagne-deliver-${r.id}');
      final done = bar.book.champagneOf(r.id)!;
      expect(done.stage, ChampagneStage.delivered);
      expect(done.deliveredBy, 'personal-1');
      expect(bar.book.sales, isEmpty);
      expect(tester.takeException(), isNull);
      // La lista de la administración se cubre en la vista normal.
      if (scale != 1) return;

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
      await tapKey(tester, 'reservation-${r.id}');
      await reveal(tester, find.byKey(ValueKey('champagne-${r.id}')));
      expect(
        textOf(tester, 'champagne-${r.id}'),
        contains('entregada en mesa'),
      );
      expect(find.byKey(ValueKey('champagne-deliver-${r.id}')), findsNothing);
    });
  }
}

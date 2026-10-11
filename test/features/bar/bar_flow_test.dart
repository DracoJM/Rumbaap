import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/bar/domain/bar.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  Future<(DemoReservationStore, DemoBarStore)> pumpApp(
    WidgetTester tester, {
    Size size = const Size(411, 914),
  }) async {
    tester.view.physicalSize = size;
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
      venueId: sagsaVenue.id,
      menu: sagsaConfig.menu,
      clock: () => _tonight,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: store,
        bar: bar,
        clock: () => _tonight,
      ),
    );
    // Siembra la noche como lo haría la primera consulta.
    await tester.runAsync(() => store.availabilityFor(_friday));
    return (store, bar);
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      if (lists.evaluate().isEmpty) break;
      final main = lists.evaluate().reduce((a, b) {
        final sa = a.size!, sb = b.size!;
        return sa.width * sa.height >= sb.width * sb.height ? a : b;
      });
      await tester.drag(
        find.byElementPredicate((e) => e == main),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String id) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await tapKey(tester, 'identity-$id');
  }

  testWidgets('barra registra tras el pago completo y vincula mesa y cuenta; '
      'el cliente ve su comprobante; caja anula con motivo; el mesero acepta '
      'el consumo a mano', (tester) async {
    final (store, bar) = await pumpApp(tester);
    final reservation = store.book
        .forNight(_friday)
        .firstWhere((r) => r.status == ReservationStatus.confirmed);

    // Barra.
    await enter(tester, 'barra-1');
    await tapKey(tester, 'bar-add-coctel');
    await tapKey(tester, 'bar-add-coctel');
    await tapKey(tester, 'bar-add-agua');
    await tapKey(tester, 'bar-reservation');
    await tester.tap(find.textContaining(reservation.id).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bar-qr')),
      'QRP-CLIENTE-A',
    );
    // Sin confirmar el pago completo no se registra.
    await tapKey(tester, 'bar-register');
    await tapKey(tester, 'dialog-confirm');
    expect(bar.book.sales, isEmpty);
    expect(find.textContaining('pago presencial completo'), findsWidgets);
    await tapKey(tester, 'bar-paid');
    await tapKey(tester, 'bar-register');
    await tapKey(tester, 'dialog-confirm');
    final sale = bar.book.sales.single;
    expect(sale.total, 2 * 35000 + 6000);
    expect(sale.reservationId, reservation.id);
    expect(sale.accountId, 'cliente-a');
    expect(sale.registeredBy, 'barra-1');

    // Cliente: comprobante en «Menú».
    await enter(tester, 'cliente-a');
    await tapKey(tester, 'tab-Menú');
    expect(find.byKey(ValueKey('receipt-${sale.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-coctel')), findsOneWidget);

    // Mesero: consulta y acepta.
    await enter(tester, 'personal-1');
    await tapKey(tester, 'tab-Consumo');
    await tapKey(tester, 'consumption-${reservation.id}');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('consumption-sum'))).data,
      contains('76.000 COP'),
    );
    expect(bar.book.acceptanceFor(reservation.id), isNull);
    await tapKey(tester, 'consumption-accept');
    await tapKey(tester, 'dialog-confirm');
    final acc = bar.book.acceptanceFor(reservation.id)!;
    expect(acc.acceptedBy, 'personal-1');
    expect(acc.totalSeen, 76000);

    // Caja anula con motivo; queda trazado y la aceptación avisa.
    await enter(tester, 'caja-1');
    await tapKey(tester, 'tab-Pedidos');
    await tapKey(tester, 'bar-correct-${sale.id}');
    await tapKey(tester, 'bar-void');
    await tester.enterText(
      find.byKey(const ValueKey('bar-reason')),
      'Registrada en la mesa equivocada',
    );
    await tapKey(tester, 'dialog-confirm');
    final voided = bar.book.saleById(sale.id)!;
    expect(voided.status, BarSaleStatus.voided);
    expect(voided.corrections.single.actorId, 'caja-1');
    expect(find.textContaining('Registrada en la mesa equivocada'), findsOne);

    await enter(tester, 'personal-1');
    await tapKey(tester, 'tab-Consumo');
    await tapKey(tester, 'consumption-${reservation.id}');
    expect(
      find.textContaining('cambiaron después de la aceptación'),
      findsOneWidget,
    );
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('el cliente no ve ventas de otras cuentas y el menú no permite '
      'comprar', (tester) async {
    final (_, bar) = await pumpApp(tester);
    bar.perform(
      (b) => b.register(
        quantities: {'botella': 1},
        paidInFull: true,
        actorId: 'barra-1',
        accountId: 'cliente-b',
      ),
    );
    await enter(tester, 'cliente-a');
    await tapKey(tester, 'tab-Menú');
    // Solo la carta: la venta de cliente B no aparece como comprobante.
    expect(find.byKey(const ValueKey('menu-botella')), findsOneWidget);
    expect(
      find.byKey(ValueKey('receipt-${bar.book.sales.single.id}')),
      findsNothing,
    );
    expect(find.textContaining('Total:'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
    'barra con texto al 200 % en 320 dp, sin errores',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, size: const Size(320, 568));
      await enter(tester, 'barra-1');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'bar-add-agua');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}

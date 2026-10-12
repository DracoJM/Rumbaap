import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/theme/app_background.dart';

import '../features/reservations/fakes.dart';

/// Viernes 9 de octubre de 2026, 10:00 p. m.: noche en curso.
final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  late DemoTicketStore tickets;
  late DemoBarStore bar;

  /// App completa en 320 dp con el texto al 200 %: el caso más exigente.
  Future<void> pumpNarrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final reservations = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => _tonight,
    );
    tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => _tonight,
      latency: Duration.zero,
    );
    bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => _tonight,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: reservations,
        tickets: tickets,
        bar: bar,
        clock: () => _tonight,
      ),
    );
    await tester.runAsync(() => reservations.availabilityFor(_friday));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
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
        const Offset(0, -200),
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

  Future<void> type(WidgetTester tester, String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selector de perfiles: fondo lineal sin discos, perfiles legibles y '
    'tocables en 320 dp con texto al 200 %',
    (tester) async {
      await pumpNarrow(tester);
      final background = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient = (background.decoration as BoxDecoration).gradient;
      expect(gradient, isA<LinearGradient>());
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('CLIENTE'), findsNothing);
      await tapKey(tester, 'identity-cliente-a');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'promotor: formulario de venta con nombre, teléfono y cédula en 320 dp '
    'al 200 %, y su detalle sin desbordes',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'promotor-1');
      await tapKey(tester, 'tab-Entradas');
      await type(tester, 'ticket-holder', 'Comprador demo');
      await type(tester, 'ticket-phone', '3001112233');
      await type(tester, 'ticket-id-number', '1020304050');
      await tapKey(tester, 'ticket-buy');
      expect(tester.takeException(), isNull);
      final p = tickets.purchasesBy('promotor-1').single;
      expect(p.buyerPhone, '3001112233');
      await reveal(tester, find.text('1020304050'));
      expect(find.text('1020304050'), findsOneWidget);
      await tapKey(tester, 'purchase-pay');
      await tapKey(tester, 'dialog-confirm');
      expect(find.byKey(const ValueKey('promoter-undelivered')), findsOne);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Barra: cliente sin cuenta, producto y confirmación en 320 dp al 200 %',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'barra-1');
      await tapKey(tester, 'bar-add-agua');
      final noAccount = find.text('Cliente sin cuenta');
      await reveal(tester, noAccount);
      await tester.ensureVisible(noAccount);
      await tester.pumpAndSettle();
      await tester.tap(noAccount);
      await tester.pumpAndSettle();
      await type(tester, 'bar-guest-name', 'Ana');
      await tapKey(tester, 'bar-paid');
      await tapKey(tester, 'bar-register');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapKey(tester, 'dialog-confirm');
      expect(bar.book.sales.single.customer!.name, 'Ana');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}

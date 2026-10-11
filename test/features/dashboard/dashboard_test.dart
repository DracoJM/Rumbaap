import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/admin_tickets.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));

void main() {
  late DemoReservationStore store;
  late DemoTicketStore tickets;
  late DemoBarStore bar;

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = textScale == 1
        ? const Size(411, 914)
        : const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    store = DemoReservationStore(
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
      venueId: sagsaVenue.id,
      menu: sagsaConfig.menu,
      clock: () => _tonight,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: store,
        tickets: tickets,
        bar: bar,
        clock: () => _tonight,
      ),
    );
    await tester.runAsync(() => store.availabilityFor(_friday));

    // Datos: 3 entradas pagadas el viernes (40.000 c/u), 1 cortesía,
    // 1 entrada pagada el sábado (50.000).
    final p = tickets.perform(
      (b) => b.sell(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 3,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      ),
    );
    tickets.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
    final [t1, t2, t3] = tickets.book.ticketsOf(p.id);
    tickets.perform(
      (b) => b.confirmFirstEntry(t1.credential!, actorId: 'seguridad-1'),
    );
    tickets.perform(
      (b) => b.redeem(
        t2.credential!,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
      ),
    );
    tickets.perform((b) => b.requestRefund(t3.id, actorId: 'cliente-a'));
    tickets.perform((b) => b.authorizeRequest(t3.id, actorId: 'admin-1'));
    tickets.perform(
      (b) => b.authorizeCourtesy(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        actorId: 'admin-1',
        holderName: 'Invitado',
        reason: 'VIP 1',
      ),
    );
    final sat = tickets.perform(
      (b) => b.sell(
        night: _saturday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-b',
        ownerId: 'cliente-b',
      ),
    );
    tickets.perform((b) => b.simulatePayment(sat.id, actorId: 'cliente-b'));
    // Barra: una vigente (70.000) y una anulada.
    bar.perform(
      (b) => b.register(
        quantities: {'coctel': 2},
        paidInFull: true,
        actorId: 'barra-1',
      ),
    );
    final v = bar.perform(
      (b) => b.register(
        quantities: {'botella': 1},
        paidInFull: true,
        actorId: 'barra-1',
      ),
    );
    bar.perform((b) => b.voidSale(v.id, actorId: 'caja-1', reason: 'Error'));
    // Prepago VIP verificado.
    final vip = store.book
        .forNight(_friday)
        .firstWhere((r) => r.status == ReservationStatus.pendingPayment);
    store.perform((b) => b.markPrepaymentReceived(vip.id));
    await tester.pumpAndSettle();
  }

  /// Desplaza la lista vertical principal (la de mayor área) hasta que
  /// [f] exista y se vea: las listas largas se construyen bajo demanda.
  Future<void> reveal(WidgetTester tester, Finder f, {double dy = -200}) async {
    for (var i = 0; i < 60 && f.hitTestable().evaluate().isEmpty; i++) {
      final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      final main = lists.evaluate().reduce((a, b) {
        final sa = a.size!, sb = b.size!;
        return sa.width * sa.height >= sb.width * sb.height ? a : b;
      });
      await tester.drag(
        find.byElementPredicate((e) => e == main),
        Offset(0, dy),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> openDashboard(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('identity-admin-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('tab-Más'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('open-dashboard')));
    await tester.tap(find.byKey(const ValueKey('open-dashboard')));
    await tester.pumpAndSettle();
  }

  /// Valor de un indicador; lo trae a la vista (la lista es perezosa).
  Future<String> value(WidgetTester tester, String key) async {
    await reveal(tester, find.byKey(ValueKey('dash-$key')));
    return tester.widget<Text>(find.byKey(ValueKey('dash-$key-value'))).data!;
  }

  Future<void> scrollTo(WidgetTester tester, String key) =>
      reveal(tester, find.byKey(ValueKey('dash-$key')));

  testWidgets('personas e importes por separado, sin contar dos veces ni '
      'sumar anuladas o cortesías; filtra por noche', (tester) async {
    await pumpApp(tester);
    await openDashboard(tester);
    expect(await value(tester, 'entries'), '1');
    expect(await value(tester, 'redeemed'), '1');
    // t1 (con ingreso), cortesía y la del sábado siguen sin canjear.
    expect(await value(tester, 'pending'), '3');
    await scrollTo(tester, 'ticket-income');
    expect(
      await value(tester, 'ticket-income'),
      '170.000 COP',
    ); // 3×40.000 + 50.000
    expect(await value(tester, 'refunds'), '40.000 COP');
    await scrollTo(tester, 'bar-income');
    expect(await value(tester, 'bar-income'), '70.000 COP');
    await scrollTo(tester, 'vip');
    expect(await value(tester, 'vip'), '1');
    expect(find.textContaining('para no contarlo dos veces'), findsOneWidget);
    await scrollTo(tester, 'reservations');
    expect(find.textContaining('no rentabilidad'), findsOneWidget);
    await scrollTo(tester, 'goals');
    expect(find.textContaining('sin metas configuradas'), findsOneWidget);

    // Solo el sábado: una entrada pagada, sin barra.
    await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
    await tester.tap(find.byKey(const ValueKey('dash-night')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sábado 10 de octubre de 2026').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, 'ticket-income');
    expect(await value(tester, 'ticket-income'), '50.000 COP');
    await scrollTo(tester, 'bar-income');
    expect(await value(tester, 'bar-income'), '0 COP');
  });

  testWidgets('cada indicador abre su lista y desde ella la ficha', (
    tester,
  ) async {
    await pumpApp(tester);
    await openDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('dash-redeemed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dash-list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dash-row-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminTicketPage), findsOneWidget);
    expect(find.text('Canjeada · No canjeable'), findsOneWidget);
  });

  testWidgets(
    'panel con texto al 200 % en 320 dp, sin errores',
    (tester) async {
      await pumpApp(tester, textScale: 2);
      await openDashboard(tester);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}

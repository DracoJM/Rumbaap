import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/admin_tickets.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

/// Viernes 9 de octubre de 2026, 10:00 p. m.: noche en curso.
final _tonight = venueInstant(2026, 10, 9, 22);

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  late _Clock clock;

  Future<DemoTicketStore> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    clock = _Clock(_tonight);
    final tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: clock.call,
      latency: Duration.zero,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: DemoReservationStore(
          venue: sagsaVenue,
          latency: Duration.zero,
          clock: clock.call,
        ),
        tickets: tickets,
        clock: clock.call,
      ),
    );
    return tickets;
  }

  /// Desplaza la lista visible hasta construir el elemento (las listas
  /// largas se construyen bajo demanda).
  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      if (lists.evaluate().isEmpty) break;
      // La lista principal: la de mayor área (no la cabecera ni un campo).
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
    // Vuelve a la entrada si hay una sesión abierta.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
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

  String title(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('desk-result-title')))
      .data!;

  Future<void> clientBuysAndPays(WidgetTester tester, {int qty = 1}) async {
    await enter(tester, 'cliente-a');
    await tapKey(tester, 'tab-Entradas');
    for (var i = 1; i < qty; i++) {
      await tapKey(tester, 'ticket-more');
    }
    await tapKey(tester, 'ticket-buy');
    await tapKey(tester, 'purchase-pay');
    // Del comprobante vuelve a «Entradas».
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('recorrido cliente → puerta → taquilla → administración: '
      'consulta, primer ingreso una vez, canje una vez y «No canjeable»', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await clientBuysAndPays(tester);
    final t = store.ticketsOf('cliente-a').single;
    expect(t.status, TicketStatus.active);
    final code = t.credential!;

    // Puerta: consultar no registra nada.
    await enter(tester, 'seguridad-1');
    await type(tester, 'door-code', code);
    await tapKey(tester, 'door-consult');
    expect(title(tester), contains('sin ingreso'));
    expect(
      find.textContaining('Cliente demo A · cédula 1000000001'),
      findsOneWidget,
    );
    expect(store.book.ticketById(t.id)!.firstEntryAt, isNull);
    await tapKey(tester, 'door-confirm-entry');
    expect(title(tester), 'Primer ingreso registrado.');
    await tapKey(tester, 'door-consult');
    expect(title(tester), startsWith('Ingreso ya registrado'));
    expect(title(tester), isNot(contains('..')));
    expect(find.byKey(const ValueKey('door-confirm-entry')), findsNothing);

    // Taquilla canjea aunque la puerta ya leyó la credencial.
    await enter(tester, 'caja-1');
    await type(tester, 'box-code', code);
    await tapKey(tester, 'box-redeem');
    await tapKey(tester, 'dialog-confirm');
    expect(title(tester), contains('Canje registrado'));
    await tapKey(tester, 'box-redeem');
    await tapKey(tester, 'dialog-confirm');
    expect(title(tester), startsWith('No canjeable'));

    await enter(tester, 'seguridad-1');
    await type(tester, 'door-code', code);
    await tapKey(tester, 'door-consult');
    expect(title(tester), startsWith('No canjeable'));

    final after = store.book.ticketById(t.id)!;
    expect(after.status, TicketStatus.redeemed);
    expect(
      after.history.where((e) => e.type == TicketEventType.redeemed),
      hasLength(1),
    );
    expect(
      after.history
          .where((e) => e.type == TicketEventType.firstEntryRecorded)
          .single
          .actorId,
      'seguridad-1',
    );

    // Administración: busca por cédula y abre la ficha con su historial.
    await enter(tester, 'admin-1');
    await tapKey(tester, 'tab-Entradas');
    expect(find.byType(AdminTickets), findsOneWidget);
    await type(tester, 'admin-ticket-search', '1000000001');
    await tapKey(tester, 'ticket-${t.id}');
    expect(find.text('Canjeada · No canjeable'), findsOneWidget);
    expect(find.textContaining('Seguridad demo'), findsWidgets);
    expect(find.textContaining('Caja demo'), findsWidgets);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('promotor: la venta no se activa sola; al comprobar el pago se '
      'activa y se canjea con su lote, no en taquilla', (tester) async {
    final store = await pumpApp(tester);
    await enter(tester, 'promotor-1');
    await tapKey(tester, 'tab-Entradas');
    await type(tester, 'ticket-holder', 'Comprador demo');
    await type(tester, 'ticket-phone', '3001112233');
    await type(tester, 'ticket-id-number', '1020304050');
    await tapKey(tester, 'ticket-buy');
    final p = store.purchasesBy('promotor-1').single;
    final t = store.book.ticketsOf(p.id).single;
    expect(t.status, TicketStatus.pendingPayment);
    expect(p.buyerPhone, '3001112233');
    expect(p.buyerIdNumber, '1020304050');
    expect(t.credential, isNull);
    expect(find.byKey(ValueKey('promoter-redeem-${t.id}')), findsNothing);

    await tapKey(tester, 'purchase-pay');
    await tapKey(tester, 'dialog-confirm');
    final active = store.book.ticketById(t.id)!;
    expect(active.status, TicketStatus.active);
    expect(find.byKey(ValueKey('promoter-credential-${t.id}')), findsOneWidget);

    // Taquilla no canjea una venta del promotor.
    final code = active.credential!;
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await enter(tester, 'caja-1');
    await type(tester, 'box-code', code);
    await tapKey(tester, 'box-redeem');
    await tapKey(tester, 'dialog-confirm');
    expect(title(tester), startsWith('Otro circuito'));

    // El promotor canjea con su lote.
    await enter(tester, 'promotor-1');
    await tapKey(tester, 'tab-Entradas');
    await tapKey(tester, 'purchase-${p.id}');
    await tapKey(tester, 'promoter-redeem-${t.id}');
    await tapKey(tester, 'dialog-confirm');
    expect(store.book.ticketById(t.id)!.redeemPoint, RedeemPoint.promoterLot);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('credencial reemplazada: la antigua se rechaza en puerta y la '
      'nueva funciona; otra noche se rechaza sin revocar el derecho', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await clientBuysAndPays(tester);
    final t = store.ticketsOf('cliente-a').single;
    final old = t.credential!;
    await tapKey(tester, 'ticket-${t.id}');
    await tapKey(tester, 'ticket-replace');
    await tapKey(tester, 'dialog-confirm');
    final fresh = store.book.ticketById(t.id)!.credential!;
    expect(fresh, isNot(old));
    expect(fresh.length, old.length);

    await enter(tester, 'seguridad-1');
    await type(tester, 'door-code', old);
    await tapKey(tester, 'door-consult');
    expect(title(tester), startsWith('Credencial retirada'));
    await type(tester, 'door-code', fresh);
    await tapKey(tester, 'door-consult');
    expect(title(tester), contains('sin ingreso'));

    // Entrada del sábado leída el viernes: rechazo, derecho intacto.
    final sat = store.perform(
      (b) => b.sell(
        night: Night(DateTime.utc(2026, 10, 10)),
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-b',
        ownerId: 'cliente-b',
      ),
    );
    store.perform((b) => b.simulatePayment(sat.id, actorId: 'cliente-b'));
    final satTicket = store.book.ticketsOf(sat.id).single;
    await type(tester, 'door-code', satTicket.credential!);
    await tapKey(tester, 'door-consult');
    expect(title(tester), 'La entrada es de otra noche.');
    expect(store.book.ticketById(satTicket.id)!.status, TicketStatus.active);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('sin respuesta del servicio se informa el fallo; reintentar no '
      'registra el ingreso dos veces', (tester) async {
    final store = await pumpApp(tester);
    await clientBuysAndPays(tester);
    final code = store.ticketsOf('cliente-a').single.credential!;
    await enter(tester, 'seguridad-1');
    await type(tester, 'door-code', code);
    await tapKey(tester, 'door-consult');
    store.offline = true;
    await tapKey(tester, 'door-confirm-entry');
    expect(find.byKey(const ValueKey('desk-error')), findsOneWidget);
    store.offline = false;
    await tapKey(tester, 'door-consult');
    await tapKey(tester, 'door-confirm-entry');
    expect(title(tester), 'Primer ingreso registrado.');
    expect(
      store.book
          .ticketsOf(store.purchasesBy('cliente-a').single.id)
          .single
          .history
          .where((e) => e.type == TicketEventType.firstEntryRecorded),
      hasLength(1),
    );
  });

  testWidgets('devolución: el cliente la pide, solo la administración la '
      'autoriza y la devolución efectuada se registra aparte', (tester) async {
    final store = await pumpApp(tester);
    await clientBuysAndPays(tester);
    final t = store.ticketsOf('cliente-a').single;
    await tapKey(tester, 'ticket-${t.id}');
    await tapKey(tester, 'ticket-refund');
    await tapKey(tester, 'dialog-confirm');
    expect(store.book.ticketById(t.id)!.hasOpenRequest, isTrue);

    await enter(tester, 'admin-1');
    await tapKey(tester, 'tab-Entradas');
    await tapKey(tester, 'admin-request-${t.id}');
    await tapKey(tester, 'admin-authorize');
    await tapKey(tester, 'dialog-confirm');
    final voided = store.book.ticketById(t.id)!;
    expect(voided.status, TicketStatus.voided);
    expect(voided.request!.status, TicketRequestStatus.authorized);
    await tapKey(tester, 'admin-record-refund');
    await tapKey(tester, 'dialog-confirm');
    expect(
      store.book.ticketById(t.id)!.request!.status,
      TicketRequestStatus.refundRecorded,
    );
  });

  testWidgets('Entradas del cliente y puerta con texto al 200 % en 320 dp, '
      'sin errores', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await pumpApp(tester);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await clientBuysAndPays(tester);
    expect(tester.takeException(), isNull);
    final code = store.ticketsOf('cliente-a').single.credential!;
    await enter(tester, 'seguridad-1');
    await type(tester, 'door-code', code);
    await tapKey(tester, 'door-consult');
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.mobile());
}

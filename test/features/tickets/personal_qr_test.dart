import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/guest_tickets.dart';
import 'package:rumbaap/features/tickets/presentation/ticket_widgets.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  late DateTime now;
  late DemoTicketStore store;

  setUp(() {
    now = venueInstant(2026, 10, 9, 22); // viernes en curso
    store = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => now,
      latency: Duration.zero,
    );
  });

  /// Dos entradas pagadas del cliente A para esta noche (una compra de 2).
  List<Ticket> twoTickets() {
    final p = store.perform(
      (b) => b.sell(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 2,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      ),
    );
    store.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
    return store.book.ticketsOf(p.id);
  }

  Future<void> pump(
    WidgetTester tester, {
    String identity = 'cliente-a',
    DemoTicketStore? on,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PersonalQrCard(
              identity: DemoIdentities.byId(identity)!,
              store: on ?? store,
              clock: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? shownCode(WidgetTester tester) {
    final f = find.byKey(const ValueKey('credential-text'));
    return f.evaluate().isEmpty ? null : tester.widget<SelectableText>(f).data;
  }

  Future<void> pick(WidgetTester tester, Ticket t) async {
    await tester.ensureVisible(
      find.byKey(ValueKey('personal-qr-pick-${t.id}')),
    );
    await tester.tap(find.byKey(ValueKey('personal-qr-pick-${t.id}')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'con varias entradas no muestra ningún QR hasta elegir; luego uno a la '
    'vez, con su credencial vigente, también tras reemplazarla o canjearla',
    (tester) async {
      final [e1, e2] = twoTickets();
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('personal-qr-choose')), findsOneWidget);
      expect(find.byKey(const ValueKey('credential-qr')), findsNothing);

      await pick(tester, e2);
      expect(find.byKey(const ValueKey('credential-qr')), findsOneWidget);
      expect(shownCode(tester), credentialLabel(e2.credential!));
      await pick(tester, e1);
      expect(find.byKey(const ValueKey('credential-qr')), findsOneWidget);
      expect(shownCode(tester), credentialLabel(e1.credential!));

      // Reemplazo desde su ficha: el QR elegido muestra la nueva.
      store.perform(
        (b) => b.replaceCredential(e1.id, actorId: 'cliente-a', reason: 'x'),
      );
      await tester.pumpAndSettle();
      final fresh = store.book.ticketById(e1.id)!.credential!;
      expect(shownCode(tester), credentialLabel(fresh));

      // Canjeada: sigue visible para identificarse, sin otro canje.
      store.book.redeem(fresh, actorId: 'caja-1', point: RedeemPoint.boxOffice);
      store.perform((_) {});
      await tester.pumpAndSettle();
      expect(find.textContaining('canjeada'), findsOneWidget);
      expect(
        store.book.doorCheck(fresh, actorId: 'seguridad-1').reason,
        RejectReason.redeemed,
      );
      // Nada creado ni fusionado: siguen siendo las mismas dos entradas.
      expect(store.ticketsOf('cliente-a'), hasLength(2));
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets('la elección no pasa a otra cuenta, otro local ni otra noche; '
      'al volver no reaparece', (tester) async {
    final [_, e2] = twoTickets();
    await pump(tester);
    await pick(tester, e2);
    expect(shownCode(tester), credentialLabel(e2.credential!));

    // Otra cuenta, sin entradas: estado honesto, nada ajeno.
    await pump(tester, identity: 'cliente-b');
    expect(find.byKey(const ValueKey('personal-qr-none')), findsOneWidget);
    expect(shownCode(tester), isNull);
    // De vuelta a A: la elección anterior se descartó.
    await pump(tester);
    expect(shownCode(tester), isNull);
    expect(find.byKey(const ValueKey('personal-qr-choose')), findsOneWidget);

    // Otro local con los mismos ID de entrada: tampoco se arrastra.
    await pick(tester, e2);
    final other = DemoTicketStore(
      venueId: 'otro',
      venueTag: 'OT',
      clock: () => now,
      latency: Duration.zero,
    );
    final p = other.perform(
      (b) => b.sell(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 2,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      ),
    );
    other.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
    await pump(tester, on: other);
    expect(shownCode(tester), isNull);

    // Otra noche: las del viernes ya no se ofrecen.
    await pump(tester);
    await pick(tester, e2);
    now = venueInstant(2026, 10, 10, 22);
    await pump(tester);
    expect(find.byKey(const ValueKey('personal-qr-none')), findsOneWidget);
    expect(shownCode(tester), isNull);
  });
}

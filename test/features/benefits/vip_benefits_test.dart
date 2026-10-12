import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app_theme.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/benefits/vip_benefits.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/presentation/admin/reservation_page.dart';
import 'package:rumbaap/features/reservations/presentation/guest/my_reservation_detail_page.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/features/venues/venue_config.dart';

import '../reservations/fakes.dart';

// Miércoles 7: el viernes 9 aún no ha empezado; se puede reservar y emitir.
final _friday = Night(DateTime.utc(2026, 10, 9));
const _holder = ReservationHolder(
  name: 'Titular demo',
  idNumber: '100',
  phone: '300',
);

void main() {
  late DemoReservationStore reservations;
  late DemoTicketStore tickets;

  setUp(() {
    reservations = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: fixedClock,
    );
    tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: fixedClock,
      latency: Duration.zero,
    );
  });

  Reservation vipRequest(String table) => reservations.perform(
    (b) => b.requestVip(
      night: _friday,
      tableId: table,
      holder: _holder,
      origin: ReservationOrigin.client,
    ),
  );

  Reservation confirm(Reservation r) =>
      reservations.perform((b) => b.markPrepaymentReceived(r.id));

  TicketPurchase issue(Reservation r, int quantity) => tickets.perform(
    (b) => issueVipCourtesies(
      b,
      reservation: reservations.book.byId(r.id)!,
      venue: sagsaVenue,
      product: sagsaConfig.ticketProducts.single,
      quantity: quantity,
      holderName: 'Invitado demo',
      actorId: 'admin-1',
    ),
  );

  VipBenefits benefits(Reservation r) =>
      VipBenefits.of(reservations.book.byId(r.id)!, sagsaVenue, tickets.book)!;

  group('derecho y emisión', () {
    test('6 cortesías y 1 botella por VIP; ambas zonas suman 12 y 2', () {
      final a = confirm(vipRequest('VIP 1'));
      final b = confirm(vipRequest('VIP 2'));
      final all = [benefits(a), benefits(b)];
      expect(all.map((x) => x.entitledCourtesies).reduce((p, q) => p + q), 12);
      expect(all.map((x) => x.bottles).reduce((p, q) => p + q), 2);
      // Una mesa normal no tiene beneficios VIP.
      final normal = reservations.perform(
        (x) => x.createDirect(night: _friday, tableId: 'M01', holder: _holder),
      );
      expect(VipBenefits.of(normal, sagsaVenue, tickets.book), isNull);
    });

    test('pendiente de prepago: no se emite (regla no definida) y no se crea '
        'ninguna entrada', () {
      final r = vipRequest('VIP 1');
      expect(benefits(r).state, VipBenefitState.pendingPrepayment);
      expect(() => issue(r, 1), throwsA(isA<VipBenefitException>()));
      expect(tickets.book.tickets, isEmpty);
    });

    test('confirmada: emite por el circuito de cortesías, con nombre y '
        'motivo, sin pasar del derecho ni contar dos veces', () {
      final r = confirm(vipRequest('VIP 1'));
      final p = issue(r, 4);
      expect(p.channel, TicketChannel.courtesy);
      expect(p.payment, PaymentStatus.courtesy);
      expect(p.reservationId, r.id);
      expect(p.note, contains(r.id));
      final issued = tickets.book.ticketsOf(p.id);
      expect(issued, hasLength(4));
      expect(issued.every((t) => t.status == TicketStatus.active), isTrue);
      expect(benefits(r).remaining, 2);

      // Pasarse del derecho: rechazado y sin efectos.
      expect(() => issue(r, 3), throwsA(isA<VipBenefitException>()));
      expect(tickets.book.tickets, hasLength(4));

      // Una cortesía general (sin reserva) no consume el beneficio.
      tickets.perform(
        (b) => b.authorizeCourtesy(
          night: _friday,
          product: sagsaConfig.ticketProducts.single,
          quantity: 1,
          actorId: 'admin-1',
          holderName: 'Otro',
          reason: 'Cortesía general',
        ),
      );
      expect(benefits(r).issued, hasLength(4));

      issue(r, 2);
      expect(benefits(r).remaining, 0);
      expect(() => issue(r, 1), throwsA(isA<VipBenefitException>()));
    });

    test('canjeadas se siguen contando; si la reserva termina no se emiten '
        'más y lo emitido se conserva', () {
      final r = confirm(vipRequest('VIP 1'));
      final p = issue(r, 2);
      final t = tickets.book.ticketsOf(p.id).first;
      tickets.book.redeem(
        t.credential!,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
      );
      // El viernes aún no empezó: el canje se rechaza fuera de la noche, así
      // que no cuenta como canjeada.
      expect(benefits(r).redeemed, 0);

      reservations.perform((b) => b.revoke(r.id));
      final after = benefits(r);
      expect(after.state, VipBenefitState.reservationEnded);
      expect(after.issued, hasLength(2));
      expect(() => issue(r, 1), throwsA(isA<VipBenefitException>()));
    });
  });

  test('persistencia: el enlace con la reserva se guarda; una compra guardada '
      'sin él se carga como cortesía general', () {
    final r = confirm(vipRequest('VIP 1'));
    issue(r, 3);
    final bar = DemoBarStore(
      venueId: sagsaVenue.id,
      menu: sagsaConfig.menu,
      clock: fixedClock,
    );
    final raw = encodeDemoSnapshot(
      config: sagsaConfig,
      reservations: reservations,
      tickets: tickets,
      bar: bar,
      savedAt: fixedClock(),
    );
    DemoTicketStore load(String json) {
      final r2 = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: fixedClock,
      );
      final t2 = DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: fixedClock,
      );
      decodeDemoSnapshot(
        json,
        config: sagsaConfig,
        reservations: r2,
        tickets: t2,
        bar: DemoBarStore(
          venueId: sagsaVenue.id,
          menu: sagsaConfig.menu,
          clock: fixedClock,
        ),
      );
      return t2;
    }

    expect(load(raw).book.courtesiesOfReservation(r.id), hasLength(3));
    final old = jsonDecode(raw) as Map<String, Object?>;
    for (final p in (old['tickets']! as Map)['purchases'] as List<Object?>) {
      (p! as Map).remove('reservationId');
    }
    final loaded = load(jsonEncode(old));
    expect(loaded.book.courtesiesOfReservation(r.id), isEmpty);
    expect(loaded.book.tickets, hasLength(3));
  });

  group('vistas', () {
    Future<void> pump(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        VenueScope(
          config: sagsaConfig,
          child: MaterialApp(
            theme: AppTheme.build(sagsaConfig.theme),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> revealKey(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'administración: emite con validación y ve nombres; el titular solo ve '
      'recuentos, sin nombres ni acciones; la botella dice que su entrega no '
      'está definida',
      (tester) async {
        final r = confirm(vipRequest('VIP 1'));
        await pump(
          tester,
          ReservationPage(
            store: reservations,
            reservationId: r.id,
            clock: fixedClock,
            tickets: tickets,
            identity: DemoIdentities.byId('admin-1'),
          ),
        );
        await revealKey(tester, 'vip-issue-${r.id}');
        expect(
          find.textContaining('6 cortesías y 1 botella fuera del consumo'),
          findsOneWidget,
        );
        expect(find.byKey(ValueKey('vip-bottle-${r.id}')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('vip-issue-${r.id}')));
        await tester.pumpAndSettle();
        // Más de lo disponible y sin nombre: no se acepta.
        await tester.enterText(find.byKey(const ValueKey('vip-qty')), '7');
        await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
        await tester.pumpAndSettle();
        expect(find.textContaining('entre 1 y 6'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('vip-qty')), '2');
        await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
        await tester.pumpAndSettle();
        expect(find.textContaining('nombre de quien recibe'), findsWidgets);
        await tester.enterText(
          find.byKey(const ValueKey('vip-name')),
          'Invitada demo',
        );
        await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
        await tester.pumpAndSettle();
        expect(benefits(r).issued, hasLength(2));
        expect(find.textContaining('2 de 6 emitidas'), findsOneWidget);
        expect(find.textContaining('Invitada demo'), findsWidgets);

        // Titular: una reserva VIP directa vinculada a su cuenta (R7), con
        // dos cortesías emitidas. Su ficha no muestra nombres ni el botón.
        final own = reservations.perform(
          (b) => b.createDirect(
            night: _friday,
            tableId: 'VIP 2',
            holder: _holder,
            linkedAccountId: 'cliente-a',
          ),
        );
        issue(own, 2);
        await pump(
          tester,
          MyReservationDetailPage(
            store: reservations,
            identity: DemoIdentities.byId('cliente-a')!,
            reservationId: own.id,
            tickets: tickets,
          ),
        );
        await revealKey(tester, 'vip-courtesies-${own.id}');
        expect(find.textContaining('2 de 6 emitidas'), findsOneWidget);
        expect(find.textContaining('Invitado demo'), findsNothing);
        expect(find.byKey(ValueKey('vip-issue-${own.id}')), findsNothing);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('pendiente de prepago: se explica y no se ofrece emitir', (
      tester,
    ) async {
      final r = vipRequest('VIP 2');
      await pump(
        tester,
        ReservationPage(
          store: reservations,
          reservationId: r.id,
          clock: fixedClock,
          tickets: tickets,
          identity: DemoIdentities.byId('admin-1'),
        ),
      );
      await revealKey(tester, 'vip-blocked-${r.id}');
      expect(find.textContaining('No está definido si'), findsOneWidget);
      expect(find.byKey(ValueKey('vip-issue-${r.id}')), findsNothing);
    });
  });
}

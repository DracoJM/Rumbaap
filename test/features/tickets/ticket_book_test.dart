import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/domain/ticket_book.dart';

import '../reservations/fakes.dart';

const _product = TicketProduct(
  id: 'general',
  name: 'Demo',
  demoPriceByWeekday: {
    DateTime.friday: 40000,
    DateTime.saturday: 50000,
    DateTime.sunday: 30000,
  },
);
final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));
final _tonightFriday = venueInstant(2026, 10, 9, 22);

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  late _Clock clock;
  late TicketBook book;
  setUp(() {
    clock = _Clock(fixedClock()); // miércoles 7, 3:00 p. m.
    book = TicketBook(venueId: 'sagsa', venueTag: 'SG', clock: clock.call);
  });

  Ticket appTicket({Night? night, bool pay = true}) {
    final p = book.sell(
      night: night ?? _friday,
      product: _product,
      quantity: 1,
      channel: TicketChannel.app,
      actorId: 'cliente-a',
      ownerId: 'cliente-a',
    );
    if (pay) book.simulatePayment(p.id, actorId: 'cliente-a');
    return book.ticketsOf(p.id).single;
  }

  Ticket promoterTicket({bool verify = true}) {
    final p = book.sell(
      night: _friday,
      product: _product,
      quantity: 1,
      channel: TicketChannel.promoter,
      actorId: 'promotor-1',
      holderName: 'Comprador demo',
    );
    if (verify) book.verifyPromoterPayment(p.id, actorId: 'promotor-1');
    return book.ticketsOf(p.id).single;
  }

  group('venta, pago y activación', () {
    test('crear la venta no activa el derecho ni emite credencial', () {
      final p = book.sell(
        night: _saturday,
        product: _product,
        quantity: 3,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      );
      expect(p.unitPrice, 50000); // precio de la noche (sábado)
      expect(p.total, 150000);
      final ts = book.ticketsOf(p.id);
      expect(ts, hasLength(3));
      expect(ts.every((t) => t.status == TicketStatus.pendingPayment), isTrue);
      expect(ts.every((t) => t.credential == null), isTrue);

      book.simulatePayment(p.id, actorId: 'cliente-a');
      final active = book.ticketsOf(p.id);
      expect(active.every((t) => t.status == TicketStatus.active), isTrue);
      final codes = active.map((t) => t.credential!).toSet();
      expect(codes, hasLength(3));
      expect(
        codes.every(
          (c) => c.length == TicketBook.credentialLength && c.startsWith('SG'),
        ),
        isTrue,
      );
      expect(
        () => book.simulatePayment(p.id, actorId: 'cliente-a'),
        throwsA(isA<TicketException>()),
      );
    });

    test('el promotor activa su venta solo al comprobar el pago; registra '
        'su actor', () {
      final t = promoterTicket(verify: false);
      expect(t.status, TicketStatus.pendingPayment);
      book.verifyPromoterPayment(t.purchaseId, actorId: 'promotor-1');
      final after = book.ticketById(t.id)!;
      expect(after.status, TicketStatus.active);
      expect(
        after.history
            .firstWhere((e) => e.type == TicketEventType.paymentVerified)
            .actorId,
        'promotor-1',
      );
      // El pago simulado del cliente no aplica a una venta del promotor.
      final p2 = book.sell(
        night: _friday,
        product: _product,
        quantity: 1,
        channel: TicketChannel.promoter,
        actorId: 'promotor-1',
        holderName: 'Otro',
      );
      expect(
        () => book.simulatePayment(p2.id, actorId: 'cliente-a'),
        throwsA(isA<TicketException>()),
      );
    });

    test('la cortesía autorizada no exige pago y queda activa', () {
      final p = book.authorizeCourtesy(
        night: _friday,
        product: _product,
        quantity: 2,
        actorId: 'admin-1',
        holderName: 'Invitado VIP demo',
        reason: 'Mesa VIP 1',
      );
      expect(p.payment, PaymentStatus.courtesy);
      expect(p.total, 0);
      expect(
        book.ticketsOf(p.id).every((t) => t.status == TicketStatus.active),
        isTrue,
      );
    });

    test('no se vende para una noche terminada ni sin precio', () {
      clock.now = venueInstant(2026, 10, 10, 3);
      expect(() => appTicket(night: _friday), throwsA(isA<TicketException>()));
      expect(
        () => book.sell(
          night: Night(DateTime.utc(2026, 10, 14)), // miércoles: sin precio
          product: _product,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
        ),
        throwsA(isA<TicketException>()),
      );
    });
  });

  group('puerta: consulta, primer ingreso y canje separados', () {
    test('consultar no cambia nada; confirmar registra el primer ingreso una '
        'vez; la segunda vez avisa sin bloquear la taquilla', () {
      final t = appTicket();
      clock.now = _tonightFriday;
      final check = book.doorCheck(t.credential!, actorId: 'seguridad-1');
      expect(check.outcome, CheckOutcome.validNoEntry);
      expect(book.ticketById(t.id)!.firstEntryAt, isNull);

      expect(
        book.confirmFirstEntry(t.credential!, actorId: 'seguridad-1').outcome,
        CheckOutcome.entryRecorded,
      );
      expect(
        book.confirmFirstEntry(t.credential!, actorId: 'seguridad-1').outcome,
        CheckOutcome.entryAlreadyRecorded,
      );
      expect(
        book.doorCheck(t.credential!, actorId: 'seguridad-1').outcome,
        CheckOutcome.entryAlreadyRecorded,
      );
      expect(
        book
            .ticketById(t.id)!
            .history
            .where((e) => e.type == TicketEventType.firstEntryRecorded),
        hasLength(1),
      );

      // Taquilla canjea después de la puerta.
      expect(
        book
            .redeem(
              t.credential!,
              actorId: 'caja-1',
              point: RedeemPoint.boxOffice,
            )
            .outcome,
        CheckOutcome.redeemedNow,
      );
      // Tras el canje: puerta y taquilla rechazan («No canjeable»).
      for (final r in [
        book.doorCheck(t.credential!, actorId: 'seguridad-1'),
        book.confirmFirstEntry(t.credential!, actorId: 'seguridad-1'),
        book.redeem(
          t.credential!,
          actorId: 'caja-1',
          point: RedeemPoint.boxOffice,
        ),
      ]) {
        expect(r.outcome, CheckOutcome.rejected);
        expect(r.reason, RejectReason.redeemed);
      }
      expect(
        book
            .ticketById(t.id)!
            .history
            .where((e) => e.type == TicketEventType.redeemed),
        hasLength(1),
      );
    });

    test(
      'taquilla puede canjear aunque la puerta no haya registrado ingreso',
      () {
        final t = appTicket();
        clock.now = _tonightFriday;
        expect(
          book
              .redeem(
                t.credential!,
                actorId: 'caja-1',
                point: RedeemPoint.boxOffice,
              )
              .outcome,
          CheckOutcome.redeemedNow,
        );
      },
    );

    test('circuitos: taquilla no canjea ventas del promotor ni el promotor las '
        'de la app', () {
      final p = promoterTicket();
      final a = appTicket();
      clock.now = _tonightFriday;
      final r1 = book.redeem(
        p.credential!,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
      );
      expect(r1.reason, RejectReason.wrongCircuit);
      final r2 = book.redeem(
        a.credential!,
        actorId: 'promotor-1',
        point: RedeemPoint.promoterLot,
      );
      expect(r2.reason, RejectReason.wrongCircuit);
      expect(
        book
            .redeem(
              p.credential!,
              actorId: 'promotor-1',
              point: RedeemPoint.promoterLot,
            )
            .outcome,
        CheckOutcome.redeemedNow,
      );
    });

    test('rechaza otra noche, fuera de horario, sin pago, otro local o '
        'inexistente; anota la incidencia sin revocar el derecho', () {
      final sat = appTicket(night: _saturday);
      final unpaid = appTicket(pay: false);
      expect(
        book.doorCheck(sat.credential!, actorId: 'seguridad-1').reason,
        RejectReason.outsideNight,
      );
      clock.now = _tonightFriday;
      expect(
        book.doorCheck(sat.credential!, actorId: 'seguridad-1').reason,
        RejectReason.otherNight,
      );
      // Sin pago no hay credencial: lo que se lea no existe.
      expect(unpaid.credential, isNull);
      expect(
        book.doorCheck('XX23456789AB', actorId: 'seguridad-1').reason,
        RejectReason.otherVenue,
      );
      expect(
        book.doorCheck('nada', actorId: 'seguridad-1').reason,
        RejectReason.notFound,
      );
      expect(book.incidents, hasLength(4));
      expect(book.incidents.first.actorId, 'seguridad-1');

      // La entrada del sábado sigue válida en su noche.
      clock.now = venueInstant(2026, 10, 10, 22);
      expect(
        book.doorCheck(sat.credential!, actorId: 'seguridad-1').outcome,
        CheckOutcome.validNoEntry,
      );
      expect(book.ticketById(sat.id)!.status, TicketStatus.active);
    });
  });

  group('credencial: reemplazo sin reciclar', () {
    test('la credencial retirada se rechaza; la nueva tiene la misma longitud '
        'y funciona; venta y pago se conservan', () {
      final t = appTicket();
      final old = t.credential!;
      final r = book.replaceCredential(
        t.id,
        actorId: 'cliente-a',
        reason: 'Captura compartida',
      );
      expect(r.credential, isNot(old));
      expect(r.credential!.length, old.length);
      expect(r.retired.single.code, old);
      expect(
        book.purchaseById(t.purchaseId)!.payment,
        PaymentStatus.paidSimulated,
      );

      clock.now = _tonightFriday;
      expect(
        book.doorCheck(old, actorId: 'seguridad-1').reason,
        RejectReason.retiredCredential,
      );
      expect(
        book.doorCheck(r.credential!, actorId: 'seguridad-1').outcome,
        CheckOutcome.validNoEntry,
      );
    });

    test('ninguna credencial se repite aunque se reemplacen muchas', () {
      final t = appTicket();
      final seen = <String>{t.credential!};
      for (var i = 0; i < 50; i++) {
        final r = book.replaceCredential(t.id, actorId: 'admin-1', reason: 'x');
        expect(seen.add(r.credential!), isTrue);
      }
    });
  });

  group('devolución y cambio de noche (solo administración autoriza)', () {
    test('autorizar la devolución anula y retira la credencial, sin dinero '
        'devuelto hasta registrarlo aparte', () {
      final t = appTicket();
      book.requestRefund(t.id, actorId: 'cliente-a');
      final auth = book.authorizeRequest(t.id, actorId: 'admin-1');
      expect(auth.status, TicketStatus.voided);
      expect(auth.credential, isNull);
      expect(auth.request!.status, TicketRequestStatus.authorized);
      expect(
        book.recordRefundReturned(t.id, actorId: 'admin-1').request!.status,
        TicketRequestStatus.refundRecorded,
      );
      clock.now = _tonightFriday;
      expect(
        book.doorCheck(t.credential!, actorId: 'seguridad-1').reason,
        RejectReason.retiredCredential,
      );
    });

    test(
      'cambio de noche autorizado mueve el derecho; rechazado no cambia',
      () {
        final a = appTicket();
        final b = appTicket();
        book.requestNightChange(a.id, _saturday, actorId: 'cliente-a');
        expect(
          book.authorizeRequest(a.id, actorId: 'admin-1').night,
          _saturday,
        );
        book.requestNightChange(b.id, _saturday, actorId: 'cliente-a');
        expect(book.rejectRequest(b.id, actorId: 'admin-1').night, _friday);
      },
    );

    test(
      'con el primer ingreso registrado ya no se puede pedir devolución',
      () {
        final t = appTicket();
        clock.now = _tonightFriday;
        book.confirmFirstEntry(t.credential!, actorId: 'seguridad-1');
        expect(
          () => book.requestRefund(t.id, actorId: 'cliente-a'),
          throwsA(isA<TicketException>()),
        );
      },
    );
  });

  group('frontera asíncrona (reintentos sin duplicar)', () {
    test('el mismo identificador de operación devuelve el mismo resultado sin '
        'repetir la operación ni la incidencia', () async {
      final store = DemoTicketStore(
        venueId: 'sagsa',
        venueTag: 'SG',
        clock: () => _tonightFriday,
        latency: Duration.zero,
      );
      final bad1 = await store.confirmFirstEntry(
        'nada',
        actorId: 'seguridad-1',
        requestId: 'op-1',
      );
      final bad2 = await store.confirmFirstEntry(
        'nada',
        actorId: 'seguridad-1',
        requestId: 'op-1',
      );
      expect(identical(bad1, bad2), isTrue);
      expect(store.book.incidents, hasLength(1));

      store.offline = true;
      expect(
        () => store.doorCheck('nada', actorId: 'seguridad-1'),
        throwsA(isA<TicketGatewayUnavailable>()),
      );
    });
  });
}

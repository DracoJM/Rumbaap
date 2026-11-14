import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/domain/ticket_book.dart';

import '../reservations/fakes.dart';

const _product = TicketProduct(
  id: 'general',
  name: 'Demo',
  demoPriceByWeekday: {DateTime.friday: 40000},
);
final _friday = Night(DateTime.utc(2026, 10, 9));

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  late _Clock clock;
  late TicketBook book;
  setUp(() {
    clock = _Clock(venueInstant(2026, 10, 7, 15)); // miércoles, antes
    book = TicketBook(venueId: 'sagsa', venueTag: 'SG', clock: clock.call);
  });

  TicketPurchase sale({String actor = 'promotor-1', bool pay = true}) {
    final p = book.sell(
      night: _friday,
      product: _product,
      quantity: 2,
      channel: TicketChannel.promoter,
      actorId: actor,
      holderName: 'Comprador demo',
      buyerPhone: ' 3001112233 ',
      buyerIdNumber: '1020304050',
    );
    if (pay) book.verifyPromoterPayment(p.id, actorId: actor);
    return p;
  }

  CheckResult lot(String code, String actor) =>
      book.redeem(code, actorId: actor, point: RedeemPoint.promoterLot);

  group('venta del promotor: contacto del comprador', () {
    test('teléfono y cédula obligatorios, solo dígitos; se recortan', () {
      TicketError? errorOf(String? phone, String? id) {
        try {
          book.sell(
            night: _friday,
            product: _product,
            quantity: 1,
            channel: TicketChannel.promoter,
            actorId: 'promotor-1',
            holderName: 'X',
            buyerPhone: phone,
            buyerIdNumber: id,
          );
        } on TicketException catch (e) {
          return e.error;
        }
        return null;
      }

      for (final bad in [
        (null, '1'),
        ('1', null),
        ('', '1'),
        ('1', '  '),
        ('300 111', '1'),
        ('1', '12a'),
      ]) {
        expect(errorOf(bad.$1, bad.$2), TicketError.invalidContact);
      }
      expect(book.purchases, isEmpty);
      final p = sale(pay: false);
      expect(p.buyerPhone, '3001112233');
      expect(p.buyerIdNumber, '1020304050');
      // No vincula ninguna cuenta por coincidencia.
      expect(p.ownerId, isNull);
      expect(book.purchaseById(p.id)!.buyerPhone, '3001112233');
    });

    test('las entradas de la app no piden ni guardan estos datos', () {
      final p = book.sell(
        night: _friday,
        product: _product,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      );
      expect(p.buyerPhone, isNull);
      expect(p.buyerIdNumber, isNull);
    });

    test('el pago conserva los datos del comprador', () {
      final p = sale();
      final paid = book.purchaseById(p.id)!;
      expect(paid.payment, PaymentStatus.verifiedByPromoter);
      expect(paid.buyerPhone, '3001112233');
      expect(paid.buyerIdNumber, '1020304050');
    });
  });

  group('entrega de la manilla del promotor en cualquier momento', () {
    test('antes y después de la noche, una sola vez por entrada', () {
      final p = sale();
      final [a, b] = book.ticketsOf(p.id);
      // Antes de la noche (miércoles).
      expect(lot(a.credential!, 'promotor-1').ok, isTrue);
      final done = book.ticketById(a.id)!;
      expect(done.redeemPoint, RedeemPoint.promoterLot);
      expect(done.redeemedAt, clock.now, reason: 'hora real, sin tocar reloj');
      expect(done.history.last.actorId, 'promotor-1');
      // Doble entrega.
      expect(lot(a.credential!, 'promotor-1').reason, RejectReason.redeemed);
      // Después de que la noche terminó.
      clock.now = venueInstant(2026, 10, 10, 12);
      expect(lot(b.credential!, 'promotor-1').ok, isTrue);
      expect(book.ticketById(b.id)!.redeemedAt, clock.now);
    });

    test('durante la noche también funciona', () {
      final p = sale();
      clock.now = venueInstant(2026, 10, 9, 23);
      final t = book.ticketsOf(p.id).first;
      expect(lot(t.credential!, 'promotor-1').ok, isTrue);
    });

    test('sin pago comprobado no hay credencial que entregar', () {
      final p = sale(pay: false);
      final t = book.ticketsOf(p.id).first;
      expect(t.credential, isNull);
      expect(t.status, TicketStatus.pendingPayment);
      expect(lot('SGNOEXISTE', 'promotor-1').reason, RejectReason.notFound);
      expect(book.ticketById(t.id)!.status, TicketStatus.pendingPayment);
    });

    test('otro promotor, Caja y otros circuitos mantienen la regla de la '
        'noche', () {
      final p = sale();
      final t = book.ticketsOf(p.id).first;
      // Otro promotor, fuera de horario.
      expect(lot(t.credential!, 'promotor-2').reason, RejectReason.notYourSale);
      // Caja con una entrada del promotor, fuera de horario.
      expect(
        book
            .redeem(
              t.credential!,
              actorId: 'caja-1',
              point: RedeemPoint.boxOffice,
            )
            .reason,
        RejectReason.outsideNight,
      );
      // Entrada de la app con el punto del promotor, fuera de horario.
      final app = book.sell(
        night: _friday,
        product: _product,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      );
      book.simulatePayment(app.id, actorId: 'cliente-a');
      final at = book.ticketsOf(app.id).single;
      expect(
        lot(at.credential!, 'promotor-1').reason,
        RejectReason.outsideNight,
      );
      expect(book.ticketById(t.id)!.status, TicketStatus.active);
      expect(book.ticketById(at.id)!.status, TicketStatus.active);
    });

    test(
      'un actor ajeno a la venta no entrega desde ese lote en ninguna '
      'fecha y no cambia el estado de entrega; Caja y canales ajenos tampoco',
      () {
        final p = sale();
        final t = book.ticketsOf(p.id).first;
        for (final when in [
          venueInstant(2026, 10, 7, 15), // antes
          venueInstant(2026, 10, 9, 23), // noche activa
          venueInstant(2026, 10, 10, 12), // después
        ]) {
          clock.now = when;
          final before = book.ticketById(t.id)!;
          final r = lot(t.credential!, 'promotor-2');
          expect(r.reason, RejectReason.notYourSale);
          final after = book.ticketById(t.id)!;
          expect(after.status, TicketStatus.active);
          expect(after.redeemedAt, isNull);
          expect(after.redeemPoint, isNull);
          expect(
            after.history.where((e) => e.type == TicketEventType.redeemed),
            isEmpty,
          );
          // Solo queda el rechazo anotado, como en cualquier otro rechazo.
          expect(after.history.length, before.history.length + 1);
          expect(after.history.last.type, TicketEventType.rejected);
        }
        // Noche activa: Caja y una entrada de la app no obtienen permiso.
        clock.now = venueInstant(2026, 10, 9, 23);
        expect(
          book
              .redeem(
                t.credential!,
                actorId: 'caja-1',
                point: RedeemPoint.boxOffice,
              )
              .reason,
          RejectReason.wrongCircuit,
        );
        final app = book.sell(
          night: _friday,
          product: _product,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        );
        book.simulatePayment(app.id, actorId: 'cliente-a');
        final at = book.ticketsOf(app.id).single;
        expect(
          lot(at.credential!, 'promotor-1').reason,
          RejectReason.wrongCircuit,
        );
        expect(book.ticketById(t.id)!.status, TicketStatus.active);
        expect(book.ticketById(at.id)!.status, TicketStatus.active);
        // El promotor de la venta sí entrega.
        expect(lot(t.credential!, 'promotor-1').ok, isTrue);
      },
    );

    test('la puerta no cambia: rechaza fuera de horario y tras la entrega no '
        'admite ni registra ingreso', () {
      final p = sale();
      final t = book.ticketsOf(p.id).first;
      expect(
        book.doorCheck(t.credential!, actorId: 'seguridad-1').reason,
        RejectReason.outsideNight,
      );
      lot(t.credential!, 'promotor-1');
      clock.now = venueInstant(2026, 10, 9, 23);
      expect(
        book.doorCheck(t.credential!, actorId: 'seguridad-1').reason,
        RejectReason.redeemed,
      );
      expect(book.ticketById(t.id)!.firstEntryAt, isNull);
    });
  });
}

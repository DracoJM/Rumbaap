import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/domain/ticket_book.dart';

import '../reservations/fakes.dart';

const _product = TicketProduct(id: 'general', name: 'Demo', demoPrice: 50000);
final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));

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
    book = TicketBook(venueId: 'sagsa', clock: clock.call);
  });

  TicketPurchase buy({int qty = 2, Night? night, bool pay = true}) {
    final p = book.purchase(
      night: night ?? _friday,
      product: _product,
      quantity: qty,
      channel: TicketChannel.app,
      createdBy: 'cliente-a',
      ownerId: 'cliente-a',
    );
    return pay ? book.simulatePayment(p.id) : p;
  }

  group('compra y pago simulado (separados)', () {
    test('una entrada por persona, cada una con su código; sin pago no '
        'dan acceso', () {
      final p = buy(qty: 3, pay: false);
      expect(p.payment, PaymentStatus.pending);
      expect(p.total, 150000);
      final ts = book.ticketsOf(p.id);
      expect(ts, hasLength(3));
      expect(ts.map((t) => t.code).toSet(), hasLength(3));
      expect(ts.every((t) => t.code.startsWith('SAGSA-')), isTrue);
      expect(ts.every((t) => t.status == TicketStatus.pendingPayment), isTrue);

      final paid = book.simulatePayment(p.id);
      expect(paid.payment, PaymentStatus.paidSimulated);
      expect(
        book.ticketsOf(p.id).every((t) => t.status == TicketStatus.valid),
        isTrue,
      );
      expect(() => book.simulatePayment(p.id), throwsA(isA<TicketException>()));
    });

    test('no se vende para una noche terminada ni con cantidad 0; el '
        'promotor necesita el nombre del comprador', () {
      clock.now = venueInstant(2026, 10, 10, 3);
      expect(() => buy(night: _friday), throwsA(isA<TicketException>()));
      expect(
        () => buy(qty: 0, night: _saturday),
        throwsA(isA<TicketException>()),
      );
      expect(
        () => book.purchase(
          night: _saturday,
          product: _product,
          quantity: 1,
          channel: TicketChannel.promoter,
          createdBy: 'promotor-1',
          holderName: ' ',
        ),
        throwsA(isA<TicketException>()),
      );
      expect(book.tickets, isEmpty);
    });
  });

  group('validación en el acceso', () {
    test('solo la noche en curso; repetir la lectura no duplica el acceso', () {
      final t = book.ticketsOf(buy().id).first;
      expect(book.validateAccess(t.code).result, AccessResult.outsideNight);

      clock.now = venueInstant(2026, 10, 9, 22);
      final first = book.validateAccess(t.code.toLowerCase());
      expect(first.result, AccessResult.admitted);
      final again = book.validateAccess(t.code);
      expect(again.result, AccessResult.alreadyAdmitted);
      expect(
        book
            .ticketById(t.id)!
            .history
            .where((e) => e.type == TicketEventType.admitted),
        hasLength(1),
      );
    });

    test('rechaza entradas de otra noche, sin pagar, de otro local o '
        'inexistentes', () {
      final sat = book.ticketsOf(buy(night: _saturday).id).first;
      final unpaid = book.ticketsOf(buy(pay: false).id).first;
      clock.now = venueInstant(2026, 10, 9, 22);
      expect(book.validateAccess(sat.code).result, AccessResult.otherNight);
      expect(book.validateAccess(unpaid.code).result, AccessResult.unpaid);
      expect(
        book.validateAccess('OTRO-E1-ABCDE').result,
        AccessResult.otherVenue,
      );
      expect(book.validateAccess('nada').result, AccessResult.notFound);
      expect(
        book.tickets.where((t) => t.status == TicketStatus.admitted),
        isEmpty,
      );
    });
  });

  group('manilla', () {
    test('solo tras validar el acceso; una por entrada aunque se repita', () {
      final t = book.ticketsOf(buy().id).first;
      clock.now = venueInstant(2026, 10, 9, 22);
      expect(book.deliverWristband(t.code).result, WristbandResult.notAdmitted);
      book.validateAccess(t.code);
      expect(book.deliverWristband(t.code).result, WristbandResult.delivered);
      expect(
        book.deliverWristband(t.code).result,
        WristbandResult.alreadyDelivered,
      );
      expect(
        book
            .ticketById(t.id)!
            .history
            .where((e) => e.type == TicketEventType.wristbandDelivered),
        hasLength(1),
      );
    });

    test('las ventas del promotor siguen su propio circuito', () {
      final p = book.purchase(
        night: _friday,
        product: _product,
        quantity: 1,
        channel: TicketChannel.promoter,
        createdBy: 'promotor-1',
        holderName: 'Comprador demo',
      );
      book.simulatePayment(p.id);
      final t = book.ticketsOf(p.id).single;
      clock.now = venueInstant(2026, 10, 9, 22);
      book.validateAccess(t.code);
      expect(
        book.deliverWristband(t.code).result,
        WristbandResult.promoterCircuit,
      );
    });
  });

  group('devolución y cambio de noche', () {
    test('autorizar una devolución anula la entrada pero no registra dinero '
        'devuelto hasta que se indica aparte', () {
      final t = book.ticketsOf(buy().id).first;
      book.requestRefund(t.id);
      expect(book.ticketById(t.id)!.hasOpenRequest, isTrue);
      final auth = book.authorizeRequest(t.id);
      expect(auth.status, TicketStatus.voided);
      expect(auth.request!.status, TicketRequestStatus.authorized);
      final done = book.recordRefundReturned(t.id);
      expect(done.request!.status, TicketRequestStatus.refundRecorded);

      clock.now = venueInstant(2026, 10, 9, 22);
      expect(book.validateAccess(t.code).result, AccessResult.voided);
    });

    test('cambio de noche: solicitado por el dueño, autorizado por la '
        'administración; rechazar no cambia la entrada', () {
      final ts = book.ticketsOf(buy().id);
      book.requestNightChange(ts[0].id, _saturday);
      expect(book.authorizeRequest(ts[0].id).night, _saturday);
      book.requestNightChange(ts[1].id, _saturday);
      final rejected = book.rejectRequest(ts[1].id);
      expect(rejected.night, _friday);
      expect(rejected.request!.status, TicketRequestStatus.rejected);
      expect(
        () => book.requestNightChange(ts[1].id, _friday),
        throwsA(isA<TicketException>()),
      );
    });

    test('una entrada ya usada no admite solicitudes', () {
      final t = book.ticketsOf(buy().id).first;
      clock.now = venueInstant(2026, 10, 9, 22);
      book.validateAccess(t.code);
      expect(() => book.requestRefund(t.id), throwsA(isA<TicketException>()));
    });
  });
}

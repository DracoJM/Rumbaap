import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/benefits/vip_benefits.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

// Antes de la noche del viernes: se reserva y se emiten cortesías.
final _friday = Night(DateTime.utc(2026, 10, 9));
const _holder = ReservationHolder(
  name: 'Titular demo',
  idNumber: '100',
  phone: '300',
);

void main() {
  late DateTime now;
  late DemoReservationStore reservations;
  late DemoTicketStore tickets;
  late DemoBarStore bar;
  final vipTables = sagsaVenue.tables.where((t) => t.isVip).toList();

  setUp(() {
    now = venueInstant(2026, 10, 7, 15);
    reservations = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => now,
    );
    tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => now,
      latency: Duration.zero,
    );
    bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => now,
    );
  });

  /// Conexión de la app (como en RumbaapApp).
  void wire() =>
      tickets.book.vipCourtesyCheck = (id) =>
          vipCourtesyCheckFor(reservations.book.byId, sagsaVenue, id);

  /// Cortesía enlazada a la reserva, emitida por el circuito de cortesías
  /// (simula una credencial ya emitida, sin pasar por el gate de emisión).
  Ticket linkedCourtesy(Reservation r) {
    final p = tickets.book.authorizeCourtesy(
      night: _friday,
      product: sagsaConfig.ticketProducts.single,
      quantity: 1,
      actorId: 'admin-1',
      holderName: 'Invitado demo',
      reason: 'Beneficio VIP',
      reservationId: r.id,
    );
    return tickets.book.ticketsOf(p.id).single;
  }

  Reservation request(int i) => reservations.perform(
    (b) => b.requestVip(
      night: _friday,
      tableId: vipTables[i].id,
      holder: _holder,
      origin: ReservationOrigin.client,
    ),
  );

  void tonight() => now = venueInstant(2026, 10, 9, 22);

  test('sin conexión, el dominio rechaza la cortesía VIP en puerta y '
      'taquilla; una cortesía general no cambia', () {
    final vip = linkedCourtesy(request(0));
    final general = tickets.book
        .ticketsOf(
          tickets.book
              .authorizeCourtesy(
                night: _friday,
                product: sagsaConfig.ticketProducts.single,
                quantity: 1,
                actorId: 'admin-1',
                holderName: 'Otro',
                reason: 'Cortesía general',
              )
              .id,
        )
        .single;
    tonight();
    expect(
      tickets.book.doorCheck(vip.credential!, actorId: 'seguridad-1').reason,
      RejectReason.vipPendingApproval,
    );
    expect(
      tickets.book
          .doorCheck(general.credential!, actorId: 'seguridad-1')
          .outcome,
      CheckOutcome.validNoEntry,
    );
  });

  test(
    'antes de aprobación+verificación: consulta, ingreso y canje se '
    'cortan, también por el gateway, sin cambiar la entrada; tras '
    '«prepago verificado» proceden sin inventar un saldo de 2.000.000',
    () async {
      wire();
      final r = request(0);
      final t = linkedCourtesy(r);
      tonight();
      final code = t.credential!;
      expect(
        tickets.book.doorCheck(code, actorId: 'seguridad-1').reason,
        RejectReason.vipPendingApproval,
      );
      expect(
        (await tickets.confirmFirstEntry(
          code,
          actorId: 'seguridad-1',
          requestId: 'op-1',
        )).reason,
        RejectReason.vipPendingApproval,
      );
      expect(
        (await tickets.redeem(
          code,
          actorId: 'caja-1',
          point: RedeemPoint.boxOffice,
          requestId: 'op-2',
        )).reason,
        RejectReason.vipPendingApproval,
      );
      final still = tickets.book.ticketById(t.id)!;
      expect(still.status, TicketStatus.active);
      expect(still.firstEntryAt, isNull);

      // Prueba histórica: «prepago verificado» (sin importe registrado).
      reservations.perform((b) => b.markPrepaymentReceived(r.id));
      expect(bar.book.balanceOf(r.id), isNull);
      expect(
        tickets.book.doorCheck(code, actorId: 'seguridad-1').outcome,
        CheckOutcome.validNoEntry,
      );
      expect(
        (await tickets.redeem(
          code,
          actorId: 'caja-1',
          point: RedeemPoint.boxOffice,
          requestId: 'op-3',
        )).outcome,
        CheckOutcome.redeemedNow,
      );
    },
  );

  test('VIP directa de la administración (R7: pago validado) procede; una '
      'revocación posterior no cancela la cortesía ya aprobada', () {
    wire();
    final direct = reservations.perform(
      (b) => b.createDirect(
        night: _friday,
        tableId: vipTables[1].id,
        holder: _holder,
      ),
    );
    final t = linkedCourtesy(direct);
    reservations.perform((b) => b.revoke(direct.id));
    tonight();
    expect(
      tickets.book.doorCheck(t.credential!, actorId: 'seguridad-1').outcome,
      CheckOutcome.validNoEntry,
    );
  });

  test(
    'una reserva inexistente o de una mesa normal no aprueba la cortesía',
    () {
      wire();
      final normal = reservations.perform(
        (b) => b.createDirect(night: _friday, tableId: 'M01', holder: _holder),
      );
      final t = linkedCourtesy(normal);
      tonight();
      expect(
        tickets.book.doorCheck(t.credential!, actorId: 'seguridad-1').reason,
        RejectReason.vipPendingApproval,
      );
    },
  );
}

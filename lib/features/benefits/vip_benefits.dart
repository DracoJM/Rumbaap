import '../reservations/domain/reservation.dart';
import '../reservations/domain/venue_table.dart';
import '../tickets/domain/ticket.dart';
import '../tickets/domain/ticket_book.dart';

/// Beneficios de una reserva VIP (aclaración de Juanmi del 2026-10-09):
/// 6 cortesías y 1 botella fuera del consumo por cada mesa VIP. Quien
/// reserva las dos zonas VIP tiene dos reservas: 12 cortesías y 2 botellas.
abstract final class VipBenefitRules {
  static const courtesiesPerVip = 6;
  static const bottlesPerVip = 1;
}

/// Si se pueden emitir cortesías ahora, o qué regla falta.
enum VipBenefitState {
  /// Reserva aprobada (confirmada o con llegada) Y prepago registrado por
  /// la administración: las cortesías se pueden emitir y canjear.
  active,

  /// Reserva aprobada, pero la administración aún no registró su prepago.
  prepaidNotRegistered,

  /// Solicitud pendiente de pago. NOT DECIDED: si las cortesías se emiten
  /// antes de verificar el prepago.
  pendingPrepayment,

  /// Reserva terminada (revocada, rechazada, liberada o expirada). NOT
  /// DECIDED: qué pasa con el derecho; lo ya emitido se conserva.
  reservationEnded,
}

/// Derecho y seguimiento de una reserva VIP. Las cortesías emitidas son
/// entradas del circuito de cortesías enlazadas a la reserva: se cuentan
/// una vez, en cualquier estado. Una anulada no se repone sola (NOT
/// DECIDED).
class VipBenefits {
  VipBenefits._(this.reservation, this.issued, this.prepaidRegistered);

  /// `null` si la reserva no es de una mesa VIP. [prepaidRegistered]: la
  /// administración registró su prepago; sin él no se activan cortesías.
  static VipBenefits? of(
    Reservation r,
    Venue venue,
    TicketBook tickets, {
    required bool prepaidRegistered,
  }) {
    if (venue.tableById(r.tableId)?.isVip != true) return null;
    return VipBenefits._(
      r,
      tickets.courtesiesOfReservation(r.id),
      prepaidRegistered,
    );
  }

  final bool prepaidRegistered;

  final Reservation reservation;

  /// Cortesías emitidas para esta reserva (con su estado y su historial).
  final List<Ticket> issued;

  int get entitledCourtesies => VipBenefitRules.courtesiesPerVip;
  int get bottles => VipBenefitRules.bottlesPerVip;
  int get remaining => entitledCourtesies - issued.length;
  int get redeemed =>
      issued.where((t) => t.status == TicketStatus.redeemed).length;
  int get voided => issued.where((t) => t.status == TicketStatus.voided).length;

  VipBenefitState get state => switch (reservation.status) {
    ReservationStatus.confirmed || ReservationStatus.seated =>
      prepaidRegistered
          ? VipBenefitState.active
          : VipBenefitState.prepaidNotRegistered,
    ReservationStatus.pendingPayment => VipBenefitState.pendingPrepayment,
    _ => VipBenefitState.reservationEnded,
  };
}

enum VipBenefitError { notVip, notActive, exceedsEntitlement }

class VipBenefitException implements Exception {
  const VipBenefitException(this.error);
  final VipBenefitError error;
}

/// La administración emite cortesías del beneficio VIP por el circuito de
/// cortesías existente (nombre y motivo obligatorios). No supera el derecho
/// de la reserva y solo se emite con la reserva aprobada y su prepago
/// registrado por la administración.
TicketPurchase issueVipCourtesies(
  TicketBook tickets, {
  required Reservation reservation,
  required bool prepaidRegistered,
  required Venue venue,
  required TicketProduct product,
  required int quantity,
  required String holderName,
  required String actorId,
}) {
  final b = VipBenefits.of(
    reservation,
    venue,
    tickets,
    prepaidRegistered: prepaidRegistered,
  );
  if (b == null) throw const VipBenefitException(VipBenefitError.notVip);
  if (b.state != VipBenefitState.active) {
    throw const VipBenefitException(VipBenefitError.notActive);
  }
  if (quantity > b.remaining) {
    throw const VipBenefitException(VipBenefitError.exceedsEntitlement);
  }
  return tickets.authorizeCourtesy(
    night: reservation.night,
    product: product,
    quantity: quantity,
    actorId: actorId,
    holderName: holderName,
    reason: 'Beneficio VIP · reserva ${reservation.id}',
    reservationId: reservation.id,
  );
}

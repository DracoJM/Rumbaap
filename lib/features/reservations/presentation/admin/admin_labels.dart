import 'package:flutter/material.dart';

import '../../domain/reservation.dart';
import '../../domain/venue_table.dart';
import '../../../../theme/status_colors.dart';

/// Textos y colores de reservas para la vista del administrador.
extension ReservationLabels on Reservation {
  /// Mesa de la reserva dentro de su local.
  VenueTable tableIn(Venue venue) => venue.tableById(tableId)!;

  bool get wasRejected =>
      status == ReservationStatus.revoked &&
      history.last.type == ReservationEventType.rejected;

  String get statusLabel => switch (status) {
    ReservationStatus.inProcess => 'En proceso',
    ReservationStatus.pendingPayment => 'Pendiente de pago',
    ReservationStatus.confirmed => 'Reservada',
    ReservationStatus.seated => 'Ocupada',
    ReservationStatus.revoked => wasRejected ? 'Rechazada' : 'Revocada',
    ReservationStatus.released => 'Liberada',
    ReservationStatus.expired => 'Expirada',
  };

  IconData get statusIcon => switch (status) {
    ReservationStatus.inProcess => Icons.hourglass_top_rounded,
    ReservationStatus.pendingPayment => Icons.payments_outlined,
    ReservationStatus.confirmed => Icons.event_rounded,
    ReservationStatus.seated => Icons.groups_rounded,
    ReservationStatus.revoked => Icons.block_rounded,
    ReservationStatus.released => Icons.lock_open_rounded,
    ReservationStatus.expired => Icons.timer_off_outlined,
  };

  Color statusColorIn(StatusColors colors) => switch (status) {
    ReservationStatus.inProcess => colors.inProgress,
    ReservationStatus.pendingPayment => colors.vipPaymentPending,
    ReservationStatus.confirmed => colors.reserved,
    ReservationStatus.seated => colors.occupied,
    ReservationStatus.revoked ||
    ReservationStatus.released ||
    ReservationStatus.expired => colors.unknown,
  };

  String get originLabel => switch (origin) {
    ReservationOrigin.client => 'Cliente',
    ReservationOrigin.promoter => 'Promotor',
    ReservationOrigin.admin => 'Administrador',
  };
}

String eventLabel(ReservationEventType type) => switch (type) {
  ReservationEventType.requested => 'Solicitada',
  ReservationEventType.completed => 'Trámite completado: confirmada',
  ReservationEventType.prepaymentMarked => 'Prepago marcado como verificado',
  ReservationEventType.rejected => 'Solicitud rechazada',
  ReservationEventType.createdDirect =>
    'Creada por el administrador: confirmada',
  ReservationEventType.arrived => 'Llegada registrada: ocupada',
  ReservationEventType.revoked => 'Revocada',
  ReservationEventType.released => 'Mesa liberada',
  ReservationEventType.expired => 'Expiró sin completarse',
};

/// Mensaje para una operación que el libro rechazó. Siempre indica que no se
/// cambió nada.
String actionErrorMessage(ReservationError error) => switch (error) {
  ReservationError.tableTaken =>
    'La mesa ya tiene una reserva activa en esa noche. No se hizo ningún '
        'cambio.',
  ReservationError.nightEnded =>
    'Esa noche ya terminó. No se hizo ningún cambio.',
  ReservationError.invalidTransition =>
    'La reserva cambió de estado y esta acción ya no aplica. No se hizo '
        'ningún cambio.',
  ReservationError.outsideNight =>
    'La llegada solo se registra durante la noche, de 8:30 p. m. a '
        '3:00 a. m. (hora de Colombia). No se hizo ningún cambio.',
  ReservationError.invalidHolder =>
    'Revisa los datos del titular. No se hizo ningún cambio.',
  ReservationError.notFound =>
    'No se encontró la reserva. No se hizo ningún cambio.',
  ReservationError.unknownTable || ReservationError.wrongTableKind =>
    'La mesa no admite esta operación. No se hizo ningún cambio.',
};

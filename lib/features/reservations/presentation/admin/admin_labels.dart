import 'package:flutter/material.dart';

import '../../domain/reservation.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';

/// Textos y colores de reservas para la vista del administrador.
extension ReservationLabels on Reservation {
  VenueTable get table => VenueTables.byId(tableId)!;

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
    ReservationStatus.inProcess => TableMapStatus.pending.icon,
    ReservationStatus.pendingPayment => TableMapStatus.pendingPayment.icon,
    ReservationStatus.confirmed => TableMapStatus.reserved.icon,
    ReservationStatus.seated => TableMapStatus.occupied.icon,
    ReservationStatus.revoked => Icons.block_rounded,
    ReservationStatus.released => Icons.lock_open_rounded,
    ReservationStatus.expired => Icons.timer_off_outlined,
  };

  Color get statusColor => switch (status) {
    ReservationStatus.inProcess => TableMapStatus.pending.color,
    ReservationStatus.pendingPayment => TableMapStatus.pendingPayment.color,
    ReservationStatus.confirmed => TableMapStatus.reserved.color,
    ReservationStatus.seated => TableMapStatus.occupied.color,
    ReservationStatus.revoked ||
    ReservationStatus.released ||
    ReservationStatus.expired => TableMapStatus.unknown.color,
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

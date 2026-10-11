/// Modelo de reserva de mesa. Reglas R1–R10 de
/// `docs/business-rules/reservas-y-noches.md`.
library;

import 'night_schedule.dart';

enum ReservationStatus {
  /// Mesa normal: el cliente o el promotor están completando la reserva
  /// (R1). Expira a los 10 min si no se completa.
  inProcess,

  /// Mesa VIP solicitada: espera a que el administrador verifique el prepago
  /// (R2). No caduca.
  pendingPayment,

  /// Reservada.
  confirmed,

  /// Ocupada: el titular, o alguien en su nombre, reclamó la mesa (R5).
  seated,

  /// Anulada por el administrador: revocada (R4) o, si era una VIP pendiente
  /// de pago, rechazada (el historial distingue ambos casos).
  revoked,

  /// Mesa liberada por el administrador (R6).
  released,

  /// Mesa normal en proceso que no se completó a tiempo (R1).
  expired,

  /// Trámite normal abandonado expresamente por quien lo inició (R15).
  cancelled;

  /// Una reserva activa bloquea la mesa en su noche (R3).
  bool get isActive => switch (this) {
    inProcess || pendingPayment || confirmed || seated => true,
    revoked || released || expired || cancelled => false,
  };
}

/// Procedencia de la reserva: qué perspectiva la creó. Es distinta de la
/// identidad creadora ([Reservation.createdBy]) y de la cuenta vinculada al
/// titular ([Reservation.linkedAccountId]).
enum ReservationOrigin { client, promoter, admin }

/// Titular de la reserva.
///
/// La cédula ([idNumber]) es el ID de la cuenta registrada, si existe (R8).
/// PENDIENTE (fuera de alcance): enlace con cuentas reales, autenticación y
/// puntos de beneficio; no se decide aquí la identidad de las cuentas.
class ReservationHolder {
  const ReservationHolder({required this.name, this.idNumber, this.phone});

  final String name;

  /// Cédula, como texto de dígitos.
  final String? idNumber;

  /// Teléfono de contacto, como texto de dígitos (R8).
  final String? phone;
}

enum ReservationEventType {
  requested,
  completed,
  prepaymentMarked,
  rejected,
  createdDirect,
  arrived,
  revoked,
  released,
  expired,
  cancelled,
}

/// Cambio registrado en el historial de una reserva (trazabilidad).
class ReservationEvent {
  const ReservationEvent(this.type, this.at);

  final ReservationEventType type;

  /// Instante real (UTC) del cambio.
  final DateTime at;
}

/// Reserva de una mesa en una noche concreta. La noche nunca cambia: no
/// depende de la semana que se esté consultando en el mapa.
class Reservation {
  Reservation({
    required this.id,
    required this.night,
    required this.tableId,
    required this.holder,
    required this.origin,
    required this.status,
    required List<ReservationEvent> history,
    this.createdBy,
    this.linkedAccountId,
  }) : history = List.unmodifiable(history) {
    assert(
      holder != null || hasPendingHolder,
      'Solo un trámite normal no enviado puede no tener titular',
    );
  }

  final String id;
  final Night night;
  final String tableId;

  /// Titular. Solo falta en un trámite normal que no se ha enviado: En
  /// proceso, o Cancelado o Expirado sin haberse enviado (R14).
  final ReservationHolder? holder;
  final ReservationOrigin origin;
  final ReservationStatus status;
  final List<ReservationEvent> history;

  /// Identidad de demostración que creó la reserva; `null` en los datos
  /// sembrados y en las del administrador.
  final String? createdBy;

  /// Cuenta ficticia vinculada por cédula (R12), si se encontró.
  final String? linkedAccountId;

  DateTime get createdAt => history.first.at;

  bool get hasPendingHolder =>
      status == ReservationStatus.inProcess ||
      status == ReservationStatus.cancelled ||
      status == ReservationStatus.expired;

  Reservation withEvent(
    ReservationStatus status,
    ReservationEvent event, {
    ReservationHolder? holder,
    String? linkedAccountId,
  }) => Reservation(
    id: id,
    night: night,
    tableId: tableId,
    holder: holder ?? this.holder,
    origin: origin,
    status: status,
    history: [...history, event],
    createdBy: createdBy,
    linkedAccountId: linkedAccountId ?? this.linkedAccountId,
  );
}

enum ReservationError {
  unknownTable,

  /// La operación no corresponde al tipo de mesa (normal/VIP).
  wrongTableKind,

  /// No se reserva en una noche que ya terminó.
  nightEnded,

  /// Ya hay una reserva activa para esa mesa en esa noche (R3).
  tableTaken,
  notFound,

  /// La reserva no está en un estado que permita la operación; también
  /// cubre repetir una operación ya hecha, que no se duplica.
  invalidTransition,

  /// La llegada solo se registra durante la noche en curso (R5, N6).
  outsideNight,

  /// Datos del titular incompletos o con formato no válido (R7, R12).
  invalidHolder,

  /// El trámite normal venció antes de enviarse (R1, R14): ya no se puede
  /// confirmar; hay que iniciar uno nuevo.
  expired,
}

class ReservationException implements Exception {
  const ReservationException(this.error);

  final ReservationError error;

  @override
  String toString() => 'ReservationException($error)';
}

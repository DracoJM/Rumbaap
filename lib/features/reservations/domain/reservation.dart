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
  expired;

  /// Una reserva activa bloquea la mesa en su noche (R3).
  bool get isActive => switch (this) {
    inProcess || pendingPayment || confirmed || seated => true,
    revoked || released || expired => false,
  };
}

/// Procedencia de la reserva.
///
/// PENDIENTE (fuera de alcance): las vistas de cliente (R9), promotor (R10)
/// y personal no existen todavía; hoy solo crea reservas el administrador y
/// los datos de demostración.
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
  }) : history = List.unmodifiable(history);

  final String id;
  final Night night;
  final String tableId;
  final ReservationHolder holder;
  final ReservationOrigin origin;
  final ReservationStatus status;
  final List<ReservationEvent> history;

  DateTime get createdAt => history.first.at;

  Reservation withEvent(ReservationStatus status, ReservationEvent event) =>
      Reservation(
        id: id,
        night: night,
        tableId: tableId,
        holder: holder,
        origin: origin,
        status: status,
        history: [...history, event],
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

  /// Datos del titular incompletos o con formato no válido (R7).
  invalidHolder,
}

class ReservationException implements Exception {
  const ReservationException(this.error);

  final ReservationError error;

  @override
  String toString() => 'ReservationException($error)';
}

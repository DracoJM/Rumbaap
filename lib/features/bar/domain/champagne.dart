import '../../reservations/domain/night_schedule.dart';

/// Responsabilidad de quien opera la botella de champaña VIP. La resuelve
/// la app a partir de la identidad; el dominio no se fía de lo que diga la
/// vista.
enum ChampagneActor {
  /// Cliente titular de la reserva (la creó o está vinculada a su cuenta).
  client,

  /// Mesero: registra la petición verbal de la mesa y confirma la entrega.
  waiter,

  /// Barra: registra la salida de la botella.
  bar,
}

enum ChampagneStage { requested, dispatched, delivered }

/// Botella de champaña de una reserva VIP (aclaración del usuario del
/// 2026-10-12): regalo fuera del consumo, una por mesa. La reserva aprobada
/// con el prepago verificado la habilita, pero no la despacha: solo con la
/// mesa ocupada y la petición explícita de la mesa sale de barra, y el
/// mesero confirma la entrega. Sin precio, marca ni movimiento de dinero.
class ChampagneRelease {
  const ChampagneRelease({
    required this.reservationId,
    required this.tableId,
    required this.venueId,
    required this.night,
    required this.requestedBy,
    required this.requestedAt,
    this.dispatchedBy,
    this.dispatchedAt,
    this.deliveredBy,
    this.deliveredAt,
  });

  final String reservationId;
  final String tableId;
  final String venueId;
  final Night night;

  final String requestedBy;
  final DateTime requestedAt;
  final String? dispatchedBy;
  final DateTime? dispatchedAt;
  final String? deliveredBy;
  final DateTime? deliveredAt;

  ChampagneStage get stage => deliveredAt != null
      ? ChampagneStage.delivered
      : dispatchedAt != null
      ? ChampagneStage.dispatched
      : ChampagneStage.requested;

  ChampagneRelease _with({
    String? dispatchedBy,
    DateTime? dispatchedAt,
    String? deliveredBy,
    DateTime? deliveredAt,
  }) => ChampagneRelease(
    reservationId: reservationId,
    tableId: tableId,
    venueId: venueId,
    night: night,
    requestedBy: requestedBy,
    requestedAt: requestedAt,
    dispatchedBy: dispatchedBy ?? this.dispatchedBy,
    dispatchedAt: dispatchedAt ?? this.dispatchedAt,
    deliveredBy: deliveredBy ?? this.deliveredBy,
    deliveredAt: deliveredAt ?? this.deliveredAt,
  );

  ChampagneRelease dispatched(String actorId, DateTime at) =>
      _with(dispatchedBy: actorId, dispatchedAt: at.toUtc());

  ChampagneRelease delivered(String actorId, DateTime at) =>
      _with(deliveredBy: actorId, deliveredAt: at.toUtc());
}

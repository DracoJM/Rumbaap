import 'night_schedule.dart';
import 'reservation.dart';
import 'venue_table.dart';

/// Registro de reservas de un local ([venue]) con las reglas R1–R8, en
/// memoria y con reloj inyectable. Solo admite mesas de ese local: los datos
/// de locales distintos nunca comparten registro.
///
/// Las reglas R1–R8 y el horario son las confirmadas para Sagsa, hoy el único
/// local configurado. PENDIENTE (fuera de alcance): parametrizarlas por local
/// cuando exista un segundo local con reglas propias. No conoce roles: quién puede ejecutar cada operación lo
/// decidirá la perspectiva que la use (administrador hoy; por ejemplo, el
/// mesero también registrará llegadas, R5).
///
/// PENDIENTE (fuera de alcance): persistencia y datos compartidos (backend),
/// liberación automática de las 11 p. m., unión transaccional de las dos VIP
/// y eventos añadidos por el promotor.
class ReservationBook {
  ReservationBook({required this.venue, Clock clock = systemClock})
    : _clock = clock;

  final Venue venue;

  /// Tiempo máximo de una mesa normal en proceso (R1). Editable en el futuro.
  static const inProcessTimeout = Duration(minutes: 10);

  final Clock _clock;
  final Map<String, Reservation> _reservations = {};
  int _sequence = 0;

  /// Todas las reservas de [night], incluidas las terminadas (historial).
  List<Reservation> forNight(Night night) {
    _expireOverdue();
    return [
      for (final r in _reservations.values)
        if (r.night == night) r,
    ];
  }

  Reservation? byId(String id) {
    _expireOverdue();
    return _reservations[id];
  }

  /// Reserva activa de la mesa en esa noche, si la hay (R3).
  Reservation? activeFor(Night night, String tableId) {
    _expireOverdue();
    return _activeFor(night, tableId);
  }

  /// Instante en que expirará la próxima reserva en proceso de [night], para
  /// que quien muestre la noche sepa cuándo volver a consultar.
  DateTime? nextExpiry(Night night) {
    _expireOverdue();
    DateTime? next;
    for (final r in _reservations.values) {
      if (r.night != night || r.status != ReservationStatus.inProcess) {
        continue;
      }
      final at = r.createdAt.add(inProcessTimeout);
      if (next == null || at.isBefore(next)) next = at;
    }
    return next;
  }

  /// Mesa normal: el cliente o el promotor inician la reserva (R1).
  Reservation requestNormal({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required ReservationOrigin origin,
  }) {
    assert(origin != ReservationOrigin.admin, 'El admin usa createDirect.');
    _checkCanReserve(night, tableId, vip: false);
    return _create(
      night,
      tableId,
      holder,
      origin,
      ReservationStatus.inProcess,
      ReservationEventType.requested,
    );
  }

  /// Mesa normal: se completó el trámite y se confirma automáticamente (R1).
  Reservation completeRequest(String id) => _transition(
    id,
    from: {ReservationStatus.inProcess},
    to: ReservationStatus.confirmed,
    event: ReservationEventType.completed,
  );

  /// Mesa VIP: solicitud pendiente de pago, sin caducidad (R2).
  Reservation requestVip({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required ReservationOrigin origin,
  }) {
    assert(origin != ReservationOrigin.admin, 'El admin usa createDirect.');
    _checkCanReserve(night, tableId, vip: true);
    return _create(
      night,
      tableId,
      holder,
      origin,
      ReservationStatus.pendingPayment,
      ReservationEventType.requested,
    );
  }

  /// El administrador verificó el prepago VIP (R2).
  ///
  /// NOT DECIDED: proveedor de pagos. Hoy el pago se marca a mano; aquí se
  /// conectará la ruta de pago dentro de la app cuando se decida.
  Reservation markPrepaymentReceived(String id) => _transition(
    id,
    from: {ReservationStatus.pendingPayment},
    to: ReservationStatus.confirmed,
    event: ReservationEventType.prepaymentMarked,
  );

  /// El administrador rechaza una VIP pendiente de pago (R2).
  Reservation rejectRequest(String id) => _transition(
    id,
    from: {ReservationStatus.pendingPayment},
    to: ReservationStatus.revoked,
    event: ReservationEventType.rejected,
  );

  /// Reserva directa del administrador: confirmada desde el inicio, también
  /// en VIP, porque se asume el pago ya verificado (R7).
  Reservation createDirect({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
  }) {
    if (!_isValidDirectHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    _checkCanReserve(night, tableId, vip: null);
    return _create(
      night,
      tableId,
      holder,
      ReservationOrigin.admin,
      ReservationStatus.confirmed,
      ReservationEventType.createdDirect,
    );
  }

  /// Llegada: solo una reserva confirmada de la noche en curso (R5, N6).
  /// La apertura no la registra sola.
  Reservation markArrival(String id) {
    final r = _get(id);
    if (r.status != ReservationStatus.confirmed) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    if (!r.night.isInProgress(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.outsideNight);
    }
    return _apply(r, ReservationStatus.seated, ReservationEventType.arrived);
  }

  /// El administrador revoca una reserva confirmada (R4). La advertencia
  /// previa es responsabilidad de la vista.
  Reservation revoke(String id) => _transition(
    id,
    from: {ReservationStatus.confirmed},
    to: ReservationStatus.revoked,
    event: ReservationEventType.revoked,
  );

  /// El administrador libera una mesa reservada u ocupada (R6). La doble
  /// confirmación es responsabilidad de la vista. No implica devolución de
  /// dinero ni una política de cancelación.
  Reservation release(String id) => _transition(
    id,
    from: {ReservationStatus.confirmed, ReservationStatus.seated},
    to: ReservationStatus.released,
    event: ReservationEventType.released,
  );

  // ---------------------------------------------------------------------

  void _checkCanReserve(Night night, String tableId, {required bool? vip}) {
    final table = venue.tableById(tableId);
    if (table == null) {
      throw const ReservationException(ReservationError.unknownTable);
    }
    if (vip != null && table.isVip != vip) {
      throw const ReservationException(ReservationError.wrongTableKind);
    }
    if (night.hasEnded(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.nightEnded);
    }
    _expireOverdue();
    if (_activeFor(night, tableId) != null) {
      throw const ReservationException(ReservationError.tableTaken);
    }
  }

  Reservation _create(
    Night night,
    String tableId,
    ReservationHolder holder,
    ReservationOrigin origin,
    ReservationStatus status,
    ReservationEventType event,
  ) {
    final reservation = Reservation(
      id: 'R${++_sequence}',
      night: night,
      tableId: tableId,
      holder: holder,
      origin: origin,
      status: status,
      history: [ReservationEvent(event, _clock().toUtc())],
    );
    _reservations[reservation.id] = reservation;
    return reservation;
  }

  Reservation _transition(
    String id, {
    required Set<ReservationStatus> from,
    required ReservationStatus to,
    required ReservationEventType event,
  }) {
    final r = _get(id);
    if (!from.contains(r.status)) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    return _apply(r, to, event);
  }

  Reservation _apply(
    Reservation r,
    ReservationStatus status,
    ReservationEventType event,
  ) {
    final updated = r.withEvent(
      status,
      ReservationEvent(event, _clock().toUtc()),
    );
    _reservations[r.id] = updated;
    return updated;
  }

  Reservation _get(String id) {
    _expireOverdue();
    final r = _reservations[id];
    if (r == null) throw const ReservationException(ReservationError.notFound);
    return r;
  }

  Reservation? _activeFor(Night night, String tableId) {
    for (final r in _reservations.values) {
      if (r.night == night && r.tableId == tableId && r.status.isActive) {
        return r;
      }
    }
    return null;
  }

  /// Las mesas normales en proceso expiran exactamente a los 10 min (R1). Se
  /// registra el instante exacto de expiración, no el de la consulta.
  void _expireOverdue() {
    final now = _clock().toUtc();
    for (final r in _reservations.values.toList()) {
      if (r.status != ReservationStatus.inProcess) continue;
      final deadline = r.createdAt.add(inProcessTimeout);
      if (!now.isBefore(deadline)) {
        _reservations[r.id] = r.withEvent(
          ReservationStatus.expired,
          ReservationEvent(ReservationEventType.expired, deadline),
        );
      }
    }
  }

  static final _digits = RegExp(r'^\d+$');

  /// R7: nombre, cédula y teléfono obligatorios; cédula y teléfono solo con
  /// dígitos, sin validar longitud ni formato.
  static bool _isValidDirectHolder(ReservationHolder h) =>
      h.name.trim().isNotEmpty &&
      _digits.hasMatch(h.idNumber ?? '') &&
      _digits.hasMatch(h.phone ?? '');
}

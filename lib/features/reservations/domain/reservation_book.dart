import 'night_schedule.dart';
import 'reservation.dart';
import 'venue_table.dart';

/// Registro de reservas de un local ([venue]) con las reglas R1–R16, en
/// memoria y con reloj inyectable. Solo admite mesas de ese local: los datos
/// de locales distintos nunca comparten registro.
///
/// Las reglas y el horario son las confirmadas para Sagsa, hoy el único
/// local configurado. PENDIENTE (fuera de alcance): parametrizarlas por local
/// cuando exista un segundo local con reglas propias. No conoce roles: quién puede ejecutar cada operación lo
/// decide la perspectiva que la use (administración, cliente, promotor o
/// personal). Tampoco calcula el vínculo de cuenta (R12): la vista lo
/// obtiene por cédula exacta y lo pasa como `linkedAccountId`.
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
    if (!isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
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

  /// Mesa normal: el cliente o el promotor pulsan «Reservar esta mesa» y
  /// empieza el trámite (R14): la mesa queda En proceso hasta 10 min, sin
  /// titular todavía. La comprobación y el bloqueo ocurren aquí, en una sola
  /// operación.
  Reservation startNormal({
    required Night night,
    required String tableId,
    required ReservationOrigin origin,
    String? createdBy,
  }) {
    assert(origin != ReservationOrigin.admin, 'El admin usa createDirect.');
    _checkCanReserve(night, tableId, vip: false);
    return _create(
      night,
      tableId,
      null,
      origin,
      ReservationStatus.inProcess,
      ReservationEventType.requested,
      createdBy: createdBy,
    );
  }

  /// Envío final del trámite normal (R13, R14): valida al titular (R12) y lo
  /// confirma si el trámite sigue activo y sin vencer. Si algo falla no
  /// cambia nada.
  Reservation submitNormal(
    String id, {
    required ReservationHolder holder,
    String? linkedAccountId,
  }) {
    final r = _get(id);
    if (r.status == ReservationStatus.expired) {
      throw const ReservationException(ReservationError.expired);
    }
    if (r.status != ReservationStatus.inProcess) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    // Un trámite iniciado antes del cierre no se confirma después (I7): la
    // noche ya terminó.
    if (r.night.hasEnded(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.nightEnded);
    }
    if (!isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    return _apply(
      r,
      ReservationStatus.confirmed,
      ReservationEventType.completed,
      holder: holder,
      linkedAccountId: linkedAccountId,
    );
  }

  /// Abandono expreso del trámite normal (R15): solo un trámite En proceso.
  Reservation cancelInProcess(String id) => _transition(
    id,
    from: {ReservationStatus.inProcess},
    to: ReservationStatus.cancelled,
    event: ReservationEventType.cancelled,
  );

  /// VIP del cliente o del promotor (R16): la solicitud se crea solo con el
  /// envío final válido y queda pendiente de pago, sin caducidad (R2).
  Reservation submitVip({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required ReservationOrigin origin,
    String? createdBy,
    String? linkedAccountId,
  }) {
    assert(origin != ReservationOrigin.admin, 'El admin usa createDirect.');
    if (!isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    _checkCanReserve(night, tableId, vip: true);
    return _create(
      night,
      tableId,
      holder,
      origin,
      ReservationStatus.pendingPayment,
      ReservationEventType.requested,
      createdBy: createdBy,
      linkedAccountId: linkedAccountId,
    );
  }

  /// Reservas creadas por una identidad, de todas las noches.
  List<Reservation> createdBy(String identityId) {
    _expireOverdue();
    return [
      for (final r in _reservations.values)
        if (r.createdBy == identityId) r,
    ];
  }

  /// Reservas que una identidad creó o que están adjudicadas a su cuenta
  /// ficticia ([Reservation.linkedAccountId]), sin duplicados. No cambia
  /// quién la creó.
  List<Reservation> createdByOrLinkedTo(String identityId) {
    _expireOverdue();
    return [
      for (final r in _reservations.values)
        if (r.createdBy == identityId || r.linkedAccountId == identityId) r,
    ];
  }

  /// Ruta anterior a R14 (siembra y tests del administrador): confirma un
  /// trámite que ya tiene titular. Aplica las mismas comprobaciones que
  /// [submitNormal], para que no sirva de atajo: sin titular válido, vencido o
  /// con la noche cerrada no confirma.
  Reservation completeRequest(String id) {
    final r = _get(id);
    if (r.status == ReservationStatus.expired) {
      throw const ReservationException(ReservationError.expired);
    }
    if (r.status != ReservationStatus.inProcess) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    if (r.night.hasEnded(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.nightEnded);
    }
    final holder = r.holder;
    if (holder == null || !isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    return _apply(
      r,
      ReservationStatus.confirmed,
      ReservationEventType.completed,
    );
  }

  /// Mesa VIP: solicitud pendiente de pago, sin caducidad (R2).
  Reservation requestVip({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required ReservationOrigin origin,
  }) {
    assert(origin != ReservationOrigin.admin, 'El admin usa createDirect.');
    if (!isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
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
    String? linkedAccountId,
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
      linkedAccountId: linkedAccountId,
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
    ReservationHolder? holder,
    ReservationOrigin origin,
    ReservationStatus status,
    ReservationEventType event, {
    String? createdBy,
    String? linkedAccountId,
  }) {
    final reservation = Reservation(
      id: 'R${++_sequence}',
      night: night,
      tableId: tableId,
      holder: holder,
      origin: origin,
      status: status,
      history: [ReservationEvent(event, _clock().toUtc())],
      createdBy: createdBy,
      linkedAccountId: linkedAccountId,
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
    ReservationEventType event, {
    ReservationHolder? holder,
    String? linkedAccountId,
  }) {
    final updated = r.withEvent(
      status,
      ReservationEvent(event, _clock().toUtc()),
      holder: holder,
      linkedAccountId: linkedAccountId,
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

  /// R12: nombre y teléfono obligatorios; la cédula es opcional. Teléfono y
  /// cédula (si se escribe) solo con dígitos, sin longitud ni formato.
  static bool isValidRequestHolder(ReservationHolder h) =>
      h.name.trim().isNotEmpty &&
      _digits.hasMatch(h.phone ?? '') &&
      (h.idNumber == null ||
          h.idNumber!.isEmpty ||
          _digits.hasMatch(h.idNumber!));

  /// R7: nombre, cédula y teléfono obligatorios; cédula y teléfono solo con
  /// dígitos, sin validar longitud ni formato.
  static bool _isValidDirectHolder(ReservationHolder h) =>
      h.name.trim().isNotEmpty &&
      _digits.hasMatch(h.idNumber ?? '') &&
      _digits.hasMatch(h.phone ?? '');
}

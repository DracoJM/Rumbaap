import 'dart:math' as math;

import 'night_schedule.dart';
import 'reservation.dart';
import 'venue_table.dart';

/// Acciones sobre una reserva que exigen un cargo y guardan quién las hizo.
enum ReservationAction { confirmPrepayment, reject, arrival, revoke, release }

/// Registro de reservas de un local ([venue]) con las reglas R1–R16, en
/// memoria y con reloj inyectable. Solo admite mesas de ese local: los datos
/// de locales distintos nunca comparten registro.
///
/// Las reglas y el horario son las confirmadas para Sagsa, hoy el único
/// local configurado. PENDIENTE (fuera de alcance): parametrizarlas por local
/// cuando exista un segundo local con reglas propias. No conoce los cargos:
/// las altas, las acciones de [ReservationAction] y el cumpleaños consultan
/// los permisos que inyecta la app ([canCreate], [canPerform],
/// [canManageBirthdays]). Tampoco calcula el vínculo de cuenta
/// (R12): la vista lo obtiene por cédula exacta y lo pasa como
/// `linkedAccountId`.
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

  /// Si una identidad puede confirmar las condiciones de un cumpleaños y
  /// marcar su decoración preparada (la administración). Por defecto nadie:
  /// sin conexión no se confirma nada.
  bool Function(String actorId) canManageBirthdays = _nobody;

  /// Si una identidad puede ejecutar una [ReservationAction]. Por defecto
  /// nadie: sin conexión no se ejecuta ninguna.
  bool Function(String actorId, ReservationAction action) canPerform =
      _nobodyFor;

  /// Si una identidad puede crear una reserva con ese origen: solicitudes
  /// de cliente o de promotor, o reserva directa de la administración. Por
  /// defecto nadie: sin conexión no se crea ninguna.
  bool Function(String actorId, ReservationOrigin origin) canCreate =
      _nobodyCreates;

  static bool _nobody(String _) => false;
  static bool _nobodyFor(String _, ReservationAction _) => false;
  static bool _nobodyCreates(String _, ReservationOrigin _) => false;

  void _authorize(String actorId, ReservationAction action) {
    if (!canPerform(actorId, action)) {
      throw const ReservationException(ReservationError.notAllowed);
    }
  }

  int _sequence = 0;

  /// Estado completo, para la persistencia local de la demostración.
  ({List<Reservation> reservations, int sequence}) exportState() =>
      (reservations: _reservations.values.toList(), sequence: _sequence);

  /// Restaura un estado exportado en un libro recién creado.
  void importState(List<Reservation> reservations, int sequence) {
    if (_reservations.isNotEmpty) {
      throw StateError('Solo se restaura en un libro vacío');
    }
    for (final r in reservations) {
      _reservations[r.id] = r;
    }
    _sequence = sequence;
  }

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

  // ------------------------------------------------------ Altas de usuario
  //
  // Antes que nada se comprueba si la identidad puede crear con ese origen
  // ([canCreate]); un intento denegado no crea nada ni bloquea la mesa. Quien
  // crea queda como actor del evento y, en las solicitudes de cliente y
  // promotor, como creador ([Reservation.createdBy]). El titular es aparte.

  /// Mesa normal: el cliente o el promotor pulsan «Reservar esta mesa» y
  /// empieza el trámite (R14): la mesa queda En proceso hasta 10 min, sin
  /// titular todavía. La comprobación y el bloqueo ocurren aquí, en una sola
  /// operación.
  Reservation startNormal({
    required Night night,
    required String tableId,
    required ReservationOrigin origin,
    required String actorId,
  }) {
    _authorizeRequestOrigin(origin);
    _authorizeCreation(actorId, origin);
    _checkCanReserve(night, tableId, vip: false);
    return _create(
      night,
      tableId,
      null,
      origin,
      ReservationStatus.inProcess,
      ReservationEventType.requested,
      createdBy: actorId,
      actorId: actorId,
    );
  }

  /// Envío final del trámite normal (R13, R14): valida al titular (R12) y lo
  /// confirma si el trámite sigue activo y sin vencer. Solo lo envía quien
  /// lo empezó. Si algo falla no cambia nada.
  Reservation submitNormal(
    String id, {
    required ReservationHolder holder,
    String? linkedAccountId,
    BirthdayCelebration? birthday,
    required String actorId,
  }) {
    final r = _get(id);
    _authorizeOwnDraft(r, actorId);
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
    _checkBirthday(birthday);
    return _apply(
      r,
      ReservationStatus.confirmed,
      ReservationEventType.completed,
      holder: holder,
      linkedAccountId: linkedAccountId,
      birthday: birthday,
      actorId: actorId,
    );
  }

  /// Abandono expreso del trámite normal (R15): solo un trámite En proceso,
  /// y solo quien lo empezó.
  Reservation cancelInProcess(String id, {required String actorId}) {
    final r = _get(id);
    _authorizeOwnDraft(r, actorId);
    if (r.status != ReservationStatus.inProcess) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    return _apply(
      r,
      ReservationStatus.cancelled,
      ReservationEventType.cancelled,
      actorId: actorId,
    );
  }

  /// VIP del cliente o del promotor (R16): la solicitud se crea solo con el
  /// envío final válido y queda pendiente de pago, sin caducidad (R2).
  Reservation submitVip({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required ReservationOrigin origin,
    required String actorId,
    String? linkedAccountId,
    BirthdayCelebration? birthday,
  }) {
    _authorizeRequestOrigin(origin);
    _authorizeCreation(actorId, origin);
    if (!isValidRequestHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    _checkBirthday(birthday);
    _checkCanReserve(night, tableId, vip: true);
    return _create(
      night,
      tableId,
      holder,
      origin,
      ReservationStatus.pendingPayment,
      ReservationEventType.requested,
      createdBy: actorId,
      linkedAccountId: linkedAccountId,
      birthday: birthday,
      actorId: actorId,
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

  /// Las solicitudes (trámite normal y VIP) son del cliente o del promotor.
  /// El origen administrativo solo entra por [createDirect]: aunque la
  /// administración pueda crear con ese origen, por aquí se rechaza, también
  /// con los asserts desactivados.
  static void _authorizeRequestOrigin(ReservationOrigin origin) {
    if (origin == ReservationOrigin.admin) {
      throw const ReservationException(ReservationError.notAllowed);
    }
  }

  void _authorizeCreation(String actorId, ReservationOrigin origin) {
    if (!canCreate(actorId, origin)) {
      throw const ReservationException(ReservationError.notAllowed);
    }
  }

  /// El trámite normal es de quien lo empezó: sin creador (siembra o datos
  /// anteriores) nadie lo envía ni lo cancela; vence solo (R1).
  void _authorizeOwnDraft(Reservation r, String actorId) {
    if (r.createdBy != actorId || !canCreate(actorId, r.origin)) {
      throw const ReservationException(ReservationError.notAllowed);
    }
  }

  // ------------------------------------------- Siembra de demostración

  /// Rellena una noche VACÍA y no terminada con datos ficticios para la
  /// demostración: cinco normales confirmadas, un trámite normal En proceso,
  /// una VIP pendiente de pago y, si la noche está en curso, dos llegadas.
  /// No es un alta de usuario: no tiene actor ni creador. Con cualquier
  /// reserva en la noche, no hace nada. Aplica las mismas comprobaciones de
  /// mesa, noche y titular que las altas.
  void seedDemoNight(Night night) {
    final venueNow = VenueTime.of(_clock());
    if (night.hasEnded(venueNow)) return;
    if (forNight(night).isNotEmpty) return;
    final random = math.Random(
      night.date.year * 10000 + night.date.month * 100 + night.date.day,
    );

    final normals = venue.tables.where((t) => !t.isVip).toList()
      ..shuffle(random);
    final confirmed = <Reservation>[];
    for (var i = 0; i < math.min(5, normals.length); i++) {
      final holder = _seedHolder(i, promoterByName: i.isOdd);
      _checkCanReserve(night, normals[i].id, vip: false);
      final r = _create(
        night,
        normals[i].id,
        holder,
        i.isOdd ? ReservationOrigin.promoter : ReservationOrigin.client,
        ReservationStatus.inProcess,
        ReservationEventType.requested,
      );
      confirmed.add(
        _apply(r, ReservationStatus.confirmed, ReservationEventType.completed),
      );
    }
    // Un trámite normal en proceso: vencerá a los 10 min (R1) y, como no se
    // ha enviado, todavía no tiene titular (R14).
    if (normals.length > 5) {
      _checkCanReserve(night, normals[5].id, vip: false);
      _create(
        night,
        normals[5].id,
        null,
        ReservationOrigin.client,
        ReservationStatus.inProcess,
        ReservationEventType.requested,
      );
    }

    // Siempre hay una VIP pendiente de pago para poder demostrar la
    // verificación del prepago (R2). El sorteo se conserva para que la
    // elección de mesas siga siendo la misma para la misma fecha.
    final vips = venue.tables.where((t) => t.isVip).toList()..shuffle(random);
    random.nextDouble();
    if (vips.isNotEmpty) {
      _checkCanReserve(night, vips.first.id, vip: true);
      _create(
        night,
        vips.first.id,
        _seedHolder(6),
        ReservationOrigin.client,
        ReservationStatus.pendingPayment,
        ReservationEventType.requested,
      );
    }

    if (night.isInProgress(venueNow)) {
      for (final r in confirmed.take(2)) {
        _apply(r, ReservationStatus.seated, ReservationEventType.arrived);
      }
    }
  }

  /// Titulares claramente ficticios. «Por nombre» (promotor) no lleva cédula
  /// (R10).
  static ReservationHolder _seedHolder(int n, {bool promoterByName = false}) {
    final suffix = (n + 1).toString().padLeft(2, '0');
    return ReservationHolder(
      name: 'Titular demo $suffix',
      idNumber: promoterByName ? null : '00000000$suffix',
      phone: '00000000$suffix',
    );
  }

  /// El administrador verificó el prepago VIP (R2).
  ///
  /// NOT DECIDED: proveedor de pagos. Hoy el pago se marca a mano; aquí se
  /// conectará la ruta de pago dentro de la app cuando se decida.
  Reservation markPrepaymentReceived(String id, {required String actorId}) =>
      _transition(
        id,
        action: ReservationAction.confirmPrepayment,
        actorId: actorId,
        from: {ReservationStatus.pendingPayment},
        to: ReservationStatus.confirmed,
        event: ReservationEventType.prepaymentMarked,
      );

  /// El administrador rechaza una VIP pendiente de pago (R2).
  Reservation rejectRequest(String id, {required String actorId}) =>
      _transition(
        id,
        action: ReservationAction.reject,
        actorId: actorId,
        from: {ReservationStatus.pendingPayment},
        to: ReservationStatus.revoked,
        event: ReservationEventType.rejected,
      );

  /// Reserva directa del administrador: confirmada desde el inicio, también
  /// en VIP, porque se asume el pago ya verificado (R7). Quien la crea queda
  /// como actor del evento; el creador ([Reservation.createdBy]) sigue
  /// vacío, como hasta ahora, porque no es una solicitud propia.
  Reservation createDirect({
    required Night night,
    required String tableId,
    required ReservationHolder holder,
    required String actorId,
    String? linkedAccountId,
    BirthdayCelebration? birthday,
  }) {
    _authorizeCreation(actorId, ReservationOrigin.admin);
    if (!_isValidDirectHolder(holder)) {
      throw const ReservationException(ReservationError.invalidHolder);
    }
    _checkBirthday(birthday);
    _checkCanReserve(night, tableId, vip: null);
    return _create(
      night,
      tableId,
      holder,
      ReservationOrigin.admin,
      ReservationStatus.confirmed,
      ReservationEventType.createdDirect,
      linkedAccountId: linkedAccountId,
      birthday: birthday,
      actorId: actorId,
    );
  }

  /// Llegada: solo una reserva confirmada de la noche en curso (R5, N6).
  /// La apertura no la registra sola.
  Reservation markArrival(String id, {required String actorId}) {
    _authorize(actorId, ReservationAction.arrival);
    final r = _get(id);
    if (r.status != ReservationStatus.confirmed) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    if (!r.night.isInProgress(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.outsideNight);
    }
    return _apply(
      r,
      ReservationStatus.seated,
      ReservationEventType.arrived,
      actorId: actorId,
    );
  }

  /// El administrador revoca una reserva confirmada (R4). La advertencia
  /// previa es responsabilidad de la vista.
  Reservation revoke(String id, {required String actorId}) => _transition(
    id,
    action: ReservationAction.revoke,
    actorId: actorId,
    from: {ReservationStatus.confirmed},
    to: ReservationStatus.revoked,
    event: ReservationEventType.revoked,
  );

  /// El administrador libera una mesa reservada u ocupada (R6). La doble
  /// confirmación es responsabilidad de la vista. No implica devolución de
  /// dinero ni una política de cancelación.
  Reservation release(String id, {required String actorId}) => _transition(
    id,
    action: ReservationAction.release,
    actorId: actorId,
    from: {ReservationStatus.confirmed, ReservationStatus.seated},
    to: ReservationStatus.released,
    event: ReservationEventType.released,
  );

  /// La administración confirma a mano las condiciones del cumpleaños y si
  /// requiere decoración, y puede ajustarlas mientras la reserva siga
  /// vigente y la noche no haya cerrado. El acuerdo anterior y su
  /// preparación quedan en el historial; si había decoración preparada,
  /// hay que revisarla otra vez. Repetir el mismo acuerdo no cambia nada.
  Reservation confirmBirthday(
    String id, {
    required String conditions,
    required bool decorationRequired,
    required String actorId,
  }) {
    if (!canManageBirthdays(actorId)) {
      throw const ReservationException(ReservationError.notAllowed);
    }
    final r = _get(id);
    final b = r.birthday;
    if (b == null) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    final text = conditions.trim();
    if (text.isEmpty) {
      throw const ReservationException(ReservationError.invalidBirthday);
    }
    if (b.terms case final t?
        when t.conditions == text &&
            t.decorationRequired == decorationRequired) {
      return r;
    }
    _checkBirthdayOpen(r, {
      ReservationStatus.pendingPayment,
      ReservationStatus.confirmed,
      ReservationStatus.seated,
    });
    return _replace(
      r.withBirthday(
        b.withTerms(
          BirthdayTerms(
            conditions: text,
            decorationRequired: decorationRequired,
            confirmed: ActorStamp(actorId, _clock().toUtc()),
          ),
        ),
      ),
    );
  }

  /// Decoración preparada (antes de la apertura, si corresponde): solo si
  /// la administración la confirmó como necesaria. Repetirlo no cambia
  /// nada.
  Reservation markDecorationPrepared(String id, {required String actorId}) {
    if (!canManageBirthdays(actorId)) {
      throw const ReservationException(ReservationError.notAllowed);
    }
    final r = _get(id);
    final b = r.birthday;
    if (b?.terms?.decorationRequired != true) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    if (b!.decorationPrepared != null) return r;
    _checkBirthdayOpen(r, {
      ReservationStatus.confirmed,
      ReservationStatus.seated,
    });
    return _replace(
      r.withBirthday(
        b.withDecorationPrepared(ActorStamp(actorId, _clock().toUtc())),
      ),
    );
  }

  // ---------------------------------------------------------------------

  /// Cumpleaños de un alta: con nombre y sin condiciones ni decoración ya
  /// confirmadas (eso lo hace después la administración).
  static void _checkBirthday(BirthdayCelebration? b) {
    if (b == null) return;
    if (b.honoreeName.trim().isEmpty ||
        b.terms != null ||
        b.decorationPrepared != null) {
      throw const ReservationException(ReservationError.invalidBirthday);
    }
  }

  void _checkBirthdayOpen(Reservation r, Set<ReservationStatus> allowed) {
    if (!allowed.contains(r.status)) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    if (r.night.hasEnded(VenueTime.of(_clock()))) {
      throw const ReservationException(ReservationError.nightEnded);
    }
  }

  Reservation _replace(Reservation updated) =>
      _reservations[updated.id] = updated;

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
    BirthdayCelebration? birthday,
    String? actorId,
  }) {
    final reservation = Reservation(
      id: 'R${++_sequence}',
      night: night,
      tableId: tableId,
      holder: holder,
      origin: origin,
      status: status,
      history: [ReservationEvent(event, _clock().toUtc(), actorId: actorId)],
      createdBy: createdBy,
      linkedAccountId: linkedAccountId,
      birthday: _normalized(birthday),
    );
    _reservations[reservation.id] = reservation;
    return reservation;
  }

  /// Transición de estado. Con [action], antes comprueba el permiso de
  /// [actorId] y lo guarda en el evento.
  Reservation _transition(
    String id, {
    ReservationAction? action,
    String? actorId,
    required Set<ReservationStatus> from,
    required ReservationStatus to,
    required ReservationEventType event,
  }) {
    if (action != null) _authorize(actorId!, action);
    final r = _get(id);
    if (!from.contains(r.status)) {
      throw const ReservationException(ReservationError.invalidTransition);
    }
    return _apply(r, to, event, actorId: actorId);
  }

  Reservation _apply(
    Reservation r,
    ReservationStatus status,
    ReservationEventType event, {
    ReservationHolder? holder,
    String? linkedAccountId,
    BirthdayCelebration? birthday,
    String? actorId,
  }) {
    final updated = r.withEvent(
      status,
      ReservationEvent(event, _clock().toUtc(), actorId: actorId),
      holder: holder,
      linkedAccountId: linkedAccountId,
      birthday: _normalized(birthday),
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

  static BirthdayCelebration? _normalized(BirthdayCelebration? b) {
    if (b == null) return null;
    final notes = b.notes?.trim();
    return BirthdayCelebration(
      honoreeName: b.honoreeName.trim(),
      notes: notes == null || notes.isEmpty ? null : notes,
    );
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

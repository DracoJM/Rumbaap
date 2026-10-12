import 'dart:math';

import '../../reservations/domain/night_schedule.dart';
import 'ticket.dart';

/// Registro de entradas de un local, en memoria y con reloj inyectable.
///
/// Pasos separados: venta → pago (simulado, comprobado por el promotor o
/// cortesía autorizada) → credencial → consulta de puerta → primer ingreso
/// → canje por manilla. Cada operación comprueba el estado actual y no
/// tiene efectos parciales; repetirla no duplica nada. Registra el actor de
/// cada operación nueva. No conoce permisos: qué perspectiva llama a cada
/// operación lo decide la vista (el backend futuro deberá autorizarlo).
///
/// PROPUESTAS pendientes de ratificar (ver docs/business-rules/entradas.md):
/// credencial nueva de longitud fija que se invalida sin reciclarse, y
/// primer ingreso separado del canje.
class TicketBook {
  TicketBook({
    required this.venueId,
    required this.venueTag,
    Clock clock = systemClock,
    Random? random,
  }) : _clock = clock,
       _random = random ?? Random.secure();

  final String venueId;

  /// Prefijo de 2 letras del local en sus credenciales.
  final String venueTag;
  final Clock _clock;

  /// Fuente de las credenciales: aleatoria (segura en la app), para que
  /// una credencial de una demo anterior, reiniciada, no vuelva a coincidir
  /// con una nueva.
  final Random _random;

  /// Comprueba una cortesía enlazada a una reserva VIP antes de consultarla,
  /// registrar su ingreso o canjearla: `null` si procede, o el motivo del
  /// rechazo. Por defecto rechaza: si la app no lo conecta, no se canjea
  /// ninguna cortesía VIP. Las cortesías generales no pasan por aquí.
  RejectReason? Function(String reservationId) vipCourtesyCheck =
      _pendingApproval;

  static RejectReason? _pendingApproval(String _) =>
      RejectReason.vipPendingApproval;

  final _purchases = <String, TicketPurchase>{};
  final _tickets = <String, Ticket>{};
  final _byCredential = <String, String>{};
  final _retiredIndex = <String, String>{};
  final _incidents = <TicketIncident>[];
  int _nextPurchase = 1;
  int _nextTicket = 1;
  int _nextCredential = 1;

  /// Longitud fija de toda credencial: prefijo del local + 10 caracteres.
  static const credentialLength = 12;

  DateTime get _now => _clock();
  DateTime get _venueNow => VenueTime.of(_now);

  // --------------------------------------------- Persistencia local

  /// Estado completo, para la persistencia local de la demostración.
  ({
    List<TicketPurchase> purchases,
    List<Ticket> tickets,
    List<TicketIncident> incidents,
    List<int> counters,
  })
  exportState() => (
    purchases: _purchases.values.toList(),
    tickets: _tickets.values.toList(),
    incidents: List.of(_incidents),
    counters: [_nextPurchase, _nextTicket, _nextCredential],
  );

  /// Restaura un estado exportado en un libro recién creado. Los índices de
  /// credenciales vigentes y retiradas se reconstruyen desde las entradas:
  /// ninguna credencial se regenera ni se reactiva.
  void importState({
    required List<TicketPurchase> purchases,
    required List<Ticket> tickets,
    required List<TicketIncident> incidents,
    required List<int> counters,
  }) {
    if (_tickets.isNotEmpty || _purchases.isNotEmpty) {
      throw StateError('Solo se restaura en un libro vacío');
    }
    for (final p in purchases) {
      _purchases[p.id] = p;
    }
    for (final t in tickets) {
      _tickets[t.id] = t;
      if (t.credential case final c?) _byCredential[c] = t.id;
      for (final r in t.retired) {
        _retiredIndex[r.code] = t.id;
      }
    }
    _incidents.addAll(incidents);
    _nextPurchase = counters[0];
    _nextTicket = counters[1];
    _nextCredential = counters[2];
  }

  // ---------------------------------------------------------- Consultas

  List<TicketPurchase> get purchases => _purchases.values.toList();
  List<Ticket> get tickets => _tickets.values.toList();
  List<TicketIncident> get incidents => List.unmodifiable(_incidents);

  TicketPurchase? purchaseById(String id) => _purchases[id];
  Ticket? ticketById(String id) => _tickets[id];

  /// Cortesías emitidas como beneficio de la reserva [reservationId], en
  /// cualquier estado (también canjeadas o anuladas).
  List<Ticket> courtesiesOfReservation(String reservationId) => [
    for (final p in _purchases.values)
      if (p.channel == TicketChannel.courtesy &&
          p.reservationId == reservationId)
        ...ticketsOf(p.id),
  ];

  List<Ticket> ticketsOf(String purchaseId) => [
    for (final t in _tickets.values)
      if (t.purchaseId == purchaseId) t,
  ];

  List<Ticket> ownedBy(String accountId) => [
    for (final t in _tickets.values)
      if (t.ownerId == accountId) t,
  ];

  List<TicketPurchase> createdBy(String identityId) => [
    for (final p in _purchases.values)
      if (p.createdBy == identityId) p,
  ];

  // ------------------------------------------------- Venta, pago, cortesía

  /// Venta pendiente de pago: crea los derechos sin activarlos ni emitir
  /// credencial. Mostrar la venta no activa nada.
  TicketPurchase sell({
    required Night night,
    required TicketProduct product,
    required int quantity,
    required TicketChannel channel,
    required String actorId,
    String? ownerId,
    String? holderName,
  }) {
    assert(channel != TicketChannel.courtesy, 'Usa authorizeCourtesy.');
    final price = product.demoPriceFor(night);
    if (price == null) throw const TicketException(TicketError.noPrice);
    if (channel == TicketChannel.promoter &&
        (holderName == null || holderName.trim().isEmpty)) {
      throw const TicketException(TicketError.invalidHolder);
    }
    return _create(
      night: night,
      product: product,
      quantity: quantity,
      unitPrice: price,
      channel: channel,
      actorId: actorId,
      ownerId: ownerId,
      holderName: holderName?.trim(),
      payment: PaymentStatus.pending,
    );
  }

  /// Cortesía autorizada por la administración: activa sin pago.
  TicketPurchase authorizeCourtesy({
    required Night night,
    required TicketProduct product,
    required int quantity,
    required String actorId,
    required String holderName,
    required String reason,
    String? ownerId,
    String? reservationId,
  }) {
    if (holderName.trim().isEmpty || reason.trim().isEmpty) {
      throw const TicketException(TicketError.invalidHolder);
    }
    final p = _create(
      night: night,
      product: product,
      quantity: quantity,
      unitPrice: 0,
      channel: TicketChannel.courtesy,
      actorId: actorId,
      ownerId: ownerId,
      holderName: holderName.trim(),
      note: reason.trim(),
      reservationId: reservationId,
      payment: PaymentStatus.courtesy,
    );
    for (final t in ticketsOf(p.id)) {
      _activate(t, TicketEventType.courtesyAuthorized, actorId, reason.trim());
    }
    return _purchases[p.id] = p.withPayment(
      PaymentStatus.courtesy,
      _now,
      actorId,
    );
  }

  /// Cliente: pago SIMULADO de su compra. Activa y emite credenciales.
  TicketPurchase simulatePayment(
    String purchaseId, {
    required String actorId,
  }) => _pay(
    purchaseId,
    TicketChannel.app,
    PaymentStatus.paidSimulated,
    TicketEventType.paymentSimulated,
    actorId,
  );

  /// Promotor: declara comprobado el pago de su venta. Solo entonces se
  /// activa el derecho de su circuito.
  TicketPurchase verifyPromoterPayment(
    String purchaseId, {
    required String actorId,
  }) => _pay(
    purchaseId,
    TicketChannel.promoter,
    PaymentStatus.verifiedByPromoter,
    TicketEventType.paymentVerified,
    actorId,
  );

  TicketPurchase _pay(
    String id,
    TicketChannel channel,
    PaymentStatus to,
    TicketEventType event,
    String actorId,
  ) {
    final p = _purchases[id];
    if (p == null) throw const TicketException(TicketError.notFound);
    if (p.channel != channel) {
      throw const TicketException(TicketError.wrongChannel);
    }
    if (p.payment != PaymentStatus.pending) {
      throw const TicketException(TicketError.alreadyPaid);
    }
    if (p.night.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    for (final t in ticketsOf(id)) {
      _activate(t, event, actorId, null);
    }
    return _purchases[id] = p.withPayment(to, _now, actorId);
  }

  // ------------------------------------------------- Puerta y taquilla

  /// Consulta de puerta: no cambia el derecho. Devuelve el estado vigente
  /// para este local y la noche en curso. Un rechazo queda como incidencia.
  CheckResult doorCheck(String code, {required String actorId}) {
    final found = _resolve(code, actorId, 'Puerta');
    if (found is CheckResult) return found;
    final t = found as Ticket;
    if (t.firstEntryAt != null) {
      return CheckResult(CheckOutcome.entryAlreadyRecorded, ticket: t);
    }
    return CheckResult(CheckOutcome.validNoEntry, ticket: t);
  }

  /// La puerta confirma el primer ingreso: se registra una sola vez.
  /// Repetirlo devuelve «Ingreso ya registrado» sin cambiar nada; no
  /// bloquea el canje en taquilla.
  CheckResult confirmFirstEntry(String code, {required String actorId}) {
    final found = _resolve(code, actorId, 'Puerta');
    if (found is CheckResult) return found;
    final t = found as Ticket;
    if (t.firstEntryAt != null) {
      return CheckResult(CheckOutcome.entryAlreadyRecorded, ticket: t);
    }
    final done = _tickets[t.id] = t.copyWith(
      firstEntryAt: _now,
      event: TicketEvent(
        TicketEventType.firstEntryRecorded,
        _now,
        actorId: actorId,
      ),
    );
    return CheckResult(CheckOutcome.entryRecorded, ticket: done);
  }

  /// Canje por manilla, una sola vez. Taquilla canjea app y cortesías; el
  /// promotor canjea con su lote las de su circuito. Tras el canje, puerta
  /// y taquilla responden «No canjeable».
  CheckResult redeem(
    String code, {
    required String actorId,
    required RedeemPoint point,
  }) {
    final where = point == RedeemPoint.boxOffice ? 'Taquilla' : 'Promotor';
    final found = _resolve(code, actorId, where);
    if (found is CheckResult) return found;
    final t = found as Ticket;
    final promoterTicket = t.channel == TicketChannel.promoter;
    if (promoterTicket != (point == RedeemPoint.promoterLot)) {
      return _reject(code, actorId, where, RejectReason.wrongCircuit, t);
    }
    final done = _tickets[t.id] = t.copyWith(
      status: TicketStatus.redeemed,
      redeemedAt: _now,
      redeemPoint: point,
      event: TicketEvent(TicketEventType.redeemed, _now, actorId: actorId),
    );
    return CheckResult(CheckOutcome.redeemedNow, ticket: done);
  }

  /// Barra: identifica la CUENTA dueña de la entrada cuya credencial
  /// VIGENTE se leyó, para enviarle el comprobante. La identidad sale del
  /// registro, nunca del QR. Solo consulta: no registra ingreso ni canje, no
  /// cambia la entrada ni anota incidencias. Una entrada ya canjeada sigue
  /// identificando a su dueño, sin recuperar derechos; una credencial
  /// retirada, de otra noche o de otro local no identifica a nadie.
  AccountLookup identifyAccount(String raw) {
    final code = normalize(raw);
    final id = _byCredential[code];
    if (id == null) {
      if (_retiredIndex.containsKey(code)) {
        return const AccountLookup.failed(AccountLookupError.retiredCredential);
      }
      final looksLike =
          code.length == credentialLength && !code.startsWith(venueTag);
      return AccountLookup.failed(
        looksLike ? AccountLookupError.otherVenue : AccountLookupError.notFound,
      );
    }
    final t = _tickets[id]!;
    if (t.status == TicketStatus.voided) {
      return AccountLookup.failed(AccountLookupError.voided, ticket: t);
    }
    if (!t.night.isInProgress(_venueNow)) {
      final anyTonight = NightSchedule.weekendNights(
        _venueNow,
      ).any((n) => n.isInProgress(_venueNow));
      return AccountLookup.failed(
        anyTonight
            ? AccountLookupError.otherNight
            : AccountLookupError.outsideNight,
        ticket: t,
      );
    }
    final owner = t.ownerId;
    if (owner == null) {
      return AccountLookup.failed(AccountLookupError.noAccount, ticket: t);
    }
    return AccountLookup.identified(owner, t);
  }

  /// Comprueba credencial, local, noche, pago y canje. Devuelve la entrada
  /// si sigue vigente, o el rechazo ya registrado.
  Object _resolve(String raw, String actorId, String point) {
    final code = normalize(raw);
    final id = _byCredential[code];
    if (id == null) {
      final retiredOf = _retiredIndex[code];
      if (retiredOf != null) {
        return _reject(
          code,
          actorId,
          point,
          RejectReason.retiredCredential,
          _tickets[retiredOf],
        );
      }
      final looksLike =
          code.length == credentialLength && !code.startsWith(venueTag);
      return _reject(
        code,
        actorId,
        point,
        looksLike ? RejectReason.otherVenue : RejectReason.notFound,
        null,
      );
    }
    final t = _tickets[id]!;
    switch (t.status) {
      case TicketStatus.voided:
        return _reject(code, actorId, point, RejectReason.voided, t);
      case TicketStatus.pendingPayment:
        return _reject(code, actorId, point, RejectReason.unpaid, t);
      case TicketStatus.redeemed:
        return _reject(code, actorId, point, RejectReason.redeemed, t);
      case TicketStatus.active:
        break;
    }
    // Cortesía de una reserva VIP: requiere su aprobación y verificación,
    // también para credenciales ya emitidas (enlace estructurado).
    if (_purchases[t.purchaseId]?.reservationId case final rid?) {
      if (vipCourtesyCheck(rid) case final reason?) {
        return _reject(code, actorId, point, reason, t);
      }
    }
    if (!t.night.isInProgress(_venueNow)) {
      final anyTonight = NightSchedule.weekendNights(
        _venueNow,
      ).any((n) => n.isInProgress(_venueNow));
      return _reject(
        code,
        actorId,
        point,
        anyTonight ? RejectReason.otherNight : RejectReason.outsideNight,
        t,
      );
    }
    return t;
  }

  CheckResult _reject(
    String code,
    String actorId,
    String point,
    RejectReason reason,
    Ticket? t,
  ) {
    _incidents.add(
      TicketIncident(
        at: _now,
        actorId: actorId,
        point: point,
        code: code,
        reason: reason,
        ticketId: t?.id,
      ),
    );
    Ticket? updated;
    if (t != null) {
      // El rechazo se anota en el historial, pero no cambia el derecho.
      updated = _tickets[t.id] = t.copyWith(
        event: TicketEvent(
          TicketEventType.rejected,
          _now,
          actorId: actorId,
          note: '$point · ${reason.name}',
        ),
      );
    }
    return CheckResult(CheckOutcome.rejected, ticket: updated, reason: reason);
  }

  // ------------------------------------------------- Credenciales

  /// Retira la credencial vigente y emite otra nueva, de la misma longitud.
  /// La retirada no se recicla: leerla después da «credencial retirada».
  /// No borra venta, pago ni cuenta. No aplica tras el canje.
  Ticket replaceCredential(
    String ticketId, {
    required String actorId,
    required String reason,
  }) {
    final t = _get(ticketId);
    if (t.status != TicketStatus.active || t.credential == null) {
      throw const TicketException(TicketError.notEligible);
    }
    final old = t.credential!;
    _byCredential.remove(old);
    _retiredIndex[old] = t.id;
    final fresh = _newCredential();
    _byCredential[fresh] = t.id;
    return _tickets[t.id] = t
        .copyWith(
          credential: fresh,
          retired: [...t.retired, RetiredCredential(old, _now, reason)],
          event: TicketEvent(
            TicketEventType.credentialRetired,
            _now,
            actorId: actorId,
            note: reason,
          ),
        )
        .copyWith(
          event: TicketEvent(
            TicketEventType.credentialIssued,
            _now,
            actorId: actorId,
          ),
        );
  }

  // --------------------------------------------- Devolución y cambio

  bool canRequest(Ticket t) =>
      t.status == TicketStatus.active &&
      t.firstEntryAt == null &&
      t.channel != TicketChannel.courtesy &&
      !t.hasOpenRequest &&
      !t.night.hasEnded(_venueNow);

  Ticket requestRefund(String ticketId, {required String actorId}) =>
      _request(ticketId, TicketRequestType.refund, actorId);

  Ticket requestNightChange(
    String ticketId,
    Night target, {
    required String actorId,
  }) {
    final t = _get(ticketId);
    if (target == t.night) throw const TicketException(TicketError.sameNight);
    if (target.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    return _request(ticketId, TicketRequestType.changeNight, actorId, target);
  }

  Ticket _request(
    String id,
    TicketRequestType kind,
    String actorId, [
    Night? target,
  ]) {
    final t = _get(id);
    if (!canRequest(t)) throw const TicketException(TicketError.notEligible);
    return _tickets[id] = t.copyWith(
      request: TicketRequest(
        type: kind,
        status: TicketRequestStatus.requested,
        requestedAt: _now,
        targetNight: target,
      ),
      event: TicketEvent(
        kind == TicketRequestType.refund
            ? TicketEventType.refundRequested
            : TicketEventType.changeRequested,
        _now,
        actorId: actorId,
        note: target?.id,
      ),
    );
  }

  /// La administración autoriza. Una devolución autorizada anula la
  /// entrada y retira su credencial, pero NO devuelve dinero.
  Ticket authorizeRequest(String ticketId, {required String actorId}) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null || r.status != TicketRequestStatus.requested) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    if (t.status != TicketStatus.active || t.firstEntryAt != null) {
      throw const TicketException(TicketError.notEligible);
    }
    if (r.type == TicketRequestType.refund) {
      final old = t.credential;
      if (old != null) {
        _byCredential.remove(old);
        _retiredIndex[old] = t.id;
      }
      return _tickets[ticketId] = t.copyWith(
        status: TicketStatus.voided,
        clearCredential: true,
        retired: [
          ...t.retired,
          if (old != null) RetiredCredential(old, _now, 'Devolución'),
        ],
        request: r.withStatus(TicketRequestStatus.authorized),
        event: TicketEvent(
          TicketEventType.refundAuthorized,
          _now,
          actorId: actorId,
        ),
      );
    }
    final target = r.targetNight!;
    if (target.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    return _tickets[ticketId] = t.copyWith(
      night: target,
      request: r.withStatus(TicketRequestStatus.authorized),
      event: TicketEvent(
        TicketEventType.nightChanged,
        _now,
        actorId: actorId,
        note: target.id,
      ),
    );
  }

  Ticket rejectRequest(String ticketId, {required String actorId}) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null || r.status != TicketRequestStatus.requested) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    return _tickets[ticketId] = t.copyWith(
      request: r.withStatus(TicketRequestStatus.rejected),
      event: TicketEvent(
        TicketEventType.requestRejected,
        _now,
        actorId: actorId,
      ),
    );
  }

  /// Registra que el dinero de una devolución autorizada se devolvió fuera
  /// de la app. La app no ejecuta devoluciones.
  Ticket recordRefundReturned(String ticketId, {required String actorId}) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null ||
        r.type != TicketRequestType.refund ||
        r.status != TicketRequestStatus.authorized) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    return _tickets[ticketId] = t.copyWith(
      request: r.withStatus(TicketRequestStatus.refundRecorded),
      event: TicketEvent(
        TicketEventType.refundRecorded,
        _now,
        actorId: actorId,
      ),
    );
  }

  // ------------------------------------------------------------ Interno

  /// Normaliza lo leído o escrito: mayúsculas, sin espacios ni guiones.
  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  TicketPurchase _create({
    required Night night,
    required TicketProduct product,
    required int quantity,
    required int unitPrice,
    required TicketChannel channel,
    required String actorId,
    required PaymentStatus payment,
    String? ownerId,
    String? holderName,
    String? note,
    String? reservationId,
  }) {
    if (night.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    if (quantity < 1) throw const TicketException(TicketError.invalidQuantity);
    final id = 'C${_nextPurchase++}';
    final p = TicketPurchase(
      id: id,
      venueId: venueId,
      night: night,
      product: product,
      quantity: quantity,
      unitPrice: unitPrice,
      channel: channel,
      createdBy: actorId,
      ownerId: ownerId,
      holderName: holderName,
      note: note,
      reservationId: reservationId,
      createdAt: _now,
      payment: payment,
    );
    _purchases[id] = p;
    for (var i = 0; i < quantity; i++) {
      final tid = 'E${_nextTicket++}';
      _tickets[tid] = Ticket(
        id: tid,
        purchaseId: id,
        venueId: venueId,
        night: night,
        channel: channel,
        ownerId: ownerId,
        holderName: holderName,
        status: TicketStatus.pendingPayment,
        history: [TicketEvent(TicketEventType.sold, _now, actorId: actorId)],
      );
    }
    return p;
  }

  void _activate(
    Ticket t,
    TicketEventType event,
    String actorId,
    String? note,
  ) {
    final code = _newCredential();
    _byCredential[code] = t.id;
    _tickets[t.id] = t
        .copyWith(
          status: TicketStatus.active,
          credential: code,
          event: TicketEvent(event, _now, actorId: actorId, note: note),
        )
        .copyWith(
          event: TicketEvent(
            TicketEventType.credentialIssued,
            _now,
            actorId: actorId,
          ),
        );
  }

  Ticket _get(String id) {
    final t = _tickets[id];
    if (t == null) throw const TicketException(TicketError.notFound);
    return t;
  }

  /// Credencial opaca de longitud fija: prefijo del local y 10 caracteres
  /// aleatorios de un alfabeto sin ambigüedades (32^10 combinaciones). Se
  /// comprueba que no exista ni esté retirada en este registro. Es una
  /// decisión de DEMO: la emisión y verificación reales serán del backend.
  String _newCredential() {
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    while (true) {
      _nextCredential++;
      final buf = StringBuffer(venueTag);
      for (var i = 0; i < 10; i++) {
        buf.write(alphabet[_random.nextInt(alphabet.length)]);
      }
      final code = buf.toString();
      if (!_byCredential.containsKey(code) &&
          !_retiredIndex.containsKey(code)) {
        return code;
      }
    }
  }
}

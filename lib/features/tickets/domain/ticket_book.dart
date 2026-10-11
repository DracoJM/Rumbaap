import '../../reservations/domain/night_schedule.dart';
import 'ticket.dart';

/// Registro de entradas de un local, en memoria y con reloj inyectable.
///
/// Separa cuatro pasos: compra (venta), pago simulado, validación digital
/// en el acceso y entrega de la manilla física. Cada operación comprueba
/// el estado actual y no tiene efectos parciales. No conoce roles: qué
/// perspectiva puede llamar a cada operación lo decide la vista.
///
/// NOT DECIDED: proveedor de pagos, límite de entradas por compra, aforo del
/// local (no se deduce de las entradas vendidas), tipos de entrada y precios
/// reales. Los productos y precios son de demostración.
class TicketBook {
  TicketBook({required this.venueId, Clock clock = systemClock})
    : _clock = clock;

  final String venueId;
  final Clock _clock;

  final _purchases = <String, TicketPurchase>{};
  final _tickets = <String, Ticket>{};
  int _nextPurchase = 1;
  int _nextTicket = 1;

  DateTime get _now => _clock();
  DateTime get _venueNow => VenueTime.of(_now);

  // ---------------------------------------------------------- Consultas

  List<TicketPurchase> get purchases => _purchases.values.toList();
  List<Ticket> get tickets => _tickets.values.toList();

  TicketPurchase? purchaseById(String id) => _purchases[id];
  Ticket? ticketById(String id) => _tickets[id];

  Ticket? ticketByCode(String code) {
    final c = code.trim().toUpperCase();
    for (final t in _tickets.values) {
      if (t.code == c) return t;
    }
    return null;
  }

  List<Ticket> ticketsOf(String purchaseId) => [
    for (final t in _tickets.values)
      if (t.purchaseId == purchaseId) t,
  ];

  /// Entradas de la cuenta de un cliente.
  List<Ticket> ownedBy(String accountId) => [
    for (final t in _tickets.values)
      if (t.ownerId == accountId) t,
  ];

  /// Compras o ventas hechas por una identidad.
  List<TicketPurchase> createdBy(String identityId) => [
    for (final p in _purchases.values)
      if (p.createdBy == identityId) p,
  ];

  // ---------------------------------------------------------- Compra y pago

  /// Crea la compra pendiente de pago y sus entradas, una por persona. Sin
  /// pago no dan acceso.
  TicketPurchase purchase({
    required Night night,
    required TicketProduct product,
    required int quantity,
    required TicketChannel channel,
    required String createdBy,
    String? ownerId,
    String? holderName,
  }) {
    if (night.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    if (quantity < 1) {
      throw const TicketException(TicketError.invalidQuantity);
    }
    if (channel == TicketChannel.promoter &&
        (holderName == null || holderName.trim().isEmpty)) {
      throw const TicketException(TicketError.invalidHolder);
    }
    final id = 'C${_nextPurchase++}';
    final p = TicketPurchase(
      id: id,
      venueId: venueId,
      night: night,
      product: product,
      quantity: quantity,
      channel: channel,
      createdBy: createdBy,
      ownerId: ownerId,
      holderName: holderName?.trim(),
      createdAt: _now,
      payment: PaymentStatus.pending,
    );
    _purchases[id] = p;
    for (var i = 0; i < quantity; i++) {
      final tid = 'E${_nextTicket++}';
      _tickets[tid] = Ticket(
        id: tid,
        code: _codeFor(tid),
        purchaseId: id,
        venueId: venueId,
        night: night,
        channel: channel,
        ownerId: ownerId,
        status: TicketStatus.pendingPayment,
        history: [TicketEvent(TicketEventType.purchased, _now)],
      );
    }
    return p;
  }

  /// Pago SIMULADO: no cobra dinero. Habilita las entradas de la compra.
  TicketPurchase simulatePayment(String purchaseId) {
    final p = _purchases[purchaseId];
    if (p == null) throw const TicketException(TicketError.notFound);
    if (p.payment != PaymentStatus.pending) {
      throw const TicketException(TicketError.alreadyPaid);
    }
    if (p.night.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    final paid = p.paid(_now);
    _purchases[purchaseId] = paid;
    for (final t in ticketsOf(purchaseId)) {
      _tickets[t.id] = t.copyWith(
        status: TicketStatus.valid,
        event: TicketEvent(TicketEventType.paid, _now),
      );
    }
    return paid;
  }

  // ------------------------------------------------------------- Acceso

  /// Lectura de la entrada en el acceso (Seguridad). Solo da acceso una
  /// entrada pagada de este local para la noche en curso. Repetir la
  /// lectura devuelve [AccessResult.alreadyAdmitted] sin cambiar nada.
  ({AccessResult result, Ticket? ticket}) validateAccess(String code) {
    final c = code.trim().toUpperCase();
    final t = ticketByCode(c);
    if (t == null) {
      // Un código con el formato de otro local se distingue de uno que no
      // existe.
      final otherVenue =
          RegExp(r'^[A-Z0-9]+-E\d+-[0-9A-F]{5}$').hasMatch(c) &&
          !c.startsWith('${_prefix(venueId)}-');
      return (
        result: otherVenue ? AccessResult.otherVenue : AccessResult.notFound,
        ticket: null,
      );
    }
    switch (t.status) {
      case TicketStatus.admitted:
        return (result: AccessResult.alreadyAdmitted, ticket: t);
      case TicketStatus.voided:
        return (result: AccessResult.voided, ticket: t);
      case TicketStatus.pendingPayment:
        return (result: AccessResult.unpaid, ticket: t);
      case TicketStatus.valid:
        break;
    }
    if (!t.night.isInProgress(_venueNow)) {
      // Fuera de horario, o la entrada es de otra noche que la que está en
      // curso (N1, N6).
      final anyTonight = NightSchedule.weekendNights(
        _venueNow,
      ).any((n) => n.isInProgress(_venueNow));
      return (
        result: anyTonight
            ? AccessResult.otherNight
            : AccessResult.outsideNight,
        ticket: t,
      );
    }
    final admitted = t.copyWith(
      status: TicketStatus.admitted,
      admittedAt: _now,
      event: TicketEvent(TicketEventType.admitted, _now),
    );
    _tickets[t.id] = admitted;
    return (result: AccessResult.admitted, ticket: admitted);
  }

  /// Entrega de la manilla física (Caja), solo para compras en la app y con
  /// el acceso ya validado. Una por entrada: repetir no entrega otra.
  ({WristbandResult result, Ticket? ticket}) deliverWristband(String code) {
    final t = ticketByCode(code);
    if (t == null) return (result: WristbandResult.notFound, ticket: null);
    if (t.status == TicketStatus.voided) {
      return (result: WristbandResult.voided, ticket: t);
    }
    if (t.channel == TicketChannel.promoter) {
      return (result: WristbandResult.promoterCircuit, ticket: t);
    }
    if (t.wristbandAt != null) {
      return (result: WristbandResult.alreadyDelivered, ticket: t);
    }
    if (t.status != TicketStatus.admitted) {
      return (result: WristbandResult.notAdmitted, ticket: t);
    }
    final done = t.copyWith(
      wristbandAt: _now,
      event: TicketEvent(TicketEventType.wristbandDelivered, _now),
    );
    _tickets[t.id] = done;
    return (result: WristbandResult.delivered, ticket: done);
  }

  // --------------------------------------------- Devolución y cambio

  bool canRequest(Ticket t) =>
      t.status == TicketStatus.valid &&
      !t.hasOpenRequest &&
      !t.night.hasEnded(_venueNow);

  /// El dueño solicita la devolución de una entrada pagada y sin usar.
  Ticket requestRefund(String ticketId) =>
      _request(ticketId, TicketRequestType.refund);

  /// El dueño solicita pasar una entrada sin usar a otra noche.
  Ticket requestNightChange(String ticketId, Night target) {
    final t = _get(ticketId);
    if (target == t.night) throw const TicketException(TicketError.sameNight);
    if (target.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    return _request(ticketId, TicketRequestType.changeNight, target: target);
  }

  Ticket _request(String id, TicketRequestType kind, {Night? target}) {
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
      ),
    );
  }

  /// La administración autoriza la solicitud abierta. Una devolución
  /// autorizada anula la entrada, pero NO devuelve dinero: eso se registra
  /// aparte. Un cambio autorizado mueve la entrada a la noche pedida.
  Ticket authorizeRequest(String ticketId) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null || r.status != TicketRequestStatus.requested) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    if (t.status != TicketStatus.valid) {
      throw const TicketException(TicketError.notEligible);
    }
    if (r.type == TicketRequestType.refund) {
      return _tickets[ticketId] = t.copyWith(
        status: TicketStatus.voided,
        request: r.withStatus(TicketRequestStatus.authorized),
        event: TicketEvent(TicketEventType.refundAuthorized, _now),
      );
    }
    final target = r.targetNight!;
    if (target.hasEnded(_venueNow)) {
      throw const TicketException(TicketError.nightEnded);
    }
    return _tickets[ticketId] = t.copyWith(
      night: target,
      request: r.withStatus(TicketRequestStatus.authorized),
      event: TicketEvent(TicketEventType.nightChanged, _now),
    );
  }

  Ticket rejectRequest(String ticketId) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null || r.status != TicketRequestStatus.requested) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    return _tickets[ticketId] = t.copyWith(
      request: r.withStatus(TicketRequestStatus.rejected),
      event: TicketEvent(TicketEventType.requestRejected, _now),
    );
  }

  /// Registra que el dinero de una devolución autorizada se devolvió fuera
  /// de la app. La app no ejecuta devoluciones.
  Ticket recordRefundReturned(String ticketId) {
    final t = _get(ticketId);
    final r = t.request;
    if (r == null ||
        r.type != TicketRequestType.refund ||
        r.status != TicketRequestStatus.authorized) {
      throw const TicketException(TicketError.noOpenRequest);
    }
    return _tickets[ticketId] = t.copyWith(
      request: r.withStatus(TicketRequestStatus.refundRecorded),
      event: TicketEvent(TicketEventType.refundRecorded, _now),
    );
  }

  // ------------------------------------------------------------ Interno

  Ticket _get(String id) {
    final t = _tickets[id];
    if (t == null) throw const TicketException(TicketError.notFound);
    return t;
  }

  /// Código legible de la entrada: prefijo del local, ID y una
  /// comprobación corta. Es ficticio y no se puede escanear.
  String _codeFor(String ticketId) {
    var h = 7;
    for (final c in '$venueId:$ticketId'.codeUnits) {
      h = (h * 31 + c) & 0xFFFFF;
    }
    final check = h.toRadixString(16).toUpperCase().padLeft(5, '0');
    return '${_prefix(venueId)}-$ticketId-$check';
  }

  static String _prefix(String venueId) => venueId.toUpperCase();
}

import 'dart:convert';

import '../../features/bar/data/demo_bar_store.dart';
import '../../features/bar/domain/bar.dart';
import '../../features/bar/domain/champagne.dart';
import '../../features/dashboard/data/demo_goal_store.dart';
import '../../features/dashboard/domain/night_goals.dart';
import '../../features/reservations/data/demo_reservation_store.dart';
import '../../features/reservations/domain/night_schedule.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/tickets/data/demo_ticket_store.dart';
import '../../features/tickets/domain/ticket.dart';
import '../../features/venues/venue_config.dart';

/// Formato del estado guardado de la demostración. Si cambia de forma
/// incompatible, se sube y los datos anteriores no se cargan en silencio.
const demoSnapshotFormat = 1;

/// Los datos guardados no se pueden usar. Nunca se sustituyen solos por
/// datos de ejemplo: la persona decide si reiniciar la demo.
class DemoDataException implements Exception {
  const DemoDataException(this.incompatible, this.detail);

  /// `true`: formato de otra versión o de otro local; `false`: datos
  /// dañados.
  final bool incompatible;
  final String detail;

  @override
  String toString() => 'DemoDataException($detail)';
}

/// Estado compartido de UN local: reservas y entradas de todas las cuentas
/// ficticias. Cada vista sigue leyendo solo su proyección; cambiar de
/// identidad no copia ni reinicia nada.
String encodeDemoSnapshot({
  required VenueConfig config,
  required DemoReservationStore reservations,
  required DemoTicketStore tickets,
  required DemoBarStore bar,
  DemoGoalStore? goals,
  required DateTime savedAt,
}) {
  final r = reservations.book.exportState();
  final t = tickets.book.exportState();
  final b = bar.book.exportState();
  return jsonEncode({
    'format': demoSnapshotFormat,
    'venueId': config.venue.id,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'reservations': {
      'sequence': r.sequence,
      'seededNights': [for (final n in reservations.seededNights) n.id],
      'items': [for (final x in r.reservations) _reservation(x)],
    },
    'tickets': {
      'counters': t.counters,
      'purchases': [for (final p in t.purchases) _purchase(p)],
      'tickets': [for (final x in t.tickets) _ticket(x)],
      'incidents': [for (final i in t.incidents) _incident(i)],
      'results': {
        for (final e in tickets.resultsByRequest.entries)
          e.key: {
            'outcome': e.value.outcome.name,
            'ticketId': e.value.ticket?.id,
            'reason': e.value.reason?.name,
          },
      },
    },
    'bar': {
      'next': b.next,
      'sales': [for (final s in b.sales) _sale(s)],
      'acceptances': [for (final a in b.acceptances) _acceptance(a)],
      'prepaids': [for (final p in b.prepaids) _prepaid(p)],
      'champagne': [for (final c in b.champagne) _champagne(c)],
    },
    if (goals != null) 'goals': [for (final g in goals.book.goals) _goal(g)],
  });
}

/// Carga el estado guardado en almacenes recién creados. Si algo no encaja
/// lanza [DemoDataException] y no deja nada a medias.
void decodeDemoSnapshot(
  String raw, {
  required VenueConfig config,
  required DemoReservationStore reservations,
  required DemoTicketStore tickets,
  required DemoBarStore bar,
  DemoGoalStore? goals,
}) {
  final Object? root;
  try {
    root = jsonDecode(raw);
  } on FormatException catch (e) {
    throw DemoDataException(false, 'JSON no válido: ${e.message}');
  }
  if (root is! Map<String, Object?>) {
    throw const DemoDataException(false, 'Raíz inesperada');
  }
  if (root['format'] != demoSnapshotFormat) {
    throw DemoDataException(true, 'Formato ${root['format']}');
  }
  if (root['venueId'] != config.venue.id) {
    throw DemoDataException(true, 'Datos de otro local: ${root['venueId']}');
  }
  try {
    final products = {for (final p in config.ticketProducts) p.id: p};
    final rs = root['reservations']! as Map<String, Object?>;
    final ts = root['tickets']! as Map<String, Object?>;
    final restoredReservations = [
      for (final x in rs['items']! as List) _reservationFrom(x as Map),
    ];
    final restoredTickets = [
      for (final x in ts['tickets']! as List) _ticketFrom(x as Map),
    ];
    final byId = {for (final t in restoredTickets) t.id: t};
    final purchases = [
      for (final x in ts['purchases']! as List)
        _purchaseFrom(x as Map, products),
    ];
    final incidents = [
      for (final x in ts['incidents']! as List) _incidentFrom(x as Map),
    ];
    final results = {
      for (final e in (ts['results']! as Map).entries)
        e.key as String: CheckResult(
          CheckOutcome.values.byName((e.value as Map)['outcome'] as String),
          ticket: byId[(e.value as Map)['ticketId']],
          reason: _enumOrNull(RejectReason.values, (e.value as Map)['reason']),
        ),
    };
    final counters = [
      for (final c in ts['counters']! as List) (c as num).toInt(),
    ];
    // La sección de barra se añadió después sin cambiar el formato: si
    // falta, no había ventas de barra.
    final bs = root['bar'] as Map<String, Object?>?;
    final sales = [
      for (final x in (bs?['sales'] as List?) ?? const []) _saleFrom(x as Map),
    ];
    final acceptances = [
      for (final x in (bs?['acceptances'] as List?) ?? const [])
        _acceptanceFrom(x as Map),
    ];
    // Prepagos registrados: añadidos después; si faltan, no había ninguno.
    final prepaids = [
      for (final x in (bs?['prepaids'] as List?) ?? const [])
        _prepaidFrom(x as Map),
    ];
    // Champaña VIP: añadida después; si falta, no había ninguna botella.
    final champagne = [
      for (final x in (bs?['champagne'] as List?) ?? const [])
        _champagneFrom(x as Map),
    ];
    // Las metas se añadieron después sin cambiar el formato: si faltan, no
    // había metas configuradas.
    final restoredGoals = [
      for (final x in (root['goals'] as List?) ?? const []) _goalFrom(x as Map),
    ];
    for (final g in restoredGoals) {
      if (g.target <= 0 || g.target > GoalBook.maxTarget) {
        throw DemoDataException(false, 'Meta no válida: ${g.target}');
      }
    }
    // Todo validado: ahora sí se aplica.
    reservations.book.importState(
      restoredReservations,
      (rs['sequence']! as num).toInt(),
    );
    reservations.importSeededNights([
      for (final id in rs['seededNights']! as List) _night(id as String),
    ]);
    tickets.book.importState(
      purchases: purchases,
      tickets: restoredTickets,
      incidents: incidents,
      counters: counters,
    );
    tickets.importResults(results);
    bar.book.importState(
      sales: sales,
      acceptances: acceptances,
      prepaids: prepaids,
      champagne: champagne,
      next: ((bs?['next'] as num?) ?? 1).toInt(),
    );
    goals?.book.importState(restoredGoals);
  } on DemoDataException {
    rethrow;
  } catch (e) {
    throw DemoDataException(false, 'Datos dañados: $e');
  }
}

// ------------------------------------------------------------- Reservas

Map<String, Object?> _reservation(Reservation r) => {
  'id': r.id,
  'night': r.night.id,
  'tableId': r.tableId,
  'holder': r.holder == null
      ? null
      : {
          'name': r.holder!.name,
          'idNumber': r.holder!.idNumber,
          'phone': r.holder!.phone,
        },
  'origin': r.origin.name,
  'status': r.status.name,
  'createdBy': r.createdBy,
  'linkedAccountId': r.linkedAccountId,
  if (r.birthday case final b?) 'birthday': _birthday(b),
  'history': [
    for (final e in r.history) {'type': e.type.name, 'at': _time(e.at)},
  ],
};

Reservation _reservationFrom(Map j) {
  final h = j['holder'] as Map?;
  return Reservation(
    id: j['id'] as String,
    night: _night(j['night'] as String),
    tableId: j['tableId'] as String,
    holder: h == null
        ? null
        : ReservationHolder(
            name: h['name'] as String,
            idNumber: h['idNumber'] as String?,
            phone: h['phone'] as String?,
          ),
    origin: ReservationOrigin.values.byName(j['origin'] as String),
    status: ReservationStatus.values.byName(j['status'] as String),
    createdBy: j['createdBy'] as String?,
    linkedAccountId: j['linkedAccountId'] as String?,
    // Añadido después: las reservas guardadas antes no lo tienen.
    birthday: j['birthday'] == null
        ? null
        : _birthdayFrom(j['birthday']! as Map),
    history: [
      for (final e in j['history'] as List)
        ReservationEvent(
          ReservationEventType.values.byName((e as Map)['type'] as String),
          _parseTime(e['at']),
        ),
    ],
  );
}

Map<String, Object?> _stamp(ActorStamp s) => {
  'actorId': s.actorId,
  'at': _time(s.at),
};

ActorStamp _stampFrom(Map j) =>
    ActorStamp(j['actorId'] as String, _parseTime(j['at']));

Map<String, Object?> _terms(BirthdayTerms t) => {
  'conditions': t.conditions,
  'decorationRequired': t.decorationRequired,
  'confirmed': _stamp(t.confirmed),
};

BirthdayTerms _termsFrom(Map t) => BirthdayTerms(
  conditions: t['conditions'] as String,
  decorationRequired: t['decorationRequired'] as bool,
  confirmed: _stampFrom(t['confirmed'] as Map),
);

Map<String, Object?> _birthday(BirthdayCelebration b) => {
  'honoreeName': b.honoreeName,
  'notes': b.notes,
  if (b.terms case final t?) 'terms': _terms(t),
  if (b.decorationPrepared case final d?) 'decorationPrepared': _stamp(d),
  if (b.previous.isNotEmpty)
    'previous': [
      for (final a in b.previous)
        {
          'terms': _terms(a.terms),
          if (a.decorationPrepared case final d?)
            'decorationPrepared': _stamp(d),
        },
    ],
};

BirthdayCelebration _birthdayFrom(Map j) {
  final t = j['terms'] as Map?;
  final d = j['decorationPrepared'] as Map?;
  return BirthdayCelebration(
    honoreeName: j['honoreeName'] as String,
    notes: j['notes'] as String?,
    terms: t == null ? null : _termsFrom(t),
    decorationPrepared: d == null ? null : _stampFrom(d),
    previous: [
      for (final a in (j['previous'] as List?) ?? const [])
        BirthdayAgreement(
          _termsFrom((a as Map)['terms'] as Map),
          a['decorationPrepared'] == null
              ? null
              : _stampFrom(a['decorationPrepared'] as Map),
        ),
    ],
  );
}

// ------------------------------------------------------------- Entradas

Map<String, Object?> _purchase(TicketPurchase p) => {
  'id': p.id,
  'venueId': p.venueId,
  'night': p.night.id,
  'productId': p.product.id,
  'quantity': p.quantity,
  'unitPrice': p.unitPrice,
  'channel': p.channel.name,
  'createdBy': p.createdBy,
  'createdAt': _time(p.createdAt),
  'payment': p.payment.name,
  'paidAt': p.paidAt == null ? null : _time(p.paidAt!),
  'paymentBy': p.paymentBy,
  'holderName': p.holderName,
  if (p.buyerPhone != null) 'buyerPhone': p.buyerPhone,
  if (p.buyerIdNumber != null) 'buyerIdNumber': p.buyerIdNumber,
  'ownerId': p.ownerId,
  'note': p.note,
  if (p.reservationId != null) 'reservationId': p.reservationId,
};

TicketPurchase _purchaseFrom(Map j, Map<String, TicketProduct> products) {
  final product = products[j['productId']];
  if (product == null) {
    throw DemoDataException(true, 'Producto desconocido ${j['productId']}');
  }
  return TicketPurchase(
    id: j['id'] as String,
    venueId: j['venueId'] as String,
    night: _night(j['night'] as String),
    product: product,
    quantity: (j['quantity'] as num).toInt(),
    unitPrice: (j['unitPrice'] as num).toInt(),
    channel: TicketChannel.values.byName(j['channel'] as String),
    createdBy: j['createdBy'] as String,
    createdAt: _parseTime(j['createdAt']),
    payment: PaymentStatus.values.byName(j['payment'] as String),
    paidAt: j['paidAt'] == null ? null : _parseTime(j['paidAt']),
    paymentBy: j['paymentBy'] as String?,
    holderName: j['holderName'] as String?,
    buyerPhone: j['buyerPhone'] as String?,
    buyerIdNumber: j['buyerIdNumber'] as String?,
    ownerId: j['ownerId'] as String?,
    note: j['note'] as String?,
    // Añadido después sin cambiar el formato: si falta, no es de una VIP.
    reservationId: j['reservationId'] as String?,
  );
}

Map<String, Object?> _ticket(Ticket t) => {
  'id': t.id,
  'purchaseId': t.purchaseId,
  'venueId': t.venueId,
  'night': t.night.id,
  'channel': t.channel.name,
  'status': t.status.name,
  'credential': t.credential,
  'retired': [
    for (final r in t.retired)
      {'code': r.code, 'at': _time(r.at), 'reason': r.reason},
  ],
  'ownerId': t.ownerId,
  'holderName': t.holderName,
  'firstEntryAt': t.firstEntryAt == null ? null : _time(t.firstEntryAt!),
  'redeemedAt': t.redeemedAt == null ? null : _time(t.redeemedAt!),
  'redeemPoint': t.redeemPoint?.name,
  'request': t.request == null
      ? null
      : {
          'type': t.request!.type.name,
          'status': t.request!.status.name,
          'requestedAt': _time(t.request!.requestedAt),
          'targetNight': t.request!.targetNight?.id,
        },
  'history': [
    for (final e in t.history)
      {
        'type': e.type.name,
        'at': _time(e.at),
        'actorId': e.actorId,
        'note': e.note,
      },
  ],
};

Ticket _ticketFrom(Map j) {
  final status = TicketStatus.values.byName(j['status'] as String);
  final redeemedAt = j['redeemedAt'] == null
      ? null
      : _parseTime(j['redeemedAt']);
  // Una entrada canjeada sin hora de canje sería ambigua: no se adivina.
  if (status == TicketStatus.redeemed && redeemedAt == null) {
    throw const DemoDataException(false, 'Canje sin hora');
  }
  final r = j['request'] as Map?;
  return Ticket(
    id: j['id'] as String,
    purchaseId: j['purchaseId'] as String,
    venueId: j['venueId'] as String,
    night: _night(j['night'] as String),
    channel: TicketChannel.values.byName(j['channel'] as String),
    status: status,
    credential: j['credential'] as String?,
    retired: [
      for (final x in j['retired'] as List)
        RetiredCredential(
          (x as Map)['code'] as String,
          _parseTime(x['at']),
          x['reason'] as String,
        ),
    ],
    ownerId: j['ownerId'] as String?,
    holderName: j['holderName'] as String?,
    firstEntryAt: j['firstEntryAt'] == null
        ? null
        : _parseTime(j['firstEntryAt']),
    redeemedAt: redeemedAt,
    redeemPoint: _enumOrNull(RedeemPoint.values, j['redeemPoint']),
    request: r == null
        ? null
        : TicketRequest(
            type: TicketRequestType.values.byName(r['type'] as String),
            status: TicketRequestStatus.values.byName(r['status'] as String),
            requestedAt: _parseTime(r['requestedAt']),
            targetNight: r['targetNight'] == null
                ? null
                : _night(r['targetNight'] as String),
          ),
    history: [
      for (final e in j['history'] as List)
        TicketEvent(
          TicketEventType.values.byName((e as Map)['type'] as String),
          _parseTime(e['at']),
          actorId: e['actorId'] as String,
          note: e['note'] as String?,
        ),
    ],
  );
}

Map<String, Object?> _incident(TicketIncident i) => {
  'at': _time(i.at),
  'actorId': i.actorId,
  'point': i.point,
  'code': i.code,
  'reason': i.reason.name,
  'ticketId': i.ticketId,
};

TicketIncident _incidentFrom(Map j) => TicketIncident(
  at: _parseTime(j['at']),
  actorId: j['actorId'] as String,
  point: j['point'] as String,
  code: j['code'] as String,
  reason: RejectReason.values.byName(j['reason'] as String),
  ticketId: j['ticketId'] as String?,
);

// ---------------------------------------------------------------- Barra

Map<String, Object?> _line(SaleLine l) => {
  'itemId': l.itemId,
  'name': l.name,
  'unitPrice': l.unitPrice,
  'quantity': l.quantity,
};

SaleLine _lineFrom(Map j) => SaleLine(
  itemId: j['itemId'] as String,
  name: j['name'] as String,
  unitPrice: (j['unitPrice'] as num).toInt(),
  quantity: (j['quantity'] as num).toInt(),
);

Map<String, Object?> _sale(BarSale s) => {
  'id': s.id,
  'venueId': s.venueId,
  'night': s.night.id,
  'lines': [for (final l in s.lines) _line(l)],
  'registeredBy': s.registeredBy,
  'registeredAt': _time(s.registeredAt),
  'status': s.status.name,
  'reservationId': s.reservationId,
  'tableId': s.tableId,
  'accountId': s.accountId,
  if (s.customer case final c?)
    'customer': {
      if (c.name != null) 'name': c.name,
      if (c.phone != null) 'phone': c.phone,
      if (c.idNumber != null) 'idNumber': c.idNumber,
    },
  if (s.prepaidApplied > 0) 'prepaidApplied': s.prepaidApplied,
  'corrections': [
    for (final c in s.corrections)
      {
        'kind': c.kind.name,
        'at': _time(c.at),
        'actorId': c.actorId,
        'reason': c.reason,
        'previousLines': [for (final l in c.previousLines) _line(l)],
      },
  ],
};

BarSale _saleFrom(Map j) => BarSale(
  id: j['id'] as String,
  venueId: j['venueId'] as String,
  night: _night(j['night'] as String),
  lines: [for (final l in j['lines'] as List) _lineFrom(l as Map)],
  registeredBy: j['registeredBy'] as String,
  registeredAt: _parseTime(j['registeredAt']),
  status: BarSaleStatus.values.byName(j['status'] as String),
  reservationId: j['reservationId'] as String?,
  tableId: j['tableId'] as String?,
  accountId: j['accountId'] as String?,
  customer: j['customer'] is Map
      ? UnverifiedCustomer(
          name: (j['customer'] as Map)['name'] as String?,
          phone: (j['customer'] as Map)['phone'] as String?,
          idNumber: (j['customer'] as Map)['idNumber'] as String?,
        )
      : null,
  prepaidApplied: ((j['prepaidApplied'] as num?) ?? 0).toInt(),
  corrections: [
    for (final c in j['corrections'] as List)
      BarCorrection(
        kind: CorrectionKind.values.byName((c as Map)['kind'] as String),
        at: _parseTime(c['at']),
        actorId: c['actorId'] as String,
        reason: c['reason'] as String,
        previousLines: [
          for (final l in c['previousLines'] as List) _lineFrom(l as Map),
        ],
      ),
  ],
);

Map<String, Object?> _prepaid(VipPrepaid p) => {
  'reservationId': p.reservationId,
  'tableId': p.tableId,
  'night': p.night.id,
  'amount': p.amount,
  'registeredBy': p.registeredBy,
  'registeredAt': _time(p.registeredAt),
};

VipPrepaid _prepaidFrom(Map j) => VipPrepaid(
  reservationId: j['reservationId'] as String,
  tableId: j['tableId'] as String,
  night: _night(j['night'] as String),
  amount: (j['amount'] as num).toInt(),
  registeredBy: j['registeredBy'] as String,
  registeredAt: _parseTime(j['registeredAt']),
);

Map<String, Object?> _champagne(ChampagneRelease c) => {
  'reservationId': c.reservationId,
  'tableId': c.tableId,
  'venueId': c.venueId,
  'night': c.night.id,
  'requestedBy': c.requestedBy,
  'requestedAt': _time(c.requestedAt),
  'dispatchedBy': c.dispatchedBy,
  'dispatchedAt': c.dispatchedAt == null ? null : _time(c.dispatchedAt!),
  'deliveredBy': c.deliveredBy,
  'deliveredAt': c.deliveredAt == null ? null : _time(c.deliveredAt!),
};

ChampagneRelease _champagneFrom(Map j) => ChampagneRelease(
  reservationId: j['reservationId'] as String,
  tableId: j['tableId'] as String,
  venueId: j['venueId'] as String,
  night: _night(j['night'] as String),
  requestedBy: j['requestedBy'] as String,
  requestedAt: _parseTime(j['requestedAt']),
  dispatchedBy: j['dispatchedBy'] as String?,
  dispatchedAt: j['dispatchedAt'] == null
      ? null
      : _parseTime(j['dispatchedAt']),
  deliveredBy: j['deliveredBy'] as String?,
  deliveredAt: j['deliveredAt'] == null ? null : _parseTime(j['deliveredAt']),
);

Map<String, Object?> _acceptance(ConsumptionAcceptance a) => {
  'reservationId': a.reservationId,
  'tableId': a.tableId,
  'night': a.night.id,
  'acceptedBy': a.acceptedBy,
  'at': _time(a.at),
  'saleIds': a.saleIds,
  'totalSeen': a.totalSeen,
  'note': a.note,
};

ConsumptionAcceptance _acceptanceFrom(Map j) => ConsumptionAcceptance(
  reservationId: j['reservationId'] as String,
  tableId: j['tableId'] as String,
  night: _night(j['night'] as String),
  acceptedBy: j['acceptedBy'] as String,
  at: _parseTime(j['at']),
  saleIds: [for (final s in j['saleIds'] as List) s as String],
  totalSeen: (j['totalSeen'] as num).toInt(),
  note: j['note'] as String?,
);

// ---------------------------------------------------------------- Metas

Map<String, Object?> _goal(NightGoal g) => {
  'night': g.night.id,
  'metric': g.metric.name,
  'target': g.target,
  'setBy': g.setBy,
  'setAt': _time(g.setAt),
};

NightGoal _goalFrom(Map j) => NightGoal(
  night: _night(j['night'] as String),
  metric: GoalMetric.values.byName(j['metric'] as String),
  target: (j['target'] as num).toInt(),
  setBy: j['setBy'] as String,
  setAt: _parseTime(j['setAt']),
);

// -------------------------------------------------------------- Comunes

String _time(DateTime t) => t.toUtc().toIso8601String();

DateTime _parseTime(Object? v) => DateTime.parse(v! as String).toUtc();

Night _night(String id) {
  final d = DateTime.parse(id);
  return Night(DateTime.utc(d.year, d.month, d.day));
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? name) =>
    name == null ? null : values.byName(name as String);

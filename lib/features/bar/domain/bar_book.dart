import '../../reservations/domain/night_schedule.dart';
import '../../reservations/domain/venue_table.dart';
import 'bar.dart';

/// Registro de ventas de barra de un local, en memoria y con reloj
/// inyectable.
///
/// Reglas de la demo:
/// - Barra registra la venta solo tras confirmar el pago presencial
///   completo. La app no cobra.
/// - Caja y administración corrigen (ajustar o anular) con un motivo; queda
///   lo que había antes.
/// - El mesero acepta el consumo de una reserva a mano. Nada se declara
///   cumplido por sumar importes.
///
/// No conoce roles: la vista decide quién llama a cada operación. No hay
/// inventario, tienda de licor, beneficios ni puntos.
class BarBook {
  BarBook({required this.venue, required this.menu, Clock clock = systemClock})
    : _clock = clock;

  /// Local con sus mesas reales: decide si un destino es VIP.
  final Venue venue;
  String get venueId => venue.id;
  final List<MenuItem> menu;
  final Clock _clock;

  final _sales = <String, BarSale>{};
  final _prepaids = <String, VipPrepaid>{};
  final _acceptances = <String, ConsumptionAcceptance>{};
  int _next = 1;

  DateTime get _now => _clock();

  List<BarSale> get sales => _sales.values.toList();
  List<ConsumptionAcceptance> get acceptances => _acceptances.values.toList();
  BarSale? saleById(String id) => _sales[id];

  List<BarSale> salesForReservation(String reservationId) => [
    for (final s in _sales.values)
      if (s.reservationId == reservationId) s,
  ];

  List<BarSale> salesOfAccount(String accountId) => [
    for (final s in _sales.values)
      if (s.accountId == accountId) s,
  ];

  VipPrepaid? prepaidOf(String reservationId) => _prepaids[reservationId];

  List<VipPrepaid> get prepaids => _prepaids.values.toList();

  /// Saldo del prepago de la reserva, o `null` si no está registrado.
  VipPrepaidBalance? balanceOf(String reservationId) {
    final p = _prepaids[reservationId];
    if (p == null) return null;
    var consumed = 0, charged = 0;
    for (final s in salesForReservation(reservationId)) {
      if (s.status == BarSaleStatus.voided) continue;
      consumed += s.prepaidApplied;
      charged += s.charged;
    }
    return VipPrepaidBalance(p, consumed, charged);
  }

  /// La administración registra el prepago de consumo de una reserva VIP,
  /// tras verificarlo. Uno por reserva; la mesa debe ser VIP del local.
  VipPrepaid registerPrepaid({
    required String reservationId,
    required String tableId,
    required Night night,
    required int amount,
    required String actorId,
  }) {
    if (venue.tableById(tableId)?.isVip != true) {
      throw const BarException(BarError.invalidDestination);
    }
    if (amount <= 0) throw const BarException(BarError.invalidAmount);
    if (_prepaids.containsKey(reservationId)) {
      throw const BarException(BarError.prepaidAlreadyRegistered);
    }
    return _prepaids[reservationId] = VipPrepaid(
      reservationId: reservationId,
      tableId: tableId,
      night: night,
      amount: amount,
      registeredBy: actorId,
      registeredAt: _now,
    );
  }

  ConsumptionAcceptance? acceptanceFor(String reservationId) =>
      _acceptances[reservationId];

  /// La noche ya terminó, según el reloj del libro (el saldo de su
  /// prepago no consumido se perdió).
  bool hasEnded(Night night) => night.hasEnded(VenueTime.of(_now));

  /// La noche en curso, si la hay.
  Night? get currentNight {
    final now = VenueTime.of(_now);
    for (final n in NightSchedule.weekendNights(now)) {
      if (n.isInProgress(now)) return n;
    }
    return null;
  }

  /// Barra registra una compra YA pagada en persona. Sin la confirmación
  /// del pago completo no se registra nada.
  BarSale register({
    required Map<String, int> quantities,
    required bool paidInFull,
    required String actorId,
    String? reservationId,
    String? tableId,
    String? accountId,
  }) {
    final night = currentNight;
    if (night == null) throw const BarException(BarError.outsideNight);
    // Destino resuelto con las mesas del local: reserva y mesa van juntas y
    // la mesa existe.
    if ((reservationId == null) != (tableId == null)) {
      throw const BarException(BarError.invalidDestination);
    }
    var applied = 0;
    final lines = _lines(quantities);
    final total = lines.fold(0, (t, l) => t + l.total);
    if (tableId != null) {
      final table = venue.tableById(tableId);
      if (table == null) throw const BarException(BarError.invalidDestination);
      if (table.isVip) {
        // Mesa VIP: se consume contra su prepago registrado; solo se cobra
        // el excedente, nunca otra vez el prepago.
        final balance = balanceOf(reservationId!);
        if (balance == null) {
          throw const BarException(BarError.vipPrepaidPending);
        }
        if (balance.prepaid.tableId != tableId ||
            balance.prepaid.night != night) {
          throw const BarException(BarError.invalidDestination);
        }
        applied = balance.remaining.clamp(0, total);
      }
    }
    // Lo que no cubre el prepago se cobra en persona, completo.
    if (total - applied > 0 && !paidInFull) {
      throw const BarException(BarError.paymentNotConfirmed);
    }
    final id = 'P${_next++}';
    return _sales[id] = BarSale(
      id: id,
      venueId: venueId,
      night: night,
      lines: lines,
      registeredBy: actorId,
      registeredAt: _now,
      status: BarSaleStatus.active,
      reservationId: reservationId,
      tableId: tableId,
      accountId: accountId,
      prepaidApplied: applied,
    );
  }

  /// Caja o administración quitan unidades de una venta, con motivo. Subir
  /// una cantidad o añadir un producto se rechaza sin cambiar nada: lo que
  /// se vende de más es una venta nueva de barra, tras su pago.
  BarSale adjust(
    String id, {
    required Map<String, int> quantities,
    required String actorId,
    required String reason,
  }) {
    final s = _active(id);
    if (reason.trim().isEmpty) {
      throw const BarException(BarError.missingReason);
    }
    final before = {for (final l in s.lines) l.itemId: l.quantity};
    for (final MapEntry(key: item, value: q) in quantities.entries) {
      if (q > (before[item] ?? 0)) {
        throw const BarException(BarError.onlyRemoveUnits);
      }
    }
    final lines = _lines(quantities);
    return _sales[id] = s.corrected(
      lines: lines,
      status: BarSaleStatus.active,
      correction: BarCorrection(
        kind: CorrectionKind.adjusted,
        at: _now,
        actorId: actorId,
        reason: reason.trim(),
        previousLines: s.lines,
      ),
    );
  }

  /// Caja o administración anulan una venta, con motivo. La venta y su
  /// historial se conservan.
  BarSale voidSale(
    String id, {
    required String actorId,
    required String reason,
  }) {
    final s = _active(id);
    if (reason.trim().isEmpty) {
      throw const BarException(BarError.missingReason);
    }
    return _sales[id] = s.corrected(
      lines: s.lines,
      status: BarSaleStatus.voided,
      correction: BarCorrection(
        kind: CorrectionKind.voided,
        at: _now,
        actorId: actorId,
        reason: reason.trim(),
        previousLines: s.lines,
      ),
    );
  }

  /// El mesero acepta el consumo de una reserva tras consultar barra. Se
  /// guarda lo que vio. Una sola aceptación por reserva.
  ConsumptionAcceptance acceptConsumption({
    required String reservationId,
    required String tableId,
    required Night night,
    required String actorId,
    String? note,
  }) {
    if (_acceptances.containsKey(reservationId)) {
      throw const BarException(BarError.alreadyAccepted);
    }
    final sales = salesForReservation(
      reservationId,
    ).where((s) => s.status == BarSaleStatus.active).toList();
    return _acceptances[reservationId] = ConsumptionAcceptance(
      reservationId: reservationId,
      tableId: tableId,
      night: night,
      acceptedBy: actorId,
      at: _now,
      saleIds: [for (final s in sales) s.id],
      totalSeen: sales.fold(0, (t, s) => t + s.total),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    );
  }

  // ------------------------------------------------ Persistencia local

  ({
    List<BarSale> sales,
    List<ConsumptionAcceptance> acceptances,
    List<VipPrepaid> prepaids,
    int next,
  })
  exportState() =>
      (sales: sales, acceptances: acceptances, prepaids: prepaids, next: _next);

  void importState({
    required List<BarSale> sales,
    required List<ConsumptionAcceptance> acceptances,
    List<VipPrepaid> prepaids = const [],
    required int next,
  }) {
    for (final p in prepaids) {
      _prepaids[p.reservationId] = p;
    }
    if (_sales.isNotEmpty || _acceptances.isNotEmpty) {
      throw StateError('Solo se restaura en un libro vacío');
    }
    for (final s in sales) {
      _sales[s.id] = s;
    }
    for (final a in acceptances) {
      _acceptances[a.reservationId] = a;
    }
    _next = next;
  }

  // ------------------------------------------------------------ Interno

  BarSale _active(String id) {
    final s = _sales[id];
    if (s == null) throw const BarException(BarError.notFound);
    if (s.status == BarSaleStatus.voided) {
      throw const BarException(BarError.alreadyVoided);
    }
    // Qué pasa con el prepago y el excedente al corregir: no definido.
    if (s.prepaidApplied > 0 ||
        (s.tableId != null && venue.tableById(s.tableId!)?.isVip == true)) {
      throw const BarException(BarError.vipCorrectionUndecided);
    }
    return s;
  }

  List<SaleLine> _lines(Map<String, int> quantities) {
    final lines = <SaleLine>[];
    for (final MapEntry(key: id, value: q) in quantities.entries) {
      if (q <= 0) continue;
      final item = menu.where((m) => m.id == id).firstOrNull;
      if (item == null) throw const BarException(BarError.unknownItem);
      lines.add(
        SaleLine(
          itemId: id,
          name: item.name,
          unitPrice: item.demoPrice,
          quantity: q,
        ),
      );
    }
    if (lines.isEmpty) throw const BarException(BarError.emptySale);
    return lines;
  }
}

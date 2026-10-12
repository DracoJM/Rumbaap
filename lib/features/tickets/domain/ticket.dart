import '../../reservations/domain/night_schedule.dart';

/// Circuito por el que nace y se canjea una entrada.
///
/// - [app]: compra del cliente en la app; la manilla la entrega taquilla.
/// - [promoter]: venta del promotor; la manilla sale de su lote físico.
///   Activar la credencial no traslada esa custodia a taquilla.
/// - [courtesy]: cortesía autorizada por la administración (por ejemplo,
///   de una mesa VIP); no exige pago y se canjea en taquilla.
enum TicketChannel { app, promoter, courtesy }

/// Estado de pago de una compra. Todo pago es SIMULADO en este prototipo:
/// no se cobra ni se devuelve dinero. `NOT DECIDED: proveedor de pagos`.
enum PaymentStatus {
  /// Venta creada; el derecho aún no está activo.
  pending,

  /// Cliente en la app: pago simulado.
  paidSimulated,

  /// Promotor: declara el pago comprobado de su venta.
  verifiedByPromoter,

  /// Cortesía autorizada: sin pago.
  courtesy,
}

/// Derecho de una entrada. Venta, pago, primer ingreso y canje (manilla)
/// son pasos distintos; el primer ingreso y el canje se registran aparte.
enum TicketStatus {
  /// Vendida sin pago: no da derecho y no tiene credencial.
  pendingPayment,

  /// Derecho activo. Puede tener primer ingreso registrado y seguir
  /// pendiente de canje.
  active,

  /// Canjeada por manilla: «No canjeable». El reingreso es con la manilla.
  redeemed,

  /// Anulada por una devolución autorizada.
  voided,
}

/// Dónde se entregó la manilla del canje.
enum RedeemPoint { boxOffice, promoterLot }

enum TicketEventType {
  sold,
  paymentSimulated,
  paymentVerified,
  courtesyAuthorized,
  credentialIssued,
  credentialRetired,
  doorChecked,
  firstEntryRecorded,
  redeemed,
  rejected,
  refundRequested,
  changeRequested,
  requestRejected,
  refundAuthorized,
  refundRecorded,
  nightChanged,
}

/// Cambio del historial de una entrada. [actorId] es la identidad que hizo
/// la operación en la demo (nunca se deduce después).
class TicketEvent {
  const TicketEvent(this.type, this.at, {required this.actorId, this.note});

  final TicketEventType type;
  final DateTime at;
  final String actorId;
  final String? note;
}

/// Entrada a la venta con precio de DEMOSTRACIÓN por noche. No es política
/// del local.
class TicketProduct {
  const TicketProduct({
    required this.id,
    required this.name,
    required this.demoPriceByWeekday,
  });

  final String id;
  final String name;

  /// Precio ficticio en COP según el día de la noche
  /// ([DateTime.friday]…). `NOT DECIDED: precios y eventos reales`.
  final Map<int, int> demoPriceByWeekday;

  int? demoPriceFor(Night night) => demoPriceByWeekday[night.date.weekday];
}

/// Compra (cliente), venta (promotor) o cortesía (administración).
class TicketPurchase {
  const TicketPurchase({
    required this.id,
    required this.venueId,
    required this.night,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.channel,
    required this.createdBy,
    required this.createdAt,
    required this.payment,
    this.paidAt,
    this.paymentBy,
    this.holderName,
    this.ownerId,
    this.note,
    this.reservationId,
  });

  final String id;
  final String venueId;
  final Night night;
  final TicketProduct product;
  final int quantity;

  /// Precio unitario de demostración fijado al vender (0 en cortesía).
  final int unitPrice;
  final TicketChannel channel;

  /// Identidad que hizo la compra, la venta o autorizó la cortesía.
  final String createdBy;

  /// Cuenta ficticia dueña de las entradas, si la hay.
  final String? ownerId;

  /// Nombre del comprador (venta del promotor o cortesía).
  final String? holderName;

  /// Motivo de una cortesía (por ejemplo, la reserva VIP).
  final String? note;

  /// Cortesía emitida como beneficio de esta reserva VIP. Así se cuentan
  /// contra su derecho sin contar dos veces ni mezclarla con otras
  /// cortesías.
  final String? reservationId;
  final DateTime createdAt;
  final PaymentStatus payment;
  final DateTime? paidAt;
  final String? paymentBy;

  int get total => unitPrice * quantity;

  TicketPurchase withPayment(PaymentStatus p, DateTime at, String actor) =>
      TicketPurchase(
        id: id,
        venueId: venueId,
        night: night,
        product: product,
        quantity: quantity,
        unitPrice: unitPrice,
        channel: channel,
        createdBy: createdBy,
        createdAt: createdAt,
        payment: p,
        paidAt: at,
        paymentBy: actor,
        holderName: holderName,
        ownerId: ownerId,
        note: note,
        reservationId: reservationId,
      );
}

/// Credencial retirada: no se recicla nunca y se conserva para trazar
/// lecturas posteriores.
class RetiredCredential {
  const RetiredCredential(this.code, this.at, this.reason);

  final String code;
  final DateTime at;
  final String reason;
}

enum TicketRequestType { refund, changeNight }

enum TicketRequestStatus {
  requested,
  authorized,
  rejected,

  /// Devolución autorizada y registrada como hecha fuera de la app.
  refundRecorded,
}

class TicketRequest {
  const TicketRequest({
    required this.type,
    required this.status,
    required this.requestedAt,
    this.targetNight,
  });

  final TicketRequestType type;
  final TicketRequestStatus status;
  final DateTime requestedAt;
  final Night? targetNight;

  TicketRequest withStatus(TicketRequestStatus s) => TicketRequest(
    type: type,
    status: s,
    requestedAt: requestedAt,
    targetNight: targetNight,
  );
}

/// Entrada digital: un derecho por persona, con su propia credencial (lo
/// que mostraría el QR). La credencial es una referencia opaca: no lleva
/// nombre, cédula ni estado; la puerta los consulta en el registro.
class Ticket {
  const Ticket({
    required this.id,
    required this.purchaseId,
    required this.venueId,
    required this.night,
    required this.channel,
    required this.status,
    required this.history,
    this.credential,
    this.retired = const [],
    this.ownerId,
    this.holderName,
    this.firstEntryAt,
    this.redeemedAt,
    this.redeemPoint,
    this.request,
  });

  final String id;
  final String purchaseId;
  final String venueId;
  final Night night;
  final TicketChannel channel;
  final TicketStatus status;

  /// Credencial vigente; `null` sin pago o tras anularse.
  final String? credential;
  final List<RetiredCredential> retired;
  final String? ownerId;
  final String? holderName;

  /// Primer ingreso confirmado por la puerta (una sola vez).
  final DateTime? firstEntryAt;

  /// Canje por manilla (una sola vez).
  final DateTime? redeemedAt;
  final RedeemPoint? redeemPoint;
  final TicketRequest? request;
  final List<TicketEvent> history;

  bool get hasOpenRequest => request?.status == TicketRequestStatus.requested;

  Ticket copyWith({
    TicketStatus? status,
    Night? night,
    String? credential,
    bool clearCredential = false,
    List<RetiredCredential>? retired,
    DateTime? firstEntryAt,
    DateTime? redeemedAt,
    RedeemPoint? redeemPoint,
    TicketRequest? request,
    TicketEvent? event,
  }) => Ticket(
    id: id,
    purchaseId: purchaseId,
    venueId: venueId,
    night: night ?? this.night,
    channel: channel,
    status: status ?? this.status,
    credential: clearCredential ? null : (credential ?? this.credential),
    retired: retired ?? this.retired,
    ownerId: ownerId,
    holderName: holderName,
    firstEntryAt: firstEntryAt ?? this.firstEntryAt,
    redeemedAt: redeemedAt ?? this.redeemedAt,
    redeemPoint: redeemPoint ?? this.redeemPoint,
    request: request ?? this.request,
    history: [...history, ?event],
  );
}

enum TicketError {
  nightEnded,
  noPrice,
  invalidQuantity,
  invalidHolder,
  notFound,
  wrongChannel,
  alreadyPaid,
  notEligible,
  sameNight,
  noOpenRequest,
}

class TicketException implements Exception {
  const TicketException(this.error);

  final TicketError error;

  @override
  String toString() => 'TicketException($error)';
}

/// Motivo por el que una lectura no da paso. Una lectura rechazada nunca
/// cambia el derecho: una entrada válida para otra noche o local sigue
/// válida en su contexto.
enum RejectReason {
  notFound,
  retiredCredential,
  otherVenue,
  otherNight,
  outsideNight,
  unpaid,
  voided,
  redeemed,
  wrongCircuit,
}

/// Resultado de consultar o registrar en la puerta o en taquilla.
enum CheckOutcome {
  /// Consulta de puerta: derecho vigente, sin primer ingreso.
  validNoEntry,

  /// Derecho vigente con el primer ingreso ya registrado: la puerta no
  /// registra otro, pero taquilla aún puede canjear.
  entryAlreadyRecorded,

  /// Primer ingreso registrado ahora.
  entryRecorded,

  /// Canje registrado ahora: manilla entregada.
  redeemedNow,

  rejected,
}

class CheckResult {
  const CheckResult(this.outcome, {this.ticket, this.reason});

  final CheckOutcome outcome;
  final Ticket? ticket;
  final RejectReason? reason;

  bool get ok => outcome != CheckOutcome.rejected;
}

/// Por qué una credencial leída en barra no identifica una cuenta.
enum AccountLookupError {
  notFound,
  otherVenue,
  retiredCredential,
  voided,
  otherNight,
  outsideNight,

  /// La entrada existe pero no pertenece a una cuenta (venta del promotor o
  /// cortesía): se identifica a mano o la venta queda sin comprobante.
  noAccount,
}

/// Resultado de identificar en barra al dueño de una entrada. Solo
/// identifica: no da ni cambia derechos.
class AccountLookup {
  const AccountLookup.identified(String this.accountId, Ticket this.ticket)
    : error = null;
  const AccountLookup.failed(AccountLookupError this.error, {this.ticket})
    : accountId = null;

  final String? accountId;
  final Ticket? ticket;
  final AccountLookupError? error;

  bool get ok => accountId != null;
}

/// Lectura rechazada (incidencia), con su motivo, hora y actor. Si la
/// credencial corresponde a una entrada, también va a su historial.
class TicketIncident {
  const TicketIncident({
    required this.at,
    required this.actorId,
    required this.point,
    required this.code,
    required this.reason,
    this.ticketId,
  });

  final DateTime at;
  final String actorId;

  /// «Puerta» o «Taquilla».
  final String point;
  final String code;
  final RejectReason reason;
  final String? ticketId;
}

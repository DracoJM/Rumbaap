import '../../reservations/domain/night_schedule.dart';

/// Canal por el que se vendió una entrada. La manilla de las compras en la
/// app la entrega Caja; las ventas del promotor siguen su propio circuito.
enum TicketChannel { app, promoter }

/// Estado de pago de una compra. El pago es SIMULADO en este prototipo: no
/// se cobra dinero. `NOT DECIDED: proveedor de pagos`.
enum PaymentStatus { pending, paidSimulated }

/// Estado de una entrada digital. El pago, la validación de acceso y la
/// entrega de la manilla son pasos distintos.
enum TicketStatus {
  /// La compra aún no se pagó: la entrada no da acceso.
  pendingPayment,

  /// Pagada (simulado) y sin usar.
  valid,

  /// Seguridad validó el acceso. El reingreso se hace con la manilla
  /// física, sin volver a leer la entrada.
  admitted,

  /// Anulada por una devolución autorizada.
  voided,
}

enum TicketEventType {
  purchased,
  paid,
  admitted,
  wristbandDelivered,
  refundRequested,
  changeRequested,
  requestRejected,
  refundAuthorized,
  refundRecorded,
  nightChanged,
}

class TicketEvent {
  const TicketEvent(this.type, this.at, {this.note});

  final TicketEventType type;
  final DateTime at;
  final String? note;
}

/// Producto de entrada con precio de DEMOSTRACIÓN: no es política del local.
class TicketProduct {
  const TicketProduct({
    required this.id,
    required this.name,
    required this.demoPrice,
  });

  final String id;
  final String name;

  /// Precio ficticio en COP, solo para recorrer la demo.
  final int demoPrice;
}

/// Compra de una o varias entradas para una noche.
class TicketPurchase {
  const TicketPurchase({
    required this.id,
    required this.venueId,
    required this.night,
    required this.product,
    required this.quantity,
    required this.channel,
    required this.createdBy,
    required this.createdAt,
    required this.payment,
    this.paidAt,
    this.holderName,
    this.ownerId,
  });

  final String id;
  final String venueId;
  final Night night;
  final TicketProduct product;
  final int quantity;
  final TicketChannel channel;

  /// Identidad que hizo la compra (cliente) o la venta (promotor).
  final String createdBy;

  /// Cuenta del cliente dueña de las entradas, si la hay.
  final String? ownerId;

  /// Nombre del comprador en una venta del promotor.
  final String? holderName;
  final DateTime createdAt;
  final PaymentStatus payment;
  final DateTime? paidAt;

  int get total => product.demoPrice * quantity;

  TicketPurchase paid(DateTime at) => TicketPurchase(
    id: id,
    venueId: venueId,
    night: night,
    product: product,
    quantity: quantity,
    channel: channel,
    createdBy: createdBy,
    createdAt: createdAt,
    payment: PaymentStatus.paidSimulated,
    paidAt: at,
    holderName: holderName,
    ownerId: ownerId,
  );
}

/// Solicitud sobre una entrada sin usar. Autorizar una devolución no mueve
/// dinero: el dinero devuelto se registra aparte, cuando ocurre fuera de la
/// app.
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

/// Entrada digital: una por persona, con su propio código. No es el QR
/// personal de la cuenta (que solo identifica, sin pago ni edad).
class Ticket {
  const Ticket({
    required this.id,
    required this.code,
    required this.purchaseId,
    required this.venueId,
    required this.night,
    required this.channel,
    required this.status,
    required this.history,
    this.ownerId,
    this.admittedAt,
    this.wristbandAt,
    this.request,
  });

  final String id;

  /// Código de la entrada (se mostraría como QR). Incluye el local.
  final String code;
  final String purchaseId;
  final String venueId;
  final Night night;
  final TicketChannel channel;
  final String? ownerId;
  final TicketStatus status;
  final DateTime? admittedAt;

  /// Entrega de la manilla física (no nominativa). Una por entrada.
  final DateTime? wristbandAt;
  final TicketRequest? request;
  final List<TicketEvent> history;

  bool get hasOpenRequest => request?.status == TicketRequestStatus.requested;

  Ticket copyWith({
    TicketStatus? status,
    Night? night,
    DateTime? admittedAt,
    DateTime? wristbandAt,
    TicketRequest? request,
    bool clearRequest = false,
    TicketEvent? event,
  }) => Ticket(
    id: id,
    code: code,
    purchaseId: purchaseId,
    venueId: venueId,
    night: night ?? this.night,
    channel: channel,
    ownerId: ownerId,
    status: status ?? this.status,
    admittedAt: admittedAt ?? this.admittedAt,
    wristbandAt: wristbandAt ?? this.wristbandAt,
    request: clearRequest ? null : (request ?? this.request),
    history: [...history, ?event],
  );
}

enum TicketError {
  nightEnded,
  invalidQuantity,
  invalidHolder,
  notFound,
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

/// Resultado de leer una entrada en el acceso. Repetir la lectura nunca
/// duplica el acceso.
enum AccessResult {
  admitted,
  alreadyAdmitted,
  notFound,
  otherVenue,
  otherNight,
  outsideNight,
  unpaid,
  voided,
}

/// Resultado de entregar la manilla. Repetirlo nunca entrega una segunda.
enum WristbandResult {
  delivered,
  alreadyDelivered,
  notFound,
  notAdmitted,
  promoterCircuit,
  voided,
}

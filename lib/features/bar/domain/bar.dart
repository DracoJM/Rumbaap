import '../../reservations/domain/night_schedule.dart';

/// Producto del menú INFORMATIVO de la demo, con precio de DEMOSTRACIÓN.
/// El cliente lo consulta; no se compra ni se paga en la app.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.demoPrice,
  });

  final String id;
  final String name;
  final String category;

  /// Precio ficticio en COP. `NOT DECIDED: carta y precios reales`.
  final int demoPrice;
}

/// Línea de una venta de barra: copia nombre y precio del momento.
class SaleLine {
  const SaleLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String itemId;
  final String name;
  final int unitPrice;
  final int quantity;

  int get total => unitPrice * quantity;
}

enum BarSaleStatus { active, voided }

enum CorrectionKind { adjusted, voided }

/// Corrección trazable de una venta: quién, cuándo, por qué y qué había.
class BarCorrection {
  const BarCorrection({
    required this.kind,
    required this.at,
    required this.actorId,
    required this.reason,
    required this.previousLines,
  });

  final CorrectionKind kind;
  final DateTime at;
  final String actorId;
  final String reason;
  final List<SaleLine> previousLines;

  int get previousTotal => previousLines.fold(0, (s, l) => s + l.total);
}

/// Compra registrada por barra DESPUÉS de recibir el pago presencial
/// completo (simulado: no se cobra en la app). Puede vincularse a una
/// reserva de la noche y a la cuenta del cliente identificada por el QR de su
/// entrada.
class BarSale {
  const BarSale({
    required this.id,
    required this.venueId,
    required this.night,
    required this.lines,
    required this.registeredBy,
    required this.registeredAt,
    required this.status,
    this.reservationId,
    this.tableId,
    this.accountId,
    this.corrections = const [],
    this.prepaidApplied = 0,
  });

  final String id;
  final String venueId;
  final Night night;
  final List<SaleLine> lines;

  /// Parte del importe cubierta por el prepago de la mesa VIP (0 si no).
  final int prepaidApplied;
  final String registeredBy;
  final DateTime registeredAt;
  final BarSaleStatus status;
  final String? reservationId;
  final String? tableId;
  final String? accountId;
  final List<BarCorrection> corrections;

  /// Importe vigente: 0 si se anuló.
  int get total =>
      status == BarSaleStatus.voided ? 0 : lines.fold(0, (s, l) => s + l.total);

  /// Dinero cobrado en barra (pago presencial): el importe menos lo cubierto
  /// por el prepago. El consumo contra prepago no es dinero de esta venta.
  int get charged =>
      status == BarSaleStatus.voided ? 0 : total - prepaidApplied;

  BarSale corrected({
    required List<SaleLine> lines,
    required BarSaleStatus status,
    required BarCorrection correction,
  }) => BarSale(
    id: id,
    venueId: venueId,
    night: night,
    lines: lines,
    registeredBy: registeredBy,
    registeredAt: registeredAt,
    status: status,
    reservationId: reservationId,
    tableId: tableId,
    accountId: accountId,
    corrections: [...corrections, correction],
    prepaidApplied: prepaidApplied,
  );
}

/// Prepago de consumo de una reserva VIP, registrado EXPRESAMENTE por la
/// administración. Nunca se deduce de prepagos anteriores.
class VipPrepaid {
  const VipPrepaid({
    required this.reservationId,
    required this.tableId,
    required this.night,
    required this.amount,
    required this.registeredBy,
    required this.registeredAt,
  });

  final String reservationId;
  final String tableId;
  final Night night;
  final int amount;
  final String registeredBy;
  final DateTime registeredAt;
}

/// Saldo del prepago de una reserva: lo consumido sale de sus ventas.
class VipPrepaidBalance {
  const VipPrepaidBalance(this.prepaid, this.consumed, this.charged);

  final VipPrepaid prepaid;

  /// Consumo cubierto por el prepago.
  final int consumed;

  /// Excedente cobrado en barra por encima del prepago.
  final int charged;

  int get remaining => prepaid.amount - consumed;

  /// El saldo sin consumir se pierde al terminar la noche.
  bool lostAt(DateTime venueNow) => prepaid.night.hasEnded(venueNow);
}

/// Aceptación HUMANA del consumo de una reserva por el mesero, tras
/// consultar las ventas de barra. No es automática por sumar importes.
class ConsumptionAcceptance {
  const ConsumptionAcceptance({
    required this.reservationId,
    required this.tableId,
    required this.night,
    required this.acceptedBy,
    required this.at,
    required this.saleIds,
    required this.totalSeen,
    this.note,
  });

  final String reservationId;
  final String tableId;
  final Night night;
  final String acceptedBy;
  final DateTime at;

  /// Ventas y suma que el mesero vio al aceptar.
  final List<String> saleIds;
  final int totalSeen;
  final String? note;
}

enum BarError {
  outsideNight,
  emptySale,
  paymentNotConfirmed,
  unknownItem,
  notFound,
  alreadyVoided,
  missingReason,
  alreadyAccepted,

  /// Una corrección solo quita unidades: no sube cantidades ni añade
  /// productos.
  onlyRemoveUnits,

  /// Reserva y mesa no casan, o la mesa no existe en el local.
  invalidDestination,

  /// Mesa VIP sin prepago registrado por la administración: no se puede
  /// consumir contra él ni cobrarlo como otro pago completo.
  vipPrepaidPending,

  /// El prepago de esa reserva ya está registrado (uno por reserva).
  prepaidAlreadyRegistered,

  /// Importe de prepago no válido.
  invalidAmount,

  /// Corregir o anular una venta contra prepago: no definido.
  vipCorrectionUndecided,
}

class BarException implements Exception {
  const BarException(this.error);

  final BarError error;

  @override
  String toString() => 'BarException($error)';
}

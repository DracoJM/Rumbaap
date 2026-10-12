import 'package:flutter/foundation.dart';

import '../../reservations/domain/night_schedule.dart';
import '../domain/ticket.dart';
import '../domain/ticket_book.dart';

/// Almacén único de entradas del local en esta ejecución, compartido por
/// todos los perfiles (como el de reservas). Las vistas leen proyecciones
/// propias: el cliente sus entradas, el promotor sus ventas y la
/// administración todo su local.
///
/// Las lecturas de puerta y taquilla pasan por [TicketGateway]: es la
/// frontera que el backend futuro deberá cumplir (autorizar, comprobar y
/// registrar cada paso de forma indivisible, y aceptar reintentos con el
/// mismo identificador sin duplicar). Aquí todo ocurre en memoria, en un
/// solo dispositivo: NO hay concurrencia real entre dispositivos.
class DemoTicketStore extends ChangeNotifier implements TicketGateway {
  DemoTicketStore({
    required this.venueId,
    required String venueTag,
    Clock clock = systemClock,
    this.latency = const Duration(milliseconds: 350),
  }) : book = TicketBook(venueId: venueId, venueTag: venueTag, clock: clock);

  final String venueId;
  final TicketBook book;

  /// Espera simulada de la red, para que la interfaz muestre «consultando».
  final Duration latency;

  /// Solo para pruebas: simula que el servicio no responde.
  @visibleForTesting
  bool offline = false;

  final _results = <String, CheckResult>{};

  /// Se llama tras cada cambio de datos: lo usa la persistencia local.
  VoidCallback? onDataChanged;

  /// Resultados ya dados por identificador de operación (idempotencia), para
  /// la persistencia local.
  Map<String, CheckResult> get resultsByRequest => Map.unmodifiable(_results);

  void importResults(Map<String, CheckResult> results) =>
      _results.addAll(results);

  /// Ejecuta una operación del libro y avisa a las vistas. Si lanza, no
  /// cambia nada.
  T perform<T>(T Function(TicketBook book) operation) {
    final result = operation(book);
    notifyListeners();
    onDataChanged?.call();
    return result;
  }

  List<Ticket> ticketsOf(String accountId) =>
      book.ownedBy(accountId)..sort(_newestFirst);

  List<TicketPurchase> purchasesBy(String identityId) =>
      book.createdBy(identityId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static int _newestFirst(Ticket a, Ticket b) =>
      b.history.first.at.compareTo(a.history.first.at);

  // ------------------------------------------------------- TicketGateway

  @override
  Future<CheckResult> doorCheck(String code, {required String actorId}) =>
      _call(null, () => book.doorCheck(code, actorId: actorId));

  @override
  Future<CheckResult> confirmFirstEntry(
    String code, {
    required String actorId,
    required String requestId,
  }) => _call(requestId, () => book.confirmFirstEntry(code, actorId: actorId));

  @override
  Future<CheckResult> redeem(
    String code, {
    required String actorId,
    required RedeemPoint point,
    required String requestId,
  }) =>
      _call(requestId, () => book.redeem(code, actorId: actorId, point: point));

  /// Consulta de solo lectura: no avisa a las vistas ni guarda nada.
  @override
  Future<AccountLookup> identifyAccount(
    String code, {
    required String actorId,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline) throw const TicketGatewayUnavailable();
    return book.identifyAccount(code);
  }

  Future<CheckResult> _call(
    String? requestId,
    CheckResult Function() op,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline) throw const TicketGatewayUnavailable();
    // Un reintento con el mismo identificador devuelve el mismo resultado
    // sin volver a ejecutar ni anotar otra incidencia.
    final cached = requestId == null ? null : _results[requestId];
    if (cached != null) return cached;
    final result = op();
    if (requestId != null) _results[requestId] = result;
    notifyListeners();
    onDataChanged?.call();
    return result;
  }
}

/// Operaciones de puerta y taquilla. Asíncronas e idempotentes por
/// [requestId]: el contrato que deberá cumplir un servicio real.
abstract interface class TicketGateway {
  Future<CheckResult> doorCheck(String code, {required String actorId});

  Future<CheckResult> confirmFirstEntry(
    String code, {
    required String actorId,
    required String requestId,
  });

  Future<CheckResult> redeem(
    String code, {
    required String actorId,
    required RedeemPoint point,
    required String requestId,
  });

  /// Barra: identifica la cuenta dueña de la entrada leída. Consulta
  /// autorizada para el personal de barra; no registra nada.
  Future<AccountLookup> identifyAccount(String code, {required String actorId});
}

/// El servicio no respondió: no se sabe si la operación se aplicó. La
/// interfaz debe reintentar con el mismo identificador, nunca con otro.
class TicketGatewayUnavailable implements Exception {
  const TicketGatewayUnavailable();
}

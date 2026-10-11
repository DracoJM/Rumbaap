import 'package:flutter/foundation.dart';

import '../../reservations/domain/night_schedule.dart';
import '../domain/ticket.dart';
import '../domain/ticket_book.dart';

/// Almacén único de entradas del local en esta ejecución, compartido por
/// todos los perfiles (como el de reservas). Las vistas leen proyecciones
/// propias: el cliente sus entradas, el promotor sus ventas y la
/// administración todo su local.
class DemoTicketStore extends ChangeNotifier {
  DemoTicketStore({required this.venueId, Clock clock = systemClock})
    : book = TicketBook(venueId: venueId, clock: clock);

  final String venueId;
  final TicketBook book;

  /// Ejecuta una operación del libro y avisa a las vistas. Si lanza, no
  /// cambia nada.
  T perform<T>(T Function(TicketBook book) operation) {
    final result = operation(book);
    notifyListeners();
    return result;
  }

  /// Entradas del cliente, de la más reciente a la más antigua.
  List<Ticket> ticketsOf(String accountId) =>
      book.ownedBy(accountId)..sort(_newestFirst);

  /// Ventas del promotor (o compras del cliente), solo las suyas.
  List<TicketPurchase> purchasesBy(String identityId) =>
      book.createdBy(identityId)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static int _newestFirst(Ticket a, Ticket b) =>
      b.history.first.at.compareTo(a.history.first.at);
}

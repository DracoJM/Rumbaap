import 'package:flutter/foundation.dart';

import '../../reservations/domain/night_schedule.dart';
import '../domain/bar.dart';
import '../domain/bar_book.dart';

/// Almacén único de ventas de barra del local, compartido por todos los
/// perfiles. Cada vista lee lo suyo: el cliente sus comprobantes, el mesero
/// las ventas de una reserva y caja o administración todo el local.
class DemoBarStore extends ChangeNotifier {
  DemoBarStore({
    required String venueId,
    required List<MenuItem> menu,
    Clock clock = systemClock,
  }) : book = BarBook(venueId: venueId, menu: menu, clock: clock);

  final BarBook book;

  /// Se llama tras cada cambio de datos: lo usa la persistencia local.
  VoidCallback? onDataChanged;

  T perform<T>(T Function(BarBook book) operation) {
    final result = operation(book);
    notifyListeners();
    onDataChanged?.call();
    return result;
  }
}

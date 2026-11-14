import 'package:flutter/foundation.dart';

import '../../reservations/domain/night_schedule.dart';
import '../domain/night_goals.dart';

/// Metas del local en esta demo, compartidas por las vistas de la
/// administración y guardadas con el resto de la demostración.
class DemoGoalStore extends ChangeNotifier {
  DemoGoalStore({Clock clock = systemClock}) : book = GoalBook(clock: clock);

  final GoalBook book;

  /// Se llama tras cada cambio: lo usa la persistencia local.
  VoidCallback? onDataChanged;

  T perform<T>(T Function(GoalBook book) operation) {
    final result = operation(book);
    notifyListeners();
    onDataChanged?.call();
    return result;
  }
}

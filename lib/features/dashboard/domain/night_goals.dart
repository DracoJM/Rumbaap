import '../../reservations/domain/night_schedule.dart';

/// Parámetro con meta opcional. Cada uno es UN indicador del panel, con su
/// propia unidad: no se suman entre sí ni se combinan en una puntuación.
enum GoalMetric {
  /// Asistencia registrada: entradas con primer ingreso en puerta.
  firstEntries,

  /// Asistencia registrada: reservas con llegada registrada. Aparte de los
  /// ingresos con entrada: una persona puede tener las dos.
  reservationArrivals,

  /// Ingresos registrados (COP): compras de entradas pagadas.
  ticketIncome,

  /// Ingresos registrados (COP): cobrado en barra (pago presencial).
  barIncome,

  /// Ingresos de productos asociados a la noche (COP): prepagos VIP con
  /// importe registrado + cobrado en barra, sin sumar dos veces el consumo.
  productIncome,
}

/// Meta de un parámetro para una noche de un local, con quién la fijó.
class NightGoal {
  const NightGoal({
    required this.night,
    required this.metric,
    required this.target,
    required this.setBy,
    required this.setAt,
  });

  final Night night;
  final GoalMetric metric;

  /// Personas o reservas (asistencia), o COP (ingresos). Siempre > 0.
  final int target;
  final String setBy;
  final DateTime setAt;
}

enum GoalError { notPositive, tooLarge }

class GoalException implements Exception {
  const GoalException(this.error);
  final GoalError error;
}

/// Metas opcionales de UN local, por noche y parámetro. No hay valores por
/// defecto: sin meta, el parámetro está «sin configurar». No hay metas
/// para «todo el período».
class GoalBook {
  GoalBook({Clock clock = systemClock}) : _clock = clock;

  final Clock _clock;
  final _goals = <(Night, GoalMetric), NightGoal>{};

  /// Límite técnico de la entrada (12 cifras), no una regla de negocio.
  static const maxTarget = 999999999999;

  NightGoal? goalFor(Night night, GoalMetric metric) => _goals[(night, metric)];

  List<NightGoal> get goals => _goals.values.toList();

  NightGoal set(
    Night night,
    GoalMetric metric,
    int target, {
    required String actorId,
  }) {
    if (target <= 0) throw const GoalException(GoalError.notPositive);
    if (target > maxTarget) throw const GoalException(GoalError.tooLarge);
    return _goals[(night, metric)] = NightGoal(
      night: night,
      metric: metric,
      target: target,
      setBy: actorId,
      setAt: _clock(),
    );
  }

  /// Quita la meta; el parámetro vuelve a «sin configurar».
  void remove(Night night, GoalMetric metric) => _goals.remove((night, metric));

  // ------------------------------------------------ Persistencia local

  void importState(List<NightGoal> goals) {
    if (_goals.isNotEmpty) {
      throw StateError('Solo se restaura en un libro vacío');
    }
    for (final g in goals) {
      if (g.target <= 0 || g.target > maxTarget) {
        throw const GoalException(GoalError.notPositive);
      }
      _goals[(g.night, g.metric)] = g;
    }
  }
}

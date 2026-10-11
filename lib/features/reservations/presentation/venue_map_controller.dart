import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/venue_table.dart';

enum LoadStatus { loading, ready, failed }

/// Estado compartido de la consulta: fin de semana y noche elegidos,
/// disponibilidad y mesa seleccionada. Solo lee; no decide reservas, pagos
/// ni confirmaciones.
///
/// Si recibe [changes], vuelve a consultar la noche mostrada cada vez que
/// los datos cambian (p. ej. una operación del administrador), para que
/// cualquier vista abierta muestre el resultado sin reiniciar la app.
class VenueMapController extends ChangeNotifier {
  VenueMapController(
    this._repository, {
    required this.venue,
    Clock clock = systemClock,
    Listenable? changes,
  }) : _clock = clock,
       _changes = changes {
    _changes?.addListener(_onDataChanged);
  }

  /// Local consultado: sus mesas son las únicas seleccionables.
  final Venue venue;
  final NightAvailabilityRepository _repository;
  final Clock _clock;
  final Listenable? _changes;

  int _weeksAhead = 0;
  List<Night> _nights = const [];
  Night? _night;
  LoadStatus _availabilityStatus = LoadStatus.loading;
  NightAvailability? _availability;
  String? _selectedTableId;
  bool _refreshing = false;

  // Cada consulta recibe un número; solo la más reciente puede publicar su
  // resultado, para que una respuesta tardía no sobrescriba otra noche.
  int _query = 0;
  bool _disposed = false;

  // Se dispara en la siguiente apertura o cierre para que el paso del tiempo
  // no deje visible una noche terminada ni su ocupación.
  Timer? _changeTimer;

  // Se dispara cuando los datos mostrados vencen por sí solos (p. ej. expira
  // una reserva en proceso a los 10 min, R1).
  Timer? _dataTimer;

  /// 0 = fin de semana de la semana en curso.
  int get weeksAhead => _weeksAhead;
  List<Night> get nights => _nights;
  Night? get night => _night;
  LoadStatus get availabilityStatus => _availabilityStatus;
  String? get selectedTableId => _selectedTableId;

  /// Datos de la noche mostrada; `null` mientras carga o si falló.
  NightAvailability? get availability =>
      _availabilityStatus == LoadStatus.ready ? _availability : null;

  /// `true` mientras se vuelve a consultar tras un cambio de datos. Se
  /// siguen mostrando los datos anteriores de la misma noche; las acciones
  /// deben esperar al resultado nuevo.
  bool get isRefreshing => _refreshing;

  /// Hora actual del establecimiento.
  DateTime get venueNow => VenueTime.of(_clock());

  VenueTable? get selectedTable =>
      _selectedTableId == null ? null : venue.tableById(_selectedTableId!);

  /// `null` mientras carga, si falló la consulta o si falta el dato.
  TableAvailability? availabilityOf(String tableId) =>
      _availabilityStatus == LoadStatus.ready
      ? _availability?.statusOf(tableId)
      : null;

  /// Muestra el fin de semana de la semana en curso.
  Future<void> start() => showWeek(0);

  /// Cambia de fin de semana (0 = en curso). Este mapa no navega a semanas
  /// pasadas (regla M3). [weeksAhead] es un desplazamiento relativo solo de
  /// consulta: las reservas quedan ligadas a una noche concreta.
  Future<void> showWeek(int weeksAhead) async {
    if (weeksAhead < 0) return;
    _weeksAhead = weeksAhead;
    _nights = _computeNights();
    if (_nights.isEmpty) {
      ++_query;
      _resetNight(null);
      _notify();
      return;
    }
    await selectNight(_nights.first.id);
  }

  /// Vuelve a calcular las noches con la hora actual y consulta de nuevo la
  /// noche mostrada. Se llama al cruzar una apertura o un cierre y al volver
  /// la app del segundo plano. Si la noche mostrada ya no se ofrece, pasa a
  /// la primera disponible; si sigue, conserva la mesa seleccionada.
  Future<void> refresh() async {
    final previous = _night;
    _nights = _computeNights();
    final still = previous == null ? null : _byId(previous.id);
    if (still == null) {
      if (_nights.isEmpty) {
        ++_query;
        _resetNight(null);
        _notify();
        return;
      }
      return selectNight(_nights.first.id);
    }
    return _load(still, keepSelection: true);
  }

  /// `true` si existe una noche anterior a la mostrada en este mapa: en su
  /// fin de semana o en uno anterior que no sea pasado (regla M3).
  bool get hasPreviousNight {
    final index = _nights.indexWhere((n) => n.id == _night?.id);
    return index > 0 || _weeksAhead > 0;
  }

  /// Pasa a la noche anterior ([delta] < 0) o siguiente ([delta] > 0). Al
  /// salir del fin de semana mostrado, pasa al anterior o al siguiente.
  Future<void> showAdjacentNight(int delta) async {
    if (delta == 0) return;
    final index = _nights.indexWhere((n) => n.id == _night?.id);
    final target = index + delta.sign;
    if (index >= 0 && target >= 0 && target < _nights.length) {
      return selectNight(_nights[target].id);
    }
    if (delta < 0) {
      if (_weeksAhead == 0) return;
      _weeksAhead -= 1;
      _nights = _computeNights();
      if (_nights.isEmpty) return showWeek(_weeksAhead);
      return selectNight(_nights.last.id);
    }
    return showWeek(_weeksAhead + 1);
  }

  /// Cambia de noche: limpia selección y datos antes de consultar.
  Future<void> selectNight(String nightId) async {
    final night = _byId(nightId);
    if (night == null) return;
    return _load(night, keepSelection: false);
  }

  Future<void> _load(Night night, {required bool keepSelection}) async {
    final query = ++_query;
    _dataTimer?.cancel();
    _refreshing = false;
    final selected = _selectedTableId;
    _resetNight(night);
    if (keepSelection) _selectedTableId = selected;
    _notify();
    try {
      final availability = await _repository.availabilityFor(night);
      if (!_isCurrent(query)) return;
      _checkResponse(availability, night);
      _availability = availability;
      _availabilityStatus = LoadStatus.ready;
      _scheduleDataRefresh(availability.refreshAt);
    } catch (_) {
      if (!_isCurrent(query)) return;
      _availability = null;
      _availabilityStatus = LoadStatus.failed;
    }
    _notify();
  }

  /// Los datos cambiaron: se vuelve a consultar la misma noche conservando lo
  /// mostrado hasta que llegue la respuesta, para no presentar como
  /// desconocida una noche que solo se está actualizando.
  Future<void> _onDataChanged() async {
    final night = _night;
    if (night == null || _disposed) return;
    // Sin datos que conservar (cargando o con error): consulta normal, que
    // también descarta una respuesta en curso anterior al cambio.
    if (_availabilityStatus != LoadStatus.ready) {
      return _load(night, keepSelection: true);
    }
    final query = ++_query;
    _dataTimer?.cancel();
    _refreshing = true;
    _notify();
    try {
      final availability = await _repository.availabilityFor(night);
      if (!_isCurrent(query)) return;
      _checkResponse(availability, night);
      _availability = availability;
      _availabilityStatus = LoadStatus.ready;
      _scheduleDataRefresh(availability.refreshAt);
    } catch (_) {
      if (!_isCurrent(query)) return;
      _availability = null;
      _availabilityStatus = LoadStatus.failed;
    }
    _refreshing = false;
    _notify();
  }

  /// Una respuesta de otra noche o de otro local se trata como error: nunca se
  /// muestran estados que no corresponden a lo consultado.
  void _checkResponse(NightAvailability availability, Night night) {
    if (availability.nightId != night.id) {
      throw StateError('Respuesta de otra noche: ${availability.nightId}');
    }
    final venueId = availability.venueId;
    if (venueId != null && venueId != venue.id) {
      throw StateError('Respuesta de otro local: $venueId');
    }
  }

  Future<void> retry() {
    final night = _night;
    return night == null ? showWeek(_weeksAhead) : selectNight(night.id);
  }

  /// Tocar la mesa ya seleccionada la deselecciona.
  void toggleTable(String tableId) {
    if (venue.tableById(tableId) == null) return;
    _selectedTableId = _selectedTableId == tableId ? null : tableId;
    _notify();
  }

  /// Selección explícita (p. ej. desde la lista): nunca deselecciona.
  void selectTable(String tableId) {
    if (venue.tableById(tableId) == null || _selectedTableId == tableId) {
      return;
    }
    _selectedTableId = tableId;
    _notify();
  }

  void clearSelection() {
    if (_selectedTableId == null) return;
    _selectedTableId = null;
    _notify();
  }

  void _scheduleDataRefresh(DateTime? refreshAt) {
    _dataTimer?.cancel();
    if (refreshAt == null || _disposed) return;
    final wait = refreshAt.difference(_clock());
    _dataTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      refresh();
    });
  }

  Night? _byId(String nightId) =>
      _nights.where((n) => n.id == nightId).firstOrNull;

  List<Night> _computeNights() {
    final now = venueNow;
    _changeTimer?.cancel();
    if (!_disposed) {
      _changeTimer = Timer(NightSchedule.nextChange(now).difference(now), () {
        refresh();
      });
    }
    return NightSchedule.weekendNights(now, weeksAhead: _weeksAhead);
  }

  void _resetNight(Night? night) {
    _refreshing = false;
    _night = night;
    _availability = null;
    _availabilityStatus = LoadStatus.loading;
    _selectedTableId = null;
  }

  bool _isCurrent(int query) => !_disposed && query == _query;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _changes?.removeListener(_onDataChanged);
    _changeTimer?.cancel();
    _dataTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';

import '../domain/night_availability.dart';
import '../domain/venue_table.dart';

enum LoadStatus { loading, ready, failed }

/// Estado compartido de la consulta: noche elegida, disponibilidad y mesa
/// seleccionada. Solo lee; no decide reservas, pagos ni confirmaciones.
class VenueMapController extends ChangeNotifier {
  VenueMapController(this._repository);

  final NightAvailabilityRepository _repository;

  LoadStatus _nightsStatus = LoadStatus.loading;
  List<Night> _nights = const [];
  Night? _night;
  LoadStatus _availabilityStatus = LoadStatus.loading;
  NightAvailability? _availability;
  String? _selectedTableId;

  // Cada consulta recibe un número; solo la más reciente puede publicar su
  // resultado, para que una respuesta tardía no sobrescriba otra noche.
  int _query = 0;
  bool _disposed = false;

  LoadStatus get nightsStatus => _nightsStatus;
  List<Night> get nights => _nights;
  Night? get night => _night;
  LoadStatus get availabilityStatus => _availabilityStatus;
  String? get selectedTableId => _selectedTableId;

  VenueTable? get selectedTable =>
      _selectedTableId == null ? null : VenueTables.byId(_selectedTableId!);

  /// `null` mientras carga, si falló la consulta o si falta el dato.
  TableAvailability? availabilityOf(String tableId) =>
      _availabilityStatus == LoadStatus.ready
      ? _availability?.statusOf(tableId)
      : null;

  Future<void> loadNights() async {
    final query = ++_query;
    _nightsStatus = LoadStatus.loading;
    _nights = const [];
    _resetNight(null);
    _notify();
    try {
      final nights = await _repository.listNights();
      if (!_isCurrent(query)) return;
      _nights = List.unmodifiable(nights);
      _nightsStatus = LoadStatus.ready;
    } catch (_) {
      if (!_isCurrent(query)) return;
      _nightsStatus = LoadStatus.failed;
      _notify();
      return;
    }
    if (_nights.isEmpty) {
      _notify();
      return;
    }
    await selectNight(_nights.first.id);
  }

  /// Cambia de noche: limpia selección y datos antes de consultar.
  Future<void> selectNight(String nightId) async {
    final night = _nights.where((n) => n.id == nightId).firstOrNull;
    if (night == null) return;
    final query = ++_query;
    _resetNight(night);
    _notify();
    try {
      final availability = await _repository.availabilityFor(nightId);
      if (!_isCurrent(query)) return;
      if (availability.nightId != nightId) {
        throw StateError('Respuesta de otra noche: ${availability.nightId}');
      }
      _availability = availability;
      _availabilityStatus = LoadStatus.ready;
    } catch (_) {
      if (!_isCurrent(query)) return;
      _availability = null;
      _availabilityStatus = LoadStatus.failed;
    }
    _notify();
  }

  Future<void> retry() {
    final night = _night;
    if (_nightsStatus != LoadStatus.ready || night == null) {
      return loadNights();
    }
    return selectNight(night.id);
  }

  /// Tocar la mesa ya seleccionada la deselecciona.
  void toggleTable(String tableId) {
    if (VenueTables.byId(tableId) == null) return;
    _selectedTableId = _selectedTableId == tableId ? null : tableId;
    _notify();
  }

  /// Selección explícita (p. ej. desde la lista): nunca deselecciona.
  void selectTable(String tableId) {
    if (VenueTables.byId(tableId) == null || _selectedTableId == tableId) {
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

  void _resetNight(Night? night) {
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
    super.dispose();
  }
}

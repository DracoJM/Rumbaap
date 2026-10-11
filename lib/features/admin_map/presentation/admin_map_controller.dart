import 'package:flutter/foundation.dart';

import '../../reservations/domain/venue_table.dart';
import '../data/demo_admin_nights.dart';
import '../domain/admin_table_status.dart';

/// Estado de la pantalla del mapa del administrador: noche, filtro por
/// estado, mesa seleccionada y ficha abierta o cerrada. Solo lee datos de
/// demostración; no crea ni cambia reservas.
class AdminMapController extends ChangeNotifier {
  AdminMapController({String initialTableId = 'M07'})
    : _selectedId = initialTableId,
      _statuses = DemoAdminNights.statusesFor(0);

  int _nightOffset = 0;
  Map<String, AdminTableStatus> _statuses;
  AdminTableStatus? _filter;
  String _selectedId;
  bool _sheetExpanded = false;

  int get nightOffset => _nightOffset;
  DateTime get nightDate => DemoAdminNights.dateFor(_nightOffset);
  AdminTableStatus? get filter => _filter;
  bool get sheetExpanded => _sheetExpanded;
  VenueTable get selectedTable => VenueTables.byId(_selectedId)!;

  AdminTableStatus statusOf(String tableId) =>
      _statuses[tableId] ?? AdminTableStatus.unknown;

  /// Mesas por estado, solo los estados presentes y en el orden del enum.
  Map<AdminTableStatus, int> get counts {
    final counts = <AdminTableStatus, int>{};
    for (final status in AdminTableStatus.values) {
      final n = VenueTables.all.where((t) => statusOf(t.id) == status).length;
      if (n > 0) counts[status] = n;
    }
    return counts;
  }

  /// `true` si el filtro activo deja fuera a la mesa.
  bool isDimmed(String tableId) =>
      _filter != null && statusOf(tableId) != _filter;

  void showNight(int delta) {
    if (delta == 0) return;
    _nightOffset += delta;
    _statuses = DemoAdminNights.statusesFor(_nightOffset);
    // Un filtro sin mesas en la nueva noche no tiene chip para quitarlo.
    if (_filter != null && !counts.containsKey(_filter)) _filter = null;
    notifyListeners();
  }

  /// Tocar el estado activo quita el filtro.
  void toggleFilter(AdminTableStatus status) {
    _filter = _filter == status ? null : status;
    notifyListeners();
  }

  void selectTable(String tableId) {
    if (VenueTables.byId(tableId) == null || tableId == _selectedId) return;
    _selectedId = tableId;
    notifyListeners();
  }

  void toggleSheet() {
    _sheetExpanded = !_sheetExpanded;
    notifyListeners();
  }
}

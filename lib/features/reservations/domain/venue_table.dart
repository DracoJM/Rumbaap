/// Mesas físicas del establecimiento, independientes de cualquier noche.
///
/// Los IDs M01–M20 y VIP 1/VIP 2 vienen del prototipo de demostración y se
/// conservan para continuidad del desarrollo; no son la numeración física
/// oficial confirmada por el establecimiento.
library;

enum TableKind { regular, vip }

/// Zona física donde está la mesa.
enum TableZone { west, east, vip }

class VenueTable {
  const VenueTable({required this.id, required this.kind, required this.zone});

  final String id;
  final TableKind kind;
  final TableZone zone;

  bool get isVip => kind == TableKind.vip;
}

abstract final class VenueTables {
  /// Orden: VIP de occidente a oriente; luego cada lado de norte a sur.
  static final List<VenueTable> all = List.unmodifiable([
    const VenueTable(id: 'VIP 1', kind: TableKind.vip, zone: TableZone.vip),
    const VenueTable(id: 'VIP 2', kind: TableKind.vip, zone: TableZone.vip),
    for (var i = 1; i <= 10; i++)
      VenueTable(
        id: 'M${i.toString().padLeft(2, '0')}',
        kind: TableKind.regular,
        zone: TableZone.west,
      ),
    for (var i = 11; i <= 20; i++)
      VenueTable(id: 'M$i', kind: TableKind.regular, zone: TableZone.east),
  ]);

  static VenueTable? byId(String id) {
    for (final table in all) {
      if (table.id == id) return table;
    }
    return null;
  }

  static List<VenueTable> inZone(TableZone zone) =>
      all.where((t) => t.zone == zone).toList(growable: false);
}

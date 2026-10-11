/// Local (discoteca) y sus mesas físicas, independientes de cualquier noche.
///
/// Cada local trae su propia configuración: mesas, zonas y tipos. Un ID de
/// mesa como «M01» solo identifica una mesa dentro de su local; para
/// distinguir locales se usa [Venue.id]. La configuración de cada local vive
/// en `lib/features/venues/`.
library;

enum TableKind { regular, vip }

/// Zona del local donde está la mesa, definida por la configuración del
/// local.
class VenueZone {
  const VenueZone({required this.id, required this.label});

  final String id;

  /// Texto para mostrar, por ejemplo «Lado occidental».
  final String label;
}

class VenueTable {
  const VenueTable({required this.id, required this.kind, required this.zone});

  /// Identificador dentro del local.
  final String id;
  final TableKind kind;
  final VenueZone zone;

  bool get isVip => kind == TableKind.vip;
}

class Venue {
  Venue({
    required this.id,
    required this.name,
    required List<VenueTable> tables,
  }) : tables = List.unmodifiable(tables) {
    assert(
      tables.map((t) => t.id).toSet().length == tables.length,
      'IDs de mesa repetidos en el local $id',
    );
  }

  final String id;
  final String name;

  /// Mesas en el orden en que se listan.
  final List<VenueTable> tables;

  VenueTable? tableById(String tableId) {
    for (final table in tables) {
      if (table.id == tableId) return table;
    }
    return null;
  }

  /// Posición de la mesa en [tables], para ordenar listas; -1 si no existe.
  int orderOf(String tableId) => tables.indexWhere((t) => t.id == tableId);
}

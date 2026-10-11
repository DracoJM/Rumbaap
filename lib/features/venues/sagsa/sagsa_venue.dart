import '../../reservations/domain/venue_table.dart';

/// Mesas de Sagsa.
///
/// Los IDs M01–M20 y VIP 1/VIP 2 vienen del prototipo de demostración y se
/// conservan para continuidad del desarrollo; no son la numeración física
/// oficial confirmada por el establecimiento.
abstract final class SagsaZones {
  static const west = VenueZone(id: 'west', label: 'Lado occidental');
  static const east = VenueZone(id: 'east', label: 'Lado oriental');
  static const vip = VenueZone(id: 'vip', label: 'Zona VIP elevada · norte');
}

/// Orden: VIP de occidente a oriente; luego cada lado de norte a sur.
final sagsaVenue = Venue(
  id: 'sagsa',
  name: 'Sagsa',
  tables: [
    const VenueTable(id: 'VIP 1', kind: TableKind.vip, zone: SagsaZones.vip),
    const VenueTable(id: 'VIP 2', kind: TableKind.vip, zone: SagsaZones.vip),
    for (var i = 1; i <= 10; i++)
      VenueTable(
        id: 'M${i.toString().padLeft(2, '0')}',
        kind: TableKind.regular,
        zone: SagsaZones.west,
      ),
    for (var i = 11; i <= 20; i++)
      VenueTable(id: 'M$i', kind: TableKind.regular, zone: SagsaZones.east),
  ],
);

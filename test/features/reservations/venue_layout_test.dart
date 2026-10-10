import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';
import 'package:rumbaap/features/reservations/presentation/venue_geometry.dart';

void main() {
  group('mesas físicas', () {
    test('hay 22 mesas con IDs únicos', () {
      final ids = VenueTables.all.map((t) => t.id).toList();
      expect(ids, hasLength(22));
      expect(ids.toSet(), hasLength(22));
    });

    test('10 normales al occidente, 10 al oriente y 2 VIP', () {
      final west = VenueTables.inZone(TableZone.west);
      final east = VenueTables.inZone(TableZone.east);
      final vip = VenueTables.inZone(TableZone.vip);

      expect(west, hasLength(10));
      expect(east, hasLength(10));
      expect(vip.map((t) => t.id), ['VIP 1', 'VIP 2']);
      expect([...west, ...east].every((t) => !t.isVip), isTrue);
      expect(vip.every((t) => t.isVip), isTrue);
    });
  });

  group('geometría del plano', () {
    const bar = VenueGeometry.bar;

    test('las normales están en las paredes occidental y oriental', () {
      for (final t in VenueTables.inZone(TableZone.west)) {
        expect(VenueGeometry.boundsOf(t).right, lessThan(bar.left));
        expect(VenueGeometry.centerOf(t).dx, VenueGeometry.westX);
      }
      for (final t in VenueTables.inZone(TableZone.east)) {
        expect(VenueGeometry.boundsOf(t).left, greaterThan(bar.right));
        expect(VenueGeometry.centerOf(t).dx, VenueGeometry.eastX);
      }
    });

    test('las VIP están sobre la tarima elevada del norte', () {
      final vip = VenueTables.inZone(TableZone.vip);
      for (final t in vip) {
        expect(
          VenueGeometry.vipDeck.contains(VenueGeometry.centerOf(t)),
          isTrue,
        );
        expect(VenueGeometry.centerOf(t).dy, lessThan(bar.top));
      }
      // VIP 1 al occidente de VIP 2.
      expect(
        VenueGeometry.centerOf(vip[0]).dx,
        lessThan(VenueGeometry.centerOf(vip[1]).dx),
      );
    });

    test('las aberturas de los sofás miran hacia el interior', () {
      for (final t in VenueTables.inZone(TableZone.west)) {
        expect(VenueGeometry.openingOf(t).dx, closeTo(1, 1e-9));
      }
      for (final t in VenueTables.inZone(TableZone.east)) {
        expect(VenueGeometry.openingOf(t).dx, closeTo(-1, 1e-9));
      }
      for (final t in VenueTables.inZone(TableZone.vip)) {
        // Hacia el sur, es decir, hacia el salón.
        expect(VenueGeometry.openingOf(t).dy, closeTo(1, 1e-9));
      }
    });

    test('ninguna mesa se superpone con otra ni sale del salón', () {
      final bounds = [
        for (final t in VenueTables.all) VenueGeometry.boundsOf(t),
      ];
      for (var i = 0; i < bounds.length; i++) {
        expect(
          VenueGeometry.hall.expandToInclude(bounds[i]),
          VenueGeometry.hall,
        );
        for (var j = i + 1; j < bounds.length; j++) {
          final overlap = bounds[i].intersect(bounds[j]);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: '${VenueTables.all[i].id} y ${VenueTables.all[j].id}',
          );
        }
      }
    });

    test('barra central norte-sur, DJ al sur y acceso al sureste', () {
      const hall = VenueGeometry.hall;
      expect(bar.height, greaterThan(bar.width));
      expect(bar.center.dx, closeTo(hall.center.dx, 1));
      expect(VenueGeometry.djStage.bottom, hall.bottom);
      expect(VenueGeometry.djStage.center.dx, closeTo(hall.center.dx, 1));
      expect(VenueGeometry.access.right, hall.right);
      expect(VenueGeometry.access.bottom, hall.bottom);
    });
  });
}

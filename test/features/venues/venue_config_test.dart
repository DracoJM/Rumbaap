import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_layout.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_layout.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

void main() {
  final layout = sagsaConfig.layout;
  final canvas = Offset.zero & layout.size;
  TablePlacement at(String id) => layout.placementOf(id)!;
  List<VenueTable> zone(VenueZone z) =>
      sagsaVenue.tables.where((t) => t.zone == z).toList();

  group('mesas de Sagsa', () {
    test('22 mesas con IDs únicos: 10 por costado y 2 VIP', () {
      final ids = sagsaVenue.tables.map((t) => t.id).toList();
      expect(ids, hasLength(22));
      expect(ids.toSet(), hasLength(22));
      expect(zone(SagsaZones.west), hasLength(10));
      expect(zone(SagsaZones.east), hasLength(10));
      expect(zone(SagsaZones.vip).map((t) => t.id), ['VIP 1', 'VIP 2']);
      expect(zone(SagsaZones.vip).every((t) => t.isVip), isTrue);
      expect(
        [
          ...zone(SagsaZones.west),
          ...zone(SagsaZones.east),
        ].every((t) => !t.isVip),
        isTrue,
      );
    });

    test('las mesas se buscan dentro del local', () {
      expect(sagsaVenue.tableById('M07')?.zone, SagsaZones.west);
      expect(sagsaVenue.tableById('X99'), isNull);
      expect(sagsaVenue.orderOf('VIP 1'), 0);
      expect(sagsaVenue.orderOf('X99'), -1);
    });
  });

  group('distribución v7 de Sagsa', () {
    test('lienzo de 400 × 622 y todas las mesas con posición', () {
      expect(layout.size, const Size(400, 622));
      for (final t in sagsaVenue.tables) {
        expect(layout.placementOf(t.id), isNotNull, reason: t.id);
      }
    });

    test('10 mesas por costado en x 30 y 370, desde y 140 cada 44', () {
      for (final (i, t) in zone(SagsaZones.west).indexed) {
        expect(at(t.id).center, Offset(30, 140 + 44.0 * i));
      }
      for (final (i, t) in zone(SagsaZones.east).indexed) {
        expect(at(t.id).center, Offset(370, 140 + 44.0 * i));
      }
    });

    test('proporciones VIP de v7: tarima 192 × 68 y dos mesas encima', () {
      expect(layout.vipDeck, const Rect.fromLTWH(104, 6, 192, 68));
      expect(at('VIP 1').center, const Offset(158, 38));
      expect(at('VIP 2').center, const Offset(242, 38));
      for (final id in ['VIP 1', 'VIP 2']) {
        expect(layout.vipDeck!.contains(at(id).center), isTrue);
        expect(at(id).hitRect.size, const Size(72, 58));
      }
      // VIP 1 al occidente, con su icono hacia fuera.
      expect(at('VIP 1').badgeSide, -1);
      expect(at('VIP 2').badgeSide, 1);
    });

    test('cada mesa normal toca en su franja completa de 58 × 44', () {
      for (final t in sagsaVenue.tables.where((t) => !t.isVip)) {
        final hit = at(t.id).hitRect;
        expect(hit.size, const Size(58, 44));
        expect(hit.contains(at(t.id).center), isTrue);
      }
      for (final z in [SagsaZones.west, SagsaZones.east]) {
        final side = zone(z);
        for (var i = 0; i + 1 < side.length; i++) {
          expect(at(side[i].id).hitRect.bottom, at(side[i + 1].id).hitRect.top);
        }
      }
    });

    test('ninguna zona táctil se solapa ni sale del lienzo', () {
      final tables = sagsaVenue.tables;
      for (var i = 0; i < tables.length; i++) {
        final a = at(tables[i].id).hitRect;
        expect(canvas.expandToInclude(a), canvas, reason: tables[i].id);
        for (var j = i + 1; j < tables.length; j++) {
          final overlap = a.intersect(at(tables[j].id).hitRect);
          expect(
            overlap.width <= 0 || overlap.height <= 0,
            isTrue,
            reason: '${tables[i].id} y ${tables[j].id}',
          );
        }
      }
    });

    test('los sofás se abren hacia el centro y los VIP hacia el salón', () {
      for (final t in zone(SagsaZones.west)) {
        expect(at(t.id).rotation, closeTo(0, 1e-9));
      }
      for (final t in zone(SagsaZones.east)) {
        expect(at(t.id).rotation, closeTo(math.pi, 1e-9));
      }
      for (final t in zone(SagsaZones.vip)) {
        expect(at(t.id).rotation, closeTo(math.pi / 2, 1e-9));
      }
    });

    test('barra centrada en la pista y cabina del DJ abajo sin mesas', () {
      final bar = layout.bar!;
      expect(bar, const Rect.fromLTWH(180, 235, 40, 206));
      expect(bar.center.dx, layout.size.width / 2);
      expect(layout.danceFloor!.contains(bar.topLeft), isTrue);
      expect(layout.danceFloor!.contains(bar.bottomRight), isTrue);
      final booth = layout.djBooth!;
      expect(booth, const Rect.fromLTWH(142, 560, 116, 56));
      for (final t in sagsaVenue.tables) {
        expect(at(t.id).hitRect.bottom, lessThan(booth.top));
      }
      expect(layout.access!.left, greaterThan(booth.right));
      expect(SagsaLayout.rowPitch, 44);
    });
  });

  group('condiciones de Sagsa', () {
    test('VIP: hasta 20 personas y 2.000.000 COP; sin beneficios sin '
        'confirmar', () {
      final vip = sagsaConfig.termsOf(sagsaVenue.tableById('VIP 1')!);
      expect(vip.capacity, 'Hasta 20 personas');
      expect(vip.conditions.join(' '), contains('2.000.000 COP'));
      final all = [
        for (final t in sagsaConfig.terms.values) ...t.conditions,
      ].join(' ');
      expect(all, isNot(contains('cortesía')));
    });

    test('normal: capacidad por confirmar y consumo de referencia', () {
      final normal = sagsaConfig.termsOf(sagsaVenue.tableById('M01')!);
      expect(normal.capacity, 'Por confirmar');
      expect(normal.conditions.join(' '), contains('400.000 COP'));
    });
  });
}

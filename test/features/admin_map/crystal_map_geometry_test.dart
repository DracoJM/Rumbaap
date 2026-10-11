import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/admin_map/presentation/crystal_map_geometry.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';

typedef G = CrystalMapGeometry;

void main() {
  final canvas = Offset.zero & G.size;

  test('el lienzo lógico mide 400 × 622', () {
    expect(G.size, const Size(400, 622));
  });

  test('10 mesas por costado en x 30 y 370, desde y 140 cada 44', () {
    final west = VenueTables.inZone(TableZone.west);
    final east = VenueTables.inZone(TableZone.east);
    for (var i = 0; i < 10; i++) {
      expect(G.centerOf(west[i]), Offset(30, 140 + 44.0 * i));
      expect(G.centerOf(east[i]), Offset(370, 140 + 44.0 * i));
    }
  });

  test('las VIP están sobre la tarima, VIP 1 al occidente', () {
    final vip = VenueTables.inZone(TableZone.vip);
    expect(G.centerOf(vip[0]), const Offset(158, 38));
    expect(G.centerOf(vip[1]), const Offset(242, 38));
    for (final t in vip) {
      expect(G.vipDeck.contains(G.centerOf(t)), isTrue);
    }
  });

  test('cada mesa normal toca en su franja completa de 58 × 44', () {
    for (final t in VenueTables.all.where((t) => !t.isVip)) {
      final hit = G.hitRectOf(t);
      expect(hit.size, const Size(58, 44));
      expect(hit.contains(G.centerOf(t)), isTrue);
    }
  });

  test('ninguna zona táctil se solapa ni sale del lienzo', () {
    final tables = VenueTables.all;
    for (var i = 0; i < tables.length; i++) {
      final a = G.hitRectOf(tables[i]);
      expect(canvas.expandToInclude(a), canvas, reason: tables[i].id);
      for (var j = i + 1; j < tables.length; j++) {
        final overlap = a.intersect(G.hitRectOf(tables[j]));
        expect(
          overlap.width <= 0 || overlap.height <= 0,
          isTrue,
          reason: '${tables[i].id} y ${tables[j].id}',
        );
      }
    }
  });

  test('las franjas vecinas de un costado quedan contiguas', () {
    for (final zone in [TableZone.west, TableZone.east]) {
      final side = VenueTables.inZone(zone);
      for (var i = 0; i + 1 < side.length; i++) {
        expect(G.hitRectOf(side[i]).bottom, G.hitRectOf(side[i + 1]).top);
      }
    }
  });

  test('los sofás se abren hacia el centro y los VIP hacia el salón', () {
    for (final t in VenueTables.inZone(TableZone.west)) {
      expect(G.rotationOf(t), closeTo(0, 1e-9));
    }
    for (final t in VenueTables.inZone(TableZone.east)) {
      expect(G.rotationOf(t).abs(), closeTo(math.pi, 1e-9));
    }
    for (final t in VenueTables.inZone(TableZone.vip)) {
      expect(G.rotationOf(t), closeTo(math.pi / 2, 1e-9));
    }
  });

  test('barra centrada, pista alrededor y cabina del DJ abajo sin mesas', () {
    expect(G.bar, const Rect.fromLTWH(180, 235, 40, 206));
    expect(G.bar.center.dx, G.size.width / 2);
    expect(G.danceFloor.contains(G.bar.topLeft), isTrue);
    expect(G.danceFloor.contains(G.bar.bottomRight), isTrue);
    expect(G.djBooth, const Rect.fromLTWH(142, 560, 116, 56));
    for (final t in VenueTables.all) {
      expect(G.hitRectOf(t).bottom, lessThan(G.djBooth.top));
    }
    expect(G.access.left, greaterThan(G.djBooth.right));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/admin_map/data/demo_admin_nights.dart';
import 'package:rumbaap/features/admin_map/domain/admin_table_status.dart';
import 'package:rumbaap/features/admin_map/presentation/admin_map_controller.dart';

void main() {
  late AdminMapController c;
  var notified = 0;

  setUp(() {
    c = AdminMapController()..addListener(() => notified++);
    notified = 0;
  });
  tearDown(() => c.dispose());

  test('empieza en la noche base con M07 seleccionada y la ficha cerrada', () {
    expect(c.nightOffset, 0);
    expect(c.nightDate, DemoAdminNights.baseDate);
    expect(c.selectedTable.id, 'M07');
    expect(c.sheetExpanded, isFalse);
    expect(c.filter, isNull);
  });

  test('cuenta las mesas por estado, solo los presentes y en orden', () {
    expect(c.counts, {
      AdminTableStatus.available: 15,
      AdminTableStatus.reserved: 3,
      AdminTableStatus.inProgress: 1,
      AdminTableStatus.occupied: 1,
      AdminTableStatus.vipPaymentPending: 1,
      AdminTableStatus.unknown: 1,
    });
    expect(c.counts.keys.toList(), AdminTableStatus.values);
  });

  test('el filtro atenúa las demás mesas y tocarlo otra vez lo quita', () {
    c.toggleFilter(AdminTableStatus.reserved);
    expect(c.filter, AdminTableStatus.reserved);
    expect(c.isDimmed('M06'), isFalse);
    expect(c.isDimmed('M07'), isTrue);
    c.toggleFilter(AdminTableStatus.reserved);
    expect(c.filter, isNull);
    expect(c.isDimmed('M07'), isFalse);
    expect(notified, 2);
  });

  test('cambiar de noche carga sus estados y conserva la mesa', () {
    c.showNight(1);
    expect(c.nightOffset, 1);
    expect(c.nightDate, DateTime.utc(2026, 10, 12));
    final expected = DemoAdminNights.statusesFor(1);
    for (final id in ['M01', 'M07', 'VIP 1']) {
      expect(c.statusOf(id), expected[id]);
    }
    expect(c.selectedTable.id, 'M07');
    c.showNight(-1);
    expect(c.nightOffset, 0);
  });

  test('un filtro sin mesas en la nueva noche se quita', () {
    var offset = 1;
    while (DemoAdminNights.statusesFor(
      offset,
    ).containsValue(AdminTableStatus.unknown)) {
      offset++;
    }
    c.toggleFilter(AdminTableStatus.unknown);
    c.showNight(offset);
    expect(c.filter, isNull);
  });

  test('seleccionar mesa notifica; la misma o un ID desconocido no', () {
    c.selectTable('VIP 2');
    expect(c.selectedTable.id, 'VIP 2');
    c.selectTable('VIP 2');
    c.selectTable('X99');
    expect(notified, 1);
    c.toggleSheet();
    expect(c.sheetExpanded, isTrue);
  });
}

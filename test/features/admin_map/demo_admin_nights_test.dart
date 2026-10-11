import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/admin_map/data/demo_admin_nights.dart';
import 'package:rumbaap/features/admin_map/domain/admin_table_status.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';

void main() {
  test('la noche base es el domingo 11 de octubre de 2026', () {
    final date = DemoAdminNights.dateFor(0);
    expect(date, DateTime.utc(2026, 10, 11));
    expect(date.weekday, DateTime.sunday);
    expect(DemoAdminNights.dateFor(1), DateTime.utc(2026, 10, 12));
    expect(DemoAdminNights.dateFor(-11), DateTime.utc(2026, 9, 30));
  });

  test('la noche base reproduce los estados de la maqueta', () {
    final s = DemoAdminNights.statusesFor(0);
    expect(s['VIP 1'], AdminTableStatus.vipPaymentPending);
    expect(s['VIP 2'], AdminTableStatus.reserved);
    expect(s['M04'], AdminTableStatus.inProgress);
    expect(s['M06'], AdminTableStatus.reserved);
    expect(s['M09'], AdminTableStatus.unknown);
    expect(s['M13'], AdminTableStatus.reserved);
    expect(s['M16'], AdminTableStatus.occupied);
    expect(s['M07'], AdminTableStatus.available);
    expect(
      s.values.where((v) => v == AdminTableStatus.available),
      hasLength(15),
    );
  });

  test('cada noche cubre las 22 mesas y siempre da lo mismo', () {
    for (final offset in [-3, -1, 1, 2, 30]) {
      final a = DemoAdminNights.statusesFor(offset);
      expect(a.keys.toSet(), VenueTables.all.map((t) => t.id).toSet());
      expect(DemoAdminNights.statusesFor(offset), a);
    }
    expect(
      DemoAdminNights.statusesFor(1),
      isNot(DemoAdminNights.statusesFor(2)),
    );
  });

  test('el pago VIP pendiente solo aparece en mesas VIP', () {
    for (var offset = -10; offset <= 10; offset++) {
      final s = DemoAdminNights.statusesFor(offset);
      for (final t in VenueTables.all.where((t) => !t.isVip)) {
        expect(s[t.id], isNot(AdminTableStatus.vipPaymentPending));
      }
    }
  });
}

import '../../reservations/domain/venue_table.dart';
import '../domain/admin_table_status.dart';

/// DATOS DE DEMOSTRACIÓN ficticios del mapa del administrador.
///
/// La noche base reproduce los estados de la maqueta aprobada; las demás se
/// generan con una semilla fija por noche, así cada noche es siempre igual
/// y los tests no dependen de la hora ni del azar.
abstract final class DemoAdminNights {
  /// Domingo 11 de octubre de 2026, la noche de la maqueta.
  static final DateTime baseDate = DateTime.utc(2026, 10, 11);

  static const _baseRegular = {
    'M04': AdminTableStatus.inProgress,
    'M06': AdminTableStatus.reserved,
    'M09': AdminTableStatus.unknown,
    'M13': AdminTableStatus.reserved,
    'M16': AdminTableStatus.occupied,
  };

  static DateTime dateFor(int offset) => baseDate.add(Duration(days: offset));

  static Map<String, AdminTableStatus> statusesFor(int offset) {
    if (offset == 0) {
      return {
        for (final t in VenueTables.all)
          t.id: switch (t.id) {
            'VIP 1' => AdminTableStatus.vipPaymentPending,
            'VIP 2' => AdminTableStatus.reserved,
            _ => _baseRegular[t.id] ?? AdminTableStatus.available,
          },
      };
    }
    final next = _generator(9973 + offset * 7919);
    // Mismo orden que la maqueta: M01–M20 y después las VIP.
    final ordered = [
      ...VenueTables.all.where((t) => !t.isVip),
      ...VenueTables.all.where((t) => t.isVip),
    ];
    return {
      for (final t in ordered) t.id: t.isVip ? _vip(next()) : _regular(next()),
    };
  }

  static AdminTableStatus _vip(double x) => x < 0.4
      ? AdminTableStatus.available
      : x < 0.75
      ? AdminTableStatus.reserved
      : AdminTableStatus.vipPaymentPending;

  static AdminTableStatus _regular(double x) => x < 0.55
      ? AdminTableStatus.available
      : x < 0.75
      ? AdminTableStatus.reserved
      : x < 0.83
      ? AdminTableStatus.inProgress
      : x < 0.93
      ? AdminTableStatus.occupied
      : AdminTableStatus.unknown;

  /// Congruencial lineal: deterministas y sin estado global.
  static double Function() _generator(int seed) {
    const modulus = 4294967296;
    var s = seed % modulus;
    if (s < 0) s += modulus;
    return () {
      s = (s * 1664525 + 1013904223) % modulus;
      return s / modulus;
    };
  }
}

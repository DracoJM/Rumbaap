/// Identidades de DEMOSTRACIÓN para recorrer el prototipo por perfiles.
///
/// No hay contraseñas ni autenticación: elegir una identidad no demuestra
/// quién es la persona. La cédula identifica una cuenta ficticia (R8), nunca
/// es una contraseña. Autenticación real: `NOT DECIDED`.
library;

enum DemoProfile { client, promoter, admin, staff }

/// Responsabilidad del personal en la demo. Cada una ve solo sus tareas;
/// no hay autenticación real.
enum StaffRole { security, cashier, waiter }

class DemoIdentity {
  const DemoIdentity({
    required this.id,
    required this.name,
    required this.profile,
    this.idNumber,
    this.phone,
    this.staffRole,
  });

  final String id;
  final String name;
  final DemoProfile profile;

  /// Cédula de la cuenta ficticia (solo clientes).
  final String? idNumber;
  final String? phone;

  /// Solo para el perfil de personal.
  final StaffRole? staffRole;
}

abstract final class DemoIdentities {
  static const all = [
    DemoIdentity(
      id: 'cliente-a',
      name: 'Cliente demo A',
      profile: DemoProfile.client,
      idNumber: '1000000001',
      phone: '3000000001',
    ),
    DemoIdentity(
      id: 'cliente-b',
      name: 'Cliente demo B',
      profile: DemoProfile.client,
      idNumber: '1000000002',
      phone: '3000000002',
    ),
    DemoIdentity(
      id: 'promotor-1',
      name: 'Promotor demo',
      profile: DemoProfile.promoter,
    ),
    DemoIdentity(
      id: 'admin-1',
      name: 'Administrador (demostración)',
      profile: DemoProfile.admin,
    ),
    DemoIdentity(
      id: 'seguridad-1',
      name: 'Seguridad demo',
      profile: DemoProfile.staff,
      staffRole: StaffRole.security,
    ),
    DemoIdentity(
      id: 'caja-1',
      name: 'Caja demo',
      profile: DemoProfile.staff,
      staffRole: StaffRole.cashier,
    ),
    DemoIdentity(
      id: 'personal-1',
      name: 'Mesero demo',
      profile: DemoProfile.staff,
      staffRole: StaffRole.waiter,
    ),
  ];

  static List<DemoIdentity> of(DemoProfile profile) =>
      all.where((i) => i.profile == profile).toList(growable: false);

  /// Cuenta ficticia con esa cédula exacta (R12). Nunca se busca por nombre
  /// ni por teléfono; sin coincidencia exacta no hay vínculo.
  static DemoIdentity? accountByIdNumber(String? idNumber) {
    if (idNumber == null || idNumber.isEmpty) return null;
    for (final i in all) {
      if (i.profile == DemoProfile.client && i.idNumber == idNumber) return i;
    }
    return null;
  }

  static DemoIdentity? byId(String? id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return null;
  }
}

extension DemoProfileLabels on DemoProfile {
  String get label => switch (this) {
    DemoProfile.client => 'Cliente',
    DemoProfile.promoter => 'Promotor',
    DemoProfile.admin => 'Administración',
    DemoProfile.staff => 'Personal',
  };

  String get summary => switch (this) {
    DemoProfile.client =>
      'Consulta las noches de esta semana y reserva a tu nombre o al de '
          'otra persona.',
    DemoProfile.promoter =>
      'Reserva para tus clientes, también en noches futuras.',
    DemoProfile.admin =>
      'Gestiona reservas, pagos VIP por verificar, llegadas y mesas.',
    DemoProfile.staff =>
      'Seguridad valida entradas, Caja entrega manillas y el mesero '
          'registra llegadas a mesas.',
  };
}

extension StaffRoleLabels on StaffRole {
  String get label => switch (this) {
    StaffRole.security => 'Seguridad',
    StaffRole.cashier => 'Caja',
    StaffRole.waiter => 'Mesero / barra',
  };
}

/// Código del QR PERSONAL de una cuenta ficticia: solo identifica la cuenta.
/// No es un pago, no prueba la edad y no es una entrada.
String personalQrCode(DemoIdentity identity) =>
    'QRP-${identity.id.toUpperCase()}';

import 'dart:ui';

import '../../../theme/status_colors.dart';
import '../../reservations/domain/venue_table.dart';
import '../domain/admin_table_status.dart';

/// Textos de la maqueta aprobada «Noche de cristal» v7.
extension AdminTableStatusLabels on AdminTableStatus {
  String get label => switch (this) {
    AdminTableStatus.available => 'Disponible',
    AdminTableStatus.reserved => 'Reservada',
    AdminTableStatus.inProgress => 'En proceso',
    AdminTableStatus.occupied => 'Ocupada',
    AdminTableStatus.vipPaymentPending => 'Pago VIP pendiente',
    AdminTableStatus.unknown => 'Sin información',
  };

  /// Nombre en plural de los chips de resumen.
  String get summaryLabel => switch (this) {
    AdminTableStatus.available => 'Disponibles',
    AdminTableStatus.reserved => 'Reservadas',
    AdminTableStatus.inProgress => 'En proceso',
    AdminTableStatus.occupied => 'Ocupadas',
    AdminTableStatus.vipPaymentPending => 'Pago VIP',
    AdminTableStatus.unknown => 'Sin info',
  };

  Color colorIn(StatusColors colors) => switch (this) {
    AdminTableStatus.available => colors.available,
    AdminTableStatus.reserved => colors.reserved,
    AdminTableStatus.inProgress => colors.inProgress,
    AdminTableStatus.occupied => colors.occupied,
    AdminTableStatus.vipPaymentPending => colors.vipPaymentPending,
    AdminTableStatus.unknown => colors.unknown,
  };
}

extension AdminTableLabels on VenueTable {
  String get adminName => 'Mesa $id';

  /// Texto dentro del disco de la mesa en el plano.
  String get mapLabel => isVip ? id.replaceAll(' ', '') : id.substring(1);

  /// Texto del icono de la ficha.
  String get sheetBadge => isVip ? 'VIP' : id.substring(1);

  String get adminDescription => isVip
      ? 'Tarima VIP · hasta 20 personas · \$2.000.000 COP · incluye 6 '
            'entradas de cortesía.'
      : '${zone == TableZone.west ? 'Costado occidental' : 'Costado oriental'}'
            ' · Salón principal · capacidad y consumo mínimo por confirmar '
            'con Sagsa.';

  /// Acción de la ficha abierta.
  String actionFor(AdminTableStatus status) => switch (status) {
    AdminTableStatus.available => isVip ? 'Crear reserva VIP' : 'Crear reserva',
    AdminTableStatus.reserved => 'Ver reserva',
    AdminTableStatus.inProgress => 'Revisar solicitud',
    AdminTableStatus.occupied => 'Ver mesa',
    AdminTableStatus.vipPaymentPending => 'Ver pago VIP',
    AdminTableStatus.unknown => 'Actualizar estado',
  };

  /// Acción de la ficha cerrada, en corto.
  String shortActionFor(AdminTableStatus status) => switch (status) {
    AdminTableStatus.available => 'Reservar',
    AdminTableStatus.reserved => 'Ver',
    AdminTableStatus.inProgress => 'Revisar',
    AdminTableStatus.occupied => 'Ver',
    AdminTableStatus.vipPaymentPending => 'Ver pago',
    AdminTableStatus.unknown => 'Actualizar',
  };
}

abstract final class NightLabels {
  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// «Dom 11 oct».
  static String short(DateTime date) =>
      '${_days[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  static const opening = 'Noche desde las 22:00';
}

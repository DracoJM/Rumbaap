import 'package:flutter/material.dart';

import 'venue_theme.dart';

/// Colores semánticos de estado de mesa. Son los mismos en todas las
/// discotecas; solo el pago VIP pendiente toma el dorado VIP del local.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.available,
    required this.reserved,
    required this.inProgress,
    required this.occupied,
    required this.unknown,
    required this.vipPaymentPending,
  });

  factory StatusColors.forVenue(VenueTheme venue) => StatusColors(
    available: const Color(0xFF6FCF9F),
    reserved: const Color(0xFF82A8E8),
    inProgress: const Color(0xFFE5C06A),
    occupied: const Color(0xFFD987B0),
    unknown: const Color(0xFF8A8A9C),
    vipPaymentPending: venue.vip,
  );

  final Color available;
  final Color reserved;
  final Color inProgress;
  final Color occupied;
  final Color unknown;
  final Color vipPaymentPending;

  static StatusColors of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({
    Color? available,
    Color? reserved,
    Color? inProgress,
    Color? occupied,
    Color? unknown,
    Color? vipPaymentPending,
  }) => StatusColors(
    available: available ?? this.available,
    reserved: reserved ?? this.reserved,
    inProgress: inProgress ?? this.inProgress,
    occupied: occupied ?? this.occupied,
    unknown: unknown ?? this.unknown,
    vipPaymentPending: vipPaymentPending ?? this.vipPaymentPending,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      available: Color.lerp(available, other.available, t)!,
      reserved: Color.lerp(reserved, other.reserved, t)!,
      inProgress: Color.lerp(inProgress, other.inProgress, t)!,
      occupied: Color.lerp(occupied, other.occupied, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      vipPaymentPending: Color.lerp(
        vipPaymentPending,
        other.vipPaymentPending,
        t,
      )!,
    );
  }
}

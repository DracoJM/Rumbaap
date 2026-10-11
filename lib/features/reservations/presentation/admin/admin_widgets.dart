import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../theme/status_colors.dart';
import '../../../../theme/venue_theme.dart';
import '../../../venues/venue_config.dart';
import '../../domain/reservation.dart';
import '../table_presentation.dart';
import 'admin_labels.dart';

/// Recuadro informativo con icono.
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Flexible(
              child: Text(text, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Text(
                '($count)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de una reserva con icono, color y texto (no solo color).
class ReservationStatusChip extends StatelessWidget {
  const ReservationStatusChip({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final color = reservation.statusColorIn(StatusColors.of(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(reservation.statusIcon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                reservation.statusLabel,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Datos del titular y de la reserva. Solo para la vista del administrador.
class HolderCard extends StatelessWidget {
  const HolderCard({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final holder = r.holder;
    final theme = Theme.of(context);
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(r.holderName, style: theme.textTheme.titleMedium),
              const _FictionalTag(),
            ],
          ),
          if (holder == null)
            line(
              Icons.hourglass_top_rounded,
              'El titular se registra al enviar el trámite.',
            )
          else ...[
            line(
              Icons.badge_outlined,
              (holder.idNumber ?? '').isEmpty
                  ? 'Sin cédula (reserva por nombre)'
                  : 'Cédula ${holder.idNumber}',
            ),
            line(
              Icons.phone_outlined,
              holder.phone == null
                  ? 'Sin teléfono'
                  : 'Teléfono ${holder.phone}',
            ),
            line(
              Icons.link_rounded,
              r.linkedAccountId == null
                  ? 'Sin cuenta vinculada'
                  : 'Cuenta ficticia vinculada: ${r.linkedAccountId}',
            ),
          ],
          line(
            Icons.confirmation_number_outlined,
            'Reserva ${r.id} · ${r.originLabel}',
          ),
        ],
      ),
    );
  }
}

class _FictionalTag extends StatelessWidget {
  const _FictionalTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'DATO FICTICIO',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.amberSoft,
        ),
      ),
    );
  }
}

/// Historial de una reserva, del más antiguo al más reciente, en hora de
/// Colombia.
class ReservationHistory extends StatelessWidget {
  const ReservationHistory({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in reservation.history)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventLabel(e.type),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        venueDateTimeLabel(e.at),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Fila de una reserva en las listas del administrador.
class ReservationTile extends StatelessWidget {
  const ReservationTile({
    super.key,
    required this.reservation,
    required this.subtitle,
    required this.onTap,
  });

  final Reservation reservation;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final table = r.tableIn(VenueScope.of(context).venue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  _TableBadge(label: table.id, vip: table.isVip),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${table.displayName} · ${r.holderName}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              r.statusIcon,
                              size: 14,
                              color: r.statusColorIn(StatusColors.of(context)),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${r.statusLabel} · $subtitle',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textFaint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableBadge extends StatelessWidget {
  const _TableBadge({required this.label, required this.vip});

  final String label;
  final bool vip;

  @override
  Widget build(BuildContext context) {
    final venue = VenueTheme.of(context);
    final accent = vip ? venue.vip : venue.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color.lerp(accent, Colors.white, 0.35),
        ),
      ),
    );
  }
}

/// Aviso flotante del resultado de una acción.
void showResultMessage(
  ScaffoldMessengerState messenger,
  String text, {
  bool error = false,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? AppColors.danger : const Color(0xFF34D399),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
}

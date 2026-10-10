import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_presentation.dart';

/// Datos públicos de una mesa en la noche consultada. No muestra clientes
/// ni reservas, y no ofrece acciones sobre la mesa.
class TableDetail extends StatelessWidget {
  const TableDetail({
    super.key,
    required this.table,
    required this.status,
    required this.nightLabel,
    required this.onClose,
  });

  final VenueTable table;
  final TableMapStatus status;
  final String nightLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                table.displayName,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(status: status),
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.table_restaurant_rounded,
          label: 'Tipo',
          value: table.kindLabel,
        ),
        _InfoRow(
          icon: Icons.place_outlined,
          label: 'Ubicación',
          value: table.zoneLabel,
        ),
        _InfoRow(
          icon: Icons.calendar_today_rounded,
          label: 'Noche consultada',
          value: nightLabel,
        ),
        _InfoRow(
          icon: Icons.people_outline_rounded,
          label: 'Capacidad',
          value: table.isVip ? 'Hasta 20 personas' : 'Por confirmar',
        ),
        const SizedBox(height: 8),
        Text('Condiciones', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final line in _conditions(table)) _Bullet(text: line),
      ],
    );
  }

  static List<String> _conditions(VenueTable table) => table.isVip
      ? const [
          'Consumo prepagado de 2.000.000 COP por mesa.',
          'Las dos mesas VIP juntas: hasta 40 personas y 4.000.000 COP; '
              'siguen siendo dos mesas.',
        ]
      : const [
          'Reserva sin costo ni prepago.',
          'Consumo de referencia de 400.000 COP; el personal valida la '
              'tolerancia.',
          'Confirmación automática al completar la reserva.',
        ];
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final TableMapStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 18, color: status.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status.label,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 8),
            child: Icon(Icons.circle, size: 6, color: AppColors.amber),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

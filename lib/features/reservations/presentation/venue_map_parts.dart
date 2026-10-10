import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/night_schedule.dart';
import 'table_presentation.dart';

/// Piezas de la pantalla del mapa compartidas por la consulta pública y la
/// vista del administrador.

class DemoDataTag extends StatelessWidget {
  const DemoDataTag({super.key, this.text = 'Datos de demostración'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: AppColors.amber,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.amberSoft),
          ),
        ),
      ],
    );
  }
}

class NightSelector extends StatelessWidget {
  const NightSelector({
    super.key,
    required this.nights,
    required this.selectedId,
    required this.venueNow,
    required this.weeksAhead,
    required this.onSelected,
    required this.onWeekChanged,
  });

  final List<Night> nights;
  final String? selectedId;
  final DateTime venueNow;
  final int weeksAhead;
  final ValueChanged<String> onSelected;
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fin de semana anterior',
            onPressed: weeksAhead > 0
                ? () => onWeekChanged(weeksAhead - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          // Wrap en lugar de una fila desplazable: todas las noches quedan a
          // la vista aunque el ancho se reduzca (p. ej. con el panel abierto).
          Expanded(
            child: nights.isEmpty
                ? const Text(
                    'No hay noches para consultar en este fin de semana.',
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final night in nights)
                        ChoiceChip(
                          key: ValueKey('night-${night.id}'),
                          label: Text(
                            night.isInProgress(venueNow)
                                ? '${night.shortLabel} · En curso'
                                : night.shortLabel,
                          ),
                          tooltip: night.label,
                          selected: night.id == selectedId,
                          onSelected: (_) {
                            if (night.id != selectedId) onSelected(night.id);
                          },
                        ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: 'Fin de semana siguiente',
            onPressed: () => onWeekChanged(weeksAhead + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class PickTableButton extends StatelessWidget {
  const PickTableButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.format_list_bulleted_rounded),
      label: const Text(
        'Elegir mesa',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (final status in TableMapStatus.values)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 4),
                  Text(status.label, style: style),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No se pudo consultar la disponibilidad de esta noche.',
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class LoadingPill extends StatelessWidget {
  const LoadingPill({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(child: Text('Consultando disponibilidad…')),
          ],
        ),
      ),
    );
  }
}

class BottomSheetPanel extends StatelessWidget {
  const BottomSheetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: child,
      ),
    );
  }
}

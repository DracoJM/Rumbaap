import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_presentation.dart';
import 'venue_map_controller.dart';

/// Forma alternativa de seleccionar mesa sin acertar sobre el dibujo del
/// plano. Lee y escribe en el mismo [VenueMapController] que el mapa.
Future<void> showTablePicker(
  BuildContext context,
  VenueMapController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    builder: (sheetContext) => _TablePicker(
      controller: controller,
      onPicked: (id) {
        controller.selectTable(id);
        Navigator.of(sheetContext).pop();
      },
    ),
  );
}

class _TablePicker extends StatelessWidget {
  const _TablePicker({required this.controller, required this.onPicked});

  final VenueMapController controller;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Elegir mesa', style: theme.textTheme.titleLarge),
                if (controller.night case final night?)
                  Text(
                    night.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final table in VenueTables.all)
                  _TableRow(
                    table: table,
                    status: TableMapStatus.from(
                      controller.availabilityOf(table.id),
                    ),
                    selected: table.id == controller.selectedTableId,
                    onTap: () => onPicked(table.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.table,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final VenueTable table;
  final TableMapStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${table.displayName}, ${status.label}, ${table.zoneLabel}',
      // excludeSemantics oculta la acción del ListTile interior, así que la
      // acción se publica aquí para lectores de pantalla.
      onTap: onTap,
      excludeSemantics: true,
      child: ListTile(
        key: ValueKey('picker-${table.id}'),
        minTileHeight: 56,
        selected: selected,
        selectedTileColor: AppColors.violet.withValues(alpha: 0.18),
        leading: Icon(status.icon, color: status.color),
        title: Text(table.displayName),
        subtitle: Text(table.zoneLabel),
        trailing: Text(status.label),
        onTap: onTap,
      ),
    );
  }
}

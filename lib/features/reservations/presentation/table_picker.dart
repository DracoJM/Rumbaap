import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../venues/venue_config.dart';
import '../domain/venue_table.dart';
import 'map/status_icon.dart';
import 'table_presentation.dart';
import 'venue_map_controller.dart';

/// «Buscar mesa»: alternativa accesible para seleccionar una mesa sin acertar
/// sobre el dibujo del plano (en móviles pequeños las franjas miden menos de
/// 48 dp). No repite el plano como listado: solo muestra las mesas que
/// coinciden con lo escrito. Elegir una la selecciona en el mismo
/// [VenueMapController] que el mapa y abre su ficha.
Future<void> showTableSearch(
  BuildContext context,
  VenueMapController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceRaised,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.75,
    ),
    builder: (sheetContext) => Padding(
      // El teclado no tapa los resultados.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _TableSearch(
        controller: controller,
        onPicked: (id) {
          controller.selectTable(id);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );
}

/// Coincidencia de búsqueda: nombre o número de la mesa, zona o estado.
/// Ignora mayúsculas, espacios y la palabra «mesa».
bool tableMatches(VenueTable table, TableMapStatus status, String query) {
  String norm(String s) =>
      s.toLowerCase().replaceAll('mesa', '').replaceAll(' ', '');
  final q = norm(query);
  if (q.isEmpty) return false;
  return norm(table.displayName).contains(q) ||
      norm(table.id).contains(q) ||
      norm(table.zoneLabel).contains(q) ||
      norm(status.label).contains(q);
}

class _TableSearch extends StatefulWidget {
  const _TableSearch({required this.controller, required this.onPicked});

  final VenueMapController controller;
  final ValueChanged<String> onPicked;

  @override
  State<_TableSearch> createState() => _TableSearchState();
}

class _TableSearchState extends State<_TableSearch> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      // Una sola lista con la cabecera dentro: con texto grande o en
      // horizontal, todo sigue siendo alcanzable.
      builder: (context, _) {
        final results = [
          for (final table in VenueScope.of(context).venue.tables)
            if (TableMapStatus.from(
                  controller.availabilityOf(table.id),
                  table: table,
                )
                case final status when tableMatches(table, status, _query.text))
              (table: table, status: status),
        ];
        final empty = _query.text.trim().isEmpty;
        return ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Buscar mesa', style: theme.textTheme.titleLarge),
                  if (controller.night case final night?)
                    Text(
                      night.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('table-search'),
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (results.length == 1) {
                        widget.onPicked(results.single.table.id);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Número, nombre, zona o estado',
                      hintText: 'Por ejemplo: 7, VIP o disponible',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    empty
                        ? 'Escribe para buscar una mesa del plano.'
                        : results.isEmpty
                        ? 'Ninguna mesa coincide.'
                        : '${results.length} '
                              '${results.length == 1 ? 'mesa' : 'mesas'}',
                    key: const ValueKey('table-search-count'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            for (final (:table, :status) in results)
              _TableRow(
                table: table,
                status: status,
                selected: table.id == controller.selectedTableId,
                onTap: () => widget.onPicked(table.id),
              ),
          ],
        );
      },
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
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.18),
        leading: StatusIcon(status: status, size: 26),
        title: Text(table.displayName),
        // El estado va bajo la zona y no a la derecha: con texto grande
        // ocupa las líneas que necesite sin recortarse.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(table.zoneLabel),
            Text(
              status.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

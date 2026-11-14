import 'package:flutter/material.dart';

import '../../../../theme/status_colors.dart';
import '../../../../theme/venue_theme.dart';
import '../../../venues/venue_config.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';
import 'crystal_layout.dart';
import 'crystal_table.dart';
import 'map_clock.dart';
import 'venue_light_painters.dart';
import 'venue_static_painters.dart';

/// Componente único del mapa «Noche de cristal» v7, compartido por todas las
/// perspectivas (consulta pública y administración). Dibuja el local que le
/// llega por [VenueScope] y los estados y la selección que le pasa cada
/// pantalla; no consulta datos ni decide acciones.
///
/// Las capas fijas y las animadas van separadas en RepaintBoundary: cada
/// fotograma solo repinta las capas de luces, nunca el plano ni las mesas.
class CrystalVenueMap extends StatelessWidget {
  const CrystalVenueMap({
    super.key,
    required this.statusOf,
    required this.selectedTableId,
    required this.onTableTap,
    required this.clock,
    this.isDimmed,
  });

  final TableMapStatus Function(VenueTable table) statusOf;
  final String? selectedTableId;
  final ValueChanged<String> onTableTap;
  final MapClock clock;

  /// Mesas atenuadas por un filtro; `null` = ninguna.
  final bool Function(VenueTable table)? isDimmed;

  @override
  Widget build(BuildContext context) {
    final config = VenueScope.of(context);
    final layout = config.layout;
    final venue = config.venue;
    final theme = VenueTheme.of(context);
    final colors = StatusColors.of(context);
    Widget layer(CustomPainter painter) => Positioned.fill(
      child: RepaintBoundary(child: CustomPaint(painter: painter)),
    );

    final selected = selectedTableId == null
        ? null
        : venue.tableById(selectedTableId!);
    final ring = selected == null ? null : layout.placementOf(selected.id);

    final canvas = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          layer(VenueBasePainter(theme, layout)),
          layer(FloorLightsPainter(theme, layout, clock)),
          layer(BarPainter(theme, layout)),
          layer(BeamsPainter(theme, layout, clock)),
          layer(BoothPainter(theme, layout)),
          layer(BoothLightsPainter(theme, layout, clock)),
          if (selected != null && ring != null)
            _selectionRing(selected, ring, statusOf(selected).colorIn(colors)),
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final table in venue.tables)
                    if (layout.placementOf(table.id) case final placement?)
                      Positioned.fromRect(
                        rect: placement.hitRect,
                        child: CrystalTable(
                          key: ValueKey('table-${table.id}'),
                          table: table,
                          placement: placement,
                          status: statusOf(table),
                          color: statusOf(table).colorIn(colors),
                          selected: table.id == selectedTableId,
                          dimmed: isDimmed?.call(table) ?? false,
                          animate: clock.animating,
                          onTap: () => onTableTap(table.id),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: 'Plano de ${venue.name}, ${venue.tables.length} mesas',
      child: AspectRatio(
        aspectRatio: layout.size.width / layout.size.height,
        child: FittedBox(child: canvas),
      ),
    );
  }

  Widget _selectionRing(VenueTable table, TablePlacement at, Color color) {
    final spec = FurnitureSpec.of(table);
    final box = (spec.outer + 1.5) * 2 * 1.4;
    return Positioned.fromRect(
      rect: Rect.fromCenter(center: at.center, width: box, height: box),
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SelectionRingPainter(
              clock: clock,
              color: color,
              spec: spec,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import 'table_detail.dart';
import 'table_picker.dart';
import 'table_presentation.dart';
import 'venue_map.dart';
import 'venue_map_controller.dart';
import 'venue_map_parts.dart';

/// «Mapa y disponibilidad»: consulta de estados por noche.
class VenueMapPage extends StatefulWidget {
  const VenueMapPage({
    super.key,
    required this.repository,
    this.clock = systemClock,
    this.changes,
  });

  final NightAvailabilityRepository repository;
  final Clock clock;

  /// Aviso de cambios en los datos: la consulta abierta se actualiza sola.
  final Listenable? changes;

  /// Ancho a partir del cual el detalle va en un panel lateral en lugar de
  /// una hoja inferior (tabletas). En horizontal también se usa el panel
  /// lateral, para que la hoja inferior no deje el mapa sin altura.
  static const sidePanelBreakpoint = 600.0;

  @override
  State<VenueMapPage> createState() => _VenueMapPageState();
}

class _VenueMapPageState extends State<VenueMapPage> {
  late final VenueMapController _controller = VenueMapController(
    widget.repository,
    clock: widget.clock,
    changes: widget.changes,
  )..start();

  // Al volver del segundo plano la hora pudo cruzar una apertura o un cierre
  // mientras el temporizador no corría.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _controller.refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text('Mapa y disponibilidad'), DemoDataTag()],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final c = _controller;
    final selected = c.selectedTable;
    final detail = selected == null
        ? null
        : TableDetail(
            key: ValueKey('detail-${selected.id}'),
            table: selected,
            status: TableMapStatus.from(
              c.availabilityOf(selected.id),
              table: selected,
            ),
            nightLabel: c.night?.label ?? '',
            onClose: c.clearSelection,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= VenueMapPage.sidePanelBreakpoint ||
            constraints.maxWidth > constraints.maxHeight;
        final mapArea = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NightSelector(
              nights: c.nights,
              selectedId: c.night?.id,
              venueNow: c.venueNow,
              weeksAhead: c.weeksAhead,
              onSelected: c.selectNight,
              onWeekChanged: c.showWeek,
            ),
            // «Elegir mesa» va en la cabecera y no sobre el mapa, para no
            // tapar mesas ni los controles de zoom en pantallas pequeñas.
            Row(
              children: [
                const Expanded(child: MapLegend()),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: PickTableButton(
                    onPressed: () => showTablePicker(context, c),
                  ),
                ),
              ],
            ),
            if (c.availabilityStatus == LoadStatus.failed)
              InlineError(onRetry: c.retry),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VenueMap(
                      statusOf: (table) => TableMapStatus.from(
                        c.availabilityOf(table.id),
                        table: table,
                      ),
                      selectedTableId: c.selectedTableId,
                      onTableTap: c.toggleTable,
                    ),
                  ),
                  if (c.availabilityStatus == LoadStatus.loading)
                    const Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(child: LoadingPill()),
                    ),
                ],
              ),
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mapArea),
              if (detail != null)
                SizedBox(
                  width: math.min(360, constraints.maxWidth * 0.45),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.border)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                      child: detail,
                    ),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: mapArea),
            if (detail != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.5,
                ),
                child: BottomSheetPanel(child: detail),
              ),
          ],
        );
      },
    );
  }
}

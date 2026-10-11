import 'package:flutter/material.dart';

import '../../venues/venue_config.dart';
import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import 'map/crystal_map_scaffold.dart';
import 'table_detail.dart';
import 'table_presentation.dart';
import 'venue_map_controller.dart';

/// «Mapa y disponibilidad»: consulta pública de estados por noche, con el
/// mapa v7 compartido. Recibe la consulta sin titulares
/// ([NightAvailabilityRepository]) y no ofrece acciones sobre las mesas.
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

  @override
  State<VenueMapPage> createState() => _VenueMapPageState();
}

class _VenueMapPageState extends State<VenueMapPage> {
  late final VenueMapController _controller = VenueMapController(
    widget.repository,
    venue: VenueScope.read(context).venue,
    clock: widget.clock,
    changes: widget.changes,
  )..start();

  // Al volver del segundo plano la hora pudo cruzar una apertura o un cierre
  // mientras el temporizador no corría.
  late final AppLifecycleListener _lifecycle;
  bool _expanded = false;

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
    return CrystalMapScaffold(
      controller: _controller,
      demoLabel: 'Datos de demostración · solo consulta',
      sheetBuilder: (context, animate) {
        final c = _controller;
        final selected = c.selectedTable;
        if (selected == null) return null;
        return TableDetail(
          key: ValueKey('detail-${selected.id}'),
          table: selected,
          status: TableMapStatus.from(
            c.availabilityOf(selected.id),
            table: selected,
          ),
          nightLabel: c.night?.label ?? '',
          onClose: c.clearSelection,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          animate: animate,
        );
      },
    );
  }
}

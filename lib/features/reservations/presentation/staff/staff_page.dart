import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../theme/night_neutrals.dart';
import '../../../session/demo_identities.dart';
import '../../../session/session_panel.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_availability.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../admin/admin_labels.dart';
import '../admin/admin_widgets.dart';
import '../map/crystal_map_scaffold.dart';
import '../map/glass_tab_bar.dart';
import '../table_presentation.dart';
import '../venue_map_controller.dart';

enum _StaffSection { arrivals, more }

/// Perspectiva del personal (mesero) en la demostración: localizar una
/// reserva de la noche y registrar la llegada (R5) durante el horario
/// permitido (N6). No ofrece revocar, liberar ni verificar prepagos.
class StaffPage extends StatefulWidget {
  const StaffPage({
    super.key,
    required this.store,
    required this.identity,
    this.clock = systemClock,
  });

  final DemoReservationStore store;
  final DemoIdentity identity;
  final Clock clock;

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late final VenueMapController _controller = VenueMapController(
    widget.store.adminView,
    venue: widget.store.venue,
    clock: widget.clock,
    changes: widget.store,
  )..start();

  late final AppLifecycleListener _lifecycle;
  final _search = TextEditingController();
  _StaffSection _section = _StaffSection.arrivals;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _controller.refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _arrive(Reservation r) async {
    final table = r.tableIn(widget.store.venue).displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Registrar la llegada?'),
        content: Text('$table · ${r.holderName}\nLa mesa pasará a Ocupada.'),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Registrar llegada'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // El libro vuelve a comprobar estado y horario (R5, N6).
      widget.store.perform((b) => b.markArrival(r.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Llegada registrada: $table queda ocupada.')),
      );
    } on ReservationException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(actionErrorMessage(e.error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // La lista depende de la consulta: se reconstruye con el controlador.
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return CrystalMapScaffold(
      controller: _controller,
      demoLabel: 'Datos ficticios · Personal (demostración)',
      sheetBuilder: (_, _) => null,
      body: switch (_section) {
        _StaffSection.arrivals => _arrivals(context),
        _StaffSection.more => SessionPanel(identity: widget.identity),
      },
      bottomBar: GlassTabBar(
        tabs: [
          GlassTab(
            icon: Icons.how_to_reg_outlined,
            label: 'Llegadas',
            selected: _section == _StaffSection.arrivals,
            onTap: () => setState(() => _section = _StaffSection.arrivals),
          ),
          GlassTab(
            icon: Icons.more_horiz_rounded,
            label: 'Más',
            selected: _section == _StaffSection.more,
            onTap: () => setState(() => _section = _StaffSection.more),
          ),
        ],
      ),
    );
  }

  Widget _arrivals(BuildContext context) {
    final c = _controller;
    final data = switch (c.availability) {
      final NightReservations d => d,
      _ => null,
    };
    final night = c.night;
    if (data == null || night == null) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Consultando reservas de la noche…'),
        ),
      );
    }
    final inProgress = night.isInProgress(c.venueNow);
    final query = _search.text.trim().toLowerCase();
    final venue = widget.store.venue;
    final candidates =
        data.reservations.where((r) {
          if (r.status != ReservationStatus.confirmed &&
              r.status != ReservationStatus.seated) {
            return false;
          }
          if (query.isEmpty) return true;
          return r.id.toLowerCase().contains(query) ||
              r.holderName.toLowerCase().contains(query) ||
              r.tableIn(venue).displayName.toLowerCase().contains(query);
        }).toList()..sort(
          (a, b) =>
              venue.orderOf(a.tableId).compareTo(venue.orderOf(b.tableId)),
        );

    return Builder(
      builder: (inner) => ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(inner).bottom,
        ),
        children: [
          TextField(
            key: const ValueKey('staff-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Buscar por mesa, titular o ID de reserva',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          if (!inProgress)
            NoticeBox(
              icon: Icons.schedule_rounded,
              color: AppColors.amber,
              text:
                  'La llegada solo se registra durante la noche, de '
                  '${night.scheduleLabel} (hora de Colombia).',
            ),
          if (candidates.isEmpty)
            const NoticeBox(
              icon: Icons.inbox_outlined,
              text: 'No hay reservas confirmadas que coincidan.',
            ),
          for (final r in candidates)
            Card(
              key: ValueKey('staff-${r.id}'),
              color: NightNeutrals.glass(0.06),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${r.tableIn(venue).displayName} · ${r.holderName}',
                      style: const TextStyle(
                        color: NightNeutrals.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r.statusLabel} · ${r.id}',
                      style: TextStyle(color: NightNeutrals.glass(0.75)),
                    ),
                    if (r.status == ReservationStatus.confirmed) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: ValueKey('staff-arrive-${r.id}'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: inProgress && !c.isRefreshing
                            ? () => _arrive(r)
                            : null,
                        icon: const Icon(Icons.how_to_reg_outlined),
                        label: const Text('Registrar llegada'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

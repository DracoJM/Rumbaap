import 'package:flutter/material.dart';

import '../../../session/demo_identities.dart';
import '../../../session/session_panel.dart';
import '../../../tickets/data/demo_ticket_store.dart';
import '../../../tickets/presentation/guest_tickets.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_availability.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/venue_table.dart';
import '../admin/admin_labels.dart';
import '../map/crystal_map_scaffold.dart';
import '../map/glass_tab_bar.dart';
import '../map/table_sheet.dart';
import '../table_detail.dart';
import '../table_presentation.dart';
import '../venue_map_controller.dart';
import 'my_reservations.dart';
import 'reservation_flow_page.dart';

enum _GuestSection { map, mine, tickets, more }

/// Perspectiva del cliente y del promotor sobre el mapa v7 compartido.
///
/// Lee la consulta pública (sin titulares ajenos) del almacén único del local.
/// Desde una mesa disponible ofrece iniciar la reserva; nunca ofrece acciones
/// del administrador.
class GuestHomePage extends StatefulWidget {
  const GuestHomePage({
    super.key,
    required this.identity,
    required this.venue,
    required this.repository,
    this.changes,
    this.store,
    this.tickets,
    this.clock = systemClock,
  });

  /// Perspectiva completa sobre el almacén de demostración del local.
  GuestHomePage.withStore({
    Key? key,
    required DemoReservationStore store,
    required DemoIdentity identity,
    DemoTicketStore? tickets,
    Clock clock = systemClock,
  }) : this(
         key: key,
         identity: identity,
         venue: store.venue,
         repository: store,
         changes: store,
         store: store,
         tickets: tickets,
         clock: clock,
       );

  final DemoIdentity identity;
  final Venue venue;

  /// Consulta pública por noche, sin titulares.
  final NightAvailabilityRepository repository;
  final Listenable? changes;

  /// Almacén donde se reserva; sin él la pantalla es solo consulta (sin
  /// «Reservar» ni «Mis reservas»).
  final DemoReservationStore? store;

  /// Entradas del local; sin él no hay pestaña «Entradas».
  final DemoTicketStore? tickets;
  final Clock clock;

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  late final VenueMapController _controller = VenueMapController(
    widget.repository,
    venue: widget.venue,
    // Cliente: su semana calendario (N5). Promotor: noches futuras (N7).
    catalog: _isClient ? NightCatalog.clientWeek : NightCatalog.operational,
    clock: widget.clock,
    changes: widget.changes,
  )..start();

  late final AppLifecycleListener _lifecycle;
  _GuestSection _section = _GuestSection.map;
  bool _expanded = false;

  bool get _isClient => widget.identity.profile == DemoProfile.client;

  ReservationOrigin get _origin =>
      _isClient ? ReservationOrigin.client : ReservationOrigin.promoter;

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

  Future<void> _reserve(
    DemoReservationStore store,
    Night night,
    VenueTable table,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String? reservationId;
    if (!table.isVip) {
      // R14: el bloqueo de 10 min empieza aquí, en el almacén compartido.
      try {
        reservationId = store
            .perform(
              (b) => b.startNormal(
                night: night,
                tableId: table.id,
                origin: _origin,
                createdBy: widget.identity.id,
              ),
            )
            .id;
      } on ReservationException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(actionErrorMessage(e.error))),
        );
        return;
      }
    }
    final result = await Navigator.of(context).push<ReservationFlowResult>(
      MaterialPageRoute(
        builder: (_) => ReservationFlowPage(
          store: store,
          clock: widget.clock,
          identity: widget.identity,
          night: night,
          table: table,
          reservationId: reservationId,
        ),
      ),
    );
    if (!mounted) return;
    if (result == ReservationFlowResult.showMine) {
      setState(() => _section = _GuestSection.mine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.identity.profile;
    return CrystalMapScaffold(
      controller: _controller,
      demoLabel: 'Datos ficticios · ${profile.label} (demostración)',
      showNight: _section == _GuestSection.map,
      body: switch (_section) {
        _GuestSection.map => null,
        _GuestSection.mine => MyReservations(
          store: widget.store!,
          identity: widget.identity,
        ),
        _GuestSection.tickets => GuestTickets(
          store: widget.tickets!,
          identity: widget.identity,
          clock: widget.clock,
        ),
        _GuestSection.more => SessionPanel(
          identity: widget.identity,
          extras: [
            if (profile == DemoProfile.client)
              PersonalQrCard(identity: widget.identity),
          ],
        ),
      },
      sheetBuilder: (context, animate) {
        if (_section != _GuestSection.map) return null;
        final c = _controller;
        final table = c.selectedTable;
        final night = c.night;
        if (table == null || night == null) return null;
        final status = TableMapStatus.from(
          c.availabilityOf(table.id),
          table: table,
        );
        final store = widget.store;
        final canReserve =
            store != null &&
            status == TableMapStatus.available &&
            !night.hasEnded(c.venueNow) &&
            !c.isRefreshing;
        return TableDetail(
          key: ValueKey('detail-${table.id}'),
          table: table,
          status: status,
          nightLabel: night.label,
          onClose: c.clearSelection,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          animate: animate,
          action: canReserve
              ? SheetAction(
                  label: 'Reservar esta mesa',
                  shortLabel: 'Reservar',
                  vip: table.isVip,
                  onPressed: () => _reserve(store, night, table),
                )
              : null,
        );
      },
      bottomBar: GlassTabBar(
        tabs: [
          GlassTab(
            icon: Icons.map_outlined,
            label: 'Mapa',
            selected: _section == _GuestSection.map,
            onTap: () => setState(() => _section = _GuestSection.map),
          ),
          if (widget.store != null)
            GlassTab(
              icon: Icons.event_note_outlined,
              label: 'Mis reservas',
              selected: _section == _GuestSection.mine,
              onTap: () => setState(() => _section = _GuestSection.mine),
            ),
          if (widget.tickets != null)
            GlassTab(
              icon: Icons.confirmation_number_outlined,
              label: 'Entradas',
              selected: _section == _GuestSection.tickets,
              onTap: () => setState(() => _section = _GuestSection.tickets),
            ),
          GlassTab(
            icon: Icons.more_horiz_rounded,
            label: 'Más',
            selected: _section == _GuestSection.more,
            onTap: () => setState(() => _section = _GuestSection.more),
          ),
        ],
      ),
    );
  }
}

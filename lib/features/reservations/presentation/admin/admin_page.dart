import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../venues/venue_config.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_availability.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_book.dart';
import '../../domain/venue_table.dart';
import '../map/crystal_map_scaffold.dart';
import '../map/glass_tab_bar.dart';
import '../map/table_sheet.dart';
import '../table_presentation.dart';
import '../venue_map_controller.dart';
import '../venue_map_parts.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';
import 'direct_reservation_page.dart';
import 'reservation_actions.dart';
import 'reservation_page.dart';

enum AdminSection { map, reservations }

/// Lista que muestra la sección Reservas.
enum AdminList { pending, reservations, activity }

/// Vista del administrador (demostración, sin autenticación real) sobre el
/// mapa v7 compartido: noche, mapa con acciones por mesa, pendientes y
/// reservas/actividad de la noche.
///
/// Lee el mismo almacén que la consulta pública, mediante
/// [DemoReservationStore.adminView]. Mapa, listas y detalle salen de la misma
/// consulta ([NightReservations]), así que coinciden.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.store, this.clock = systemClock});

  final DemoReservationStore store;
  final Clock clock;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final VenueMapController _controller = VenueMapController(
    widget.store.adminView,
    venue: widget.store.venue,
    clock: widget.clock,
    changes: widget.store,
  )..start();

  late final AppLifecycleListener _lifecycle;
  AdminSection _section = AdminSection.map;
  AdminList _list = AdminList.pending;
  bool _sheetExpanded = false;

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

  NightReservations? get _data => switch (_controller.availability) {
    final NightReservations data => data,
    _ => null,
  };

  void _openReservation(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReservationPage(
        store: widget.store,
        reservationId: id,
        clock: widget.clock,
      ),
    ),
  );

  void _openDirectForm(Night night, VenueTable table) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DirectReservationPage(
            store: widget.store,
            night: night,
            table: table,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final pendingVip =
            _data?.reservations
                .where((r) => r.status == ReservationStatus.pendingPayment)
                .length ??
            0;
        return CrystalMapScaffold(
          controller: _controller,
          demoLabel: 'Datos ficticios · sin autenticación real',
          body: switch (_section) {
            AdminSection.map => null,
            AdminSection.reservations => _listsSection(),
          },
          sheetBuilder: (context, animate) =>
              _section == AdminSection.map ? _sheet(animate) : null,
          bottomBar: GlassTabBar(
            tabs: [
              GlassTab(
                icon: Icons.map_outlined,
                label: 'Mapa',
                selected: _section == AdminSection.map,
                onTap: () => _select(AdminSection.map),
              ),
              GlassTab(
                icon: Icons.event_available_outlined,
                label: 'Reservas',
                selected: _section == AdminSection.reservations,
                badge: pendingVip,
                onTap: () => _select(AdminSection.reservations),
              ),
              // Pendientes de desarrollo: se muestran sin simular su
              // operación.
              const GlassTab(
                icon: Icons.confirmation_number_outlined,
                label: 'Entradas',
              ),
              const GlassTab(icon: Icons.local_bar_outlined, label: 'Pedidos'),
              const GlassTab(icon: Icons.more_horiz_rounded, label: 'Más'),
            ],
          ),
        );
      },
    );
  }

  void _select(AdminSection section) => setState(() => _section = section);

  // ------------------------------------------------------------- Ficha

  Widget? _sheet(bool animate) {
    final c = _controller;
    final table = c.selectedTable;
    final night = c.night;
    if (table == null || night == null) return null;
    final data = _data;
    final status = TableMapStatus.from(
      c.availabilityOf(table.id),
      table: table,
    );
    final active = data?.activeFor(table.id);
    final ended = night.hasEnded(c.venueNow);
    final busy = c.isRefreshing;

    final SheetAction action;
    if (data == null || status == TableMapStatus.unknown) {
      // Sin datos no se ofrece reservar a ciegas: solo volver a consultar.
      action = SheetAction(
        label: 'Actualizar estado',
        shortLabel: 'Actualizar',
        onPressed: c.availabilityStatus == LoadStatus.failed ? c.retry : null,
      );
    } else if (active != null) {
      action = SheetAction(
        label: switch (status) {
          TableMapStatus.pending => 'Revisar solicitud',
          TableMapStatus.pendingPayment => 'Ver pago VIP',
          TableMapStatus.occupied => 'Ver mesa',
          _ => 'Ver reserva',
        },
        shortLabel: switch (status) {
          TableMapStatus.pending => 'Revisar',
          TableMapStatus.pendingPayment => 'Ver pago',
          _ => 'Ver',
        },
        vip: table.isVip,
        onPressed: () => _openReservation(active.id),
      );
    } else {
      action = SheetAction(
        label: table.isVip ? 'Crear reserva VIP' : 'Crear reserva',
        shortLabel: 'Reservar',
        vip: table.isVip,
        onPressed: ended || busy ? null : () => _openDirectForm(night, table),
      );
    }

    return TableSheet(
      key: ValueKey('admin-sheet-${night.id}-${table.id}'),
      table: table,
      badge:
          VenueScope.of(context).layout.placementOf(table.id)?.label ??
          table.id,
      status: status,
      expanded: _sheetExpanded,
      animate: animate,
      onToggle: () => setState(() => _sheetExpanded = !_sheetExpanded),
      onClose: c.clearSelection,
      action: action,
      details: _AdminTablePanel(
        key: ValueKey('admin-panel-${night.id}-${table.id}'),
        table: table,
        night: night,
        controller: c,
        data: data,
        store: widget.store,
        clock: widget.clock,
        onOpenReservation: _openReservation,
        onCreate: () => _openDirectForm(night, table),
      ),
    );
  }

  // ---------------------------------------------------------- Listas

  Widget _listsSection() {
    final body = _listState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Una línea por segmento: con texto grande la fila se desplaza en
        // horizontal en lugar de crecer en alto y quitar sitio a la lista.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<AdminList>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: AdminList.pending,
                label: Text('Pendientes', softWrap: false),
              ),
              ButtonSegment(
                value: AdminList.reservations,
                label: Text('Reservas', softWrap: false),
              ),
              ButtonSegment(
                value: AdminList.activity,
                label: Text('Actividad', softWrap: false),
              ),
            ],
            selected: {_list},
            onSelectionChanged: (s) => setState(() => _list = s.first),
          ),
        ),
        Expanded(
          // El contexto de dentro del Scaffold del mapa: su relleno inferior
          // incluye la barra de cristal.
          child: Builder(
            builder: (inner) =>
                body ??
                switch (_list) {
                  AdminList.pending => _pendingSection(inner, _data!),
                  AdminList.reservations => _reservationsSection(inner, _data!),
                  AdminList.activity => _activitySection(inner, _data!),
                },
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- Listas: estado

  /// Carga, error o falta de noche: las listas no muestran datos parciales.
  Widget? _listState() {
    final c = _controller;
    if (c.night == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: NoticeBox(
          icon: Icons.event_busy_outlined,
          text: 'No hay noches para consultar en este fin de semana.',
        ),
      );
    }
    if (c.availabilityStatus == LoadStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [InlineError(onRetry: c.retry)],
      );
    }
    if (_data == null) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(padding: EdgeInsets.all(16), child: LoadingPill()),
      );
    }
    return null;
  }

  // ---------------------------------------------------------- Pendientes

  Widget _pendingSection(BuildContext inner, NightReservations data) {
    final vip = _byTable(
      data.reservations.where(
        (r) => r.status == ReservationStatus.pendingPayment,
      ),
    );
    final inProcess = _byTable(
      data.reservations.where((r) => r.status == ReservationStatus.inProcess),
    );
    return ListView(
      padding: _listPadding(inner, 4),
      children: [
        SectionLabel('Pagos VIP por verificar', count: vip.length),
        if (vip.isEmpty)
          const NoticeBox(
            icon: Icons.inbox_outlined,
            text: 'No hay pagos VIP por verificar en esta noche.',
          )
        else
          for (final r in vip)
            ReservationTile(
              key: ValueKey('pending-${r.id}'),
              reservation: r,
              subtitle: 'Solicitada ${venueDateTimeLabel(r.createdAt)}',
              onTap: () => _openReservation(r.id),
            ),
        const SizedBox(height: 12),
        SectionLabel('Mesas normales en proceso', count: inProcess.length),
        const NoticeBox(
          icon: Icons.hourglass_top_rounded,
          text:
              'Se confirman solas al completar el trámite o expiran a los '
              '10 min. No requieren acción del administrador.',
        ),
        const SizedBox(height: 8),
        if (inProcess.isEmpty)
          const NoticeBox(
            icon: Icons.inbox_outlined,
            text: 'No hay mesas normales en proceso en esta noche.',
          )
        else
          for (final r in inProcess)
            ReservationTile(
              key: ValueKey('pending-${r.id}'),
              reservation: r,
              subtitle:
                  'Vence a las '
                  '${venueTimeLabel(r.createdAt.add(ReservationBook.inProcessTimeout))}',
              onTap: () => _openReservation(r.id),
            ),
      ],
    );
  }

  // ----------------------------------------------- Reservas y actividad

  Widget _reservationsSection(BuildContext inner, NightReservations data) {
    final active = _byTable(data.reservations.where((r) => r.status.isActive));
    final ended = _byTable(data.reservations.where((r) => !r.status.isActive));
    return ListView(
      padding: _listPadding(inner, 8),
      children: [
        SectionLabel('Activas', count: active.length),
        if (active.isEmpty)
          const NoticeBox(
            icon: Icons.inbox_outlined,
            text: 'No hay reservas activas en esta noche.',
          ),
        for (final r in active)
          ReservationTile(
            key: ValueKey('reservation-${r.id}'),
            reservation: r,
            subtitle: '${r.id} · ${r.originLabel}',
            onTap: () => _openReservation(r.id),
          ),
        const SizedBox(height: 8),
        SectionLabel(
          'Terminadas (revocadas, rechazadas, liberadas o expiradas)',
          count: ended.length,
        ),
        if (ended.isEmpty)
          const NoticeBox(
            icon: Icons.inbox_outlined,
            text: 'Ninguna reserva de esta noche ha terminado.',
          ),
        for (final r in ended)
          ReservationTile(
            key: ValueKey('reservation-${r.id}'),
            reservation: r,
            subtitle: '${r.id} · ${r.originLabel}',
            onTap: () => _openReservation(r.id),
          ),
      ],
    );
  }

  Widget _activitySection(BuildContext inner, NightReservations data) {
    final events = [
      for (final r in data.reservations)
        for (final e in r.history) (reservation: r, event: e),
    ]..sort((a, b) => b.event.at.compareTo(a.event.at));
    return ListView(
      padding: _listPadding(inner, 8),
      children: [
        SectionLabel('Actividad de la noche', count: events.length),
        if (events.isEmpty)
          const NoticeBox(
            icon: Icons.inbox_outlined,
            text: 'Todavía no hay actividad en esta noche.',
          ),
        for (final (:reservation, :event) in events)
          _ActivityRow(
            reservation: reservation,
            event: event,
            onTap: () => _openReservation(reservation.id),
          ),
        const SizedBox(height: 8),
        Text(
          'Lista local de demostración; no es un registro de auditoría.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textFaint),
        ),
      ],
    );
  }

  /// Relleno de las listas: abajo deja libre la barra de cristal, que va
  /// encima de la lista (`extendBody`), para que la última fila se pueda
  /// ver y tocar.
  static EdgeInsets _listPadding(BuildContext inner, double top) =>
      EdgeInsets.fromLTRB(16, top, 16, 24 + MediaQuery.paddingOf(inner).bottom);

  List<Reservation> _byTable(Iterable<Reservation> reservations) {
    final venue = widget.store.venue;
    return reservations.toList()..sort((a, b) {
      final byTable = venue
          .orderOf(a.tableId)
          .compareTo(venue.orderOf(b.tableId));
      return byTable != 0 ? byTable : a.createdAt.compareTo(b.createdAt);
    });
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.reservation,
    required this.event,
    required this.onTap,
  });

  final Reservation reservation;
  final ReservationEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  venueDateTimeLabel(event.at),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventLabel(event.type),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      '${reservation.tableIn(VenueScope.of(context).venue).displayName} · '
                      '${reservation.holder.name} · ${reservation.id}',
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
      ),
    );
  }
}

/// Panel de la mesa seleccionada en el mapa del administrador.
class _AdminTablePanel extends StatelessWidget {
  const _AdminTablePanel({
    super.key,
    required this.table,
    required this.night,
    required this.controller,
    required this.data,
    required this.store,
    required this.clock,
    required this.onOpenReservation,
    required this.onCreate,
  });

  final VenueTable table;
  final Night night;
  final VenueMapController controller;
  final NightReservations? data;
  final DemoReservationStore store;
  final Clock clock;
  final ValueChanged<String> onOpenReservation;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = TableMapStatus.from(
      controller.availabilityOf(table.id),
      table: table,
    );
    final data = this.data;
    final active = data?.activeFor(table.id);
    final previous = [
      for (final r in data?.reservations ?? const <Reservation>[])
        if (r.tableId == table.id && !r.status.isActive) r,
    ];
    final ended = night.hasEnded(controller.venueNow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nombre, estado y cerrar ya están en la cabecera de la ficha.
        Text(
          '${table.kindLabel} · ${table.zoneLabel}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (data == null || status == TableMapStatus.unknown)
          const NoticeBox(
            icon: Icons.help_outline_rounded,
            text:
                'Sin información de esta mesa todavía. Espera a que termine '
                'la consulta o reintenta.',
          )
        else if (active != null) ...[
          HolderCard(reservation: active),
          const SizedBox(height: 12),
          ReservationActions(
            key: ValueKey('actions-${active.id}'),
            reservation: active,
            store: store,
            clock: clock,
            enabled: !controller.isRefreshing,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('open-reservation'),
            onPressed: () => onOpenReservation(active.id),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Ver detalle y actividad'),
          ),
        ] else ...[
          NoticeBox(
            icon: Icons.event_available_rounded,
            text: ended
                ? 'La noche terminó: ya no se crean reservas.'
                : table.isVip
                ? 'Disponible. Crea una reserva directa solo si ya '
                      'verificaste el prepago: quedará confirmada.'
                : 'Disponible. Una reserva directa queda confirmada al '
                      'crearla.',
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('create-direct'),
            onPressed: ended || controller.isRefreshing ? null : onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear reserva directa'),
          ),
        ],
        if (previous.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionLabel(
            'Reservas anteriores de esta mesa en la noche',
            count: previous.length,
          ),
          for (final r in previous)
            ReservationTile(
              key: ValueKey('previous-${r.id}'),
              reservation: r,
              subtitle: r.id,
              onTap: () => onOpenReservation(r.id),
            ),
        ],
      ],
    );
  }
}

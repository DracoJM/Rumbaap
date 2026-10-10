import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_availability.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_book.dart';
import '../../domain/venue_table.dart';
import '../table_detail.dart';
import '../table_picker.dart';
import '../table_presentation.dart';
import '../venue_map.dart';
import '../venue_map_controller.dart';
import '../venue_map_page.dart';
import '../venue_map_parts.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';
import 'direct_reservation_page.dart';
import 'reservation_actions.dart';
import 'reservation_page.dart';

enum AdminSection { map, pending, reservations }

/// Vista del administrador (demostración, sin autenticación real): noche,
/// mapa con acciones por mesa, pendientes y reservas/actividad de la noche.
///
/// Lee el mismo almacén que la consulta pública. Mapa, listas y detalle
/// salen de la misma consulta ([NightReservations]), así que coinciden.
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
    clock: widget.clock,
    changes: widget.store,
  )..start();

  late final AppLifecycleListener _lifecycle;
  AdminSection _section = AdminSection.map;
  bool _showActivity = false;

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
    final size = MediaQuery.sizeOf(context);
    final wide =
        size.width >= VenueMapPage.sidePanelBreakpoint ||
        size.width > size.height;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final pendingVip =
            _data?.reservations
                .where((r) => r.status == ReservationStatus.pendingPayment)
                .length ??
            0;
        final destinations = [
          (Icons.map_outlined, Icons.map_rounded, 'Mapa', 0),
          (
            Icons.pending_actions_outlined,
            Icons.pending_actions_rounded,
            'Pendientes',
            pendingVip,
          ),
          (Icons.list_alt_outlined, Icons.list_alt_rounded, 'Reservas', 0),
        ];
        Widget icon(IconData data, int count) => Badge.count(
          count: count,
          isLabelVisible: count > 0,
          child: Icon(data),
        );
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Administrador'),
                DemoDataTag(text: 'Datos ficticios · sin autenticación real'),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NavigationRail(
                        selectedIndex: _section.index,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: _select,
                        destinations: [
                          for (final (i, s, label, n) in destinations)
                            NavigationRailDestination(
                              icon: icon(i, n),
                              selectedIcon: icon(s, n),
                              label: Text(label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _content()),
                    ],
                  )
                : _content(),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  height: 64,
                  selectedIndex: _section.index,
                  onDestinationSelected: _select,
                  destinations: [
                    for (final (i, s, label, n) in destinations)
                      NavigationDestination(
                        icon: icon(i, n),
                        selectedIcon: icon(s, n),
                        label: label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _select(int index) =>
      setState(() => _section = AdminSection.values[index]);

  Widget _content() {
    final c = _controller;
    return Column(
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
        if (c.night case final night?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Text(
              '${night.label} · ${night.scheduleLabel} (hora de Colombia)',
              key: const ValueKey('admin-night-header'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        Expanded(
          child: switch (_section) {
            AdminSection.map => _mapSection(),
            AdminSection.pending => _listState() ?? _pendingSection(_data!),
            AdminSection.reservations =>
              _listState() ?? _reservationsSection(_data!),
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Mapa

  Widget _mapSection() {
    final c = _controller;
    final selected = c.selectedTable;
    final night = c.night;
    final panel = selected == null || night == null
        ? null
        : _AdminTablePanel(
            key: ValueKey('admin-panel-${night.id}-${selected.id}'),
            table: selected,
            night: night,
            controller: c,
            data: _data,
            store: widget.store,
            clock: widget.clock,
            onOpenReservation: _openReservation,
            onCreate: () => _openDirectForm(night, selected),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Panel lateral en tableta o con la pantalla en horizontal. No se usa
        // la proporción de esta sección: en un teléfono pequeño en vertical,
        // la noche y la barra de navegación la dejan más ancha que alta.
        final size = MediaQuery.sizeOf(context);
        final wide =
            constraints.maxWidth >= VenueMapPage.sidePanelBreakpoint ||
            size.width > size.height;
        final mapArea = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: MapLegend()),
                // Con el rail y el panel abiertos en horizontal queda poco
                // ancho: el botón se encoge antes que desbordar.
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PickTableButton(
                      onPressed: () => showTablePicker(context, c),
                    ),
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
                  if (c.availabilityStatus == LoadStatus.loading ||
                      c.isRefreshing)
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
              if (panel != null)
                SizedBox(
                  width: math.min(360, constraints.maxWidth * 0.5),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.border)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                      child: panel,
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
            if (panel != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.6,
                ),
                child: BottomSheetPanel(child: panel),
              ),
          ],
        );
      },
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

  Widget _pendingSection(NightReservations data) {
    final vip = _byTable(
      data.reservations.where(
        (r) => r.status == ReservationStatus.pendingPayment,
      ),
    );
    final inProcess = _byTable(
      data.reservations.where((r) => r.status == ReservationStatus.inProcess),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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

  Widget _reservationsSection(NightReservations data) {
    final active = _byTable(data.reservations.where((r) => r.status.isActive));
    final ended = _byTable(data.reservations.where((r) => !r.status.isActive));
    final events = [
      for (final r in data.reservations)
        for (final e in r.history) (reservation: r, event: e),
    ]..sort((a, b) => b.event.at.compareTo(a.event.at));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Reservas'),
              icon: Icon(Icons.list_alt_rounded),
            ),
            ButtonSegment(
              value: true,
              label: Text('Actividad'),
              icon: Icon(Icons.history_rounded),
            ),
          ],
          selected: {_showActivity},
          onSelectionChanged: (s) => setState(() => _showActivity = s.first),
        ),
        const SizedBox(height: 8),
        if (!_showActivity) ...[
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
        ] else ...[
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
        ],
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

  static List<Reservation> _byTable(Iterable<Reservation> reservations) {
    final order = {for (final (i, t) in VenueTables.all.indexed) t.id: i};
    return reservations.toList()..sort((a, b) {
      final byTable = order[a.tableId]!.compareTo(order[b.tableId]!);
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
                      '${reservation.table.displayName} · '
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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(table.displayName, style: theme.textTheme.headlineSmall),
                  Text(
                    '${table.kindLabel} · ${table.zoneLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar detalle',
              onPressed: controller.clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusChip(status: status),
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

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';

/// Grupos de eventos para filtrar la actividad. Agrupan tipos del historial
/// por su efecto, sin añadir estados nuevos.
enum ActivityKind {
  requests('Solicitudes y altas', Icons.add_circle_outline_rounded, {
    ReservationEventType.requested,
    ReservationEventType.createdDirect,
  }),
  confirmations('Confirmaciones', Icons.verified_outlined, {
    ReservationEventType.completed,
    ReservationEventType.prepaymentMarked,
  }),
  arrivals('Llegadas', Icons.how_to_reg_outlined, {
    ReservationEventType.arrived,
  }),
  endings('Cancelaciones y cierres', Icons.history_toggle_off_rounded, {
    ReservationEventType.rejected,
    ReservationEventType.revoked,
    ReservationEventType.released,
    ReservationEventType.expired,
    ReservationEventType.cancelled,
  });

  const ActivityKind(this.label, this.icon, this.types);

  final String label;
  final IconData icon;
  final Set<ReservationEventType> types;

  static ActivityKind of(ReservationEventType type) =>
      values.firstWhere((k) => k.types.contains(type));
}

typedef _Entry = ({Reservation reservation, ReservationEvent event, int index});

/// Registro de actividad de la noche consultada para el administrador: una
/// tarjeta por cambio, agrupadas por día (hora de Colombia), de la más
/// reciente a la más antigua. Búsqueda por mesa, ID o titular y filtros por
/// tipo de evento y mesa. Las filas se construyen bajo demanda.
class ActivityLog extends StatefulWidget {
  const ActivityLog({
    super.key,
    required this.reservations,
    required this.venue,
    required this.onOpen,
    required this.padding,
  });

  final List<Reservation> reservations;
  final Venue venue;
  final ValueChanged<String> onOpen;
  final EdgeInsets padding;

  @override
  State<ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<ActivityLog> {
  final _search = TextEditingController();
  ActivityKind? _kind;
  String? _tableId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _search.text.trim().isNotEmpty || _kind != null || _tableId != null;

  void _reset() => setState(() {
    _search.clear();
    _kind = null;
    _tableId = null;
  });

  bool _matches(_Entry e) {
    final r = e.reservation;
    if (_kind != null && !_kind!.types.contains(e.event.type)) return false;
    if (_tableId != null && r.tableId != _tableId) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return r.id.toLowerCase().contains(q) ||
        r.tableId.toLowerCase().contains(q) ||
        r.tableIn(widget.venue).displayName.toLowerCase().contains(q) ||
        (r.holder?.name.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final all =
        <_Entry>[
          for (final r in widget.reservations)
            for (final (i, e) in r.history.indexed)
              (reservation: r, event: e, index: i),
        ]..sort((a, b) {
          // Con la misma hora, el cambio posterior del historial va primero.
          final byTime = b.event.at.compareTo(a.event.at);
          return byTime != 0 ? byTime : b.index.compareTo(a.index);
        });
    final shown = all.where(_matches).toList();

    // Filas planas: cabeceras de día y tarjetas, para un ListView perezoso.
    final rows = <Object>[];
    DateTime? day;
    for (final e in shown) {
      final wall = VenueTime.of(e.event.at);
      final d = DateTime.utc(wall.year, wall.month, wall.day);
      if (d != day) {
        rows.add(d);
        day = d;
      }
      rows.add(e);
    }

    final tables = {for (final e in all) e.reservation.tableId}.toList()
      ..sort(
        (a, b) => widget.venue.orderOf(a).compareTo(widget.venue.orderOf(b)),
      );
    final header = _controls(context, tables, all.length, shown.length);

    return ListView.builder(
      padding: widget.padding,
      itemCount: rows.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return header;
        if (i == rows.length + 1) return _footer(context, all, shown);
        final row = rows[i - 1];
        return row is DateTime
            ? _DayHeader(day: row)
            : _ActivityCard(
                entry: row as _Entry,
                venue: widget.venue,
                onTap: () => widget.onOpen(row.reservation.id),
              );
      },
    );
  }

  Widget _controls(
    BuildContext context,
    List<String> tables,
    int total,
    int shown,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Actividad de la noche', count: total),
        TextField(
          key: const ValueKey('activity-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar por mesa, ID de reserva o titular',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final kind in ActivityKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: ValueKey('activity-kind-${kind.name}'),
                    avatar: Icon(kind.icon, size: 18),
                    label: Text(kind.label, softWrap: false),
                    selected: _kind == kind,
                    showCheckmark: false,
                    onSelected: (on) =>
                        setState(() => _kind = on ? kind : null),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          key: const ValueKey('activity-table'),
          initialValue: _tableId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Mesa'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Todas las mesas'),
            ),
            for (final id in tables)
              DropdownMenuItem<String?>(
                value: id,
                child: Text(widget.venue.tableById(id)!.displayName),
              ),
          ],
          onChanged: (v) => setState(() => _tableId = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              _filtered
                  ? '$shown de $total eventos'
                  : '$total ${total == 1 ? 'evento' : 'eventos'}',
              key: const ValueKey('activity-count'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            if (_filtered)
              TextButton.icon(
                key: const ValueKey('activity-reset'),
                onPressed: _reset,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Quitar filtros'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, List<_Entry> all, List<_Entry> shown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (all.isEmpty)
          const NoticeBox(
            key: ValueKey('activity-empty'),
            icon: Icons.inbox_outlined,
            text: 'Todavía no hay actividad en esta noche.',
          )
        else if (shown.isEmpty)
          const NoticeBox(
            key: ValueKey('activity-no-match'),
            icon: Icons.search_off_rounded,
            text:
                'Ningún evento coincide con la búsqueda o los filtros. '
                'Quita los filtros para ver toda la actividad.',
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
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          '${Night(day).label} de ${day.year}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: NightNeutrals.glass(0.8),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.entry,
    required this.venue,
    required this.onTap,
  });

  final _Entry entry;
  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final r = entry.reservation;
    final type = entry.event.type;
    final kind = ActivityKind.of(type);
    final color = switch (kind) {
      ActivityKind.requests => colors.inProgress,
      ActivityKind.confirmations => colors.reserved,
      ActivityKind.arrivals => colors.occupied,
      ActivityKind.endings => AppColors.textMuted,
    };
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NightNeutrals.glass(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: NightNeutrals.glass(0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('activity-${r.id}-${entry.index}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(kind.icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eventLabel(type), style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        '${r.tableIn(venue).displayName} · ${r.id} · '
                        '${venueTimeLabel(entry.event.at)}',
                        style: muted,
                      ),
                      Text('Titular: ${r.holderName}', style: muted),
                      Text(
                        // El historial no guarda quién hizo cada cambio:
                        // solo se muestra el origen de la reserva, que sí
                        // consta.
                        'Origen de la reserva: ${r.originLabel} · Estado '
                        'actual: ${r.statusLabel}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../theme/night_neutrals.dart';
import '../bar/data/demo_bar_store.dart';
import '../bar/domain/bar.dart';
import '../bar/presentation/bar_views.dart';
import '../benefits/vip_benefits.dart';
import 'data/demo_goal_store.dart';
import 'domain/night_goals.dart';
import '../reservations/data/demo_reservation_store.dart';
import '../reservations/domain/night_schedule.dart';
import '../reservations/domain/reservation.dart';
import '../reservations/presentation/admin/admin_labels.dart';
import '../reservations/presentation/admin/admin_widgets.dart';
import '../reservations/presentation/admin/reservation_page.dart';
import '../reservations/presentation/table_presentation.dart';
import '../session/demo_identities.dart';
import '../tickets/data/demo_ticket_store.dart';
import '../tickets/domain/ticket.dart';
import '../tickets/presentation/admin_tickets.dart';
import '../tickets/presentation/ticket_widgets.dart';
import '../venues/venue_config.dart';

/// Elemento de una lista del panel: texto y, si se puede, su ficha.
typedef _Row = ({String title, String subtitle, VoidCallback? open});

/// Panel de la administración (frontend de demostración).
///
/// Separa personas de importes y muestra fuente, cobertura y corte. Cada
/// indicador abre su lista y, desde ella, la ficha. No calcula ocupación ni
/// permanencia (no hay salidas registradas), no llama rentabilidad a los
/// ingresos (no hay costos) y no suma el prepago VIP a las ventas de barra
/// (sería contarlo dos veces). Sin metas ni predicciones: las acciones las
/// decide la administración fuera de la app.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.reservations,
    required this.tickets,
    required this.bar,
    required this.identity,
    this.goals,
    this.clock = systemClock,
  });

  final DemoReservationStore reservations;

  /// Metas opcionales del local por noche; sin él no se configuran.
  final DemoGoalStore? goals;
  final DemoTicketStore tickets;
  final DemoBarStore bar;
  final DemoIdentity identity;
  final Clock clock;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// `null`: todo el período con datos.
  Night? _night;

  List<Night> _nights() {
    final set = <Night>{
      for (final r in widget.reservations.book.exportState().reservations)
        r.night,
      for (final t in widget.tickets.book.tickets) t.night,
      for (final s in widget.bar.book.sales) s.night,
      for (final i in widget.tickets.book.incidents)
        if (_readingNight(i) case final n?) n,
      // Una noche con meta y aún sin movimientos sigue elegible.
      for (final g in widget.goals?.book.goals ?? const <NightGoal>[]) g.night,
    };
    return set.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  bool _in(Night n) => _night == null || n == _night;

  /// Noche operativa en curso cuando se hizo la lectura, sea cual sea la
  /// noche de la entrada leída. `null` fuera de horario: no se le inventa
  /// noche y solo aparece en todo el período.
  static Night? _readingNight(TicketIncident i) {
    final at = VenueTime.of(i.at);
    for (final n in NightSchedule.weekendNights(at)) {
      if (n.isInProgress(at)) return n;
    }
    return null;
  }

  void _openList(String title, String explanation, List<_Row> rows) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              _ListPage(title: title, explanation: explanation, rows: rows),
        ),
      );

  void _openTicket(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminTicketPage(
        store: widget.tickets,
        identity: widget.identity,
        ticketId: id,
      ),
    ),
  );

  void _openSale(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          BarSalePage(store: widget.bar, identity: widget.identity, saleId: id),
    ),
  );

  void _openIncident(TicketIncident incident) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _IncidentPage(
        incident: incident,
        readingNight: _readingNight(incident),
        ticket: incident.ticketId == null
            ? null
            : widget.tickets.book.ticketById(incident.ticketId!),
        onOpenTicket: _openTicket,
      ),
    ),
  );

  void _openReservation(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReservationPage(
        store: widget.reservations,
        reservationId: id,
        clock: widget.clock,
        tickets: widget.tickets,
        identity: widget.identity,
      ),
    ),
  );

  _Row _ticketRow(Ticket t) => (
    title: 'Entrada ${t.id} · ${t.night.shortLabel} · ${t.channel.label}',
    subtitle: t.phaseLabel,
    open: () => _openTicket(t.id),
  );

  /// Avance de cada parámetro frente a su meta, si la hay, en la noche
  /// elegida. No hay metas para «todo el período» ni un resultado global.
  List<Widget> _goalSection(
    BuildContext context, {
    required Map<GoalMetric, int> values,
    required Map<GoalMetric, VoidCallback> details,
  }) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final night = _night;
    final store = widget.goals;
    if (night == null || store == null) {
      return [
        NoticeBox(
          key: const ValueKey('goal-choose-night'),
          icon: Icons.flag_outlined,
          text: store == null
              ? 'Las metas no están disponibles en esta vista.'
              : 'Las metas se configuran por noche: elige una noche arriba. '
                    'No hay metas para todo el período.',
        ),
      ];
    }
    final now = VenueTime.of(widget.clock());
    final phase = night.hasEnded(now)
        ? _Phase.ended
        : night.isInProgress(now)
        ? _Phase.inProgress
        : _Phase.notStarted;
    return [
      Text(
        switch (phase) {
          _Phase.ended =>
            'Noche terminada: se compara con lo registrado hasta el cierre en '
                'este teléfono.',
          _Phase.inProgress =>
            'Noche en curso: el avance es parcial y no indica cómo terminará '
                'la noche.',
          _Phase.notStarted =>
            'Noche sin empezar: aún no hay ingresos en puerta; los importes '
                'pueden incluir ventas anticipadas.',
        },
        key: const ValueKey('goal-coverage'),
        style: muted,
      ),
      const SizedBox(height: 6),
      for (final m in GoalMetric.values)
        _GoalCard(
          metric: m,
          value: values[m]!,
          goal: store.book.goalFor(night, m),
          phase: phase,
          onDetail: details[m]!,
          onEdit: () => _editGoal(night, m),
          onRemove: () => _removeGoal(night, m),
        ),
    ];
  }

  Future<void> _editGoal(Night night, GoalMetric metric) async {
    final store = widget.goals!;
    final current = store.book.goalFor(night, metric);
    final target = await showDialog<int>(
      context: context,
      builder: (_) =>
          _GoalDialog(metric: metric, night: night, initial: current?.target),
    );
    if (target == null || !mounted) return;
    store.perform(
      (b) => b.set(night, metric, target, actorId: widget.identity.id),
    );
  }

  Future<void> _removeGoal(Night night, GoalMetric metric) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('¿Quitar la meta?'),
        content: Text(
          '${metric.label} · ${night.label} de ${night.date.year}. El '
          'parámetro quedará sin configurar; los registros no cambian.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('dialog-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.goals!.perform((b) => b.remove(night, metric));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenueScope.of(context).venue;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de la administración')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.reservations,
          widget.tickets,
          widget.bar,
          ?widget.goals,
        ]),
        builder: (context, _) {
          final nights = _nights();
          if (_night != null && !nights.contains(_night)) _night = null;
          final reservations = widget.reservations.book
              .exportState()
              .reservations
              .where((r) => _in(r.night))
              .toList();
          final tickets = widget.tickets.book.tickets
              .where((t) => _in(t.night))
              .toList();
          final purchases = widget.tickets.book.purchases
              .where((p) => _in(p.night))
              .toList();
          final sales = widget.bar.book.sales
              .where((s) => _in(s.night))
              .toList();
          // Por la noche de la lectura, igual con entrada o sin ella; la
          // noche de la entrada se ve aparte en la ficha de la incidencia.
          final incidents = widget.tickets.book.incidents
              .where((i) => _night == null || _readingNight(i) == _night)
              .toList();

          final entered = tickets.where((t) => t.firstEntryAt != null);
          final redeemed = tickets.where(
            (t) => t.status == TicketStatus.redeemed,
          );
          final seated = reservations.where(
            (r) =>
                r.status == ReservationStatus.seated ||
                r.history.any((e) => e.type == ReservationEventType.arrived),
          );
          final pendingRedeem = tickets.where(
            (t) => t.status == TicketStatus.active,
          );
          final paidPurchases = purchases.where(
            (p) =>
                p.payment == PaymentStatus.paidSimulated ||
                p.payment == PaymentStatus.verifiedByPromoter,
          );
          final ticketIncome = paidPurchases.fold<int>(
            0,
            (t, p) => t + p.total,
          );
          final refunds = tickets.where(
            (t) =>
                t.request?.type == TicketRequestType.refund &&
                (t.request!.status == TicketRequestStatus.authorized ||
                    t.request!.status == TicketRequestStatus.refundRecorded),
          );
          final refundAmount = refunds.fold<int>(
            0,
            (s, t) =>
                s + widget.tickets.book.purchaseById(t.purchaseId)!.unitPrice,
          );
          final activeSales = sales.where(
            (s) => s.status == BarSaleStatus.active,
          );
          final barIncome = activeSales.fold<int>(0, (t, s) => t + s.total);
          final vipPrepaid = reservations.where(
            (r) => r.history.any(
              (e) => e.type == ReservationEventType.prepaymentMarked,
            ),
          );
          final vipBenefits = [
            for (final r in reservations)
              if (r.status != ReservationStatus.inProcess)
                if (VipBenefits.of(r, venue, widget.tickets.book) case final b?)
                  b,
          ];
          final vipIssued = vipBenefits.fold<int>(
            0,
            (n, b) => n + b.issued.length,
          );
          final acceptances = widget.bar.book.acceptances
              .where((a) => _in(a.night))
              .toList();
          final now = widget.clock();

          Widget tile(
            String key,
            String label,
            String value,
            VoidCallback onTap, {
            String? note,
          }) => Card(
            key: ValueKey('dash-$key'),
            color: NightNeutrals.glass(0.06),
            child: ListTile(
              minTileHeight: 56,
              title: Text(label),
              subtitle: note == null ? null : Text(note, style: muted),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    key: ValueKey('dash-$key-value'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: onTap,
            ),
          );

          void openEntries() => _openList(
            'Primeros ingresos',
            'Entradas con primer ingreso registrado en puerta.',
            [for (final t in entered) _ticketRow(t)],
          );
          void openArrivals() => _openList(
            'Llegadas a mesas',
            'Reservas con la llegada registrada (R5).',
            [
              for (final r in seated)
                (
                  title:
                      '${r.tableIn(venue).displayName} · ${r.night.shortLabel}',
                  subtitle: '${r.id} · ${r.statusLabel}',
                  open: () => _openReservation(r.id),
                ),
            ],
          );
          void openTicketIncome() => _openList(
            'Compras de entradas pagadas',
            'Pago simulado o comprobado por el promotor. Las cortesías '
                'no tienen importe.',
            [
              for (final p in paidPurchases)
                (
                  title: '${p.id} · ${p.night.shortLabel} · ${p.channel.label}',
                  subtitle:
                      '${p.quantity} × ${copLabel(p.unitPrice)} = ${copLabel(p.total)}',
                  open: () =>
                      _openTicket(widget.tickets.book.ticketsOf(p.id).first.id),
                ),
            ],
          );
          void openBarIncome() => _openList(
            'Ventas de barra',
            'Registradas por barra tras el pago presencial; las anuladas '
                'no suman.',
            [
              for (final s in sales)
                (
                  title: 'Venta ${s.id} · ${s.night.shortLabel}',
                  subtitle:
                      '${s.status == BarSaleStatus.voided ? 'Anulada' : copLabel(s.total)}'
                      '${s.tableId == null ? '' : ' · Mesa ${s.tableId}'}',
                  open: () => _openSale(s.id),
                ),
            ],
          );

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Text(
                '${venue.name} · ${_night == null ? 'Todo el período con datos' : '${_night!.label} de ${_night!.date.year}'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: NightNeutrals.white,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Night?>(
                key: const ValueKey('dash-night'),
                initialValue: _night,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Noche o período'),
                selectedItemBuilder: (_) => [
                  const Text('Todo el período'),
                  for (final n in nights)
                    Text('${n.shortLabel} ${n.date.year}'),
                ],
                items: [
                  const DropdownMenuItem<Night?>(
                    value: null,
                    child: Text('Todo el período con datos'),
                  ),
                  for (final n in nights)
                    DropdownMenuItem<Night?>(
                      value: n,
                      child: Text('${n.label} de ${n.date.year}'),
                    ),
                ],
                onChanged: (n) => setState(() => _night = n),
              ),
              const SizedBox(height: 8),
              // El corte va al final: su hora termina en «a. m.»/«p. m.» y
              // no se le añade otro punto.
              Text(
                'Fuente: datos ficticios de demostración guardados en este '
                'teléfono. Cobertura: '
                '${nights.isEmpty ? 'sin datos' : '${nights.first.shortLabel} – ${nights.last.shortLabel}'}. '
                'Corte: ${venueDateTimeLabel(now)}',
                key: const ValueKey('dash-source'),
                style: muted,
              ),
              SectionLabel('Personas'),
              tile(
                'entries',
                'Primeros ingresos con entrada',
                '${entered.length}',
                openEntries,
              ),
              tile(
                'redeemed',
                'Manillas canjeadas',
                '${redeemed.length}',
                () => _openList(
                  'Canjes',
                  'Entradas canjeadas por manilla (taquilla o lote del '
                      'promotor).',
                  [for (final t in redeemed) _ticketRow(t)],
                ),
              ),
              tile(
                'pending',
                'Entradas vigentes sin canjear',
                '${pendingRedeem.length}',
                () => _openList(
                  'Canjes pendientes',
                  'Entradas activas que aún no se han canjeado.',
                  [for (final t in pendingRedeem) _ticketRow(t)],
                ),
              ),
              tile(
                'arrivals',
                'Reservas con llegada registrada',
                '${seated.length}',
                openArrivals,
                note:
                    'No se suman a los ingresos con entrada: una persona puede '
                    'tener ambos.',
              ),
              Text(
                'Sin salidas registradas no se calculan ocupación actual ni '
                'permanencia.',
                key: const ValueKey('dash-no-occupancy'),
                style: muted,
              ),
              SectionLabel('Importes (COP de demostración)'),
              tile(
                'ticket-income',
                'Entradas pagadas',
                copLabel(ticketIncome),
                openTicketIncome,
              ),
              tile(
                'refunds',
                'Devoluciones autorizadas',
                copLabel(refundAmount),
                () => _openList(
                  'Devoluciones',
                  'Autorizadas por la administración; «efectuada» solo si se '
                      'registró el dinero devuelto fuera de la app.',
                  [for (final t in refunds) _ticketRow(t)],
                ),
                note: 'Se muestran aparte; no se restan en silencio.',
              ),
              tile(
                'bar-income',
                'Ventas de barra vigentes',
                copLabel(barIncome),
                openBarIncome,
              ),
              tile(
                'vip',
                'Prepagos VIP verificados',
                '${vipPrepaid.length}',
                () => _openList(
                  'Prepagos VIP',
                  'Reservas VIP con el prepago marcado como verificado.',
                  [
                    for (final r in vipPrepaid)
                      (
                        title:
                            '${r.tableIn(venue).displayName} · ${r.night.shortLabel}',
                        subtitle: r.id,
                        open: () => _openReservation(r.id),
                      ),
                  ],
                ),
                note:
                    'Se cuentan, sin importe: el consumo prepagado no se suma '
                    'a las ventas de barra para no contarlo dos veces.',
              ),
              Text(
                'Son ingresos, no rentabilidad: la demo no registra costos.',
                style: muted,
              ),
              SectionLabel('Operación'),
              tile(
                'reservations',
                'Reservas',
                '${reservations.length}',
                () => _openList(
                  'Reservas',
                  'Todas las del período, con su estado actual.',
                  [
                    for (final r in reservations)
                      (
                        title:
                            '${r.tableIn(venue).displayName} · ${r.night.shortLabel}',
                        subtitle: '${r.id} · ${r.statusLabel}',
                        open: () => _openReservation(r.id),
                      ),
                  ],
                ),
              ),
              tile(
                'vip-benefits',
                'Reservas VIP con beneficios',
                '${vipBenefits.length}',
                () => _openList(
                  'Beneficios VIP',
                  'Por mesa VIP: 6 cortesías y 1 botella fuera del consumo. '
                      'Las cortesías se emiten desde la ficha de la reserva; '
                      'la entrega de la botella no tiene registro definido.',
                  [
                    for (final b in vipBenefits)
                      (
                        title:
                            '${b.reservation.tableIn(venue).displayName} · '
                            '${b.reservation.night.shortLabel} · '
                            '${b.reservation.statusLabel}',
                        subtitle:
                            '${b.reservation.id} · cortesías '
                            '${b.issued.length} de ${b.entitledCourtesies} '
                            'emitidas, ${b.redeemed} canjeadas',
                        open: () => _openReservation(b.reservation.id),
                      ),
                  ],
                ),
                note: 'Cortesías emitidas: $vipIssued. Sin importe.',
              ),
              tile(
                'acceptances',
                'Consumos aceptados por mesero',
                '${acceptances.length}',
                () => _openList(
                  'Consumos aceptados',
                  'Aceptación manual; muestra lo que vio el mesero.',
                  [
                    for (final a in acceptances)
                      (
                        title: 'Mesa ${a.tableId} · ${a.night.shortLabel}',
                        subtitle:
                            '${actorLabel(a.acceptedBy)} · vio ${copLabel(a.totalSeen)}',
                        open: () => _openReservation(a.reservationId),
                      ),
                  ],
                ),
              ),
              tile(
                'incidents',
                'Incidencias de puerta y taquilla',
                '${incidents.length}',
                () => _openList(
                  'Incidencias',
                  'Lecturas rechazadas con su motivo, por la noche en que se '
                      'leyeron. Las de fuera de horario no se asignan a una '
                      'noche: solo aparecen en todo el período.',
                  [
                    for (final i in incidents)
                      (
                        title: '${i.point} · ${venueDateTimeLabel(i.at)}',
                        subtitle:
                            '${rejectReasonLabel(i.reason)} · ${actorLabel(i.actorId)}'
                            '${_readingNight(i) == null ? ' · Fuera de horario' : ''}',
                        open: () => _openIncident(i),
                      ),
                  ],
                ),
              ),
              SectionLabel('Metas de la noche'),
              ..._goalSection(
                context,
                values: {
                  GoalMetric.firstEntries: entered.length,
                  GoalMetric.reservationArrivals: seated.length,
                  GoalMetric.ticketIncome: ticketIncome,
                  GoalMetric.barIncome: barIncome,
                },
                details: {
                  GoalMetric.firstEntries: openEntries,
                  GoalMetric.reservationArrivals: openArrivals,
                  GoalMetric.ticketIncome: openTicketIncome,
                  GoalMetric.barIncome: openBarIncome,
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Sin predicciones ni puntuaciones: cada meta se compara solo '
                'con lo registrado. Los registros guardan hora y actor.',
                key: const ValueKey('dash-goals'),
                style: muted,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  const _ListPage({
    required this.title,
    required this.explanation,
    required this.rows,
  });

  final String title;
  final String explanation;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        key: const ValueKey('dash-list'),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: rows.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                rows.isEmpty ? '$explanation\n\nSin elementos.' : explanation,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            );
          }
          final r = rows[i - 1];
          return Card(
            color: NightNeutrals.glass(0.06),
            child: ListTile(
              key: ValueKey('dash-row-${i - 1}'),
              minTileHeight: 56,
              title: Text(r.title),
              subtitle: Text(r.subtitle),
              trailing: r.open == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: r.open,
            ),
          );
        },
      ),
    );
  }
}

/// Ficha de una incidencia: la noche de la lectura y, aparte, la noche de la
/// entrada leída, que pueden no coincidir (p. ej. una entrada del viernes
/// leída el sábado).
class _IncidentPage extends StatelessWidget {
  const _IncidentPage({
    required this.incident,
    required this.readingNight,
    required this.ticket,
    required this.onOpenTicket,
  });

  final TicketIncident incident;
  final Night? readingNight;
  final Ticket? ticket;
  final void Function(String ticketId) onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final t = ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencia')),
      body: ListView(
        key: const ValueKey('dash-incident-page'),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            rejectReasonLabel(incident.reason),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Lectura: ${venueDateTimeLabel(incident.at)} · ${incident.point} · '
            '${actorLabel(incident.actorId)}',
          ),
          const SizedBox(height: 8),
          Text(
            readingNight == null
                ? 'Noche de la lectura: fuera de horario, no se asigna a '
                      'ninguna noche.'
                : 'Noche de la lectura: ${readingNight!.label} de '
                      '${readingNight!.date.year}',
            key: const ValueKey('incident-reading-night'),
          ),
          const SizedBox(height: 8),
          if (t == null)
            Text(
              'El código leído no corresponde a ninguna entrada.',
              style: muted,
            )
          else ...[
            Text(
              'Entrada ${t.id} · noche de la entrada: ${t.night.label} de '
              '${t.night.date.year}',
              key: const ValueKey('incident-ticket-night'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('incident-open-ticket'),
              onPressed: () => onOpenTicket(t.id),
              child: const Text('Ver entrada'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Phase { ended, inProgress, notStarted }

extension GoalMetricLabels on GoalMetric {
  String get label => switch (this) {
    GoalMetric.firstEntries => 'Primeros ingresos con entrada',
    GoalMetric.reservationArrivals => 'Reservas con llegada registrada',
    GoalMetric.ticketIncome => 'Entradas pagadas',
    GoalMetric.barIncome => 'Ventas de barra vigentes',
  };

  bool get isMoney =>
      this == GoalMetric.ticketIncome || this == GoalMetric.barIncome;

  String get group =>
      isMoney ? 'Ingresos registrados (COP)' : 'Asistencia registrada';

  String get definition => switch (this) {
    GoalMetric.firstEntries =>
      'Entradas con primer ingreso registrado en puerta esa noche. No es '
          'aforo ni ocupación: sin salidas registradas no se sabe cuántas '
          'personas hay dentro.',
    GoalMetric.reservationArrivals =>
      'Reservas de la noche con la llegada registrada. Cuenta reservas, no '
          'personas, y no se suma a los ingresos con entrada.',
    GoalMetric.ticketIncome =>
      'Importe de las entradas pagadas para esa noche. Las cortesías no '
          'tienen importe; las devoluciones autorizadas se muestran aparte.',
    GoalMetric.barIncome =>
      'Ventas registradas por barra tras el pago presencial; las anuladas no '
          'suman. No incluye el prepago VIP, que se cuenta sin importe.',
  };

  String format(int v) => isMoney ? copLabel(v) : '$v';
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.metric,
    required this.value,
    required this.goal,
    required this.phase,
    required this.onDetail,
    required this.onEdit,
    required this.onRemove,
  });

  final GoalMetric metric;
  final int value;
  final NightGoal? goal;
  final _Phase phase;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final g = goal;
    final String state;
    if (g == null) {
      state = 'Sin configurar · registrado: ${metric.format(value)}';
    } else {
      final shown = '${metric.format(value)} de ${metric.format(g.target)}';
      final missing = metric.format(g.target - value);
      state = value >= g.target
          ? 'Meta alcanzada: $shown.'
          : switch (phase) {
              _Phase.ended => 'No alcanzada: $shown (faltaron $missing).',
              _Phase.inProgress =>
                'Avance parcial: $shown (faltan $missing). La noche sigue en '
                    'curso.',
              _Phase.notStarted => 'Noche sin empezar: $shown.',
            };
    }
    final key = metric.name;
    return Card(
      key: ValueKey('goal-$key'),
      color: NightNeutrals.glass(0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(metric.group, style: muted),
            Text(metric.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(metric.definition, style: muted),
            const SizedBox(height: 8),
            Text(state, key: ValueKey('goal-$key-state')),
            if (g != null) ...[
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: (value / g.target).clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Meta fijada por ${actorLabel(g.setBy)} · '
                '${venueDateTimeLabel(g.setAt)}',
                style: muted,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  key: ValueKey('goal-$key-detail'),
                  onPressed: onDetail,
                  child: const Text('Ver detalle'),
                ),
                TextButton(
                  key: ValueKey('goal-$key-edit'),
                  onPressed: onEdit,
                  child: Text(g == null ? 'Configurar meta' : 'Editar meta'),
                ),
                if (g != null)
                  TextButton(
                    key: ValueKey('goal-$key-remove'),
                    onPressed: onRemove,
                    child: const Text('Quitar meta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide la meta: solo cifras, mayor que cero. Sin valor por defecto.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.metric, required this.night, this.initial});

  final GoalMetric metric;
  final Night night;
  final int? initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final _text = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_text.text);
    if (v == null || v <= 0) {
      setState(
        () => _error = widget.metric.isMoney
            ? 'Escribe un importe en COP mayor que cero, sin puntos.'
            : 'Escribe una cantidad entera mayor que cero.',
      );
      return;
    }
    if (v > GoalBook.maxTarget) {
      setState(() => _error = 'El valor es demasiado grande.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metric;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initial == null ? 'Configurar meta' : 'Editar meta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${m.label} · ${widget.night.label} de ${widget.night.date.year}',
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('goal-input'),
            controller: _text,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: m.isMoney ? 'Meta (COP)' : 'Meta',
              helperText: m.isMoney
                  ? 'Importe en COP, sin puntos.'
                  : 'Cantidad entera.',
              errorText: _error,
              errorMaxLines: 3,
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('dialog-confirm'),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

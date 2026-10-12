import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../theme/night_neutrals.dart';
import '../bar/data/demo_bar_store.dart';
import '../bar/domain/bar.dart';
import '../bar/presentation/bar_views.dart';
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
    this.clock = systemClock,
  });

  final DemoReservationStore reservations;
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
      ),
    ),
  );

  _Row _ticketRow(Ticket t) => (
    title: 'Entrada ${t.id} · ${t.night.shortLabel} · ${t.channel.label}',
    subtitle: t.phaseLabel,
    open: () => _openTicket(t.id),
  );

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
                () => _openList(
                  'Primeros ingresos',
                  'Entradas con primer ingreso registrado en puerta.',
                  [for (final t in entered) _ticketRow(t)],
                ),
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
                () => _openList(
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
                ),
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
                () => _openList(
                  'Compras de entradas pagadas',
                  'Pago simulado o comprobado por el promotor. Las cortesías '
                      'no tienen importe.',
                  [
                    for (final p in paidPurchases)
                      (
                        title:
                            '${p.id} · ${p.night.shortLabel} · ${p.channel.label}',
                        subtitle:
                            '${p.quantity} × ${copLabel(p.unitPrice)} = ${copLabel(p.total)}',
                        open: () => _openTicket(
                          widget.tickets.book.ticketsOf(p.id).first.id,
                        ),
                      ),
                  ],
                ),
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
                () => _openList(
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
                ),
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
              SectionLabel('Metas y análisis'),
              const NoticeBox(
                key: ValueKey('dash-goals'),
                icon: Icons.flag_outlined,
                text:
                    'Metas configurables: mecanismo propuesto, sin metas '
                    'configuradas. No se muestran umbrales ni índices de '
                    'éxito. Los registros guardan hora y actor para un '
                    'análisis futuro; no hay predicciones.',
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

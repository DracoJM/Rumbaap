import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../reservations/domain/night_schedule.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../session/demo_identities.dart';
import '../../venues/venue_config.dart';
import '../data/demo_ticket_store.dart';
import '../domain/ticket.dart';
import 'ticket_widgets.dart';

/// Fases para filtrar, en el orden del recorrido.
enum TicketPhase {
  pending('Pendiente de pago'),
  activeNoEntry('Vigente sin ingreso'),
  entered('Ingreso registrado'),
  redeemed('Canjeada'),
  voided('Anulada');

  const TicketPhase(this.label);
  final String label;

  static TicketPhase of(Ticket t) => switch (t.status) {
    TicketStatus.pendingPayment => pending,
    TicketStatus.active when t.firstEntryAt != null => entered,
    TicketStatus.active => activeNoEntry,
    TicketStatus.redeemed => redeemed,
    TicketStatus.voided => voided,
  };
}

/// «Entradas» de la administración: todo su local. Cifras separadas por
/// paso (venta, pago, primer ingreso, canje, incidencias, devoluciones),
/// búsqueda y filtros, ficha con historial y las excepciones que solo
/// autoriza la administración. Todo pago y devolución es simulado.
class AdminTickets extends StatefulWidget {
  const AdminTickets({
    super.key,
    required this.store,
    required this.identity,
    this.clock = systemClock,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final Clock clock;

  @override
  State<AdminTickets> createState() => _AdminTicketsState();
}

class _AdminTicketsState extends State<AdminTickets> {
  final _search = TextEditingController();
  Night? _night;
  TicketPhase? _phase;
  TicketChannel? _channel;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _search.text.trim().isNotEmpty ||
      _night != null ||
      _phase != null ||
      _channel != null;

  bool _matches(Ticket t) {
    if (_night != null && t.night != _night) return false;
    if (_phase != null && TicketPhase.of(t) != _phase) return false;
    if (_channel != null && t.channel != _channel) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final owner = DemoIdentities.byId(t.ownerId);
    final compact = q.replaceAll(RegExp(r'[\s-]'), '');
    return t.id.toLowerCase() == q ||
        t.purchaseId.toLowerCase() == q ||
        (t.credential?.toLowerCase().contains(compact) ?? false) ||
        t.retired.any((c) => c.code.toLowerCase().contains(compact)) ||
        (owner?.name.toLowerCase().contains(q) ?? false) ||
        (owner?.idNumber?.contains(q) ?? false) ||
        (t.holderName?.toLowerCase().contains(q) ?? false);
  }

  void _open(String ticketId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminTicketPage(
        store: widget.store,
        identity: widget.identity,
        ticketId: ticketId,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capacity = VenueScope.of(context).capacity;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final book = widget.store.book;
        final all = book.tickets
          ..sort((a, b) => b.history.last.at.compareTo(a.history.last.at));
        final nights = {for (final t in all) t.night}.toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        int count(bool Function(Ticket) f) => all.where(f).length;
        final open = all.where((t) => t.hasOpenRequest).toList();
        final toRecord = all
            .where(
              (t) =>
                  t.request?.type == TicketRequestType.refund &&
                  t.request?.status == TicketRequestStatus.authorized,
            )
            .toList();
        final shown = all.where(_matches).toList();
        final muted = theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
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
              'Entradas del local',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cada cifra cuenta entradas (personas), no importes.',
              style: muted,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label, n) in [
                  ('sold', 'Vendidas', all.length),
                  (
                    'paid',
                    'Pagadas o cortesía',
                    count((t) => t.status != TicketStatus.pendingPayment),
                  ),
                  (
                    'entered',
                    'Primer ingreso',
                    count((t) => t.firstEntryAt != null),
                  ),
                  (
                    'redeemed',
                    'Canjeadas',
                    count((t) => t.status == TicketStatus.redeemed),
                  ),
                  (
                    'refund-auth',
                    'Devolución autorizada',
                    count(
                      (t) =>
                          t.request?.type == TicketRequestType.refund &&
                          t.request!.status != TicketRequestStatus.requested &&
                          t.request!.status != TicketRequestStatus.rejected,
                    ),
                  ),
                  (
                    'refund-done',
                    'Devolución efectuada',
                    count(
                      (t) =>
                          t.request?.status ==
                          TicketRequestStatus.refundRecorded,
                    ),
                  ),
                  ('incidents', 'Incidencias', book.incidents.length),
                ])
                  Chip(
                    key: ValueKey('admin-count-$key'),
                    label: Text('$n · $label'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              capacity == null
                  ? 'Aforo del local: no configurado. La ocupación física no '
                        'se calcula a partir de entradas ni ingresos.'
                  : 'Aforo configurado: $capacity personas. La ocupación '
                        'física no se calcula a partir de entradas.',
              key: const ValueKey('admin-capacity'),
              style: muted,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('admin-courtesy'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CourtesyPage(
                    store: widget.store,
                    identity: widget.identity,
                    clock: widget.clock,
                  ),
                ),
              ),
              icon: const Icon(Icons.card_giftcard_rounded),
              label: const Text('Autorizar cortesía'),
            ),
            SectionLabel('Solicitudes por decidir', count: open.length),
            if (open.isEmpty)
              const NoticeBox(
                icon: Icons.inbox_outlined,
                text: 'No hay solicitudes de devolución ni de cambio.',
              ),
            for (final t in open)
              TicketTile(
                key: ValueKey('admin-request-${t.id}'),
                ticket: t,
                onTap: () => _open(t.id),
              ),
            SectionLabel(
              'Devoluciones autorizadas sin efectuar',
              count: toRecord.length,
            ),
            for (final t in toRecord)
              TicketTile(
                key: ValueKey('admin-record-${t.id}'),
                ticket: t,
                onTap: () => _open(t.id),
              ),
            SectionLabel('Incidencias', count: book.incidents.length),
            for (final i in book.incidents.reversed.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${venueDateTimeLabel(i.at)} · ${i.point} · '
                  '${actorLabel(i.actorId)} · ${rejectReasonLabel(i.reason)}'
                  '${i.ticketId == null ? ' · ${credentialLabel(i.code)}' : ' · entrada ${i.ticketId}'}',
                  style: muted,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('admin-ticket-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText:
                    'Buscar: nombre, cédula, credencial, entrada o compra',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              // Se recrea al quitar filtros para reflejar «Todas».
              key: ValueKey('night-${_night?.id}'),
              child: DropdownButtonFormField<Night?>(
                key: const ValueKey('admin-ticket-night'),
                initialValue: _night,
                isExpanded: true,
                selectedItemBuilder: (_) => [
                  const Text('Todas las noches'),
                  for (final n in nights)
                    Text('${n.shortLabel} ${n.date.year}'),
                ],
                decoration: const InputDecoration(labelText: 'Noche'),
                items: [
                  const DropdownMenuItem<Night?>(
                    value: null,
                    child: Text('Todas las noches'),
                  ),
                  for (final n in nights)
                    DropdownMenuItem<Night?>(
                      value: n,
                      child: Text('${n.label} de ${n.date.year}'),
                    ),
                ],
                onChanged: (n) => setState(() => _night = n),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in TicketPhase.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: ValueKey('admin-phase-${p.name}'),
                        label: Text(p.label, softWrap: false),
                        selected: _phase == p,
                        showCheckmark: false,
                        onSelected: (on) =>
                            setState(() => _phase = on ? p : null),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in TicketChannel.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: ValueKey('admin-channel-${c.name}'),
                        label: Text('Origen: ${c.label}', softWrap: false),
                        selected: _channel == c,
                        showCheckmark: false,
                        onSelected: (on) =>
                            setState(() => _channel = on ? c : null),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  _filtered
                      ? '${shown.length} de ${all.length} entradas'
                      : '${all.length} entradas',
                  key: const ValueKey('admin-ticket-count'),
                  style: muted,
                ),
                if (_filtered)
                  TextButton.icon(
                    key: const ValueKey('admin-ticket-reset'),
                    onPressed: () => setState(() {
                      _search.clear();
                      _night = null;
                      _phase = null;
                      _channel = null;
                    }),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Quitar filtros'),
                  ),
              ],
            ),
            if (shown.isEmpty)
              NoticeBox(
                icon: Icons.search_off_rounded,
                text: all.isEmpty
                    ? 'Todavía no hay entradas en esta demostración.'
                    : 'Ninguna entrada coincide. Quita los filtros.',
              ),
            for (final t in shown)
              TicketTile(
                ticket: t,
                extra:
                    '${t.channel.label} · '
                    '${DemoIdentities.byId(t.ownerId)?.name ?? t.holderName ?? ''}',
                onTap: () => _open(t.id),
              ),
            const SizedBox(height: 8),
            Text(
              'Datos ficticios de demostración. Pagos y devoluciones simulados: '
              'no se cobra ni se devuelve dinero.',
              style: muted,
            ),
          ],
        );
      },
    );
  }
}

/// Ficha de una entrada para la administración: datos autorizados, fases,
/// historial con actor y las excepciones que solo ella decide.
class AdminTicketPage extends StatelessWidget {
  const AdminTicketPage({
    super.key,
    required this.store,
    required this.identity,
    required this.ticketId,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final String ticketId;

  Future<void> _decide(
    BuildContext context,
    Ticket t, {
    required String title,
    required String message,
    required String confirm,
    required Ticket Function(String id) operation,
    bool destructive = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    // Estado exacto antes del await (H1): si cambia, no se aplica.
    final before = (t.status, t.request?.status, t.credential);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('dialog-confirm'),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.black,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = store.book.ticketById(t.id);
    if (now == null ||
        (now.status, now.request?.status, now.credential) != before) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'La entrada cambió mientras decidías. No se hizo ningún cambio.',
          ),
        ),
      );
      return;
    }
    try {
      store.perform((b) => operation(t.id));
    } on TicketException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ticketErrorLabel(e.error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Entrada (administración)')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final t = store.book.ticketById(ticketId);
          if (t == null) return const Center(child: Text('No encontrada.'));
          final p = store.book.purchaseById(t.purchaseId)!;
          final owner = DemoIdentities.byId(t.ownerId);
          final muted = theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          );
          final r = t.request;
          final book = store.book;
          Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$k: ', style: muted),
                  TextSpan(text: v),
                ],
              ),
            ),
          );
          return ListView(
            key: ValueKey('admin-ticket-page-${t.id}'),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Text(
                t.phaseLabel,
                key: const ValueKey('admin-ticket-phase'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: t.statusColor,
                ),
              ),
              const SizedBox(height: 6),
              row('Entrada', '${t.id} · compra ${p.id}'),
              row('Noche', '${t.night.label} de ${t.night.date.year}'),
              row('Origen', t.channel.label),
              row(
                'Cliente',
                owner != null
                    ? '${owner.name} · cédula ${owner.idNumber ?? 'sin dato'}'
                    : (t.holderName ?? 'Sin nombre'),
              ),
              if (t.channel == TicketChannel.promoter) ...[
                row('Teléfono del comprador', p.buyerPhone ?? 'No registrado'),
                row('Cédula del comprador', p.buyerIdNumber ?? 'No registrado'),
              ],
              row(
                'Venta',
                '${venueDateTimeLabel(p.createdAt)} · '
                    '${actorLabel(p.createdBy)}',
              ),
              row(
                'Importe',
                '${copLabel(p.unitPrice)} por entrada (demostración)',
              ),
              row(
                'Pago',
                p.paidAt == null
                    ? p.payment.label
                    : '${p.payment.label} · ${venueDateTimeLabel(p.paidAt!)}'
                          ' · ${actorLabel(p.paymentBy!)}',
              ),
              if (p.note case final n?) row('Motivo de la cortesía', n),
              row(
                'Primer ingreso',
                t.firstEntryAt == null
                    ? 'Sin registrar'
                    : venueDateTimeLabel(t.firstEntryAt!),
              ),
              row(
                'Canje',
                t.redeemedAt == null
                    ? 'Sin canjear'
                    : '${venueDateTimeLabel(t.redeemedAt!)} · '
                          '${t.redeemPoint == RedeemPoint.promoterLot ? 'lote del promotor' : 'taquilla'}',
              ),
              row(
                'Credencial',
                t.credential == null
                    ? 'Sin credencial vigente'
                    : credentialLabel(t.credential!),
              ),
              if (t.retired.isNotEmpty)
                row(
                  'Retiradas',
                  t.retired
                      .map((c) => '${credentialLabel(c.code)} (${c.reason})')
                      .join(', '),
                ),
              if (t.requestLabel case final l?) row('Solicitud', l),
              const SizedBox(height: 12),
              if (r?.status == TicketRequestStatus.requested) ...[
                FilledButton(
                  key: const ValueKey('admin-authorize'),
                  onPressed: () => _decide(
                    context,
                    t,
                    title: 'Autorizar solicitud',
                    message: r!.type == TicketRequestType.refund
                        ? 'La entrada ${t.id} quedará anulada y su credencial '
                              'retirada. La app NO devuelve dinero: registra la '
                              'devolución efectuada cuando se haga fuera de la '
                              'app.'
                        : 'La entrada ${t.id} pasará a '
                              '${r.targetNight!.label.toLowerCase()}.',
                    confirm: 'Autorizar',
                    operation: (id) =>
                        book.authorizeRequest(id, actorId: identity.id),
                  ),
                  child: const Text('Autorizar'),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  key: const ValueKey('admin-reject'),
                  onPressed: () => _decide(
                    context,
                    t,
                    title: 'Rechazar solicitud',
                    message: 'La entrada ${t.id} seguirá igual.',
                    confirm: 'Rechazar',
                    destructive: true,
                    operation: (id) =>
                        book.rejectRequest(id, actorId: identity.id),
                  ),
                  child: const Text('Rechazar'),
                ),
              ],
              if (r?.type == TicketRequestType.refund &&
                  r?.status == TicketRequestStatus.authorized)
                OutlinedButton(
                  key: const ValueKey('admin-record-refund'),
                  onPressed: () => _decide(
                    context,
                    t,
                    title: 'Registrar devolución efectuada',
                    message:
                        'Confirma solo si el dinero de la entrada ${t.id} ya se '
                        'devolvió fuera de la app. Esta app no devuelve dinero.',
                    confirm: 'Registrar',
                    operation: (id) =>
                        book.recordRefundReturned(id, actorId: identity.id),
                  ),
                  child: const Text('Registrar devolución efectuada'),
                ),
              if (t.status == TicketStatus.active && t.credential != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    key: const ValueKey('admin-replace-credential'),
                    onPressed: () => _decide(
                      context,
                      t,
                      title: 'Retirar y reemplazar credencial',
                      message:
                          'La credencial actual deja de servir para siempre y '
                          'se emite otra. No se borran venta, pago ni cuenta.',
                      confirm: 'Reemplazar',
                      operation: (id) => book.replaceCredential(
                        id,
                        actorId: identity.id,
                        reason: 'Retirada por la administración',
                      ),
                    ),
                    icon: const Icon(Icons.autorenew_rounded),
                    label: const Text('Retirar y reemplazar credencial'),
                  ),
                ),
              const SizedBox(height: 14),
              Text('Historial', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              TicketHistory(ticket: t),
            ],
          );
        },
      ),
    );
  }
}

/// Cortesía autorizada por la administración: activa sin pago. La
/// cantidad la decide quien autoriza; no se fija ninguna regla aquí.
class CourtesyPage extends StatefulWidget {
  const CourtesyPage({
    super.key,
    required this.store,
    required this.identity,
    this.clock = systemClock,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final Clock clock;

  @override
  State<CourtesyPage> createState() => _CourtesyPageState();
}

class _CourtesyPageState extends State<CourtesyPage> {
  final _holder = TextEditingController();
  final _reason = TextEditingController();
  Night? _night;
  int _quantity = 1;
  String? _error;

  @override
  void dispose() {
    _holder.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = VenueScope.of(context);
    final now = VenueTime.of(widget.clock());
    final nights = [
      ...NightSchedule.weekendNights(now),
      ...NightSchedule.weekendNights(now, weeksAhead: 1),
    ].where((n) => !n.hasEnded(now)).toList();
    _night ??= nights.isEmpty ? null : nights.first;
    final product = config.ticketProducts.firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Autorizar cortesía')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NoticeBox(
            icon: Icons.card_giftcard_rounded,
            text:
                'Entradas sin pago, autorizadas por la administración (por '
                'ejemplo, de una mesa VIP). Se canjean en taquilla.',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<Night>(
            key: const ValueKey('courtesy-night'),
            initialValue: _night,
            isExpanded: true,
            selectedItemBuilder: (_) => [
              for (final n in nights) Text('${n.shortLabel} ${n.date.year}'),
            ],
            decoration: const InputDecoration(labelText: 'Noche'),
            items: [
              for (final n in nights)
                DropdownMenuItem(
                  value: n,
                  child: Text('${n.label} de ${n.date.year}'),
                ),
            ],
            onChanged: (n) => setState(() => _night = n),
          ),
          TextField(
            key: const ValueKey('courtesy-holder'),
            controller: _holder,
            decoration: const InputDecoration(labelText: 'A nombre de'),
          ),
          TextField(
            key: const ValueKey('courtesy-reason'),
            controller: _reason,
            decoration: const InputDecoration(
              labelText: 'Motivo (por ejemplo, reserva VIP)',
            ),
          ),
          Row(
            children: [
              const Expanded(child: Text('Entradas')),
              IconButton(
                tooltip: 'Una menos',
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text('$_quantity'),
              IconButton(
                key: const ValueKey('courtesy-more'),
                tooltip: 'Una más',
                onPressed: _quantity < 10
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_error case final e?)
            Text(e, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('courtesy-submit'),
            onPressed: product == null || _night == null
                ? null
                : () {
                    try {
                      widget.store.perform(
                        (b) => b.authorizeCourtesy(
                          night: _night!,
                          product: product,
                          quantity: _quantity,
                          actorId: widget.identity.id,
                          holderName: _holder.text,
                          reason: _reason.text,
                        ),
                      );
                      Navigator.of(context).pop();
                    } on TicketException catch (e) {
                      setState(() => _error = ticketErrorLabel(e.error));
                    }
                  },
            child: const Text('Autorizar cortesía'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../theme/night_neutrals.dart';
import '../../reservations/domain/night_schedule.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../session/demo_identities.dart';
import '../../venues/venue_config.dart';
import '../data/demo_ticket_store.dart';
import '../domain/ticket.dart';
import 'ticket_widgets.dart';

/// Pestaña «Entradas» del cliente y del promotor.
///
/// Cliente: compra para sí (noches de su semana, N5), paga en un paso
/// aparte (simulado) y ve sus entradas con credencial, estado, comprobante
/// e historial. Promotor: registra la venta a nombre de un comprador
/// (noches operativas y futuras, N7), la activa solo al confirmar el pago
/// comprobado y canjea con su lote físico. Cada uno ve solo lo suyo.
class GuestTickets extends StatefulWidget {
  const GuestTickets({
    super.key,
    required this.store,
    required this.identity,
    this.clock = systemClock,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final Clock clock;

  @override
  State<GuestTickets> createState() => _GuestTicketsState();
}

class _GuestTicketsState extends State<GuestTickets> {
  final _holder = TextEditingController();
  Night? _night;
  int _quantity = 1;
  String? _error;

  bool get _isClient => widget.identity.profile == DemoProfile.client;

  @override
  void dispose() {
    _holder.dispose();
    super.dispose();
  }

  List<Night> _nights() {
    final now = VenueTime.of(widget.clock());
    final nights = _isClient
        ? NightSchedule.calendarWeekendNights(now)
        : [
            ...NightSchedule.weekendNights(now),
            ...NightSchedule.weekendNights(now, weeksAhead: 1),
          ];
    return nights.where((n) => !n.hasEnded(now)).toList();
  }

  void _sell(TicketProduct product) {
    final night = _night;
    if (night == null) return;
    setState(() => _error = null);
    try {
      final p = widget.store.perform(
        (b) => b.sell(
          night: night,
          product: product,
          quantity: _quantity,
          channel: _isClient ? TicketChannel.app : TicketChannel.promoter,
          actorId: widget.identity.id,
          ownerId: _isClient ? widget.identity.id : null,
          holderName: _isClient ? null : _holder.text,
        ),
      );
      _holder.clear();
      _openPurchase(p.id);
    } on TicketException catch (e) {
      setState(() => _error = ticketErrorLabel(e.error));
    }
  }

  void _openPurchase(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PurchasePage(
        store: widget.store,
        identity: widget.identity,
        purchaseId: id,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = VenueScope.of(context);
    final nights = _nights();
    if (_night != null && !nights.contains(_night)) _night = null;
    _night ??= nights.isEmpty ? null : nights.first;
    final product = config.ticketProducts.isEmpty
        ? null
        : config.ticketProducts.first;
    final price = (product != null && _night != null)
        ? product.demoPriceFor(_night!)
        : null;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final purchases = widget.store.purchasesBy(widget.identity.id);
        final mine = _isClient
            ? widget.store.ticketsOf(widget.identity.id)
            : const <Ticket>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              _isClient ? 'Entradas' : 'Vender entradas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: NightNeutrals.white,
              ),
            ),
            const SizedBox(height: 8),
            if (product == null)
              const NoticeBox(
                icon: Icons.info_outline_rounded,
                text: 'Este local no tiene entradas a la venta en la demo.',
              )
            else
              Card(
                color: NightNeutrals.glass(0.06),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(product.name, style: theme.textTheme.titleMedium),
                      DropdownButtonFormField<Night>(
                        key: const ValueKey('ticket-night'),
                        initialValue: _night,
                        isExpanded: true,
                        // Con texto grande, el campo muestra la forma corta
                        // para no recortar la fecha; la lista, la larga.
                        selectedItemBuilder: (_) => [
                          for (final n in nights)
                            Text('${n.shortLabel} ${n.date.year}'),
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
                      const SizedBox(height: 6),
                      Text(
                        price == null
                            ? 'Sin precio para esa noche.'
                            : '${copLabel(price)} por persona esa noche · '
                                  'precio de demostración, no es el del local',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.amber,
                        ),
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Personas')),
                          IconButton(
                            key: const ValueKey('ticket-less'),
                            tooltip: 'Una entrada menos',
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Text(
                            '$_quantity',
                            key: const ValueKey('ticket-quantity'),
                            style: theme.textTheme.titleMedium,
                          ),
                          IconButton(
                            key: const ValueKey('ticket-more'),
                            tooltip: 'Una entrada más',
                            // NOT DECIDED: límite por compra. 10 es solo un
                            // tope técnico de la demo.
                            onPressed: _quantity < 10
                                ? () => setState(() => _quantity++)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      if (!_isClient)
                        TextField(
                          key: const ValueKey('ticket-holder'),
                          controller: _holder,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del comprador',
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        price == null
                            ? ''
                            : 'Total: ${copLabel(price * _quantity)} '
                                  '(demostración). Una entrada por persona, '
                                  'cada una con su credencial. '
                                  '${_isClient ? 'El pago va en el paso siguiente.' : 'El derecho se activa al confirmar el pago comprobado.'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (_error case final e?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            e,
                            key: const ValueKey('ticket-error'),
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        key: const ValueKey('ticket-buy'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _night == null || price == null
                            ? null
                            : () => _sell(product),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(
                          _isClient ? 'Continuar al pago' : 'Registrar venta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isClient) ...[
              SectionLabel('Mis entradas', count: mine.length),
              if (mine.isEmpty)
                Text(
                  'Todavía no tienes entradas en esta sesión de demostración.',
                  style: TextStyle(color: NightNeutrals.glass(0.7)),
                ),
              for (final t in mine)
                TicketTile(
                  ticket: t,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TicketDetailPage(
                        store: widget.store,
                        identity: widget.identity,
                        ticketId: t.id,
                        clock: widget.clock,
                      ),
                    ),
                  ),
                ),
            ],
            SectionLabel(
              _isClient ? 'Comprobantes' : 'Mis ventas',
              count: purchases.length,
            ),
            for (final p in purchases)
              Card(
                key: ValueKey('purchase-${p.id}'),
                color: NightNeutrals.glass(0.06),
                child: ListTile(
                  minTileHeight: 56,
                  title: Text(
                    '${p.id} · ${p.quantity} '
                    '${p.quantity == 1 ? 'entrada' : 'entradas'} · '
                    '${p.night.shortLabel}',
                  ),
                  subtitle: Text(
                    '${p.holderName ?? widget.identity.name} · '
                    '${p.payment.label}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openPurchase(p.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Comprobante de una compra (cliente) o venta (promotor), con su paso de
/// pago. Solo lo ve quien la hizo.
class PurchasePage extends StatelessWidget {
  const PurchasePage({
    super.key,
    required this.store,
    required this.identity,
    required this.purchaseId,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final String purchaseId;

  Future<void> _pay(BuildContext context, TicketPurchase p) async {
    final messenger = ScaffoldMessenger.of(context);
    final promoter = p.channel == TicketChannel.promoter;
    if (promoter) {
      final ok = await _confirm(
        context,
        title: '¿Confirmar pago comprobado?',
        message:
            'Confírmalo solo si ya comprobaste el pago de ${p.holderName}. Al '
            'confirmar se activan ${p.quantity} '
            '${p.quantity == 1 ? 'entrada' : 'entradas'} de tu circuito.',
        confirm: 'Pago comprobado',
      );
      if (!ok) return;
    }
    // Se comprueba el estado exacto tras la confirmación (H1).
    if (store.book.purchaseById(p.id)?.payment != PaymentStatus.pending) {
      messenger.showSnackBar(
        SnackBar(content: Text(ticketErrorLabel(TicketError.alreadyPaid))),
      );
      return;
    }
    try {
      store.perform(
        (b) => promoter
            ? b.verifyPromoterPayment(p.id, actorId: identity.id)
            : b.simulatePayment(p.id, actorId: identity.id),
      );
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
      appBar: AppBar(title: const Text('Comprobante')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final p = store.book.purchaseById(purchaseId);
          if (p == null || p.createdBy != identity.id) {
            return const Center(child: Text('Comprobante no disponible.'));
          }
          final tickets = store.book.ticketsOf(p.id);
          final pending = p.payment == PaymentStatus.pending;
          final promoter = p.channel == TicketChannel.promoter;
          Widget row(String k, String v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(v, style: theme.textTheme.bodyLarge),
              ],
            ),
          );
          return ListView(
            key: ValueKey('purchase-page-${p.id}'),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              row(promoter ? 'Venta' : 'Compra', p.id),
              row('Local', VenueScope.of(context).venue.name),
              row('Noche', '${p.night.label} de ${p.night.date.year}'),
              row('Entrada', '${p.product.name} × ${p.quantity}'),
              if (p.holderName case final h?) row('Comprador', h),
              row(
                'Importe',
                '${copLabel(p.unitPrice)} × ${p.quantity} = '
                    '${copLabel(p.total)} (demostración)',
              ),
              row(
                'Pago',
                pending
                    ? p.payment.label
                    : '${p.payment.label} · ${venueDateTimeLabel(p.paidAt!)}',
              ),
              const SizedBox(height: 8),
              NoticeBox(
                icon: Icons.payments_outlined,
                color: AppColors.amber,
                text: pending
                    ? promoter
                          ? 'Venta registrada sin activar: el derecho se activa '
                                'cuando confirmes el pago comprobado.'
                          : 'Sin pago las entradas no dan acceso. En esta demo '
                                'el pago es simulado: no se cobra dinero.'
                    : 'No se cobró dinero real. Pago, primer ingreso y canje '
                          'de manilla son pasos distintos.',
              ),
              if (pending)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: FilledButton.icon(
                    key: const ValueKey('purchase-pay'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _pay(context, p),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      promoter
                          ? 'Confirmar pago comprobado'
                          : 'Simular pago (demostración)',
                    ),
                  ),
                ),
              SectionLabel('Entradas', count: tickets.length),
              for (final t in tickets)
                promoter
                    ? _PromoterTicket(
                        store: store,
                        identity: identity,
                        ticket: t,
                      )
                    : TicketTile(ticket: t),
            ],
          );
        },
      ),
    );
  }
}

/// Entrada de una venta del promotor: su credencial para entregar al
/// comprador y el canje con el lote físico del promotor.
class _PromoterTicket extends StatefulWidget {
  const _PromoterTicket({
    required this.store,
    required this.identity,
    required this.ticket,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final Ticket ticket;

  @override
  State<_PromoterTicket> createState() => _PromoterTicketState();
}

class _PromoterTicketState extends State<_PromoterTicket> {
  bool _busy = false;
  String? _result;

  /// Un solo identificador por intento: un reintento tras un fallo de red
  /// no puede canjear dos veces.
  String? _requestId;

  Future<void> _redeem() async {
    final t = widget.ticket;
    final ok = await _confirm(
      context,
      title: '¿Entregar manilla de tu lote?',
      message:
          'Entrada ${t.id}. Se registra el canje una sola vez; después la '
          'entrada queda «No canjeable».',
      confirm: 'Entregar manilla',
    );
    if (!ok || !mounted) return;
    _requestId ??= 'promo-${t.id}-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final r = await widget.store.redeem(
        t.credential!,
        actorId: widget.identity.id,
        point: RedeemPoint.promoterLot,
        requestId: _requestId!,
      );
      if (!mounted) return;
      setState(() {
        _result = r.ok
            ? 'Manilla de tu lote entregada.'
            : rejectReasonLabel(r.reason!);
        _requestId = null;
      });
    } on TicketGatewayUnavailable {
      if (mounted) {
        setState(
          () => _result =
              'Sin respuesta: no se sabe si quedó registrado. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    return Card(
      key: ValueKey('ticket-${t.id}'),
      color: NightNeutrals.glass(0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(t.statusIcon, color: t.statusColor),
                const SizedBox(width: 8),
                Expanded(child: Text('Entrada ${t.id} · ${t.phaseLabel}')),
              ],
            ),
            if (t.credential case final c?) ...[
              const SizedBox(height: 4),
              SelectableText(
                'Credencial: ${credentialLabel(c)}',
                key: ValueKey('promoter-credential-${t.id}'),
              ),
              Text('Entrégala al comprador. ${t.circuitLabel}', style: muted),
            ],
            if (t.status == TicketStatus.active && t.credential != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  key: ValueKey('promoter-redeem-${t.id}'),
                  onPressed: _busy ? null : _redeem,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.watch_outlined),
                  label: Text(
                    _busy ? 'Registrando…' : 'Entregar manilla de mi lote',
                  ),
                ),
              ),
            if (_result case final r?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(r, key: ValueKey('promoter-result-${t.id}')),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ficha de una entrada del cliente: credencial, fase, circuito, historial
/// y solicitudes. Solo la ve su dueño.
class TicketDetailPage extends StatelessWidget {
  const TicketDetailPage({
    super.key,
    required this.store,
    required this.identity,
    required this.ticketId,
    this.clock = systemClock,
  });

  final DemoTicketStore store;
  final DemoIdentity identity;
  final String ticketId;
  final Clock clock;

  Future<void> _request(BuildContext context, Ticket t, {Night? to}) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      title: to == null
          ? '¿Solicitar devolución?'
          : '¿Solicitar cambio de noche?',
      message: to == null
          ? 'La administración decide. Si la autoriza, la entrada se anula y '
                'el dinero se devuelve fuera de la app.'
          : 'Pasar la entrada ${t.id} a ${to.label.toLowerCase()}. La '
                'administración decide.',
      confirm: 'Solicitar',
    );
    if (!ok) return;
    try {
      store.perform(
        (b) => to == null
            ? b.requestRefund(t.id, actorId: identity.id)
            : b.requestNightChange(t.id, to, actorId: identity.id),
      );
    } on TicketException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ticketErrorLabel(e.error))),
      );
    }
  }

  Future<void> _replace(BuildContext context, Ticket t) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      context,
      title: '¿Reemplazar la credencial?',
      message:
          'La credencial actual dejará de servir para siempre (no se '
          'reutiliza) y recibirás otra. Úsalo si compartiste una captura. La '
          'compra y el pago no cambian.',
      confirm: 'Reemplazar',
    );
    if (!ok) return;
    final current = store.book.ticketById(t.id);
    if (current?.credential != t.credential) return; // cambió mientras tanto
    try {
      store.perform(
        (b) => b.replaceCredential(
          t.id,
          actorId: identity.id,
          reason: 'Solicitada por el cliente',
        ),
      );
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
      appBar: AppBar(title: const Text('Entrada')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final t = store.book.ticketById(ticketId);
          if (t == null || t.ownerId != identity.id) {
            return const Center(child: Text('Entrada no disponible.'));
          }
          final now = VenueTime.of(clock());
          final others = NightSchedule.calendarWeekendNights(
            now,
          ).where((n) => n != t.night && !n.hasEnded(now)).toList();
          final canRequest = store.book.canRequest(t);
          final muted = theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          );
          return ListView(
            key: ValueKey('ticket-page-${t.id}'),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Icon(t.statusIcon, color: t.statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.phaseLabel,
                      key: const ValueKey('ticket-status'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: t.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${t.night.label} de ${t.night.date.year} · '
                '${t.night.scheduleLabel}',
              ),
              const SizedBox(height: 12),
              if (t.status == TicketStatus.active && t.credential != null)
                DemoCodeView(
                  code: t.credential!,
                  caption:
                      'Credencial de la entrada (QR ficticio, no escaneable). '
                      'No lleva tus datos: la puerta los consulta. Si alguien '
                      'usa una captura antes que tú, entra él: no la '
                      'compartas.',
                )
              else
                NoticeBox(
                  icon: t.statusIcon,
                  text: switch (t.status) {
                    TicketStatus.pendingPayment =>
                      'La credencial aparece cuando la compra esté pagada.',
                    TicketStatus.redeemed =>
                      'Canjeada: ya tienes tu manilla. El reingreso es con la '
                          'manilla.',
                    _ => 'Entrada anulada: no tiene credencial vigente.',
                  },
                ),
              const SizedBox(height: 12),
              Text(t.circuitLabel),
              if (t.firstEntryAt case final at?)
                Text('Primer ingreso: ${venueDateTimeLabel(at)}', style: muted),
              if (t.requestLabel case final r?) ...[
                const SizedBox(height: 4),
                Text(r, key: const ValueKey('ticket-request')),
              ],
              if (t.status == TicketStatus.active && t.credential != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    key: const ValueKey('ticket-replace'),
                    onPressed: () => _replace(context, t),
                    icon: const Icon(Icons.autorenew_rounded),
                    label: const Text('Reemplazar credencial'),
                  ),
                ),
              if (canRequest) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('ticket-refund'),
                  onPressed: () => _request(context, t),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Solicitar devolución'),
                ),
                for (final n in others)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: ValueKey('ticket-change-${n.id}'),
                      onPressed: () => _request(context, t, to: n),
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: Text('Pedir cambio a ${n.shortLabel}'),
                    ),
                  ),
              ],
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

/// QR PERSONAL de la cuenta ficticia, en «Más» del cliente.
class PersonalQrCard extends StatelessWidget {
  const PersonalQrCard({super.key, required this.identity});

  final DemoIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('personal-qr'),
      color: NightNeutrals.glass(0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mi QR personal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DemoCodeView(
              code: personalQrCode(identity),
              size: 140,
              caption:
                  'Identifica tu cuenta ficticia. No es un pago, no prueba tu '
                  'edad y no es una entrada.',
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
}) async {
  final r = await showDialog<bool>(
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
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

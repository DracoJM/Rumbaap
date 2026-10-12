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
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  Night? _night;
  int _quantity = 1;
  String? _error;

  bool get _isClient => widget.identity.profile == DemoProfile.client;

  @override
  void dispose() {
    _holder.dispose();
    _phone.dispose();
    _idNumber.dispose();
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
          buyerPhone: _isClient ? null : _phone.text,
          buyerIdNumber: _isClient ? null : _idNumber.text,
        ),
      );
      _holder.clear();
      _phone.clear();
      _idNumber.clear();
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
                color: AppColors.text,
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
                color: AppColors.surface,
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
                      if (!_isClient)
                        TextField(
                          key: const ValueKey('ticket-phone'),
                          controller: _phone,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono del comprador',
                          ),
                        ),
                      if (!_isClient)
                        TextField(
                          key: const ValueKey('ticket-id-number'),
                          controller: _idNumber,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cédula del comprador',
                            helperText:
                                'Solo dígitos. Se guardan para uso futuro; '
                                'no crean ni vinculan ninguna cuenta.',
                            helperMaxLines: 2,
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
                  style: TextStyle(color: AppColors.textMuted),
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
                color: AppColors.surface,
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
              if (promoter) ...[
                row('Teléfono', p.buyerPhone ?? 'No registrado'),
                row('Cédula', p.buyerIdNumber ?? 'No registrado'),
              ],
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
              if (promoter && !pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Sin entregar: '
                    '${tickets.where((t) => t.status == TicketStatus.active).length}'
                    ' de ${tickets.length}. La entrega de la manilla de tu '
                    'lote está disponible en cualquier momento; cada entrada '
                    'se entrega una sola vez.',
                    key: const ValueKey('promoter-undelivered'),
                  ),
                ),
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
/// comprador y el canje con el lote físico del promotor. La entrega se
/// permite en cualquier momento (no es admisión: la puerta sigue
/// controlando el ingreso con la manilla).
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
          'Entrada ${t.id}. Se registra la entrega de la manilla una sola vez, '
          'con tu identidad y la hora actual; después la entrada queda '
          '«No canjeable». No es el ingreso: la puerta sigue controlando la '
          'manilla.',
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
      color: AppColors.surface,
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
                CredentialQrView(
                  code: t.credential!,
                  caption:
                      'Muéstralo en la puerta y en la taquilla. El QR solo '
                      'lleva este código, no tus datos: el personal los '
                      'consulta. Si alguien usa una captura antes que tú, '
                      'entra él: no lo compartas.',
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

/// «Mi QR» del cliente, en «Más»: el MISMO QR real de una entrada propia de
/// la noche en curso. No hay un código de cuenta permanente que una captura
/// antigua pueda usar otra noche. Con varias entradas esa noche, la persona
/// elige cuál mostrar (un QR a la vez); no se crea, fusiona ni transfiere
/// nada. Sin entrada, lo dice.
class PersonalQrCard extends StatefulWidget {
  const PersonalQrCard({
    super.key,
    required this.identity,
    required this.store,
    this.clock = systemClock,
  });

  final DemoIdentity identity;
  final DemoTicketStore store;
  final Clock clock;

  @override
  State<PersonalQrCard> createState() => _PersonalQrCardState();
}

class _PersonalQrCardState extends State<PersonalQrCard> {
  /// Elección explícita: vale solo para este local (su almacén), esta
  /// cuenta, esta noche y una entrada que siga en la lista. Si algo cambia,
  /// se descarta (los ID de entrada se repiten entre locales).
  ({DemoTicketStore store, String accountId, Night night, String ticketId})?
  _choice;

  @override
  void didUpdateWidget(PersonalQrCard old) {
    super.didUpdateWidget(old);
    // Otra cuenta u otro local: la elección anterior no se conserva.
    if (old.identity.id != widget.identity.id ||
        !identical(old.store, widget.store)) {
      _choice = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('personal-qr'),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final now = VenueTime.of(widget.clock());
            final tonight = NightSchedule.weekendNights(
              now,
            ).where((n) => n.isInProgress(now)).firstOrNull;
            final tickets = tonight == null
                ? const <Ticket>[]
                : [
                    for (final t in widget.store.ticketsOf(widget.identity.id))
                      if (t.night == tonight &&
                          t.credential != null &&
                          (t.status == TicketStatus.active ||
                              t.status == TicketStatus.redeemed))
                        t,
                  ];
            final c = _choice;
            final chosen =
                c != null &&
                    identical(c.store, widget.store) &&
                    c.accountId == widget.identity.id &&
                    c.night == tonight
                ? tickets.where((t) => t.id == c.ticketId).firstOrNull
                : null;
            final shown = tickets.length == 1 ? tickets.single : chosen;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Mi QR', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (tickets.isEmpty)
                  Text(
                    'Ahora no tienes una entrada de esta noche con QR. Tus '
                    'entradas de otras noches tienen su QR en «Entradas». En '
                    'barra la compra se puede registrar sin comprobante.',
                    key: const ValueKey('personal-qr-none'),
                    style: theme.textTheme.bodyMedium,
                  ),
                if (tickets.length > 1) ...[
                  Text(
                    'Tienes ${tickets.length} entradas para esta noche. Elige '
                    'cuál mostrar; se ve un QR a la vez.',
                    key: const ValueKey('personal-qr-choose'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in tickets)
                        ChoiceChip(
                          key: ValueKey('personal-qr-pick-${t.id}'),
                          label: Text('Entrada ${t.id} · ${t.phaseLabel}'),
                          selected: shown?.id == t.id,
                          onSelected: (_) => setState(
                            () => _choice = (
                              store: widget.store,
                              accountId: widget.identity.id,
                              night: tonight!,
                              ticketId: t.id,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (shown != null)
                  CredentialQrView(
                    code: shown.credential!,
                    caption: shown.status == TicketStatus.redeemed
                        ? 'Entrada ${shown.id} canjeada: tu acceso es la '
                              'manilla. En barra este QR te identifica para '
                              'enviarte el comprobante; no da otro canje.'
                        : 'Entrada ${shown.id} de esta noche: sirve en la '
                              'puerta, la taquilla y la barra. Solo lleva este '
                              'código, no tus datos.',
                  ),
              ],
            );
          },
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
      // Con texto al 200 % en un teléfono pequeño todo el diálogo se
      // desplaza, también título y botones.
      scrollable: true,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../theme/night_neutrals.dart';
import '../reservations/domain/reservation.dart';
import '../reservations/domain/venue_table.dart';
import '../reservations/presentation/admin/admin_widgets.dart';
import '../tickets/data/demo_ticket_store.dart';
import '../tickets/domain/ticket.dart';
import '../tickets/presentation/ticket_widgets.dart';
import '../venues/venue_config.dart';
import 'vip_benefits.dart';

/// Derechos y seguimiento de una reserva VIP. La administración ve las
/// cortesías emitidas con sus nombres y puede emitir hasta el derecho; el
/// titular solo ve recuentos y estado. Lo que no tiene regla se dice.
class VipBenefitsCard extends StatelessWidget {
  const VipBenefitsCard({
    super.key,
    required this.reservation,
    required this.venue,
    required this.tickets,
    this.adminId,
    this.onOpenTicket,
  });

  final Reservation reservation;
  final Venue venue;
  final DemoTicketStore tickets;

  /// Administración que actúa; `null` en la vista del titular.
  final String? adminId;
  final void Function(String ticketId)? onOpenTicket;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tickets,
      builder: (context, _) {
        final b = VipBenefits.of(reservation, venue, tickets.book);
        if (b == null) return const SizedBox.shrink();
        return _content(context, b);
      },
    );
  }

  Widget _content(BuildContext context, VipBenefits b) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
    );
    final admin = adminId != null;
    final products = VenueScope.of(context).ticketProducts;
    final String? blocked = switch (b.state) {
      VipBenefitState.pendingPrepayment =>
        'La reserva espera la verificación del prepago. No está definido si '
            'las cortesías se emiten antes, así que todavía no se emiten.',
      VipBenefitState.reservationEnded =>
        'La reserva terminó. No está definido qué pasa con el beneficio: no '
            'se emiten más cortesías y lo ya emitido se conserva.',
      VipBenefitState.active => null,
    };
    return Card(
      key: ValueKey('vip-benefits-${reservation.id}'),
      color: NightNeutrals.glass(0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Beneficios VIP', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Incluye ${b.entitledCourtesies} cortesías y ${b.bottles} '
              'botella fuera del consumo por esta mesa VIP.',
            ),
            const SizedBox(height: 8),
            Text(
              'Cortesías: ${b.issued.length} de ${b.entitledCourtesies} '
              'emitidas · ${b.redeemed} canjeadas · ${b.voided} anuladas · '
              '${b.remaining} por emitir',
              key: ValueKey('vip-courtesies-${reservation.id}'),
            ),
            if (b.voided > 0)
              Text(
                'Una cortesía anulada no se repone sola: no hay una regla '
                'para eso.',
                style: muted,
              ),
            if (admin)
              for (final t in b.issued)
                ListTile(
                  key: ValueKey('vip-ticket-${t.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  title: Text('Entrada ${t.id} · ${t.holderName ?? ''}'),
                  subtitle: Text(t.phaseLabel),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenTicket == null
                      ? null
                      : () => onOpenTicket!(t.id),
                ),
            const SizedBox(height: 8),
            Text(
              'Botella: ${b.bottles}, fuera del consumo (no cuenta en el '
              'consumo de la mesa). No está definido quién la entrega ni cómo '
              'se registra, así que la app no la marca como entregada.',
              key: ValueKey('vip-bottle-${reservation.id}'),
              style: muted,
            ),
            if (blocked != null) ...[
              const SizedBox(height: 8),
              NoticeBox(
                key: ValueKey('vip-blocked-${reservation.id}'),
                icon: Icons.info_outline_rounded,
                color: AppColors.amber,
                text: blocked,
              ),
            ],
            if (admin && blocked == null && b.remaining > 0) ...[
              const SizedBox(height: 8),
              if (products.length == 1)
                FilledButton.tonal(
                  key: ValueKey('vip-issue-${reservation.id}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => _issue(context, b, products.single),
                  child: const Text('Emitir cortesías'),
                )
              else
                Text(
                  'Hay varios tipos de entrada y no está definido cuál se usa '
                  'para las cortesías VIP.',
                  style: muted,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _issue(
    BuildContext context,
    VipBenefits b,
    TicketProduct product,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _IssueDialog(max: b.remaining),
    );
    if (result == null) return;
    final (quantity, name) = result;
    try {
      tickets.perform(
        (book) => issueVipCourtesies(
          book,
          reservation: reservation,
          venue: venue,
          product: product,
          quantity: quantity,
          holderName: name,
          actorId: adminId!,
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('$quantity cortesías emitidas y activas.')),
      );
    } on VipBenefitException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'El beneficio cambió mientras decidías. No se emitió nada.',
          ),
        ),
      );
    } on TicketException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ticketErrorLabel(e.error))),
      );
    }
  }
}

/// Cantidad (1 al máximo disponible) y nombre: el circuito de cortesías
/// exige nombre. Sin valores por defecto.
class _IssueDialog extends StatefulWidget {
  const _IssueDialog({required this.max});

  final int max;

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  final _qty = TextEditingController();
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final q = int.tryParse(_qty.text);
    if (q == null || q < 1 || q > widget.max) {
      setState(() => _error = 'Escribe una cantidad entre 1 y ${widget.max}.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el nombre de quien recibe.');
      return;
    }
    Navigator.of(context).pop((q, _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Emitir cortesías VIP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quedan ${widget.max}. Se activan sin pago como cortesías y se '
            'canjean en taquilla.',
          ),
          TextField(
            key: const ValueKey('vip-qty'),
            controller: _qty,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cantidad'),
            onChanged: (_) => setState(() => _error = null),
          ),
          TextField(
            key: const ValueKey('vip-name'),
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Nombre de quien recibe',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() => _error = null),
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
          child: const Text('Emitir'),
        ),
      ],
    );
  }
}

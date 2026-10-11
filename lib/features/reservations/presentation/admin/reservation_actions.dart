import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_book.dart';
import '../table_presentation.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';

/// Acciones del administrador sobre una reserva, según su estado (R2, R4–R6).
///
/// Cada acción conserva el ID de la reserva: su mesa y su noche no dependen
/// de lo que se esté mostrando. Tras cada confirmación se comprueba que la
/// reserva siga exactamente en el estado en que se abrió el recorrido, y el
/// libro vuelve a validar la operación; si algo cambió, no se hace nada y se
/// explica.
class ReservationActions extends StatefulWidget {
  const ReservationActions({
    super.key,
    required this.reservation,
    required this.store,
    required this.clock,
    this.enabled = true,
  });

  final Reservation reservation;
  final DemoReservationStore store;
  final Clock clock;

  /// `false` mientras la vista se actualiza tras un cambio.
  final bool enabled;

  @override
  State<ReservationActions> createState() => _ReservationActionsState();
}

class _ReservationActionsState extends State<ReservationActions> {
  bool _busy = false;

  Reservation get r => widget.reservation;

  String get _subject =>
      '${r.tableIn(widget.store.venue).displayName} · ${r.night.label}\nTitular: ${r.holder.name}';

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_busy;
    final venueNow = VenueTime.of(widget.clock());
    return switch (r.status) {
      ReservationStatus.pendingPayment => _column([
        const NoticeBox(
          icon: Icons.payments_outlined,
          color: AppColors.amber,
          text:
              'Solicitud VIP pendiente de pago, sin vencimiento. Confirma '
              'cuando hayas verificado el prepago, o recházala. Esta app no '
              'cobra ni comprueba pagos.',
        ),
        FilledButton.icon(
          key: const ValueKey('action-confirm-prepayment'),
          onPressed: enabled ? _confirmPrepayment : null,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Confirmar prepago verificado'),
        ),
        _dangerButton(
          key: const ValueKey('action-reject'),
          label: 'Rechazar solicitud',
          icon: Icons.close_rounded,
          onPressed: enabled ? _reject : null,
        ),
      ]),
      ReservationStatus.confirmed => _column([
        FilledButton.icon(
          key: const ValueKey('action-arrival'),
          onPressed: enabled && r.night.isInProgress(venueNow)
              ? _arrival
              : null,
          icon: const Icon(Icons.how_to_reg_outlined),
          label: const Text('Registrar llegada'),
        ),
        if (!r.night.isInProgress(venueNow))
          Text(
            r.night.hasEnded(venueNow)
                ? 'La noche terminó: ya no se registran llegadas.'
                : 'La llegada se podrá registrar desde las '
                      '${r.night.opensLabel} del '
                      '${r.night.label.toLowerCase()} (hora de Colombia).',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        _dangerButton(
          key: const ValueKey('action-revoke'),
          label: 'Revocar reserva',
          icon: Icons.block_rounded,
          onPressed: enabled ? _revoke : null,
        ),
        _releaseButton(enabled),
      ]),
      ReservationStatus.seated => _column([_releaseButton(enabled)]),
      ReservationStatus.inProcess => NoticeBox(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.amber,
        text:
            'En proceso: se confirma sola cuando se completa el trámite, o '
            'expira a las '
            '${venueTimeLabel(r.createdAt.add(ReservationBook.inProcessTimeout))}'
            ' si no se completa. No requiere acción del administrador.',
      ),
      ReservationStatus.revoked ||
      ReservationStatus.released ||
      ReservationStatus.expired => NoticeBox(
        icon: Icons.history_rounded,
        text:
            'Reserva terminada (${r.statusLabel.toLowerCase()}). No admite '
            'acciones; su historial se conserva.',
      ),
    };
  }

  Widget _column(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, child) in children.indexed) ...[
        if (i > 0) const SizedBox(height: 10),
        child,
      ],
    ],
  );

  Widget _dangerButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => OutlinedButton.icon(
    key: key,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.danger,
      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );

  Widget _releaseButton(bool enabled) => OutlinedButton.icon(
    key: const ValueKey('action-release'),
    onPressed: enabled ? _release : null,
    icon: const Icon(Icons.lock_open_rounded),
    label: const Text('Liberar mesa'),
  );

  Future<void> _confirmPrepayment() => _run(
    steps: [
      _Step(
        title: 'Confirmar prepago verificado',
        message:
            '$_subject\n\nLa reserva quedará confirmada (Reservada). '
            'Confirma solo si ya verificaste el prepago: esta app no cobra '
            'ni comprueba pagos.',
        confirmLabel: 'Confirmar prepago',
      ),
    ],
    operation: (book, id) => book.markPrepaymentReceived(id),
    success:
        'Prepago confirmado: ${r.tableIn(widget.store.venue).displayName} queda reservada para el '
        '${r.night.label.toLowerCase()}.',
  );

  Future<void> _reject() => _run(
    steps: [
      _Step(
        title: 'Rechazar solicitud VIP',
        message:
            '$_subject\n\nLa solicitud quedará rechazada y la mesa, '
            'disponible para esa noche. El historial se conserva.',
        confirmLabel: 'Rechazar',
        destructive: true,
      ),
    ],
    operation: (book, id) => book.rejectRequest(id),
    success:
        'Solicitud rechazada: ${r.tableIn(widget.store.venue).displayName} queda disponible para el '
        '${r.night.label.toLowerCase()}.',
  );

  Future<void> _arrival() => _run(
    steps: [
      _Step(
        title: 'Registrar llegada',
        message:
            '$_subject\n\nLa mesa pasará a Ocupada. Regístrala cuando el '
            'titular, o alguien en su nombre, reclame la mesa.',
        confirmLabel: 'Registrar llegada',
      ),
    ],
    operation: (book, id) => book.markArrival(id),
    success:
        'Llegada registrada: ${r.tableIn(widget.store.venue).displayName} queda ocupada.',
  );

  Future<void> _revoke() => _run(
    steps: [
      _Step(
        title: 'Revocar reserva',
        message:
            '$_subject\n\nSe anulará la reserva ${r.id} y la mesa quedará '
            'disponible para esa noche. Esta acción no se puede deshacer.',
        confirmLabel: 'Revocar',
        destructive: true,
      ),
    ],
    operation: (book, id) => book.revoke(id),
    success:
        'Reserva revocada: ${r.tableIn(widget.store.venue).displayName} queda disponible para el '
        '${r.night.label.toLowerCase()}.',
  );

  Future<void> _release() => _run(
    steps: [
      _Step(
        title: 'Liberar mesa',
        message: r.status == ReservationStatus.seated
            ? '$_subject\n\nLa mesa está OCUPADA. Liberarla la dejará '
                  'disponible para nuevas reservas de esta noche aunque haya '
                  'personas usándola.'
            : '$_subject\n\nLa mesa tiene una reserva confirmada. Liberarla '
                  'anulará esa reserva y dejará la mesa disponible.',
        confirmLabel: 'Continuar',
      ),
      _Step(
        title: '¿Confirmas la liberación?',
        message:
            'Segunda confirmación: ${r.tableIn(widget.store.venue).displayName} · '
            '${r.night.label}.\n\nEsta acción no se puede deshacer.',
        confirmLabel: 'Liberar mesa',
        destructive: true,
      ),
    ],
    operation: (book, id) => book.release(id),
    success:
        '${r.tableIn(widget.store.venue).displayName} liberada para el '
        '${r.night.label.toLowerCase()}.',
  );

  Future<void> _run({
    required List<_Step> steps,
    required Reservation Function(ReservationBook book, String id) operation,
    required String success,
  }) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    // El ID y el estado exacto se fijan antes del primer await: los avisos se
    // redactaron para ese estado (p. ej. liberar una Reservada no advierte
    // de una mesa Ocupada), aunque la operación admita otros (I13).
    final id = r.id;
    final status = r.status;
    setState(() => _busy = true);
    try {
      for (final step in steps) {
        if (!mounted || !await _confirm(step)) return;
        if (!_stillIn(id, status, messenger)) return;
      }
      try {
        widget.store.perform((book) => operation(book, id));
        showResultMessage(messenger, success);
      } on ReservationException catch (e) {
        showResultMessage(messenger, actionErrorMessage(e.error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// La reserva pudo cambiar mientras la confirmación estaba abierta (p. ej.
  /// al cruzar el cierre de la noche o desde otra vista).
  bool _stillIn(
    String id,
    ReservationStatus status,
    ScaffoldMessengerState messenger,
  ) {
    final current = widget.store.book.byId(id);
    if (current?.status == status) return true;
    showResultMessage(
      messenger,
      current == null
          ? actionErrorMessage(ReservationError.notFound)
          : 'La reserva $id cambió mientras decidías: ahora está '
                '«${current.statusLabel}». No se hizo ningún cambio.',
      error: true,
    );
    return false;
  }

  Future<bool> _confirm(_Step step) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(step.title),
        content: SingleChildScrollView(child: Text(step.message)),
        actions: [
          TextButton(
            key: const ValueKey('dialog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('dialog-confirm'),
            style: step.destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.black,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(step.confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
}

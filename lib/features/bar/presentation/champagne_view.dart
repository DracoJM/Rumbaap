import 'package:flutter/material.dart';

import '../../benefits/vip_benefits.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/domain/venue_table.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';
import '../../reservations/presentation/table_presentation.dart';
import '../../tickets/presentation/ticket_widgets.dart';
import '../data/demo_bar_store.dart';
import '../domain/bar.dart';
import '../domain/champagne.dart';
import 'bar_views.dart';

/// Estado de la botella de champaña VIP de una reserva, igual para
/// cliente, administración, barra y mesero.
String champagneStatusLabel(Reservation r, Venue venue, ChampagneRelease? c) {
  String at(String who, DateTime t) =>
      '${actorLabel(who)}, ${venueDateTimeLabel(t)}';
  final ended = !r.status.isActive;
  final text = switch (c?.stage) {
    null when !hasVipApprovalEvidence(r, venue) =>
      'Champaña: se habilita con la reserva aprobada y el prepago '
          'verificado.',
    null when ended => 'Champaña: no se pidió.',
    null when r.status == ReservationStatus.seated =>
      'Champaña: disponible. Sale de barra solo cuando la mesa la pide.',
    null =>
      'Champaña: habilitada. Se entrega con la mesa ocupada y a petición de '
          'la mesa.',
    ChampagneStage.requested =>
      'Champaña: pedida (${at(c!.requestedBy, c.requestedAt)}) · pendiente '
          'de salida de barra.',
    ChampagneStage.dispatched =>
      'Champaña: salió de barra (${at(c!.dispatchedBy!, c.dispatchedAt!)}) '
          '· pendiente de entrega en mesa.',
    ChampagneStage.delivered =>
      'Champaña: entregada en mesa (${at(c!.deliveredBy!, c.deliveredAt!)}).',
  };
  final stuck = ended && c != null && c.stage != ChampagneStage.delivered;
  return stuck
      ? '$text La reserva terminó: se conserva el historial y no se '
            'registran más pasos.'
      : text;
}

/// Estado y, según quién mira, el siguiente paso: pedir (titular o
/// mesero), registrar la salida (barra) o confirmar la entrega (mesero).
/// El dominio vuelve a comprobar permisos, orden, mesa y noche.
class ChampagneSection extends StatelessWidget {
  const ChampagneSection({
    super.key,
    required this.reservation,
    required this.venue,
    required this.bar,
    this.actorId,
  });

  final Reservation reservation;
  final Venue venue;
  final DemoBarStore bar;
  final String? actorId;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final c = bar.book.champagneOf(r.id);
    final role = actorId == null ? null : bar.book.champagneActorOf(actorId!);
    final seated = r.status == ReservationStatus.seated;
    final eligible = hasVipApprovalEvidence(r, venue);
    final (String, String, BarChampagneStep)? action = switch ((
      role,
      c?.stage,
    )) {
      (ChampagneActor.client || ChampagneActor.waiter, null)
          when seated && eligible =>
        (
          'champagne-request-${r.id}',
          role == ChampagneActor.waiter
              ? 'Registrar petición de la mesa'
              : 'Pedir la champaña a la mesa',
          BarChampagneStep.request,
        ),
      (ChampagneActor.bar, ChampagneStage.requested) when seated => (
        'champagne-dispatch-${r.id}',
        'Registrar salida de la botella',
        BarChampagneStep.dispatch,
      ),
      (ChampagneActor.waiter, ChampagneStage.dispatched) when seated => (
        'champagne-deliver-${r.id}',
        'Confirmar entrega en mesa',
        BarChampagneStep.deliver,
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          champagneStatusLabel(r, venue, c),
          key: ValueKey('champagne-${r.id}'),
        ),
        const Text(
          'Regalo fuera del consumo: no se cobra ni se descuenta del prepago.',
        ),
        if (action case (final key, final label, final step)) ...[
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: ValueKey(key),
            icon: const Icon(Icons.wine_bar_outlined),
            label: Text(label),
            onPressed: () => _run(context, step),
          ),
        ],
      ],
    );
  }

  void _run(BuildContext context, BarChampagneStep step) {
    final messenger = ScaffoldMessenger.of(context);
    final id = reservation.id, actor = actorId!;
    try {
      bar.perform(
        (b) => switch (step) {
          BarChampagneStep.request => b.requestChampagne(id, actorId: actor),
          BarChampagneStep.dispatch => b.dispatchChampagne(id, actorId: actor),
          BarChampagneStep.deliver => b.deliverChampagne(id, actorId: actor),
        },
      );
      showResultMessage(messenger, switch (step) {
        BarChampagneStep.request => 'Petición de champaña registrada.',
        BarChampagneStep.dispatch => 'Salida de la botella registrada.',
        BarChampagneStep.deliver => 'Entrega en mesa confirmada.',
      });
    } on BarException catch (e) {
      showResultMessage(messenger, barErrorLabel(e.error), error: true);
    }
  }
}

enum BarChampagneStep { request, dispatch, deliver }

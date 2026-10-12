import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../../../session/demo_identities.dart';
import '../../../tickets/data/demo_ticket_store.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/reservation.dart';
import '../admin/admin_labels.dart';
import '../admin/admin_widgets.dart';
import '../table_presentation.dart';
import 'my_reservation_detail_page.dart';

/// «Mis reservas» del cliente o del promotor: el promotor ve las que creó; el
/// cliente, además, las adjudicadas a su cuenta ficticia.
///
/// Primero las activas (en proceso, pendiente de pago, reservada u ocupada);
/// tocar una abre su ficha de solo lectura. Las terminadas (canceladas,
/// expiradas, revocadas o liberadas) van aparte, en «Historial», plegado al
/// abrir; cada una se despliega con el motivo y sus cambios de estado. Se
/// actualiza con cada cambio del almacén (por ejemplo, cuando el
/// administrador verifica un prepago VIP).
class MyReservations extends StatelessWidget {
  const MyReservations({
    super.key,
    required this.store,
    required this.identity,
    this.tickets,
  });

  final DemoReservationStore store;
  final DemoIdentity identity;

  /// Entradas del local, para los beneficios VIP en la ficha.
  final DemoTicketStore? tickets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mine = store.ownReservations(
          identity.id,
          includeLinked: identity.profile == DemoProfile.client,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final active = [
          for (final r in mine)
            if (r.status.isActive) r,
        ];
        final ended = [
          for (final r in mine)
            if (!r.status.isActive) r,
        ]..sort((a, b) => b.history.last.at.compareTo(a.history.last.at));
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Mis reservas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: NightNeutrals.white,
              ),
            ),
            const SizedBox(height: 4),
            SectionLabel('Activas', count: active.length),
            if (active.isEmpty)
              Text(
                mine.isEmpty
                    ? 'Todavía no has hecho reservas en esta sesión de '
                          'demostración.'
                    : 'No tienes reservas activas.',
                style: TextStyle(color: NightNeutrals.glass(0.7)),
              ),
            for (final r in active)
              _ActiveCard(
                reservation: r,
                store: store,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MyReservationDetailPage(
                      store: store,
                      identity: identity,
                      reservationId: r.id,
                      tickets: tickets,
                    ),
                  ),
                ),
              ),
            if (ended.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: NightNeutrals.glass(0.04),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: const PageStorageKey('mine-history'),
                  initiallyExpanded: false,
                  title: Text('Historial (${ended.length})'),
                  subtitle: const Text(
                    'Canceladas, expiradas, revocadas o liberadas',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    for (final r in ended)
                      _EndedTile(reservation: r, store: store),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.reservation,
    required this.store,
    required this.onTap,
  });

  final Reservation reservation;
  final DemoReservationStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final r = reservation;
    return Card(
      key: ValueKey('mine-${r.id}'),
      color: NightNeutrals.glass(0.06),
      child: ListTile(
        minTileHeight: 56,
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right_rounded),
        leading: Icon(r.statusIcon, color: r.statusColorIn(colors)),
        title: Text(
          '${r.tableIn(store.venue).displayName} · ${r.night.shortLabel}',
          style: const TextStyle(color: NightNeutrals.white),
        ),
        subtitle: Text(
          '${r.statusLabel} · ${r.holderName} · ${r.id}',
          style: TextStyle(color: NightNeutrals.glass(0.75)),
        ),
      ),
    );
  }
}

/// Reserva terminada: plegada muestra mesa, noche, estado y motivo; al
/// desplegarla, sus cambios de estado con hora.
class _EndedTile extends StatelessWidget {
  const _EndedTile({required this.reservation, required this.store});

  final Reservation reservation;
  final DemoReservationStore store;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final theme = Theme.of(context);
    final r = reservation;
    final last = r.history.last;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: NightNeutrals.glass(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: NightNeutrals.glass(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey('mine-${r.id}'),
          leading: Icon(r.statusIcon, color: r.statusColorIn(colors)),
          title: Text(
            '${r.tableIn(store.venue).displayName} · ${r.night.shortLabel} '
            '${r.night.date.year}',
          ),
          subtitle: Text(
            '${r.statusLabel} · Motivo: ${eventLabel(last.type)} · '
            '${venueDateTimeLabel(last.at)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${r.id} · Titular: ${r.holderName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text('Cambios de estado', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            ReservationHistory(reservation: r),
          ],
        ),
      ),
    );
  }
}

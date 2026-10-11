import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../../../session/demo_identities.dart';
import '../../data/demo_reservation_store.dart';
import '../admin/admin_labels.dart';
import '../table_presentation.dart';
import 'my_reservation_detail_page.dart';

/// «Mis reservas» del cliente o del promotor, con su estado actual: el
/// promotor ve las que creó; el cliente, además, las adjudicadas a su cuenta
/// ficticia. Tocar una abre su ficha de solo lectura. Se actualiza con cada cambio del almacén
/// (por ejemplo, cuando el administrador verifica un prepago VIP).
class MyReservations extends StatelessWidget {
  const MyReservations({
    super.key,
    required this.store,
    required this.identity,
  });

  final DemoReservationStore store;
  final DemoIdentity identity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mine = store.ownReservations(
          identity.id,
          includeLinked: identity.profile == DemoProfile.client,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(
                'Todavía no has hecho reservas en esta sesión de '
                'demostración.',
                style: TextStyle(color: NightNeutrals.glass(0.7)),
              ),
            for (final r in mine)
              Card(
                key: ValueKey('mine-${r.id}'),
                color: NightNeutrals.glass(0.06),
                child: ListTile(
                  minTileHeight: 56,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MyReservationDetailPage(
                        store: store,
                        identity: identity,
                        reservationId: r.id,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  leading: Icon(r.statusIcon, color: r.statusColorIn(colors)),
                  title: Text(
                    '${r.tableIn(store.venue).displayName} · '
                    '${r.night.shortLabel}',
                    style: const TextStyle(color: NightNeutrals.white),
                  ),
                  subtitle: Text(
                    '${r.statusLabel} · ${r.holderName} · ${r.id}',
                    style: TextStyle(color: NightNeutrals.glass(0.75)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

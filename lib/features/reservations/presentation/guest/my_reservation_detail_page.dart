import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../theme/status_colors.dart';
import '../../../session/demo_identities.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/reservation.dart';
import '../admin/admin_labels.dart';
import '../admin/admin_widgets.dart';
import '../table_presentation.dart';

/// Ficha de solo lectura de una reserva de «Mis reservas».
///
/// Lee la misma proyección propia que la lista y se actualiza con cada
/// cambio del almacén (por ejemplo, cuando el administrador verifica un
/// prepago). No ofrece acciones: volver lleva a la lista.
class MyReservationDetailPage extends StatelessWidget {
  const MyReservationDetailPage({
    super.key,
    required this.store,
    required this.identity,
    required this.reservationId,
  });

  final DemoReservationStore store;
  final DemoIdentity identity;
  final String reservationId;

  bool get _isClient => identity.profile == DemoProfile.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la reserva')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final r = store.ownReservation(
            identity.id,
            reservationId,
            includeLinked: _isClient,
          );
          if (r == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta reserva ya no está en tus reservas.'),
              ),
            );
          }
          return _details(context, r);
        },
      ),
    );
  }

  Widget _details(BuildContext context, Reservation r) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final table = r.tableIn(store.venue);
    final holder = r.holder;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
    return ListView(
      key: ValueKey('mine-detail-${r.id}'),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Icon(r.statusIcon, color: r.statusColorIn(colors)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r.statusLabel,
                key: const ValueKey('mine-detail-status'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: r.statusColorIn(colors),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        row('Local', store.venue.name),
        row('Noche', '${r.night.label} · ${r.night.scheduleLabel}'),
        row('Mesa', '${table.displayName} · ${table.kindLabel}'),
        row('Reserva', r.id),
        row('Titular', r.holderName),
        if (holder != null) ...[
          row('Teléfono', holder.phone ?? ''),
          row(
            'Cédula',
            (holder.idNumber ?? '').isEmpty ? 'Sin cédula' : holder.idNumber!,
          ),
        ],
        // De una cuenta ajena no se muestran sus datos, solo que existe.
        row('Cuenta', switch (r.linkedAccountId) {
          null => 'Sin cuenta vinculada',
          final id when id == identity.id => 'Vinculada a tu cuenta',
          _ => 'Vinculada a una cuenta existente',
        }),
        const SizedBox(height: 12),
        Text('Cambios de estado', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ReservationHistory(reservation: r),
      ],
    );
  }
}

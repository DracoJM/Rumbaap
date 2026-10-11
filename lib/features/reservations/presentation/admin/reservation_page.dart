import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../data/demo_reservation_store.dart';
import '../../domain/night_schedule.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_book.dart';
import '../table_presentation.dart';
import '../venue_map_parts.dart';
import 'admin_labels.dart';
import 'admin_widgets.dart';
import 'reservation_actions.dart';

/// Detalle de una reserva por su ID: titular, estado, acciones e historial.
/// Sirve también para reservas terminadas, que ya no son la activa de la
/// mesa. Lee directamente del almacén, así que no depende de la noche que
/// se muestre en otra pantalla.
class ReservationPage extends StatefulWidget {
  const ReservationPage({
    super.key,
    required this.store,
    required this.reservationId,
    this.clock = systemClock,
  });

  final DemoReservationStore store;
  final String reservationId;
  final Clock clock;

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  // Vuelve a pintar cuando el paso del tiempo cambia lo que se muestra:
  // vencimiento de una reserva en proceso, apertura o cierre de la noche.
  Timer? _timer;
  DateTime? _timerAt;

  // Al volver del segundo plano la hora pudo cruzar un vencimiento o un
  // cierre mientras el temporizador no corría.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => setState(() => _timerAt = null),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _wakeUpAt(DateTime at) {
    if (at == _timerAt) return;
    _timer?.cancel();
    _timerAt = at;
    final wait = at.difference(widget.clock());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (mounted) setState(() => _timerAt = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reserva ${widget.reservationId}'),
            const DemoDataTag(text: 'Datos ficticios · sin autenticación real'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final r = widget.store.book.byId(widget.reservationId);
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: NoticeBox(
          icon: Icons.search_off_rounded,
          text: 'No se encontró la reserva.',
        ),
      );
    }
    final now = widget.clock();
    final expiresAt = r.status == ReservationStatus.inProcess
        ? r.createdAt.add(ReservationBook.inProcessTimeout)
        : null;
    final nextChange = NightSchedule.nextChange(
      VenueTime.of(now),
    ).subtract(VenueTime.utcOffset);
    _wakeUpAt(
      expiresAt != null && expiresAt.isBefore(nextChange)
          ? expiresAt
          : nextChange,
    );

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${r.tableIn(widget.store.venue).displayName} · ${r.tableIn(widget.store.venue).kindLabel}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${r.night.label} · ${r.night.scheduleLabel} '
                '(hora de Colombia)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ReservationStatusChip(reservation: r),
              ),
              const SizedBox(height: 12),
              HolderCard(reservation: r),
              const SizedBox(height: 16),
              ReservationActions(
                key: ValueKey('actions-${r.id}'),
                reservation: r,
                store: widget.store,
                clock: widget.clock,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SectionLabel('Actividad de la reserva'),
              ReservationHistory(reservation: r),
              Text(
                'Lista local de demostración; no es un registro de '
                'auditoría.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

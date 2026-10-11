import 'package:flutter/material.dart';

import '../../features/bar/data/demo_bar_store.dart';
import '../../features/reservations/data/demo_reservation_store.dart';
import '../../features/reservations/domain/night_schedule.dart';
import '../../features/tickets/data/demo_ticket_store.dart';
import '../../features/venues/venue_config.dart';
import '../app.dart';
import '../app_theme.dart';
import 'demo_persistence.dart';
import 'demo_snapshot.dart';

/// Arranque de la demostración con datos guardados en el teléfono.
///
/// Carga ANTES de mostrar la app: mientras tanto no hay acciones. Si los
/// datos no se pueden leer o son de otra versión, se explica y se ofrece
/// reintentar o reiniciar la demo; nunca se reemplazan en silencio por
/// datos de ejemplo (eso podría reactivar una entrada ya canjeada).
class DemoBootstrap extends StatefulWidget {
  const DemoBootstrap({
    super.key,
    required this.config,
    required this.storage,
    this.clock = systemClock,
    this.simulatedTime = false,
    this.reservationLatency = const Duration(milliseconds: 350),
    this.ticketLatency = const Duration(milliseconds: 350),
  });

  final VenueConfig config;
  final DemoStorage storage;
  final Clock clock;
  final bool simulatedTime;
  final Duration reservationLatency;
  final Duration ticketLatency;

  @override
  State<DemoBootstrap> createState() => _DemoBootstrapState();
}

class _DemoBootstrapState extends State<DemoBootstrap> {
  DemoReservationStore? _store;
  DemoTicketStore? _tickets;
  DemoBarStore? _bar;
  DemoPersistence? _persistence;
  DemoDataException? _dataError;
  Object? _readError;
  int _generation = 0;

  String get _key => demoStorageKey(widget.config.venue.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DemoReservationStore, DemoTicketStore, DemoBarStore) _freshStores() => (
    DemoReservationStore(
      venue: widget.config.venue,
      latency: widget.reservationLatency,
      clock: widget.clock,
    ),
    DemoTicketStore(
      venueId: widget.config.venue.id,
      venueTag: widget.config.ticketTag,
      clock: widget.clock,
      latency: widget.ticketLatency,
    ),
    DemoBarStore(
      venueId: widget.config.venue.id,
      menu: widget.config.menu,
      clock: widget.clock,
    ),
  );

  Future<void> _load() async {
    setState(() {
      _store = null;
      _dataError = null;
      _readError = null;
    });
    final String? raw;
    try {
      raw = await widget.storage.read(_key);
    } catch (e) {
      if (mounted) setState(() => _readError = e);
      return;
    }
    final (store, tickets, bar) = _freshStores();
    if (raw != null) {
      try {
        decodeDemoSnapshot(
          raw,
          config: widget.config,
          reservations: store,
          tickets: tickets,
          bar: bar,
        );
      } on DemoDataException catch (e) {
        if (mounted) setState(() => _dataError = e);
        return;
      }
    }
    if (mounted) _attach(store, tickets, bar);
  }

  void _attach(
    DemoReservationStore store,
    DemoTicketStore tickets,
    DemoBarStore bar,
  ) {
    final persistence = DemoPersistence(
      storage: widget.storage,
      key: _key,
      encode: () => encodeDemoSnapshot(
        config: widget.config,
        reservations: store,
        tickets: tickets,
        bar: bar,
        savedAt: widget.clock(),
      ),
    );
    store.onDataChanged = persistence.markDirty;
    tickets.onDataChanged = persistence.markDirty;
    bar.onDataChanged = persistence.markDirty;
    setState(() {
      _store = store;
      _tickets = tickets;
      _bar = bar;
      _persistence = persistence;
      _generation++;
    });
  }

  /// Borra SOLO los datos de demostración de este local y empieza de cero.
  Future<void> _reset() async {
    await _persistence?.flush();
    await widget.storage.remove(_key);
    if (!mounted) return;
    final (store, tickets, bar) = _freshStores();
    _attach(store, tickets, bar);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return RumbaapApp(
        // Una generación nueva tras reiniciar: no queda ninguna pantalla
        // de la sesión anterior.
        key: ValueKey(_generation),
        config: widget.config,
        store: store,
        tickets: _tickets!,
        bar: _bar!,
        clock: widget.clock,
        simulatedTime: widget.simulatedTime,
        persistence: _persistence,
        onResetDemo: _reset,
      );
    }
    final error = _dataError;
    final failed = error != null || _readError != null;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(widget.config.theme),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: !failed
                  ? const Column(
                      key: ValueKey('demo-loading'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Cargando los datos de la demostración…'),
                      ],
                    )
                  : _ErrorPanel(
                      message: error == null
                          ? 'No se pudieron leer los datos guardados de la '
                                'demostración.'
                          : error.incompatible
                          ? 'Los datos guardados son de otra versión de la '
                                'demostración y no se pueden cargar.'
                          : 'Los datos guardados de la demostración están '
                                'dañados y no se pueden cargar.',
                      onRetry: _load,
                      onReset: () async {
                        try {
                          await widget.storage.remove(_key);
                        } catch (_) {
                          return;
                        }
                        if (!mounted) return;
                        final (s, t, b) = _freshStores();
                        _attach(s, t, b);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.onRetry,
    required this.onReset,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('demo-load-error'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline_rounded, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text(
          'No se han reemplazado por datos de ejemplo. Puedes reintentar o '
          'reiniciar la demostración, que borra solo sus datos guardados en '
          'este teléfono.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('demo-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('demo-reset-from-error'),
          onPressed: () => confirmDemoReset(context, onReset),
          child: const Text('Reiniciar demostración'),
        ),
      ],
    );
  }
}

/// Pide confirmación antes de borrar los datos de la demo.
Future<void> confirmDemoReset(
  BuildContext context,
  Future<void> Function() reset,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Reiniciar la demostración?'),
      content: const Text(
        'Se borran las reservas, entradas, pagos simulados e historial de '
        'demostración de este local guardados en este teléfono. No afecta a '
        'nada fuera de la demo.',
      ),
      actions: [
        TextButton(
          key: const ValueKey('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('dialog-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reiniciar'),
        ),
      ],
    ),
  );
  if (ok == true) await reset();
}

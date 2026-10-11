import 'package:flutter/material.dart';

import '../features/bar/data/demo_bar_store.dart';
import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import '../features/tickets/data/demo_ticket_store.dart';
import '../features/venues/venue_config.dart';
import 'app_theme.dart';
import 'home_page.dart';
import 'persistence/demo_persistence.dart';
import 'persistence/save_error_banner.dart';

class RumbaapApp extends StatelessWidget {
  RumbaapApp({
    super.key,
    required this.config,
    DemoReservationStore? store,
    DemoTicketStore? tickets,
    DemoBarStore? bar,
    this.clock = systemClock,
    this.simulatedTime = false,
    this.persistence,
    this.onResetDemo,
  }) : store = store ?? DemoReservationStore(venue: config.venue, clock: clock),
       tickets =
           tickets ??
           DemoTicketStore(
             venueId: config.venue.id,
             venueTag: config.ticketTag,
             clock: clock,
           ),
       bar =
           bar ??
           DemoBarStore(
             venueId: config.venue.id,
             menu: config.menu,
             clock: clock,
           ) {
    assert(
      this.store.venue == config.venue,
      'El almacén debe ser del mismo local que la configuración',
    );
  }

  /// Local que muestra la app: identidad, mesas, tema y distribución.
  final VenueConfig config;

  /// Fuente única de reservas del local en esta ejecución: la leen la
  /// consulta pública y la vista del administrador.
  final DemoReservationStore store;

  /// Fuente única de entradas del local en esta ejecución.
  final DemoTicketStore tickets;

  /// Fuente única de ventas de barra del local en esta ejecución.
  final DemoBarStore bar;
  final Clock clock;

  /// La hora viene de `RUMBAAP_DEMO_NOW` (solo pruebas): se marca en
  /// pantalla para que nunca se confunda con la real.
  final bool simulatedTime;

  /// Guardado local de la demo; sin él, los datos viven solo en memoria.
  final DemoPersistence? persistence;

  /// Borra los datos guardados de este local y empieza de nuevo.
  final Future<void> Function()? onResetDemo;

  @override
  Widget build(BuildContext context) {
    // La configuración va por encima del Navigator para que también la
    // lean las hojas y los diálogos.
    return VenueScope(
      config: config,
      child: MaterialApp(
        title: 'Rumbaap',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(config.theme),
        home: HomePage(
          store: store,
          tickets: tickets,
          bar: bar,
          clock: clock,
          onResetDemo: onResetDemo,
        ),
        builder: (context, child) {
          var result = child!;
          if (persistence case final p?) {
            result = SaveErrorBanner(persistence: p, child: result);
          }
          if (simulatedTime) {
            result = Banner(
              message: 'Hora simulada',
              location: BannerLocation.topEnd,
              child: result,
            );
          }
          return result;
        },
      ),
    );
  }
}

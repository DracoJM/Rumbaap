import 'package:flutter/material.dart';

import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import '../features/tickets/data/demo_ticket_store.dart';
import '../features/venues/venue_config.dart';
import 'app_theme.dart';
import 'home_page.dart';

class RumbaapApp extends StatelessWidget {
  RumbaapApp({
    super.key,
    required this.config,
    DemoReservationStore? store,
    DemoTicketStore? tickets,
    this.clock = systemClock,
  }) : store = store ?? DemoReservationStore(venue: config.venue, clock: clock),
       tickets =
           tickets ??
           DemoTicketStore(
             venueId: config.venue.id,
             venueTag: config.ticketTag,
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
  final Clock clock;

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
        home: HomePage(store: store, tickets: tickets, clock: clock),
      ),
    );
  }
}

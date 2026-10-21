import 'package:flutter/material.dart';

import '../features/bar/data/demo_bar_store.dart';
import '../features/bar/domain/champagne.dart';
import '../features/benefits/vip_benefits.dart';
import '../features/dashboard/data/demo_goal_store.dart';
import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import '../features/reservations/domain/reservation.dart';
import '../features/reservations/domain/reservation_book.dart';
import '../features/session/demo_identities.dart';
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
    DemoGoalStore? goals,
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
           DemoBarStore(venue: config.venue, menu: config.menu, clock: clock),
       goals = goals ?? DemoGoalStore(clock: clock) {
    assert(
      this.store.venue == config.venue,
      'El almacén debe ser del mismo local que la configuración',
    );
    // Canje de cortesías VIP: según la reserva del mismo local.
    final reservations = this.store;
    this.tickets.book.vipCourtesyCheck = (id) =>
        vipCourtesyCheckFor(reservations.book.byId, config.venue, id);
    // Champaña VIP y cumpleaños: permisos según la identidad de la demo,
    // comprobados en el dominio.
    this.bar.book
      ..reservationById = reservations.book.byId
      ..champagneActorOf = champagneActorOf;
    reservations.book
      ..canManageBirthdays = ((id) =>
          DemoIdentities.byId(id)?.profile == DemoProfile.admin)
      ..canPerform = reservationActionAllowed
      ..canCreate = reservationCreationAllowed;
  }

  /// Quién crea reservas, según el flujo vigente de cada perfil: el cliente
  /// y el promotor, sus propias solicitudes (R1, R14, R16); la
  /// administración, la reserva directa (R7). El personal no crea reservas.
  /// No es la matriz de [reservationActionAllowed].
  static bool reservationCreationAllowed(
    String actorId,
    ReservationOrigin origin,
  ) => switch ((DemoIdentities.byId(actorId)?.profile, origin)) {
    (DemoProfile.client, ReservationOrigin.client) => true,
    (DemoProfile.promoter, ReservationOrigin.promoter) => true,
    (DemoProfile.admin, ReservationOrigin.admin) => true,
    _ => false,
  };

  /// Quién ejecuta cada acción de reserva: la administración todas (R2,
  /// R4–R6); el mesero, además, la llegada (R5). Es la matriz que ya
  /// aplicaban las vistas, ahora comprobada en el dominio.
  static bool reservationActionAllowed(
    String actorId,
    ReservationAction action,
  ) {
    final i = DemoIdentities.byId(actorId);
    return switch ((i?.profile, i?.staffRole)) {
      (DemoProfile.admin, _) => true,
      (DemoProfile.staff, StaffRole.waiter) =>
        action == ReservationAction.arrival,
      _ => false,
    };
  }

  /// Responsabilidad de una identidad de la demo sobre la champaña VIP.
  static ChampagneActor? champagneActorOf(String actorId) {
    final i = DemoIdentities.byId(actorId);
    return switch ((i?.profile, i?.staffRole)) {
      (DemoProfile.client, _) => ChampagneActor.client,
      (DemoProfile.staff, StaffRole.waiter) => ChampagneActor.waiter,
      (DemoProfile.staff, StaffRole.bar) => ChampagneActor.bar,
      _ => null,
    };
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

  /// Metas opcionales del local por noche (panel de la administración).
  final DemoGoalStore goals;
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
          goals: goals,
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

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/reservation.dart';
import '../domain/reservation_book.dart';
import '../domain/venue_table.dart';

/// Almacén de DATOS DE DEMOSTRACIÓN de un local ([venue]): un único
/// [ReservationBook] en memoria por local y ejecución de la app. Cada local
/// tiene su propio almacén, así que sus datos no se mezclan. La consulta pública lo lee como
/// [NightAvailabilityRepository] y la vista del administrador, mediante
/// [adminView], con las reservas de cada noche. Navegar conserva reservas y
/// cambios; cerrar la app los pierde.
///
/// Las operaciones de las vistas pasan por [perform], que avisa a quienes
/// escuchan para que mapa, listas y detalle se actualicen. Los vencimientos
/// no avisan: cada consulta los anuncia con `refreshAt`.
///
/// PENDIENTE (fuera de alcance): persistencia y datos compartidos entre
/// dispositivos (backend).
class DemoReservationStore extends ChangeNotifier
    implements NightAvailabilityRepository {
  DemoReservationStore({
    required this.venue,
    this.latency = const Duration(milliseconds: 350),
    Clock clock = systemClock,
  }) : book = ReservationBook(venue: venue, clock: clock);

  final Venue venue;

  /// Retardo simulado para que la carga sea visible durante el desarrollo.
  final Duration latency;

  /// Reglas y datos. Cambiarlo directamente no avisa a las vistas; las vistas
  /// usan [perform].
  final ReservationBook book;
  final Set<Night> _seeded = {};

  /// Se llama tras cada cambio de datos, también los que no avisan a las
  /// vistas (la siembra de una noche): lo usa la persistencia local.
  VoidCallback? onDataChanged;

  /// Noches ya sembradas, para la persistencia local.
  Set<Night> get seededNights => Set.unmodifiable(_seeded);

  /// Restaura noches sembradas: no se vuelven a sembrar al reabrir.
  void importSeededNights(Iterable<Night> nights) => _seeded.addAll(nights);

  /// Consulta de la vista del administrador: devuelve [NightReservations].
  late final NightAvailabilityRepository adminView = _AdminView(this);

  @override
  Future<NightAvailability> availabilityFor(Night night) =>
      _snapshot(night, withReservations: false);

  /// Proyección propia, nunca la colección del administrador. El cliente ve
  /// lo que creó y lo adjudicado a su cuenta ficticia por cédula exacta; el
  /// promotor, solo lo que creó él (sus cuentas no reciben adjudicaciones).
  List<Reservation> ownReservations(
    String identityId, {
    bool includeLinked = false,
  }) => includeLinked
      ? book.createdByOrLinkedTo(identityId)
      : book.createdBy(identityId);

  /// Una reserva de la proyección propia, o `null` si no pertenece a ella.
  Reservation? ownReservation(
    String identityId,
    String reservationId, {
    bool includeLinked = false,
  }) {
    for (final r in ownReservations(identityId, includeLinked: includeLinked)) {
      if (r.id == reservationId) return r;
    }
    return null;
  }

  /// Ejecuta una operación del libro y, si tiene éxito, avisa a las vistas.
  /// Si la operación lanza [ReservationException], no cambia nada ni avisa.
  T perform<T>(T Function(ReservationBook book) operation) {
    final result = operation(book);
    notifyListeners();
    onDataChanged?.call();
    return result;
  }

  Future<NightAvailability> _snapshot(
    Night night, {
    required bool withReservations,
  }) async {
    await Future<void>.delayed(latency);
    _seedOnce(night);
    // El vencimiento se toma ANTES que los estados: si una reserva en proceso
    // vence mientras se construye la respuesta, puede seguir «pendiente», pero
    // [refreshAt] (aunque ya haya pasado) obliga a volver a consultar.
    final refreshAt = book.nextExpiry(night);
    final reservations = book.forNight(night);
    final byTableId = {
      for (final table in venue.tables)
        table.id: _availability(
          reservations
              .where((r) => r.tableId == table.id && r.status.isActive)
              .firstOrNull,
        ),
    };
    if (!withReservations) {
      return NightAvailability(
        nightId: night.id,
        venueId: venue.id,
        byTableId: byTableId,
        refreshAt: refreshAt,
      );
    }
    return NightReservations(
      nightId: night.id,
      venueId: venue.id,
      byTableId: byTableId,
      reservations: reservations,
      refreshAt: refreshAt,
    );
  }

  static TableAvailability _availability(Reservation? active) =>
      switch (active?.status) {
        null => TableAvailability.available,
        ReservationStatus.inProcess ||
        ReservationStatus.pendingPayment => TableAvailability.pending,
        ReservationStatus.confirmed => TableAvailability.reserved,
        ReservationStatus.seated => TableAvailability.occupied,
        // Los estados terminados no son activos; activeFor no los devuelve.
        ReservationStatus.revoked ||
        ReservationStatus.released ||
        ReservationStatus.expired ||
        ReservationStatus.cancelled => TableAvailability.available,
      };

  /// Siembra reservas ficticias la primera vez que se consulta una noche, con
  /// las mismas reglas que una reserva real. La elección de mesas es la misma
  /// para la misma fecha. Solo hay llegadas si la noche está en curso.
  ///
  /// Una noche que ya tiene historial (reservas creadas antes de consultarla)
  /// no se siembra: así la siembra nunca choca con operaciones reales ni
  /// rellena una mesa revocada o liberada.
  void _seedOnce(Night night) {
    if (!_seeded.add(night)) return;
    // Se guarda al terminar la siembra (al salir de este método).
    scheduleMicrotask(() => onDataChanged?.call());
    // Solo actúa con la noche vacía y sin terminar; sin actor ni creador.
    book.seedDemoNight(night);
  }
}

class _AdminView implements NightAvailabilityRepository {
  _AdminView(this._store);

  final DemoReservationStore _store;

  @override
  Future<NightAvailability> availabilityFor(Night night) =>
      _store._snapshot(night, withReservations: true);
}

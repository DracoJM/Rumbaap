import 'dart:math' as math;

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
  }) : _clock = clock,
       book = ReservationBook(venue: venue, clock: clock);

  final Venue venue;

  /// Retardo simulado para que la carga sea visible durante el desarrollo.
  final Duration latency;
  final Clock _clock;

  /// Reglas y datos. Cambiarlo directamente no avisa a las vistas; las vistas
  /// usan [perform].
  final ReservationBook book;
  final Set<Night> _seeded = {};

  /// Consulta de la vista del administrador: devuelve [NightReservations].
  late final NightAvailabilityRepository adminView = _AdminView(this);

  @override
  Future<NightAvailability> availabilityFor(Night night) =>
      _snapshot(night, withReservations: false);

  /// Proyección propia del cliente o del promotor: solo las reservas que creó
  /// esa identidad, nunca la colección del administrador.
  List<Reservation> ownReservations(String identityId) =>
      book.createdBy(identityId);

  /// Ejecuta una operación del libro y, si tiene éxito, avisa a las vistas.
  /// Si la operación lanza [ReservationException], no cambia nada ni avisa.
  T perform<T>(T Function(ReservationBook book) operation) {
    final result = operation(book);
    notifyListeners();
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
    final venueNow = VenueTime.of(_clock());
    if (night.hasEnded(venueNow)) return;
    if (book.forNight(night).isNotEmpty) return;
    final random = math.Random(
      night.date.year * 10000 + night.date.month * 100 + night.date.day,
    );

    final normals = venue.tables.where((t) => !t.isVip).toList()
      ..shuffle(random);
    final confirmed = <Reservation>[];
    for (var i = 0; i < math.min(5, normals.length); i++) {
      final r = book.requestNormal(
        night: night,
        tableId: normals[i].id,
        holder: _holder(i, promoterByName: i.isOdd),
        origin: i.isOdd ? ReservationOrigin.promoter : ReservationOrigin.client,
      );
      confirmed.add(book.completeRequest(r.id));
    }
    // Un trámite normal en proceso: vencerá a los 10 min (R1) y, como no se
    // ha enviado, todavía no tiene titular (R14).
    if (normals.length > 5) {
      book.startNormal(
        night: night,
        tableId: normals[5].id,
        origin: ReservationOrigin.client,
      );
    }

    // Siempre hay una VIP pendiente de pago para poder demostrar la
    // verificación del prepago (R2). El sorteo se conserva para que la
    // elección de mesas siga siendo la misma para la misma fecha.
    final vips = venue.tables.where((t) => t.isVip).toList()..shuffle(random);
    random.nextDouble();
    if (vips.isNotEmpty) {
      book.requestVip(
        night: night,
        tableId: vips.first.id,
        holder: _holder(6),
        origin: ReservationOrigin.client,
      );
    }

    if (night.isInProgress(venueNow)) {
      for (final r in confirmed.take(2)) {
        book.markArrival(r.id);
      }
    }
  }

  /// Titulares claramente ficticios. «Por nombre» (promotor) no lleva cédula
  /// (R10).
  static ReservationHolder _holder(int n, {bool promoterByName = false}) {
    final suffix = (n + 1).toString().padLeft(2, '0');
    return ReservationHolder(
      name: 'Titular demo $suffix',
      idNumber: promoterByName ? null : '00000000$suffix',
      phone: '00000000$suffix',
    );
  }
}

class _AdminView implements NightAvailabilityRepository {
  _AdminView(this._store);

  final DemoReservationStore _store;

  @override
  Future<NightAvailability> availabilityFor(Night night) =>
      _store._snapshot(night, withReservations: true);
}

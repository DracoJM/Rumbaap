import 'dart:math' as math;

import '../domain/night_availability.dart';
import '../domain/night_schedule.dart';
import '../domain/reservation.dart';
import '../domain/reservation_book.dart';
import '../domain/venue_table.dart';

/// Almacén de DATOS DE DEMOSTRACIÓN: un único [ReservationBook] en memoria por
/// ejecución de la app. El mapa de consulta lo lee como
/// [NightAvailabilityRepository]; la vista del administrador (Parte 3) usará
/// el mismo [book]. Navegar conserva reservas y cambios; cerrar la app los
/// pierde.
///
/// PENDIENTE (fuera de alcance): persistencia y datos compartidos entre
/// dispositivos (backend).
class DemoReservationStore implements NightAvailabilityRepository {
  DemoReservationStore({
    this.latency = const Duration(milliseconds: 350),
    Clock clock = systemClock,
  }) : _clock = clock,
       book = ReservationBook(clock: clock);

  /// Retardo simulado para que la carga sea visible durante el desarrollo.
  final Duration latency;
  final Clock _clock;
  final ReservationBook book;
  final Set<Night> _seeded = {};

  @override
  Future<NightAvailability> availabilityFor(Night night) async {
    await Future<void>.delayed(latency);
    _seedOnce(night);
    // El vencimiento se toma ANTES que los estados: si una reserva en proceso
    // vence mientras se construye la respuesta, puede seguir «pendiente», pero
    // [refreshAt] (aunque ya haya pasado) obliga a volver a consultar.
    final refreshAt = book.nextExpiry(night);
    return NightAvailability(
      nightId: night.id,
      byTableId: {
        for (final table in VenueTables.all)
          table.id: _availability(book.activeFor(night, table.id)),
      },
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
        ReservationStatus.expired => TableAvailability.available,
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

    final normals = VenueTables.all.where((t) => !t.isVip).toList()
      ..shuffle(random);
    final confirmed = <Reservation>[];
    for (var i = 0; i < 5; i++) {
      final r = book.requestNormal(
        night: night,
        tableId: normals[i].id,
        holder: _holder(i, promoterByName: i.isOdd),
        origin: i.isOdd ? ReservationOrigin.promoter : ReservationOrigin.client,
      );
      confirmed.add(book.completeRequest(r.id));
    }
    // Una reserva normal en proceso: vencerá a los 10 min (R1).
    book.requestNormal(
      night: night,
      tableId: normals[5].id,
      holder: _holder(5),
      origin: ReservationOrigin.client,
    );

    final vips = VenueTables.all.where((t) => t.isVip).toList()
      ..shuffle(random);
    if (random.nextDouble() < 0.6) {
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

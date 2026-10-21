import 'dart:async';

import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation_book.dart';

/// Los permisos de la demo para las altas y las acciones de reserva, los
/// mismos que inyecta la app, para los tests que usan el libro sin montarla.
void allowDemoReservationActions(ReservationBook book) => book
  ..canPerform = RumbaapApp.reservationActionAllowed
  ..canCreate = RumbaapApp.reservationCreationAllowed;

/// Instante en hora del establecimiento (UTC−5), expresado como instante
/// UTC real para usarlo como reloj.
DateTime venueInstant(int y, int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(VenueTime.utcOffset);

/// Miércoles 7 de octubre de 2026, 3:00 p. m. en el local: el fin de
/// semana en curso es el viernes 9, sábado 10 y domingo 11.
final wednesdayAfternoon = venueInstant(2026, 10, 7, 15);
DateTime fixedClock() => wednesdayAfternoon;

const nightA = '2026-10-09';
const nightB = '2026-10-10';

/// Repositorio cuyas respuestas se completan a mano desde el test, para
/// controlar el orden en que llegan.
class ControlledRepository implements NightAvailabilityRepository {
  final List<(String, Completer<NightAvailability>)> pending = [];

  @override
  Future<NightAvailability> availabilityFor(Night night) {
    final completer = Completer<NightAvailability>();
    pending.add((night.id, completer));
    return completer.future;
  }

  Completer<NightAvailability> request(String nightId, {int nth = 0}) =>
      pending.where((p) => p.$1 == nightId).elementAt(nth).$2;
}

NightAvailability availability(
  String nightId,
  Map<String, TableAvailability> byTableId,
) => NightAvailability(nightId: nightId, byTableId: byTableId);

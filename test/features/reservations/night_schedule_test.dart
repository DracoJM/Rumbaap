import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';

import 'fakes.dart';

/// Hora del local (los campos son la hora de pared en Colombia).
DateTime local(int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(2026, m, d, h, min);

List<String> ids(List<Night> nights) => [for (final n in nights) n.id];

void main() {
  group('hora del establecimiento', () {
    test('es UTC−5 sin depender de la zona del dispositivo', () {
      // 07:20 UTC = 02:20 a. m. en Cali.
      final venue = VenueTime.of(DateTime.utc(2026, 10, 10, 7, 20));
      expect(venue, local(10, 10, 2, 20));
    });
  });

  group('noche', () {
    final friday = Night(DateTime.utc(2026, 10, 9));

    test('abre a las 20:30 y cierra a las 03:00 del día siguiente', () {
      expect(friday.opensAt, local(10, 9, 20, 30));
      expect(friday.closesAt, local(10, 10, 3));
    });

    test('está en curso solo entre apertura y cierre', () {
      expect(friday.isInProgress(local(10, 9, 20, 29)), isFalse);
      expect(friday.isInProgress(local(10, 9, 20, 30)), isTrue);
      expect(friday.isInProgress(local(10, 10, 2, 59)), isTrue);
      expect(friday.isInProgress(local(10, 10, 3)), isFalse);
      expect(friday.hasEnded(local(10, 10, 3)), isTrue);
    });

    test('el ID es la fecha de apertura', () {
      expect(friday.id, '2026-10-09');
    });
  });

  group('noches del fin de semana', () {
    test('entre semana: viernes, sábado y domingo de la semana en curso', () {
      expect(ids(NightSchedule.weekendNights(local(10, 5, 9))), [
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
      ]);
      expect(ids(NightSchedule.weekendNights(VenueTime.of(fixedClock()))), [
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
      ]);
    });

    test('las noches ya terminadas no se ofrecen', () {
      // Sábado 10, 2:20 a. m.: la noche del viernes sigue en curso.
      expect(ids(NightSchedule.weekendNights(local(10, 10, 2, 20))), [
        '2026-10-09',
        '2026-10-10',
        '2026-10-11',
      ]);
      // Sábado 10, 3:00 a. m.: el viernes ya terminó.
      expect(ids(NightSchedule.weekendNights(local(10, 10, 3))), [
        '2026-10-10',
        '2026-10-11',
      ]);
    });

    test('la noche del domingo sigue siendo de su semana hasta las 03:00', () {
      expect(ids(NightSchedule.weekendNights(local(10, 12, 1))), [
        '2026-10-11',
      ]);
      // Lunes 12 a las 03:00 empieza la semana siguiente (regla N5).
      expect(ids(NightSchedule.weekendNights(local(10, 12, 3))), [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
      ]);
    });

    test('se puede consultar un fin de semana futuro', () {
      expect(
        ids(NightSchedule.weekendNights(local(10, 7, 15), weeksAhead: 1)),
        ['2026-10-16', '2026-10-17', '2026-10-18'],
      );
      // Cruce de mes.
      expect(
        ids(NightSchedule.weekendNights(local(10, 7, 15), weeksAhead: 3)),
        ['2026-10-30', '2026-10-31', '2026-11-01'],
      );
    });
  });

  group('próximo cambio', () {
    test('es la siguiente apertura o cierre', () {
      // Miércoles: el próximo cambio es la apertura del viernes.
      expect(NightSchedule.nextChange(local(10, 7, 15)), local(10, 9, 20, 30));
      // Viernes en curso: el cierre del sábado a las 03:00.
      expect(NightSchedule.nextChange(local(10, 9, 23)), local(10, 10, 3));
      // Domingo en curso: el cierre del lunes, que cambia la semana.
      expect(NightSchedule.nextChange(local(10, 11, 23)), local(10, 12, 3));
      // Lunes al cerrar: la apertura del viernes siguiente.
      expect(NightSchedule.nextChange(local(10, 12, 3)), local(10, 16, 20, 30));
    });
  });
}

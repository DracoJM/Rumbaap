import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/dashboard/data/demo_goal_store.dart';
import 'package:rumbaap/features/dashboard/domain/night_goals.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));
final _now = venueInstant(2026, 10, 9, 22);

void main() {
  group('metas por noche (dominio)', () {
    test('sin valores por defecto; configurar, editar y quitar, por noche y '
        'parámetro, con actor y hora', () {
      final book = GoalBook(clock: () => _now);
      for (final m in GoalMetric.values) {
        expect(book.goalFor(_friday, m), isNull);
      }
      book.set(_friday, GoalMetric.firstEntries, 120, actorId: 'admin-1');
      book.set(_friday, GoalMetric.ticketIncome, 5000000, actorId: 'admin-1');
      final edited = book.set(
        _friday,
        GoalMetric.firstEntries,
        150,
        actorId: 'admin-1',
      );
      expect(edited.target, 150);
      expect(edited.setBy, 'admin-1');
      expect(edited.setAt, _now);
      // Otra noche, otro parámetro: independientes.
      expect(book.goalFor(_saturday, GoalMetric.firstEntries), isNull);
      expect(book.goalFor(_friday, GoalMetric.reservationArrivals), isNull);
      book.remove(_friday, GoalMetric.firstEntries);
      expect(book.goalFor(_friday, GoalMetric.firstEntries), isNull);
      expect(book.goals, hasLength(1));
    });

    test('rechaza cero, negativos y valores fuera de rango sin cambiar la '
        'meta vigente', () {
      final book = GoalBook(clock: () => _now);
      book.set(_friday, GoalMetric.barIncome, 1000000, actorId: 'admin-1');
      for (final bad in [0, -5, GoalBook.maxTarget + 1]) {
        expect(
          () => book.set(_friday, GoalMetric.barIncome, bad, actorId: 'a'),
          throwsA(isA<GoalException>()),
        );
      }
      expect(book.goalFor(_friday, GoalMetric.barIncome)!.target, 1000000);
    });
  });

  group('persistencia de metas', () {
    (DemoReservationStore, DemoTicketStore, DemoBarStore, DemoGoalStore)
    stores() => (
      DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: () => _now,
      ),
      DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => _now,
        latency: Duration.zero,
      ),
      DemoBarStore(
        venueId: sagsaVenue.id,
        menu: sagsaConfig.menu,
        clock: () => _now,
      ),
      DemoGoalStore(clock: () => _now),
    );

    test('ida y vuelta con actor y hora; un estado guardado ANTES de las '
        'metas se carga igual y sin metas', () {
      final (r, t, b, g) = stores();
      g.perform(
        (x) => x.set(_friday, GoalMetric.ticketIncome, 800000, actorId: 'a1'),
      );
      final raw = encodeDemoSnapshot(
        config: sagsaConfig,
        reservations: r,
        tickets: t,
        bar: b,
        goals: g,
        savedAt: _now,
      );
      final (r2, t2, b2, g2) = stores();
      decodeDemoSnapshot(
        raw,
        config: sagsaConfig,
        reservations: r2,
        tickets: t2,
        bar: b2,
        goals: g2,
      );
      final restored = g2.book.goalFor(_friday, GoalMetric.ticketIncome)!;
      expect(restored.target, 800000);
      expect(restored.setBy, 'a1');
      expect(restored.setAt, _now);

      // Formato anterior: sin la sección «goals».
      final old = jsonDecode(raw) as Map<String, Object?>..remove('goals');
      final (r3, t3, b3, g3) = stores();
      decodeDemoSnapshot(
        jsonEncode(old),
        config: sagsaConfig,
        reservations: r3,
        tickets: t3,
        bar: b3,
        goals: g3,
      );
      expect(g3.book.goals, isEmpty);
    });

    test('una meta guardada no válida se rechaza como dato dañado, sin '
        'aplicar nada', () {
      final (r, t, b, g) = stores();
      final raw =
          jsonDecode(
                encodeDemoSnapshot(
                  config: sagsaConfig,
                  reservations: r,
                  tickets: t,
                  bar: b,
                  goals: g,
                  savedAt: _now,
                ),
              )
              as Map<String, Object?>;
      raw['goals'] = [
        {
          'night': _friday.id,
          'metric': 'firstEntries',
          'target': 0,
          'setBy': 'a1',
          'setAt': _now.toIso8601String(),
        },
      ];
      final (r2, t2, b2, g2) = stores();
      expect(
        () => decodeDemoSnapshot(
          jsonEncode(raw),
          config: sagsaConfig,
          reservations: r2,
          tickets: t2,
          bar: b2,
          goals: g2,
        ),
        throwsA(isA<DemoDataException>()),
      );
      expect(g2.book.goals, isEmpty);
    });
  });
}

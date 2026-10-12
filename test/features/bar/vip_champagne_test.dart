import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/bar/domain/bar.dart';
import 'package:rumbaap/features/bar/domain/champagne.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));
const _holder = ReservationHolder(name: 'Titular demo', phone: '300');

void main() {
  late DateTime now;
  late DemoReservationStore reservations;
  late DemoBarStore bar;
  final vipTables = sagsaVenue.tables.where((t) => t.isVip).toList();

  void wire(DemoBarStore b) => b.book
    ..reservationById = reservations.book.byId
    ..champagneActorOf = RumbaapApp.champagneActorOf;

  setUp(() {
    now = venueInstant(2026, 10, 7, 15);
    reservations = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => now,
    );
    bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => now,
    );
    wire(bar);
  });

  /// VIP del cliente A, aprobada con «prepago verificado» (sin importe
  /// registrado: la prueba histórica basta).
  Reservation approvedVip({int table = 0, Night? night}) {
    final r = reservations.perform(
      (b) => b.submitVip(
        night: night ?? _friday,
        tableId: vipTables[table].id,
        holder: _holder,
        origin: ReservationOrigin.client,
        createdBy: 'cliente-a',
      ),
    );
    return reservations.perform((b) => b.markPrepaymentReceived(r.id));
  }

  void tonight() => now = venueInstant(2026, 10, 9, 22);
  void seat(Reservation r) => reservations.perform((b) => b.markArrival(r.id));

  BarError? errorOf(void Function() f) {
    try {
      f();
    } on BarException catch (e) {
      return e.error;
    }
    return null;
  }

  test('aprobada y verificada NO despacha: antes de la noche y sin la mesa '
      'ocupada se rechaza la petición, y sin petición no hay salida', () {
    final r = approvedVip();
    expect(
      errorOf(() => bar.book.requestChampagne(r.id, actorId: 'personal-1')),
      BarError.outsideNight,
    );
    tonight();
    expect(
      errorOf(() => bar.book.requestChampagne(r.id, actorId: 'personal-1')),
      BarError.tableNotOccupied,
    );
    seat(r);
    expect(
      errorOf(() => bar.book.dispatchChampagne(r.id, actorId: 'barra-1')),
      BarError.champagneOutOfOrder,
    );
    expect(
      errorOf(() => bar.book.deliverChampagne(r.id, actorId: 'personal-1')),
      BarError.champagneOutOfOrder,
    );
    expect(bar.book.champagne, isEmpty);
  });

  test('permisos en el dominio: pide el titular o el mesero; solo barra '
      'registra la salida y solo el mesero la entrega', () {
    final r = approvedVip();
    tonight();
    seat(r);
    for (final other in ['admin-1', 'seguridad-1', 'caja-1', 'barra-1']) {
      expect(
        errorOf(() => bar.book.requestChampagne(r.id, actorId: other)),
        BarError.champagneNotAllowed,
        reason: other,
      );
    }
    // Otro cliente no es titular de esta reserva.
    expect(
      errorOf(() => bar.book.requestChampagne(r.id, actorId: 'cliente-b')),
      BarError.champagneNotAllowed,
    );
    expect(
      bar.book.requestChampagne(r.id, actorId: 'cliente-a').requestedBy,
      'cliente-a',
    );
    expect(
      errorOf(() => bar.book.dispatchChampagne(r.id, actorId: 'personal-1')),
      BarError.champagneNotAllowed,
    );
    bar.book.dispatchChampagne(r.id, actorId: 'barra-1');
    expect(
      errorOf(() => bar.book.deliverChampagne(r.id, actorId: 'barra-1')),
      BarError.champagneNotAllowed,
    );
    // Sin conexión con la app, el dominio no deja operar a nadie.
    final unwired = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => now,
    );
    expect(
      errorOf(() => unwired.book.requestChampagne(r.id, actorId: 'personal-1')),
      BarError.champagneNotAllowed,
    );
  });

  test('mesa normal, VIP sin aprobación o de otra noche: no hay botella', () {
    final normal = reservations.perform(
      (b) => b.createDirect(
        night: _friday,
        tableId: 'M01',
        holder: const ReservationHolder(
          name: 'Titular',
          idNumber: '1',
          phone: '3',
        ),
      ),
    );
    final saturday = approvedVip(table: 1, night: _saturday);
    tonight();
    seat(normal);
    expect(
      errorOf(
        () => bar.book.requestChampagne(normal.id, actorId: 'personal-1'),
      ),
      BarError.champagneNotEligible,
    );
    expect(
      errorOf(
        () => bar.book.requestChampagne(saturday.id, actorId: 'personal-1'),
      ),
      BarError.invalidDestination,
    );
    expect(bar.book.champagne, isEmpty);
  });

  test('petición → salida → entrega con actor, hora y vínculo; repetir no '
      'duplica; el regalo no mueve dinero ni descuenta el prepago', () {
    final r = approvedVip();
    tonight();
    seat(r);
    bar.perform(
      (b) => b.registerPrepaid(
        reservationId: r.id,
        tableId: r.tableId,
        night: _friday,
        amount: 2000000,
        actorId: 'admin-1',
      ),
    );
    final asked = bar.book.requestChampagne(r.id, actorId: 'personal-1');
    now = now.add(const Duration(minutes: 5));
    expect(
      bar.book.requestChampagne(r.id, actorId: 'cliente-a').requestedBy,
      'personal-1',
    );
    final out = bar.book.dispatchChampagne(r.id, actorId: 'barra-1');
    now = now.add(const Duration(minutes: 5));
    final given = bar.book.deliverChampagne(r.id, actorId: 'personal-1');
    now = now.add(const Duration(minutes: 5));
    final again = bar.book.dispatchChampagne(r.id, actorId: 'barra-1');
    final again2 = bar.book.deliverChampagne(r.id, actorId: 'personal-1');

    expect(bar.book.champagne, hasLength(1));
    expect(asked.requestedAt, venueInstant(2026, 10, 9, 22));
    expect(out.dispatchedAt, venueInstant(2026, 10, 9, 22, 5));
    expect(given.stage, ChampagneStage.delivered);
    expect(given.deliveredBy, 'personal-1');
    expect(given.deliveredAt, venueInstant(2026, 10, 9, 22, 10));
    expect(again.deliveredAt, given.deliveredAt);
    expect(again2.deliveredAt, given.deliveredAt);
    expect(
      (given.reservationId, given.tableId, given.venueId, given.night),
      (r.id, r.tableId, sagsaVenue.id, _friday),
    );
    expect(bar.book.sales, isEmpty);
    final balance = bar.book.balanceOf(r.id)!;
    expect(balance.consumed, 0);
    expect(balance.charged, 0);
    expect(balance.remaining, 2000000);
  });

  test('reserva terminada tras la salida: se conserva el historial y no se '
      'confirma la entrega, tampoco con otra ocupación de la mesa', () {
    final r = approvedVip();
    tonight();
    seat(r);
    bar.book.requestChampagne(r.id, actorId: 'personal-1');
    bar.book.dispatchChampagne(r.id, actorId: 'barra-1');
    reservations.perform((b) => b.release(r.id));
    expect(
      errorOf(() => bar.book.deliverChampagne(r.id, actorId: 'personal-1')),
      BarError.tableNotOccupied,
    );
    // La mesa vuelve a ocuparse con otra reserva: la botella anterior no
    // se entrega a esa ocupación.
    final next = reservations.perform(
      (b) => b.createDirect(
        night: _friday,
        tableId: r.tableId,
        holder: const ReservationHolder(
          name: 'Otro titular',
          idNumber: '2',
          phone: '4',
        ),
      ),
    );
    seat(next);
    expect(
      errorOf(() => bar.book.deliverChampagne(r.id, actorId: 'personal-1')),
      BarError.tableNotOccupied,
    );
    final kept = bar.book.champagneOf(r.id)!;
    expect(kept.stage, ChampagneStage.dispatched);
    expect(kept.dispatchedBy, 'barra-1');
    expect(bar.book.champagneOf(next.id), isNull);

    // Pedida pero sin salida: tampoco sale tras terminar.
    final other = approvedVip(table: 1);
    seat(other);
    bar.book.requestChampagne(other.id, actorId: 'personal-1');
    reservations.perform((b) => b.release(other.id));
    expect(
      errorOf(() => bar.book.dispatchChampagne(other.id, actorId: 'barra-1')),
      BarError.tableNotOccupied,
    );
  });

  String save() => encodeDemoSnapshot(
    config: sagsaConfig,
    reservations: reservations,
    tickets: DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => now,
      latency: Duration.zero,
    ),
    bar: bar,
    savedAt: now,
  );

  DemoBarStore load(String raw) {
    final b2 = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => now,
    );
    decodeDemoSnapshot(
      raw,
      config: sagsaConfig,
      reservations: DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: () => now,
      ),
      tickets: DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => now,
        latency: Duration.zero,
      ),
      bar: b2,
    );
    wire(b2);
    return b2;
  }

  test('vínculo ajeno en el registro (otra mesa u otro local): no se '
      'registra ninguna salida ni entrega', () {
    final r = approvedVip();
    tonight();
    seat(r);
    bar.book.requestChampagne(r.id, actorId: 'personal-1');
    final raw = jsonDecode(save()) as Map<String, Object?>;
    final c =
        ((raw['bar']! as Map)['champagne']! as List).single
            as Map<String, Object?>;
    for (final (key, value) in [
      ('tableId', vipTables[1].id),
      ('venueId', 'otro-local'),
    ]) {
      final tampered = jsonDecode(jsonEncode(raw)) as Map<String, Object?>;
      (((tampered['bar']! as Map)['champagne']! as List).single as Map)[key] =
          value;
      final b2 = load(jsonEncode(tampered));
      expect(
        errorOf(() => b2.book.dispatchChampagne(r.id, actorId: 'barra-1')),
        BarError.invalidDestination,
        reason: key,
      );
      expect(b2.book.champagneOf(r.id)!.stage, ChampagneStage.requested);
    }
    expect(c['venueId'], sagsaVenue.id);
  });

  test('reapertura: los pasos se conservan y repetirlos no duplica; datos '
      'anteriores sin la sección cargan sin botellas', () {
    final r = approvedVip();
    tonight();
    seat(r);
    bar.book.requestChampagne(r.id, actorId: 'personal-1');
    bar.book.dispatchChampagne(r.id, actorId: 'barra-1');
    final raw = save();
    final reopened = load(raw);
    // El libro reabierto no tiene las reservas: el reintento devuelve el
    // hecho ya registrado sin consultarlas.
    final same = reopened.book.dispatchChampagne(r.id, actorId: 'barra-1');
    expect(same.dispatchedBy, 'barra-1');
    expect(same.dispatchedAt, venueInstant(2026, 10, 9, 22));
    expect(reopened.book.champagne, hasLength(1));

    final legacy = jsonDecode(raw) as Map<String, Object?>;
    (legacy['bar']! as Map).remove('champagne');
    expect(load(jsonEncode(legacy)).book.champagne, isEmpty);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
const _holder = ReservationHolder(name: 'Titular', idNumber: '1', phone: '3');
const _party = BirthdayCelebration(honoreeName: ' Ana ', notes: '  ');

void main() {
  late DateTime now;
  late DemoReservationStore store;
  final vip = sagsaVenue.tables.firstWhere((t) => t.isVip);

  setUp(() {
    now = venueInstant(2026, 10, 7, 15);
    store = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => now,
    );
    allowDemoReservationActions(store.book);
    store.book.canManageBirthdays = (id) => id == 'admin-1';
  });

  ReservationError? errorOf(void Function() f) {
    try {
      f();
    } on ReservationException catch (e) {
      return e.error;
    }
    return null;
  }

  test('normal y VIP aceptan el cumpleaños sin cambiar sus reglas: la '
      'normal sigue su trámite y la VIP queda pendiente de prepago', () {
    final started = store.book.startNormal(
      night: _friday,
      tableId: 'M01',
      origin: ReservationOrigin.client,
      actorId: 'cliente-a',
    );
    final normal = store.book.submitNormal(
      actorId: 'cliente-a',
      started.id,
      holder: _holder,
      birthday: _party,
    );
    expect(normal.status, ReservationStatus.confirmed);
    expect(normal.birthday!.honoreeName, 'Ana');
    expect(normal.birthday!.notes, isNull);
    expect(normal.birthday!.stage, BirthdayStage.requested);

    final vipR = store.book.submitVip(
      actorId: 'promotor-1',
      night: _friday,
      tableId: vip.id,
      holder: _holder,
      origin: ReservationOrigin.promoter,
      birthday: const BirthdayCelebration(honoreeName: 'Luis'),
    );
    expect(vipR.status, ReservationStatus.pendingPayment);
    // La disponibilidad no cambia: la mesa sigue tomada como cualquier
    // reserva.
    expect(
      errorOf(
        () => store.book.createDirect(
          actorId: 'admin-1',
          night: _friday,
          tableId: vip.id,
          holder: _holder,
        ),
      ),
      ReservationError.tableTaken,
    );
    // Sin nombre, o con condiciones ya «confirmadas» desde el formulario,
    // no se acepta.
    expect(
      errorOf(
        () => store.book.createDirect(
          actorId: 'admin-1',
          night: _friday,
          tableId: 'M02',
          holder: _holder,
          birthday: const BirthdayCelebration(honoreeName: ' '),
        ),
      ),
      ReservationError.invalidBirthday,
    );
    expect(
      errorOf(
        () => store.book.createDirect(
          actorId: 'admin-1',
          night: _friday,
          tableId: 'M02',
          holder: _holder,
          birthday: BirthdayCelebration(
            honoreeName: 'Ana',
            terms: BirthdayTerms(
              conditions: 'Gratis',
              decorationRequired: true,
              confirmed: ActorStamp('cliente-a', now),
            ),
          ),
        ),
      ),
      ReservationError.invalidBirthday,
    );
  });

  test('solo la administración confirma condiciones y decoración; marcar '
      'cumpleaños no confirma nada solo', () {
    final r = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M01',
      holder: _holder,
      birthday: _party,
    );
    for (final actor in ['cliente-a', 'promotor-1', 'personal-1']) {
      expect(
        errorOf(
          () => store.book.confirmBirthday(
            r.id,
            conditions: 'Postre',
            decorationRequired: true,
            actorId: actor,
          ),
        ),
        ReservationError.notAllowed,
      );
    }
    expect(
      errorOf(
        () => store.book.markDecorationPrepared(r.id, actorId: 'admin-1'),
      ),
      ReservationError.invalidTransition,
    );
    expect(
      errorOf(
        () => store.book.confirmBirthday(
          r.id,
          conditions: '  ',
          decorationRequired: true,
          actorId: 'admin-1',
        ),
      ),
      ReservationError.invalidBirthday,
    );
    final c = store.book.confirmBirthday(
      r.id,
      conditions: 'Postre acordado por teléfono',
      decorationRequired: true,
      actorId: 'admin-1',
    );
    expect(c.status, ReservationStatus.confirmed);
    expect(c.history, hasLength(1));
    expect(c.birthday!.stage, BirthdayStage.decorationPending);
    expect(c.birthday!.terms!.confirmed.actorId, 'admin-1');
    expect(c.birthday!.terms!.confirmed.at, now);
    // Repetir lo mismo no cambia nada.
    expect(
      store.book
          .confirmBirthday(
            r.id,
            conditions: 'Postre acordado por teléfono',
            decorationRequired: true,
            actorId: 'admin-1',
          )
          .birthday!
          .terms!
          .confirmed
          .at,
      now,
    );
    expect(
      errorOf(
        () => store.book.markDecorationPrepared(r.id, actorId: 'personal-1'),
      ),
      ReservationError.notAllowed,
    );
    now = venueInstant(2026, 10, 9, 19);
    final p = store.book.markDecorationPrepared(r.id, actorId: 'admin-1');
    expect(p.birthday!.stage, BirthdayStage.decorationPrepared);
    expect(p.birthday!.decorationPrepared!.at, now);
  });

  test('la administración ajusta el acuerdo mientras la reserva sigue '
      'vigente: el anterior y su preparación quedan en el historial y la '
      'decoración vuelve a revisión; con la noche cerrada ya no', () {
    final r = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M01',
      holder: _holder,
      birthday: _party,
    );
    store.book.confirmBirthday(
      r.id,
      conditions: 'Postre',
      decorationRequired: true,
      actorId: 'admin-1',
    );
    now = venueInstant(2026, 10, 9, 19);
    store.book.markDecorationPrepared(r.id, actorId: 'admin-1');
    now = venueInstant(2026, 10, 9, 19, 30);
    expect(
      errorOf(
        () => store.book.confirmBirthday(
          r.id,
          conditions: 'Postre y globos',
          decorationRequired: true,
          actorId: 'cliente-a',
        ),
      ),
      ReservationError.notAllowed,
    );
    final adjusted = store.book
        .confirmBirthday(
          r.id,
          conditions: 'Postre y globos',
          decorationRequired: true,
          actorId: 'admin-1',
        )
        .birthday!;
    expect(adjusted.terms!.conditions, 'Postre y globos');
    expect(adjusted.terms!.confirmed.at, now);
    expect(adjusted.decorationPrepared, isNull);
    expect(adjusted.decorationNeedsReview, isTrue);
    final before = adjusted.previous.single;
    expect(before.terms.conditions, 'Postre');
    expect(before.decorationPrepared!.at, venueInstant(2026, 10, 9, 19));
    expect(store.book.byId(r.id)!.history, hasLength(1));

    // Revisada otra vez; luego sin decoración: todo queda en el historial.
    store.book.markDecorationPrepared(r.id, actorId: 'admin-1');
    final plain = store.book
        .confirmBirthday(
          r.id,
          conditions: 'Postre y globos',
          decorationRequired: false,
          actorId: 'admin-1',
        )
        .birthday!;
    expect(plain.stage, BirthdayStage.confirmed);
    expect(plain.previous, hasLength(2));
    expect(plain.previous.last.decorationPrepared, isNotNull);

    now = venueInstant(2026, 10, 10, 12);
    expect(
      errorOf(
        () => store.book.confirmBirthday(
          r.id,
          conditions: 'Tarde',
          decorationRequired: false,
          actorId: 'admin-1',
        ),
      ),
      ReservationError.nightEnded,
    );
  });

  test('sin decoración requerida no se marca; una reserva terminada o sin '
      'cumpleaños no se confirma', () {
    final r = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M01',
      holder: _holder,
      birthday: _party,
    );
    store.book.confirmBirthday(
      r.id,
      conditions: 'Sin promoción',
      decorationRequired: false,
      actorId: 'admin-1',
    );
    expect(store.book.byId(r.id)!.birthday!.stage, BirthdayStage.confirmed);
    expect(
      errorOf(
        () => store.book.markDecorationPrepared(r.id, actorId: 'admin-1'),
      ),
      ReservationError.invalidTransition,
    );
    final other = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M02',
      holder: _holder,
      birthday: _party,
    );
    store.book.revoke(other.id, actorId: 'admin-1');
    expect(
      errorOf(
        () => store.book.confirmBirthday(
          other.id,
          conditions: 'x',
          decorationRequired: false,
          actorId: 'admin-1',
        ),
      ),
      ReservationError.invalidTransition,
    );
    final plain = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M03',
      holder: _holder,
    );
    expect(plain.birthday, isNull);
    expect(
      errorOf(
        () => store.book.confirmBirthday(
          plain.id,
          conditions: 'x',
          decorationRequired: false,
          actorId: 'admin-1',
        ),
      ),
      ReservationError.invalidTransition,
    );
  });

  test('persistencia: cumpleaños con condiciones y decoración se conserva; '
      'reservas guardadas antes, sin cumpleaños, quedan intactas', () {
    final r = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M01',
      holder: _holder,
      birthday: const BirthdayCelebration(honoreeName: 'Ana', notes: 'Torta'),
    );
    store.book.confirmBirthday(
      r.id,
      conditions: 'Postre',
      decorationRequired: true,
      actorId: 'admin-1',
    );
    store.book.markDecorationPrepared(r.id, actorId: 'admin-1');
    store.book.confirmBirthday(
      r.id,
      conditions: 'Postre ajustado',
      decorationRequired: true,
      actorId: 'admin-1',
    );
    final plain = store.book.createDirect(
      actorId: 'admin-1',
      night: _friday,
      tableId: 'M02',
      holder: _holder,
    );
    String save() => encodeDemoSnapshot(
      config: sagsaConfig,
      reservations: store,
      tickets: DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => now,
        latency: Duration.zero,
      ),
      bar: DemoBarStore(venue: sagsaVenue, menu: sagsaConfig.menu),
      savedAt: now,
    );
    DemoReservationStore load(String raw) {
      final s = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: () => now,
      );
      allowDemoReservationActions(s.book);
      decodeDemoSnapshot(
        raw,
        config: sagsaConfig,
        reservations: s,
        tickets: DemoTicketStore(
          venueId: sagsaVenue.id,
          venueTag: sagsaConfig.ticketTag,
          clock: () => now,
          latency: Duration.zero,
        ),
        bar: DemoBarStore(venue: sagsaVenue, menu: sagsaConfig.menu),
      );
      return s;
    }

    final raw = save();
    final b = load(raw).book.byId(r.id)!.birthday!;
    expect(b.honoreeName, 'Ana');
    expect(b.notes, 'Torta');
    expect(b.terms!.conditions, 'Postre ajustado');
    expect(b.terms!.confirmed.actorId, 'admin-1');
    expect(b.decorationNeedsReview, isTrue);
    expect(b.previous.single.terms.conditions, 'Postre');
    expect(b.previous.single.decorationPrepared!.actorId, 'admin-1');

    // Formato anterior: sin la clave «birthday» en ninguna reserva.
    final old = jsonDecode(raw) as Map<String, Object?>;
    for (final x in (old['reservations']! as Map)['items']! as List) {
      (x as Map).remove('birthday');
    }
    final legacy = load(jsonEncode(old)).book;
    expect(legacy.byId(r.id)!.birthday, isNull);
    expect(legacy.byId(plain.id)!.status, ReservationStatus.confirmed);
    expect(legacy.byId(plain.id)!.holder!.name, 'Titular');
    expect(
      (jsonDecode(raw) as Map)['reservations']['items'][1].containsKey(
        'birthday',
      ),
      isFalse,
    );
  });
}

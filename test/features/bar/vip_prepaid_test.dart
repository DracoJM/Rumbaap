import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/persistence/demo_snapshot.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/bar/domain/bar.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

/// Consumo de prueba: 100.000 COP por unidad, para cifras exactas.
const _menu = [
  MenuItem(id: 'u', name: 'Unidad', category: 'Prueba', demoPrice: 100000),
];

void main() {
  late DateTime now;
  late DemoBarStore bar;
  final vip = sagsaVenue.tables.firstWhere((t) => t.isVip);
  final regular = sagsaVenue.tables.firstWhere((t) => !t.isVip);
  final prepaid = sagsaConfig.termsOf(vip).prepaidConsumption!;

  setUp(() {
    now = venueInstant(2026, 10, 9, 22);
    bar = DemoBarStore(venue: sagsaVenue, menu: _menu, clock: () => now);
  });

  void registerPrepaid({String reservationId = 'R7'}) => bar.perform(
    (b) => b.registerPrepaid(
      reservationId: reservationId,
      tableId: vip.id,
      night: _friday,
      amount: prepaid,
      actorId: 'admin-1',
    ),
  );

  BarSale sell(int units, {bool paid = false, String reservationId = 'R7'}) =>
      bar.perform(
        (b) => b.register(
          quantities: {'u': units},
          paidInFull: paid,
          actorId: 'barra-1',
          reservationId: reservationId,
          tableId: vip.id,
        ),
      );

  BarError? errorOf(void Function() f) {
    try {
      f();
    } on BarException catch (e) {
      return e.error;
    }
    return null;
  }

  test('el prepago de la configuración del local es 2.000.000 por mesa VIP '
      'y las mesas normales no tienen', () {
    expect(prepaid, 2000000);
    expect(sagsaConfig.termsOf(regular).prepaidConsumption, isNull);
  });

  test('sin prepago registrado no se consume ni se cobra como pago completo; '
      'el registro es único y solo para mesas VIP', () {
    expect(errorOf(() => sell(1, paid: true)), BarError.vipPrepaidPending);
    expect(
      errorOf(
        () => bar.book.registerPrepaid(
          reservationId: 'R1',
          tableId: regular.id,
          night: _friday,
          amount: prepaid,
          actorId: 'admin-1',
        ),
      ),
      BarError.invalidDestination,
    );
    registerPrepaid();
    expect(errorOf(registerPrepaid), BarError.prepaidAlreadyRegistered);
    expect(bar.book.prepaids, hasLength(1));
    expect(bar.book.sales, isEmpty);
  });

  test('1.500.000: se cubre con el prepago, no se cobra nada y queda un '
      'saldo de 500.000', () {
    registerPrepaid();
    final s = sell(15);
    expect(s.prepaidApplied, 1500000);
    expect(s.charged, 0);
    final b = bar.book.balanceOf('R7')!;
    expect(b.consumed, 1500000);
    expect(b.remaining, 500000);
    expect(b.charged, 0);
  });

  test('2.300.000: el prepago cubre 2.000.000 y solo se cobran 300.000, y '
      'únicamente con el pago presencial de la diferencia confirmado', () {
    registerPrepaid();
    expect(errorOf(() => sell(23)), BarError.paymentNotConfirmed);
    expect(bar.book.sales, isEmpty);
    final s = sell(23, paid: true);
    expect(s.prepaidApplied, 2000000);
    expect(s.charged, 300000);
    expect(bar.book.balanceOf('R7')!.remaining, 0);
  });

  test('repetición: el saldo se descuenta una vez; después todo se cobra en '
      'persona y nunca se vuelven a cobrar los 2.000.000', () {
    registerPrepaid();
    sell(15);
    final second = sell(10, paid: true);
    expect(second.prepaidApplied, 500000);
    expect(second.charged, 500000);
    final third = sell(2, paid: true);
    expect(third.prepaidApplied, 0);
    expect(third.charged, 200000);
    final b = bar.book.balanceOf('R7')!;
    expect(b.consumed, 2000000);
    expect(b.charged, 700000);
    // Lo cobrado en barra es solo el dinero recibido: 700.000.
    expect(bar.book.sales.fold<int>(0, (t, s) => t + s.charged), 700000);
  });

  test('destino incoherente o de otra noche: no se registra', () {
    bar.perform(
      (b) => b.registerPrepaid(
        reservationId: 'R8',
        tableId: vip.id,
        night: Night(DateTime.utc(2026, 10, 10)),
        amount: prepaid,
        actorId: 'admin-1',
      ),
    );
    expect(
      errorOf(() => sell(1, reservationId: 'R8')),
      BarError.invalidDestination,
    );
    expect(bar.book.sales, isEmpty);
  });

  test('cierre nocturno: el saldo no consumido se pierde (no se puede '
      'consumir después) y no se devuelve ni traslada', () {
    registerPrepaid();
    sell(15);
    now = venueInstant(2026, 10, 10, 12);
    expect(bar.book.hasEnded(_friday), isTrue);
    expect(errorOf(() => sell(1)), BarError.outsideNight);
    // El registro conserva el saldo como dato; no hay devolución ni traslado.
    expect(bar.book.balanceOf('R7')!.remaining, 500000);
    expect(bar.book.prepaids, hasLength(1));
  });

  test('las ventas contra prepago no se corrigen ni anulan (no definido); '
      'las de mesa normal sí', () {
    registerPrepaid();
    final s = sell(3);
    expect(
      errorOf(() => bar.book.voidSale(s.id, actorId: 'caja-1', reason: 'x')),
      BarError.vipCorrectionUndecided,
    );
    expect(
      errorOf(
        () => bar.book.adjust(
          s.id,
          quantities: {'u': 1},
          actorId: 'caja-1',
          reason: 'x',
        ),
      ),
      BarError.vipCorrectionUndecided,
    );
    final normal = bar.book.register(
      quantities: {'u': 2},
      paidInFull: true,
      actorId: 'barra-1',
      reservationId: 'R1',
      tableId: regular.id,
    );
    expect(
      bar.book.voidSale(normal.id, actorId: 'caja-1', reason: 'x').status,
      BarSaleStatus.voided,
    );
  });

  test(
    'reapertura: prepago, consumo y excedente se conservan; datos '
    'anteriores sin estos campos cargan sin prepago ni consumo inventado',
    () {
      registerPrepaid();
      sell(23, paid: true);
      final reservations = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: () => now,
      );
      final tickets = DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => now,
        latency: Duration.zero,
      );
      final raw = encodeDemoSnapshot(
        config: sagsaConfig,
        reservations: reservations,
        tickets: tickets,
        bar: bar,
        savedAt: now,
      );
      DemoBarStore load(String json) {
        final b2 = DemoBarStore(
          venue: sagsaVenue,
          menu: _menu,
          clock: () => now,
        );
        decodeDemoSnapshot(
          json,
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
        return b2;
      }

      final reopened = load(raw);
      final b = reopened.book.balanceOf('R7')!;
      expect(b.consumed, 2000000);
      expect(b.charged, 300000);
      expect(b.prepaid.registeredBy, 'admin-1');
      // Repetir la apertura no vuelve a descontar.
      expect(load(raw).book.balanceOf('R7')!.consumed, 2000000);

      final old = jsonDecode(raw) as Map<String, Object?>;
      final bs = old['bar']! as Map<String, Object?>;
      bs.remove('prepaids');
      for (final s in bs['sales']! as List<Object?>) {
        (s! as Map).remove('prepaidApplied');
      }
      final legacy = load(jsonEncode(old));
      expect(legacy.book.balanceOf('R7'), isNull);
      expect(legacy.book.sales.single.prepaidApplied, 0);
      expect(legacy.book.sales.single.total, 2300000);
    },
  );
}

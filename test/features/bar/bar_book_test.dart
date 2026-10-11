import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/bar/domain/bar.dart';
import 'package:rumbaap/features/bar/domain/bar_book.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

void main() {
  late _Clock clock;
  late BarBook book;
  setUp(() {
    clock = _Clock(venueInstant(2026, 10, 9, 23));
    book = BarBook(venueId: 'sagsa', menu: sagsaConfig.menu, clock: clock.call);
  });

  test('barra registra solo con el pago presencial completo y durante la '
      'noche; copia nombre y precio', () {
    expect(
      () => book.register(
        quantities: {'coctel': 2},
        paidInFull: false,
        actorId: 'barra-1',
      ),
      throwsA(isA<BarException>()),
    );
    expect(
      () => book.register(quantities: {}, paidInFull: true, actorId: 'barra-1'),
      throwsA(isA<BarException>()),
    );
    final s = book.register(
      quantities: {'coctel': 2, 'agua': 1},
      paidInFull: true,
      actorId: 'barra-1',
      reservationId: 'R1',
      tableId: 'M01',
      accountId: 'cliente-a',
    );
    expect(s.total, 2 * 35000 + 6000);
    expect(s.night, _friday);
    expect(s.registeredBy, 'barra-1');
    expect(book.salesOfAccount('cliente-a').single.id, s.id);

    clock.now = venueInstant(2026, 10, 7, 15); // miércoles: sin noche
    expect(
      () => book.register(
        quantities: {'agua': 1},
        paidInFull: true,
        actorId: 'barra-1',
      ),
      throwsA(isA<BarException>()),
    );
  });

  test('correcciones de caja o administración con motivo y lo anterior '
      'conservado; anular no borra', () {
    final s = book.register(
      quantities: {'coctel': 2},
      paidInFull: true,
      actorId: 'barra-1',
    );
    expect(
      () => book.adjust(
        s.id,
        quantities: {'coctel': 1},
        actorId: 'caja-1',
        reason: ' ',
      ),
      throwsA(isA<BarException>()),
    );
    final adj = book.adjust(
      s.id,
      quantities: {'coctel': 1},
      actorId: 'caja-1',
      reason: 'Se registró de más',
    );
    expect(adj.total, 35000);
    expect(adj.corrections.single.previousTotal, 70000);
    expect(adj.corrections.single.actorId, 'caja-1');
    final v = book.voidSale(s.id, actorId: 'admin-1', reason: 'Duplicada');
    expect(v.status, BarSaleStatus.voided);
    expect(v.total, 0);
    expect(v.corrections, hasLength(2));
    expect(book.saleById(s.id), isNotNull);
    expect(
      () => book.voidSale(s.id, actorId: 'admin-1', reason: 'otra'),
      throwsA(isA<BarException>()),
    );
  });

  test('el mesero acepta el consumo a mano, una vez, con lo que vio; las '
      'anuladas no cuentan', () {
    final a = book.register(
      quantities: {'botella': 1},
      paidInFull: true,
      actorId: 'barra-1',
      reservationId: 'R1',
      tableId: 'M01',
    );
    final b = book.register(
      quantities: {'agua': 2},
      paidInFull: true,
      actorId: 'barra-1',
      reservationId: 'R1',
      tableId: 'M01',
    );
    book.voidSale(b.id, actorId: 'caja-1', reason: 'Error');
    // Registrar ventas no acepta nada por sí solo.
    expect(book.acceptanceFor('R1'), isNull);
    final acc = book.acceptConsumption(
      reservationId: 'R1',
      tableId: 'M01',
      night: _friday,
      actorId: 'personal-1',
      note: 'Revisado con el titular',
    );
    expect(acc.saleIds, [a.id]);
    expect(acc.totalSeen, 250000);
    expect(acc.acceptedBy, 'personal-1');
    expect(
      () => book.acceptConsumption(
        reservationId: 'R1',
        tableId: 'M01',
        night: _friday,
        actorId: 'personal-1',
      ),
      throwsA(isA<BarException>()),
    );
  });
}

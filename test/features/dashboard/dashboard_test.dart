import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/dashboard/domain/night_goals.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/admin_tickets.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));
final _saturday = Night(DateTime.utc(2026, 10, 10));

void main() {
  late DemoReservationStore store;
  late DemoTicketStore tickets;
  late DemoBarStore bar;

  /// Hora del local en la prueba; empieza el viernes a las 22:00.
  late DateTime now;

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    now = _tonight;
    tester.view.physicalSize = textScale == 1
        ? const Size(411, 914)
        : const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    store = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => now,
    );
    tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => now,
      latency: Duration.zero,
    );
    bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => now,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: store,
        tickets: tickets,
        bar: bar,
        clock: () => now,
      ),
    );
    await tester.runAsync(() => store.availabilityFor(_friday));

    // Datos: 3 entradas pagadas el viernes (40.000 c/u), 1 cortesía,
    // 1 entrada pagada el sábado (50.000).
    final p = tickets.perform(
      (b) => b.sell(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 3,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      ),
    );
    tickets.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
    final [t1, t2, t3] = tickets.book.ticketsOf(p.id);
    tickets.perform(
      (b) => b.confirmFirstEntry(t1.credential!, actorId: 'seguridad-1'),
    );
    tickets.perform(
      (b) => b.redeem(
        t2.credential!,
        actorId: 'caja-1',
        point: RedeemPoint.boxOffice,
      ),
    );
    tickets.perform((b) => b.requestRefund(t3.id, actorId: 'cliente-a'));
    tickets.perform((b) => b.authorizeRequest(t3.id, actorId: 'admin-1'));
    tickets.perform(
      (b) => b.authorizeCourtesy(
        night: _friday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        actorId: 'admin-1',
        holderName: 'Invitado',
        reason: 'VIP 1',
      ),
    );
    final sat = tickets.perform(
      (b) => b.sell(
        night: _saturday,
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-b',
        ownerId: 'cliente-b',
      ),
    );
    tickets.perform((b) => b.simulatePayment(sat.id, actorId: 'cliente-b'));
    // Barra: una vigente (70.000) y una anulada.
    bar.perform(
      (b) => b.register(
        quantities: {'coctel': 2},
        paidInFull: true,
        actorId: 'barra-1',
      ),
    );
    final v = bar.perform(
      (b) => b.register(
        quantities: {'botella': 1},
        paidInFull: true,
        actorId: 'barra-1',
      ),
    );
    bar.perform((b) => b.voidSale(v.id, actorId: 'caja-1', reason: 'Error'));
    // Prepago VIP verificado.
    final vip = store.book
        .forNight(_friday)
        .firstWhere((r) => r.status == ReservationStatus.pendingPayment);
    store.perform((b) => b.markPrepaymentReceived(vip.id));
    await tester.pumpAndSettle();
  }

  /// Desplaza la lista vertical principal (la de mayor área) hasta que
  /// [f] exista y se vea: las listas largas se construyen bajo demanda.
  Future<void> reveal(WidgetTester tester, Finder f, {double dy = -200}) async {
    for (var i = 0; i < 60 && f.hitTestable().evaluate().isEmpty; i++) {
      final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      final main = lists.evaluate().reduce((a, b) {
        final sa = a.size!, sb = b.size!;
        return sa.width * sa.height >= sb.width * sb.height ? a : b;
      });
      await tester.drag(
        find.byElementPredicate((e) => e == main),
        Offset(0, dy),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> openDashboard(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('identity-admin-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('tab-Más'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('open-dashboard')));
    await tester.tap(find.byKey(const ValueKey('open-dashboard')));
    await tester.pumpAndSettle();
  }

  /// Valor de un indicador; lo trae a la vista (la lista es perezosa).
  Future<String> value(WidgetTester tester, String key) async {
    await reveal(tester, find.byKey(ValueKey('dash-$key')));
    return tester.widget<Text>(find.byKey(ValueKey('dash-$key-value'))).data!;
  }

  Future<void> scrollTo(WidgetTester tester, String key) =>
      reveal(tester, find.byKey(ValueKey('dash-$key')));

  testWidgets('personas e importes por separado, sin contar dos veces ni '
      'sumar anuladas o cortesías; filtra por noche', (tester) async {
    await pumpApp(tester);
    await openDashboard(tester);
    // La hora de corte termina en «p. m.»: no se repite el punto.
    final source = tester
        .widget<Text>(find.byKey(const ValueKey('dash-source')))
        .data!;
    expect(source, contains('Corte: vie 9 oct, 10:00 p. m.'));
    expect(source, isNot(contains('..')));
    expect(await value(tester, 'entries'), '1');
    expect(await value(tester, 'redeemed'), '1');
    // t1 (con ingreso), cortesía y la del sábado siguen sin canjear.
    expect(await value(tester, 'pending'), '3');
    await scrollTo(tester, 'ticket-income');
    expect(
      await value(tester, 'ticket-income'),
      '170.000 COP',
    ); // 3×40.000 + 50.000
    expect(await value(tester, 'refunds'), '40.000 COP');
    await scrollTo(tester, 'bar-income');
    expect(await value(tester, 'bar-income'), '70.000 COP');
    await scrollTo(tester, 'vip');
    expect(await value(tester, 'vip'), '1');
    expect(find.textContaining('para no contarlo dos veces'), findsOneWidget);
    await scrollTo(tester, 'reservations');
    expect(find.textContaining('no rentabilidad'), findsOneWidget);
    // Todo el período: no hay metas, se pide elegir una noche.
    await reveal(tester, find.byKey(const ValueKey('goal-choose-night')));
    expect(find.textContaining('No hay metas para todo el período'), findsOne);
    expect(find.byKey(const ValueKey('goal-firstEntries')), findsNothing);

    // Solo el sábado: una entrada pagada, sin barra.
    await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
    await tester.tap(find.byKey(const ValueKey('dash-night')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sábado 10 de octubre de 2026').last);
    await tester.pumpAndSettle();
    await scrollTo(tester, 'ticket-income');
    expect(await value(tester, 'ticket-income'), '50.000 COP');
    await scrollTo(tester, 'bar-income');
    expect(await value(tester, 'bar-income'), '0 COP');
  });

  testWidgets('las incidencias cuentan en la noche operativa de la lectura, '
      'conocidas o desconocidas; la ficha separa la noche de la entrada y '
      'las de fuera de horario solo están en todo el período', (tester) async {
    await pumpApp(tester);
    Future<void> pickNight(String label) async {
      await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
      await tester.tap(find.byKey(const ValueKey('dash-night')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final fridayCourtesy = tickets.book.tickets.firstWhere(
      (t) => t.channel == TicketChannel.courtesy,
    );
    final saturdayTicket = tickets.book.tickets.firstWhere(
      (t) => t.night == _saturday,
    );
    void read(String code) => tickets.perform(
      (b) => b.confirmFirstEntry(code, actorId: 'seguridad-1'),
    );

    // Viernes 22:00: un código que no es de ninguna entrada.
    read('ZZ0000000000');
    // Sábado 18:00, antes de abrir: la entrada del sábado y un código
    // desconocido. Fuera de horario: no pertenecen a ninguna noche.
    now = venueInstant(2026, 10, 10, 18);
    read(saturdayTicket.credential!);
    read('ZZ1111111111');
    // Sábado 22:00: la cortesía del VIERNES y otro código desconocido.
    now = venueInstant(2026, 10, 10, 22);
    read(fridayCourtesy.credential!);
    read('ZZ2222222222');
    expect(tickets.book.incidents, hasLength(5));
    expect(
      tickets.book.incidents[3].reason,
      RejectReason.otherNight,
      reason: 'la entrada del viernes se rechaza el sábado',
    );
    await tester.pumpAndSettle();
    await openDashboard(tester);

    // Todo el período: las cinco, también las de fuera de horario.
    expect(await value(tester, 'incidents'), '5');
    await tester.tap(find.byKey(const ValueKey('dash-incidents')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fuera de horario'), findsNWidgets(2));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Viernes: solo la lectura hecha el viernes. La cortesía del viernes,
    // leída el sábado, no cuenta aquí.
    await pickNight('Viernes 9 de octubre de 2026');
    expect(await value(tester, 'incidents'), '1');

    // Sábado: las dos lecturas de las 22:00, conocida y desconocida; no las
    // de las 18:00.
    await pickNight('Sábado 10 de octubre de 2026');
    expect(await value(tester, 'incidents'), '2');
    await tester.tap(find.byKey(const ValueKey('dash-incidents')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fuera de horario'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dash-row-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('incident-reading-night')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('incident-reading-night')))
          .data,
      contains('Sábado 10 de octubre'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('incident-ticket-night')))
          .data,
      allOf(contains(fridayCourtesy.id), contains('Viernes 9 de octubre')),
    );
    await tester.tap(find.byKey(const ValueKey('incident-open-ticket')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminTicketPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // La desconocida tiene ficha con su noche y sin entrada inventada.
    await tester.tap(find.byKey(const ValueKey('dash-row-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('incident-reading-night')))
          .data,
      contains('Sábado 10 de octubre'),
    );
    expect(find.byKey(const ValueKey('incident-ticket-night')), findsNothing);
    expect(find.byKey(const ValueKey('incident-open-ticket')), findsNothing);
    expect(find.textContaining('ninguna entrada'), findsOneWidget);
  });

  testWidgets('metas por noche: sin configurar por defecto, se validan, se '
      'editan y se quitan; avance parcial en curso, resultado al terminar; '
      'el prepago VIP no entra en ingresos', (tester) async {
    await pumpApp(tester);
    await openDashboard(tester);

    // Busca hacia arriba y hacia abajo: la lista se construye bajo demanda.
    Future<void> find2(Finder f) async {
      await reveal(tester, f, dy: 200);
      await reveal(tester, f);
    }

    Future<void> pickFriday() async {
      await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
      await tester.tap(find.byKey(const ValueKey('dash-night')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viernes 9 de octubre de 2026').last);
      await tester.pumpAndSettle();
    }

    String state(String metric) {
      final f = find.byKey(ValueKey('goal-$metric-state'));
      return tester.widget<Text>(f).data!;
    }

    Future<void> setGoal(String metric, String text) async {
      await find2(find.byKey(ValueKey('goal-$metric-edit')));
      await tester.tap(find.byKey(ValueKey('goal-$metric-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('goal-input')), text);
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      await tester.pumpAndSettle();
    }

    await pickFriday();
    await reveal(tester, find.byKey(const ValueKey('goal-coverage')));
    expect(find.textContaining('Noche en curso'), findsOneWidget);
    for (final m in GoalMetric.values) {
      await find2(find.byKey(ValueKey('goal-${m.name}-state')));
      expect(state(m.name), startsWith('Sin configurar'));
    }

    // Validación: cero no se acepta y el diálogo sigue abierto.
    await setGoal('ticketIncome', '0');
    expect(find.textContaining('mayor que cero'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goal-input')), '100000');
    await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
    await tester.pumpAndSettle();
    // 3 × 40.000 pagadas el viernes; la cortesía no tiene importe.
    expect(
      state('ticketIncome'),
      'Meta alcanzada: 120.000 COP de 100.000 COP.',
    );

    // Barra: solo ventas vigentes (70.000); el prepago VIP no se suma.
    await setGoal('barIncome', '500000');
    expect(state('barIncome'), contains('70.000 COP de 500.000 COP'));

    // En curso: avance parcial, nunca «no alcanzada».
    await setGoal('firstEntries', '5');
    expect(state('firstEntries'), startsWith('Avance parcial: 1 de 5'));
    expect(state('firstEntries'), isNot(contains('No alcanzada')));

    // Editar conserva el parámetro y cambia el valor.
    await setGoal('firstEntries', '1');
    expect(state('firstEntries'), 'Meta alcanzada: 1 de 1.');

    // Detalle existente.
    await reveal(
      tester,
      find.byKey(const ValueKey('goal-firstEntries-detail')),
    );
    await tester.tap(find.byKey(const ValueKey('goal-firstEntries-detail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dash-list')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Quitar: vuelve a «sin configurar».
    await reveal(
      tester,
      find.byKey(const ValueKey('goal-firstEntries-remove')),
    );
    await tester.tap(find.byKey(const ValueKey('goal-firstEntries-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
    await tester.pumpAndSettle();
    expect(state('firstEntries'), startsWith('Sin configurar'));

    // La noche termina: el resultado ya no es parcial.
    now = venueInstant(2026, 10, 10, 12);
    await setGoal('reservationArrivals', '3');
    // Las llegadas sembradas cuentan; con la noche terminada ya es final.
    expect(state('reservationArrivals'), startsWith('No alcanzada:'));
    expect(state('reservationArrivals'), contains('de 3'));
    await find2(find.byKey(const ValueKey('goal-coverage')));
    expect(find.textContaining('Noche terminada'), findsOneWidget);
  });

  testWidgets('una noche que solo tiene metas sigue en el selector, sin '
      'movimientos ni éxito afirmado', (tester) async {
    await pumpApp(tester);
    final goals = tester.widget<RumbaapApp>(find.byType(RumbaapApp)).goals;
    final empty = Night(DateTime.utc(2026, 10, 23));
    goals.perform(
      (b) => b.set(empty, GoalMetric.firstEntries, 50, actorId: 'admin-1'),
    );
    await openDashboard(tester);
    await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
    await tester.tap(find.byKey(const ValueKey('dash-night')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viernes 23 de octubre de 2026').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('goal-firstEntries-state')));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('goal-firstEntries-state')))
          .data,
      'Noche sin empezar: 0 de 50.',
    );
  });

  group('resumen de la noche', () {
    Future<void> pickFriday(WidgetTester tester) async {
      await reveal(tester, find.byKey(const ValueKey('dash-night')), dy: 200);
      await tester.tap(find.byKey(const ValueKey('dash-night')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viernes 9 de octubre de 2026').last);
      await tester.pumpAndSettle();
    }

    Future<String> openSummary(WidgetTester tester) async {
      await reveal(tester, find.byKey(const ValueKey('dash-summary')), dy: 200);
      await reveal(tester, find.byKey(const ValueKey('dash-summary')));
      await tester.tap(find.byKey(const ValueKey('dash-summary')));
      await tester.pumpAndSettle();
      return tester
          .widget<SelectableText>(find.byKey(const ValueKey('summary-text')))
          .data!;
    }

    /// Portapapeles simulado: guarda lo copiado o falla a pedido.
    String? clipboard;
    void mockClipboard(WidgetTester tester, {bool fail = false}) {
      clipboard = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'denied');
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('solo para una noche: cifras del panel con cobertura, metas '
        'e incidencias, sin datos personales; copiar solo al pulsar y la '
        'noche elegida se conserva al volver', (tester) async {
      await pumpApp(tester);
      mockClipboard(tester);
      final goals = tester.widget<RumbaapApp>(find.byType(RumbaapApp)).goals;
      goals.perform(
        (b) => b.set(_friday, GoalMetric.ticketIncome, 100000, actorId: 'a'),
      );
      tickets.perform(
        (b) => b.confirmFirstEntry('ZZ0000000000', actorId: 'seguridad-1'),
      );
      await openDashboard(tester);
      // Todo el período: sin resumen.
      expect(find.byKey(const ValueKey('dash-summary')), findsNothing);
      expect(find.byKey(const ValueKey('dash-summary-hint')), findsOneWidget);

      await pickFriday(tester);
      final text = await openSummary(tester);
      expect(clipboard, isNull, reason: 'abrir no copia nada');
      for (final part in [
        'Resumen de la noche · Sagsa',
        'Noche operativa: Viernes 9 de octubre de 2026',
        'Corte: vie 9 oct, 10:00 p. m. de 2026',
        'Noche en curso',
        '- Primeros ingresos con entrada: 1',
        '- Reservas con llegada registrada:',
        // Solo el viernes: 3 × 40.000; no la del sábado (50.000).
        '- Entradas pagadas: 120.000 COP',
        '- Devoluciones autorizadas (aparte, no restadas): 40.000 COP',
        '- Ventas de barra vigentes: 70.000 COP',
        '- Prepagos VIP verificados: 1 (sin importe',
        '- Entradas pagadas: Meta alcanzada: 120.000 COP de 100.000 COP.',
        '- Primeros ingresos con entrada: Sin configurar',
        'INCIDENCIAS DE PUERTA Y TAQUILLA (por noche de lectura): 1',
        // 12 caracteres sin el prefijo del local: «de otro local».
        '- De otro local: 1',
        'BENEFICIOS VIP',
        'Sin salidas registradas no se calculan ocupación ni permanencia.',
      ]) {
        expect(text, contains(part));
      }
      // Sin nombres, cuentas, cédulas ni credenciales.
      for (final t in tickets.book.tickets) {
        expect(text, isNot(contains(t.credential ?? '#')));
      }
      for (final bad in ['Invitado', 'cliente-a', 'Titular', 'ZZ0000000000']) {
        expect(text, isNot(contains(bad)));
      }

      await tester.tap(find.byKey(const ValueKey('summary-copy')));
      await tester.pumpAndSettle();
      expect(clipboard, text);
      expect(find.text('Resumen copiado al portapapeles.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Sagsa · Viernes 9 de octubre de 2026'), findsOneWidget);
    });

    testWidgets(
      'si el portapapeles falla se dice y el texto sigue seleccionable; '
      'en 320 dp con texto al 200 % no desborda',
      (tester) async {
        await pumpApp(tester, textScale: 2);
        mockClipboard(tester, fail: true);
        await openDashboard(tester);
        await pickFriday(tester);
        await openSummary(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('summary-copy')));
        await tester.pumpAndSettle();
        expect(find.textContaining('No se pudo copiar'), findsOneWidget);
        expect(clipboard, isNull);
        expect(find.byKey(const ValueKey('summary-text')), findsOneWidget);
      },
      variant: TargetPlatformVariant.mobile(),
    );
  });

  testWidgets('cada indicador abre su lista y desde ella la ficha', (
    tester,
  ) async {
    await pumpApp(tester);
    await openDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('dash-redeemed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dash-list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dash-row-0')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminTicketPage), findsOneWidget);
    expect(find.text('Canjeada · No canjeable'), findsOneWidget);
  });

  testWidgets(
    'panel con texto al 200 % en 320 dp, sin errores',
    (tester) async {
      await pumpApp(tester, textScale: 2);
      await openDashboard(tester);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/bar/domain/bar.dart';
import 'package:rumbaap/features/bar/presentation/bar_views.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/credential_scanner.dart';
import 'package:rumbaap/features/venues/venue_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../reservations/fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));
const _menu = [
  MenuItem(id: 'u', name: 'Unidad', category: 'Prueba', demoPrice: 100000),
];

BarError? _errorOf(void Function() f) {
  try {
    f();
  } on BarException catch (e) {
    return e.error;
  }
  return null;
}

void main() {
  group('cliente sin cuenta (dominio)', () {
    late DemoBarStore bar;
    final vip = sagsaVenue.tables.firstWhere((t) => t.isVip);
    final prepaid = sagsaConfig.termsOf(vip).prepaidConsumption!;

    setUp(() {
      final now = venueInstant(2026, 10, 9, 22);
      bar = DemoBarStore(venue: sagsaVenue, menu: _menu, clock: () => now);
    });

    BarSale sell({
      String? accountId,
      UnverifiedCustomer? customer,
      int units = 1,
    }) => bar.perform(
      (b) => b.register(
        quantities: {'u': units},
        paidInFull: true,
        actorId: 'barra-1',
        accountId: accountId,
        customer: customer,
      ),
    );

    test('cuenta y cliente sin cuenta son excluyentes; el contacto solo admite '
        'dígitos; un rechazo no registra nada', () {
      expect(
        _errorOf(
          () => sell(
            accountId: 'cliente-a',
            customer: const UnverifiedCustomer(name: 'Ana'),
          ),
        ),
        BarError.invalidCustomer,
      );
      expect(
        _errorOf(() => sell(customer: const UnverifiedCustomer(phone: '30a'))),
        BarError.invalidCustomer,
      );
      expect(
        _errorOf(
          () => sell(customer: const UnverifiedCustomer(idNumber: '1 2')),
        ),
        BarError.invalidCustomer,
      );
      expect(bar.book.sales, isEmpty);
    });

    test('guarda el contacto manual aparte de la cuenta, sin vincular ni '
        'crear nada; vacío es «sin identificar»', () {
      final s = sell(
        customer: const UnverifiedCustomer(
          name: ' Ana ',
          phone: ' 3001112233 ',
          idNumber: '',
        ),
      );
      expect(s.accountId, isNull);
      expect(s.customer!.name, 'Ana');
      expect(s.customer!.phone, '3001112233');
      expect(s.customer!.idNumber, isNull);
      expect(
        sell(customer: const UnverifiedCustomer()).customer!.isEmpty,
        true,
      );
      // Ninguna cuenta recibe la venta por coincidir cédula o teléfono.
      expect(bar.book.salesOfAccount('cliente-a'), isEmpty);
    });

    test('la corrección conserva el cliente sin cuenta y la contabilidad', () {
      final s = sell(units: 3, customer: const UnverifiedCustomer(name: 'Ana'));
      final fixed = bar.perform(
        (b) => b.adjust(
          s.id,
          quantities: {'u': 1},
          actorId: 'caja-1',
          reason: 'De más',
        ),
      );
      expect(fixed.customer!.name, 'Ana');
      expect(fixed.total, 100000);
      expect(fixed.charged, 100000);
      expect(fixed.corrections, hasLength(1));
    });

    test('mesa VIP: el prepago y el excedente se calculan igual con cliente '
        'sin cuenta', () {
      bar.perform(
        (b) => b.registerPrepaid(
          reservationId: 'R7',
          tableId: vip.id,
          night: _friday,
          amount: prepaid,
          actorId: 'admin-1',
        ),
      );
      final s = bar.perform(
        (b) => b.register(
          quantities: {'u': 23},
          paidInFull: true,
          actorId: 'barra-1',
          reservationId: 'R7',
          tableId: vip.id,
          customer: const UnverifiedCustomer(name: 'Ana'),
        ),
      );
      expect(s.total, 2300000);
      expect(s.prepaidApplied, 2000000);
      expect(s.charged, 300000);
      expect(s.customer!.name, 'Ana');
      expect(bar.book.balanceOf('R7')!.remaining, 0);
    });
  });

  group('puesto de Barra (UI)', () {
    Future<(DemoBarStore, DemoTicketStore)> pump(
      WidgetTester tester,
      DateTime now, {
      CredentialScan? scan,
    }) async {
      tester.view.physicalSize = const Size(411, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reservations = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: () => now,
      );
      final bar = DemoBarStore(
        venue: sagsaVenue,
        menu: sagsaConfig.menu,
        clock: () => now,
      );
      final tickets = DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => now,
        latency: Duration.zero,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: VenueScope(
            config: sagsaConfig,
            child: Scaffold(
              body: BarDesk(
                store: bar,
                reservations: reservations,
                identity: DemoIdentities.byId('barra-1')!,
                tickets: tickets,
                scan: scan ?? (_) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (bar, tickets);
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('selector de mesa: explica el vacío fuera de la noche y dentro '
        'de una noche sin reservas', (tester) async {
      await pump(tester, venueInstant(2026, 10, 12, 15)); // lunes
      expect(
        find.textContaining(
          'Las mesas con reserva se habilitan durante la noche',
        ),
        findsOneWidget,
      );
      // Junto a «Sin mesa» solo una ayuda breve; el horario no se repite.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('bar-no-tables'))).data,
        'No hay una noche en curso.',
      );
      expect(find.textContaining('8:30 p. m.'), findsOneWidget);
      await pump(tester, venueInstant(2026, 10, 9, 22)); // viernes, sin sembrar
      expect(
        find.text('No hay mesas con reserva confirmada para esta noche.'),
        findsOneWidget,
      );
    });

    testWidgets('«Credencial» y escribir a mano: pedir escribir da foco; '
        'cancelar no', (tester) async {
      var outcome = const ManualEntryRequested() as ScanOutcome?;
      await pump(
        tester,
        venueInstant(2026, 10, 9, 22),
        scan: (_) async => outcome,
      );
      expect(find.text('Credencial'), findsOneWidget);
      expect(find.textContaining('Escribe o pega el ID del cliente'), findsOne);
      expect(find.textContaining('Entrada del cliente'), findsNothing);
      bool focused() => tester
          .widget<TextField>(find.byKey(const ValueKey('bar-qr')))
          .focusNode!
          .hasFocus;
      outcome = null;
      await tapKey(tester, 'bar-scan');
      expect(focused(), isFalse);
      outcome = const ManualEntryRequested();
      await tapKey(tester, 'bar-scan');
      expect(focused(), isTrue);
    });

    testWidgets('cliente sin cuenta: se registra con o sin datos; cambiar de '
        'modo descarta cuenta y contacto; la cuenta no se mezcla', (
      tester,
    ) async {
      final (bar, tickets) = await pump(tester, venueInstant(2026, 10, 9, 22));
      final p = tickets.perform(
        (b) => b.sell(
          night: _friday,
          product: sagsaConfig.ticketProducts.first,
          quantity: 1,
          channel: TicketChannel.app,
          actorId: 'cliente-a',
          ownerId: 'cliente-a',
        ),
      );
      tickets.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
      final code = tickets.book.ticketsOf(p.id).single.credential!;

      // Identifica una cuenta y cambia a «sin cuenta»: se descarta el código.
      await tester.enterText(find.byKey(const ValueKey('bar-qr')), code);
      await tapKey(tester, 'bar-identify');
      expect(find.byKey(const ValueKey('bar-account-status')), findsOneWidget);
      await tester.tap(find.text('Cliente sin cuenta'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bar-qr')), findsNothing);
      expect(find.byKey(const ValueKey('bar-guest-notice')), findsOneWidget);
      await tester.tap(find.text('Cliente con cuenta'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bar-qr')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('bar-account-status')), findsNothing);

      // Venta sin cuenta y sin ningún dato.
      await tester.tap(find.text('Cliente sin cuenta'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'bar-add-agua');
      await tapKey(tester, 'bar-paid');
      await tapKey(tester, 'bar-register');
      await tapKey(tester, 'dialog-confirm');
      final s1 = bar.book.sales.single;
      expect(s1.accountId, isNull);
      expect(s1.customer!.isEmpty, isTrue);

      // Venta sin cuenta con datos opcionales.
      await tester.tap(find.text('Cliente sin cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bar-guest-name')),
        'Ana',
      );
      await tester.enterText(
        find.byKey(const ValueKey('bar-guest-phone')),
        '3001112233',
      );
      await tapKey(tester, 'bar-add-agua');
      await tapKey(tester, 'bar-paid');
      await tapKey(tester, 'bar-register');
      await tapKey(tester, 'dialog-confirm');
      final s2 = bar.book.sales.firstWhere((s) => s.id != s1.id);
      expect(s2.accountId, isNull);
      expect(s2.customer!.name, 'Ana');
      expect(s2.customer!.phone, '3001112233');
      expect(bar.book.salesOfAccount('cliente-a'), isEmpty);
    });
  });
}

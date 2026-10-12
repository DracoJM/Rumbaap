import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/session/demo_identities.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/tickets/domain/ticket.dart';
import 'package:rumbaap/features/tickets/presentation/credential_scanner.dart';
import 'package:rumbaap/features/tickets/presentation/staff_ticket_desks.dart';
import 'package:rumbaap/features/tickets/presentation/ticket_widgets.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import '../../support/fake_scanner_platform.dart';
import '../reservations/fakes.dart';

/// Viernes 9 de octubre de 2026, 10:00 p. m.: noche en curso.
final _tonight = venueInstant(2026, 10, 9, 22);
final tonightNight = Night(DateTime.utc(2026, 10, 9));

void main() {
  late DemoTicketStore store;
  late FakeScannerPlatform camera;
  late MobileScannerPlatform realPlatform;

  setUp(() {
    realPlatform = MobileScannerPlatform.instance;
    camera = FakeScannerPlatform();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() => MobileScannerPlatform.instance = realPlatform);

  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
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
    store = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => _tonight,
      latency: Duration.zero,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: DemoReservationStore(
          venue: sagsaVenue,
          latency: Duration.zero,
          clock: () => _tonight,
        ),
        tickets: store,
        clock: () => _tonight,
      ),
    );
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      final lists = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );
      if (lists.evaluate().isEmpty) break;
      final main = lists.evaluate().reduce((a, b) {
        final sa = a.size!, sb = b.size!;
        return sa.width * sa.height >= sb.width * sb.height ? a : b;
      });
      await tester.drag(
        find.byElementPredicate((e) => e == main),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String id) async {
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await tapKey(tester, 'identity-$id');
  }

  String resultTitle(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('desk-result-title')))
      .data!;

  /// Venta del cliente A, pagada (simulado): devuelve su entrada.
  Ticket paidClientTicket() {
    final p = store.perform(
      (b) => b.sell(
        night: tonightNight,
        product: sagsaConfig.ticketProducts.first,
        quantity: 1,
        channel: TicketChannel.app,
        actorId: 'cliente-a',
        ownerId: 'cliente-a',
      ),
    );
    store.perform((b) => b.simulatePayment(p.id, actorId: 'cliente-a'));
    return store.book.ticketsOf(p.id).single;
  }

  /// Abre la cámara con el botón del personal.
  Future<void> openCamera(WidgetTester tester, String key) async {
    await tapKey(tester, key);
    expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
  }

  int events(Ticket t, TicketEventType type) =>
      store.book.ticketById(t.id)!.history.where((e) => e.type == type).length;

  testWidgets(
    'QR de la entrada: cabe en 320 dp con texto al 200 %, sigue la credencial '
    'vigente tras reemplazarla y se anuncia sin doble punto',
    (tester) async {
      await pumpApp(tester, textScale: 2);
      final semantics = tester.ensureSemantics();
      final t = paidClientTicket();
      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Entradas');
      await tapKey(tester, 'ticket-${t.id}');
      expect(tester.takeException(), isNull);
      final qr = tester.getSize(find.byKey(const ValueKey('credential-qr')));
      expect(qr.width, lessThanOrEqualTo(320 - 32));
      expect(qr.width, qr.height);
      bool announces(String code) => find
          .bySemanticsLabel(RegExp(credentialLabel(code)))
          .evaluate()
          .isNotEmpty;
      expect(announces(t.credential!), isTrue);
      expect(find.bySemanticsLabel(RegExp(r'\.\.')), findsNothing);

      await tapKey(tester, 'ticket-replace');
      await tapKey(tester, 'dialog-confirm');
      final fresh = store.book.ticketById(t.id)!.credential!;
      // Vuelve arriba: la lista solo construye lo cercano a la vista.
      await tester.fling(
        find.byKey(ValueKey('ticket-page-${t.id}')),
        const Offset(0, 2000),
        3000,
      );
      await tester.pumpAndSettle();
      expect(announces(fresh), isTrue);
      expect(announces(t.credential!), isFalse);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.mobile(),
  );

  group('cámara del personal', () {
    testWidgets(
      'puerta: la lectura solo CONSULTA; varias detecciones del mismo '
      'fotograma dan una sola consulta; el ingreso lo confirma la persona y '
      'una relectura no lo duplica',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        await enter(tester, 'seguridad-1');
        await openCamera(tester, 'door-scan');
        // El lector nativo avisa varias veces seguidas del mismo código.
        camera
          ..emit(t.credential!)
          ..emit(t.credential!)
          ..emit(t.credential!);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fake-camera')), findsNothing);
        expect(resultTitle(tester), 'Vigente para esta noche · sin ingreso');
        expect(store.book.ticketById(t.id)!.firstEntryAt, isNull);
        expect(store.book.incidents, isEmpty);
        // La cámara se detuvo y se liberó al cerrar.
        expect(camera.running, isFalse);
        expect(camera.disposes, greaterThanOrEqualTo(1));

        await tapKey(tester, 'door-confirm-entry');
        expect(store.book.ticketById(t.id)!.firstEntryAt, isNotNull);

        await openCamera(tester, 'door-scan');
        camera.emit(t.credential!);
        await tester.pumpAndSettle();
        expect(resultTitle(tester), startsWith('Ingreso ya registrado'));
        expect(events(t, TicketEventType.firstEntryRecorded), 1);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'taquilla: la lectura pide la confirmación del canje; cancelar no '
      'registra nada; credencial retirada y canje repetido se rechazan',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        final old = t.credential!;
        store.perform(
          (b) => b.replaceCredential(
            t.id,
            actorId: 'cliente-a',
            reason: 'Captura compartida',
          ),
        );
        final fresh = store.book.ticketById(t.id)!.credential!;
        await enter(tester, 'caja-1');

        // Credencial retirada (una captura antigua).
        await openCamera(tester, 'box-scan');
        camera.emit(old);
        await tester.pumpAndSettle();
        await tapKey(tester, 'dialog-confirm');
        expect(resultTitle(tester), contains('Credencial retirada'));

        // Vigente, pero la persona cancela: nada cambia.
        await openCamera(tester, 'box-scan');
        camera.emit(fresh);
        await tester.pumpAndSettle();
        await tapKey(tester, 'dialog-cancel');
        expect(store.book.ticketById(t.id)!.status, TicketStatus.active);

        // Confirmado: canje una vez.
        await openCamera(tester, 'box-scan');
        camera.emit(fresh);
        await tester.pumpAndSettle();
        await tapKey(tester, 'dialog-confirm');
        expect(resultTitle(tester), 'Canje registrado: entrega la manilla.');

        // La misma entrada otra vez: «No canjeable», sin otro canje.
        await openCamera(tester, 'box-scan');
        camera.emit(fresh);
        await tester.pumpAndSettle();
        await tapKey(tester, 'dialog-confirm');
        expect(resultTitle(tester), startsWith('No canjeable'));
        expect(events(t, TicketEventType.redeemed), 1);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'permiso denegado: se explica, «Reintentar» vuelve a pedir la cámara '
      'y la lectura sigue; los códigos que no son QR se ignoran',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        await enter(tester, 'seguridad-1');
        camera.nextStartError = MobileScannerErrorCode.permissionDenied;
        await tapKey(tester, 'door-scan');
        expect(
          find.byKey(const ValueKey('scanner-error-permissionDenied')),
          findsOneWidget,
        );
        expect(find.textContaining('no tiene permiso'), findsOneWidget);

        await tapKey(tester, 'scanner-retry');
        expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
        camera.emit('4006381333931', format: BarcodeFormat.ean13);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);

        camera.emit(t.credential!);
        await tester.pumpAndSettle();
        expect(resultTitle(tester), 'Vigente para esta noche · sin ingreso');
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'sin cámara: se explica sin «Reintentar» y «Escribir la credencial» '
      'vuelve al respaldo manual, que sigue funcionando',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        await enter(tester, 'seguridad-1');
        camera.nextStartError = MobileScannerErrorCode.unsupported;
        await tapKey(tester, 'door-scan');
        expect(
          find.byKey(const ValueKey('scanner-error-unsupported')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('scanner-retry')), findsNothing);
        await tapKey(tester, 'scanner-type-instead');
        expect(find.byType(CredentialScannerPage), findsNothing);
        expect(find.byKey(const ValueKey('desk-result')), findsNothing);

        await tester.enterText(
          find.byKey(const ValueKey('door-code')),
          t.credential!,
        );
        await tapKey(tester, 'door-consult');
        expect(resultTitle(tester), 'Vigente para esta noche · sin ingreso');
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'error genérico, pausa y vuelta: se detiene al salir de la app y se '
      'reanuda al volver; al salir sin leer, una detección tardía no hace '
      'nada',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        await enter(tester, 'seguridad-1');
        camera.nextStartError = MobileScannerErrorCode.genericError;
        await tapKey(tester, 'door-scan');
        expect(
          find.byKey(const ValueKey('scanner-error-genericError')),
          findsOneWidget,
        );
        await tapKey(tester, 'scanner-retry');
        expect(camera.running, isTrue);

        final stopsBefore = camera.stops;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        expect(camera.running, isFalse);
        expect(camera.stops, greaterThan(stopsBefore));
        final startsBefore = camera.starts;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(camera.starts, startsBefore + 1);
        expect(camera.running, isTrue);

        // Sale con el «atrás» del sistema sin leer.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CredentialScannerPage), findsNothing);
        expect(camera.running, isFalse);
        camera.emit(t.credential!);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('desk-result')), findsNothing);
        expect(store.book.incidents, isEmpty);
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('una lectura que llega cuando el puesto ya no está (cambió '
        'de identidad o se cerró) no consulta nada', (tester) async {
      store = DemoTicketStore(
        venueId: sagsaVenue.id,
        venueTag: sagsaConfig.ticketTag,
        clock: () => _tonight,
        latency: Duration.zero,
      );
      final t = paidClientTicket();
      final pending = Completer<String?>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketDesk.boxOffice(
              store: store,
              identity: DemoIdentities.byId('caja-1')!,
              scan: (_) => pending.future,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('box-scan')));
      await tester.pump();
      // Mientras se lee, el botón no admite otro intento.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('box-scan')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete(t.credential);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.book.ticketById(t.id)!.status, TicketStatus.active);
      expect(store.book.incidents, isEmpty);
    });

    testWidgets(
      'promotor: lee el QR del comprador, confirma y canjea con su lote una '
      'vez; un código ajeno a la venta se avisa y lo rechaza el servicio',
      (tester) async {
        await pumpApp(tester);
        final client = paidClientTicket();
        final p = store.perform(
          (b) => b.sell(
            night: tonightNight,
            product: sagsaConfig.ticketProducts.first,
            quantity: 1,
            channel: TicketChannel.promoter,
            actorId: 'promotor-1',
            holderName: 'Comprador demo',
          ),
        );
        store.perform(
          (b) => b.verifyPromoterPayment(p.id, actorId: 'promotor-1'),
        );
        final t = store.book.ticketsOf(p.id).single;
        await enter(tester, 'promotor-1');
        await tapKey(tester, 'tab-Entradas');
        await tapKey(tester, 'purchase-${p.id}');

        await openCamera(tester, 'promoter-scan');
        camera
          ..emit(t.credential!)
          ..emit(t.credential!);
        await tester.pumpAndSettle();
        expect(find.textContaining('Entrada ${t.id} de esta venta'), findsOne);
        await tapKey(tester, 'dialog-confirm');
        expect(
          find.text('Manilla de tu lote entregada (entrada ${t.id}).'),
          findsOneWidget,
        );
        expect(
          store.book.ticketById(t.id)!.redeemPoint,
          RedeemPoint.promoterLot,
        );

        await openCamera(tester, 'promoter-scan');
        camera.emit(t.credential!);
        await tester.pumpAndSettle();
        await tapKey(tester, 'dialog-confirm');
        expect(events(t, TicketEventType.redeemed), 1);

        // La entrada de la app de otro cliente: no es de esta venta.
        await openCamera(tester, 'promoter-scan');
        camera.emit(client.credential!);
        await tester.pumpAndSettle();
        expect(find.textContaining('no es de ninguna entrada'), findsOne);
        await tapKey(tester, 'dialog-confirm');
        expect(store.book.ticketById(client.id)!.status, TicketStatus.active);
        expect(store.book.incidents.last.reason, RejectReason.wrongCircuit);
      },
      variant: TargetPlatformVariant.mobile(),
    );
  });

  group('un solo QR: «Mi QR» es el de la entrada y barra lo usa para '
      'identificar', () {
    Finder inCard(Finder f) => find.descendant(
      of: find.byKey(const ValueKey('personal-qr')),
      matching: f,
    );

    testWidgets(
      '«Mi QR» muestra el QR real de la entrada de esta noche; sin entrada '
      'lo dice y no muestra ningún código',
      (tester) async {
        await pumpApp(tester);
        await enter(tester, 'cliente-a');
        await tapKey(tester, 'tab-Más');
        expect(
          inCard(find.byKey(const ValueKey('credential-qr'))),
          findsNothing,
        );
        expect(
          inCard(find.byKey(const ValueKey('personal-qr-none'))),
          findsOne,
        );
        expect(find.textContaining('QRP-'), findsNothing);

        final t = paidClientTicket();
        await tester.pumpAndSettle();
        expect(inCard(find.byKey(const ValueKey('credential-qr'))), findsOne);
        expect(
          inCard(find.text(credentialLabel(t.credential!))),
          findsOneWidget,
        );
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'barra lee el QR de la entrada: identifica la cuenta sin registrar '
      'ingreso ni canje; una entrada de otra noche no identifica y no deja '
      'registrar con el campo sin resolver; la venta lleva la cuenta',
      (tester) async {
        await pumpApp(tester);
        final t = paidClientTicket();
        final saturday = store.perform(
          (b) => b.sell(
            night: Night(DateTime.utc(2026, 10, 10)),
            product: sagsaConfig.ticketProducts.first,
            quantity: 1,
            channel: TicketChannel.app,
            actorId: 'cliente-a',
            ownerId: 'cliente-a',
          ),
        );
        store.perform(
          (b) => b.simulatePayment(saturday.id, actorId: 'cliente-a'),
        );
        final satTicket = store.book.ticketsOf(saturday.id).single;

        await enter(tester, 'barra-1');
        await tapKey(tester, 'bar-add-coctel');

        // Entrada del sábado: otra noche.
        await openCamera(tester, 'bar-scan');
        camera.emit(satTicket.credential!);
        await tester.pumpAndSettle();
        expect(find.textContaining('otra noche'), findsOneWidget);
        await tapKey(tester, 'bar-paid');
        await tapKey(tester, 'bar-register');
        expect(find.textContaining('Identifica al cliente'), findsOneWidget);

        // Entrada de esta noche, leída dos veces seguidas: una consulta.
        await openCamera(tester, 'bar-scan');
        camera
          ..emit(t.credential!)
          ..emit(t.credential!);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Cliente identificado por la entrada ${t.id}'),
          findsOneWidget,
        );
        final after = store.book.ticketById(t.id)!;
        expect(after.status, TicketStatus.active);
        expect(after.firstEntryAt, isNull);
        expect(store.book.incidents, isEmpty);

        await tapKey(tester, 'bar-register');
        await tapKey(tester, 'dialog-confirm');
        final bar = tester.widget<RumbaapApp>(find.byType(RumbaapApp)).bar.book;
        expect(bar.sales.single.accountId, 'cliente-a');
      },
      variant: TargetPlatformVariant.mobile(),
    );
  });
}

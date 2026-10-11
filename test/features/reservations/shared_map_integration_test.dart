import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/domain/reservation_book.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_layout.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_table.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_venue_map.dart';
import 'package:rumbaap/features/reservations/presentation/map/glass_tab_bar.dart';
import 'package:rumbaap/features/reservations/presentation/table_detail.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/reservations/presentation/venue_map_controller.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/features/venues/venue_config.dart';
import 'package:rumbaap/theme/venues/sagsa.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

/// Local SINTÉTICO solo para tests: tres mesas en un lienzo pequeño, sin
/// barra ni cabina. Demuestra que el mapa no depende de las 22 mesas de
/// Sagsa; no representa ningún local real.
final _otherVenue = Venue(
  id: 'test-local',
  name: 'Local de prueba',
  tables: const [
    VenueTable(
      id: 'A1',
      kind: TableKind.regular,
      zone: VenueZone(id: 'sala', label: 'Sala'),
    ),
    VenueTable(
      id: 'A2',
      kind: TableKind.regular,
      zone: VenueZone(id: 'sala', label: 'Sala'),
    ),
    VenueTable(
      id: 'P1',
      kind: TableKind.vip,
      zone: VenueZone(id: 'palco', label: 'Palco'),
    ),
  ],
);

TablePlacement _place(Offset c, String label) => TablePlacement(
  center: c,
  rotation: math.pi / 2,
  hitRect: Rect.fromCenter(center: c, width: 60, height: 50),
  badgeSide: 1,
  label: label,
);

final _otherConfig = VenueConfig(
  venue: _otherVenue,
  theme: sagsaTheme.copyWith(name: 'Local de prueba'),
  layout: CrystalLayout(
    size: const Size(300, 200),
    placements: {
      'A1': _place(const Offset(60, 100), 'A1'),
      'A2': _place(const Offset(150, 100), 'A2'),
      'P1': _place(const Offset(240, 100), 'P1'),
    },
  ),
  terms: const {
    TableKind.regular: TableTerms(capacity: 'Prueba', conditions: []),
    TableKind.vip: TableTerms(capacity: 'Prueba', conditions: []),
  },
);

Future<DemoReservationStore> _pumpApp(
  WidgetTester tester, {
  VenueConfig? config,
  DateTime Function() clock = fixedClock,
}) async {
  final c = config ?? sagsaConfig;
  tester.view.physicalSize = const Size(411, 914);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final store = DemoReservationStore(
    venue: c.venue,
    latency: Duration.zero,
    clock: clock,
  );
  await tester.pumpWidget(RumbaapApp(config: c, store: store, clock: clock));
  return store;
}

Future<void> _open(WidgetTester tester, String entry) async {
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

TableMapStatus _statusOf(WidgetTester tester, String id) =>
    tester.widget<CrystalTable>(find.byKey(ValueKey('table-$id'))).status;

Future<void> _select(WidgetTester tester, String id) async {
  final table = find.byKey(ValueKey('table-$id'));
  await tester.ensureVisible(table);
  await tester.pumpAndSettle();
  await tester.tap(table);
  await tester.pumpAndSettle();
}

void main() {
  group('un solo mapa v7 para todas las perspectivas', () {
    testWidgets(
      'consulta pública y administración usan el mismo componente y el '
      'inicio solo ofrece esas dos entradas',
      (tester) async {
        await _pumpApp(tester);
        expect(
          find.byWidgetPredicate((w) => w is ButtonStyleButton),
          findsNWidgets(2),
        );

        await _open(tester, 'Mapa y disponibilidad');
        expect(find.byType(CrystalVenueMap), findsOneWidget);
        expect(find.byType(CrystalTable), findsNWidgets(22));
        await _back(tester);

        await _open(tester, 'Administrador (demostración)');
        expect(find.byType(AdminPage), findsOneWidget);
        expect(find.byType(CrystalVenueMap), findsOneWidget);
        expect(find.byType(CrystalTable), findsNWidgets(22));
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'la consulta pública no tiene acciones de administración ni titulares',
      (tester) async {
        final store = await _pumpApp(tester);
        await _open(tester, 'Mapa y disponibilidad');
        final reserved = store.book
            .forNight(_friday)
            .firstWhere((r) => r.status == ReservationStatus.confirmed);
        await _select(tester, reserved.tableId);
        await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
        await tester.pumpAndSettle();

        expect(find.byType(TableDetail), findsOneWidget);
        expect(find.byKey(const ValueKey('sheet-action')), findsNothing);
        expect(find.byType(GlassTabBar), findsNothing);
        expect(find.byKey(const ValueKey('create-direct')), findsNothing);
        expect(find.textContaining('Titular demo'), findsNothing);
        expect(find.textContaining(reserved.holder.phone!), findsNothing);
        final semantics = tester.ensureSemantics();
        expect(
          find.bySemanticsLabel(RegExp('Titular|${reserved.holder.phone}')),
          findsNothing,
        );
        semantics.dispose();
      },
    );

    testWidgets('Entradas, Pedidos y Más se anuncian en desarrollo y no '
        'navegan', (tester) async {
      await _pumpApp(tester);
      await _open(tester, 'Administrador (demostración)');
      final semantics = tester.ensureSemantics();
      for (final label in ['Entradas', 'Pedidos', 'Más']) {
        final tab = find.byKey(ValueKey('tab-$label'));
        // Si la barra no cabe, se desplaza: se trae la sección a la vista.
        await tester.ensureVisible(tab);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(tab),
          matchesSemantics(
            label: '$label, en desarrollo',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasSelectedState: true,
          ),
        );
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.byType(CrystalVenueMap), findsOneWidget);
      }
      expect(find.text(GlassTabBar.pendingNote), findsNWidgets(3));
      semantics.dispose();
    });
  });

  group('accesibilidad del mapa v7', () {
    for (final entry in [
      'Mapa y disponibilidad',
      'Administrador (demostración)',
    ]) {
      testWidgets(
        '$entry: áreas táctiles etiquetadas y contraste de texto',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await _pumpApp(tester);
          await _open(tester, entry);
          await _select(tester, 'M07');
          await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        },
        variant: TargetPlatformVariant.mobile(),
      );
    }

    testWidgets('consulta pública con texto al 200 % sin desbordes', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpApp(tester);
      tester.view.physicalSize = const Size(320, 568);
      await _open(tester, 'Mapa y disponibilidad');
      await _select(tester, 'VIP 1');
      await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('la ficha v7 ofrece la acción que corresponde al estado', () {
    testWidgets(
      'disponible: «Reservar» abre la reserva directa y el cambio se ve en '
      'mapa, lista y consulta pública',
      (tester) async {
        final store = await _pumpApp(tester);
        await _open(tester, 'Administrador (demostración)');
        final free = sagsaVenue.tables
            .firstWhere(
              (t) => !t.isVip && store.book.activeFor(_friday, t.id) == null,
            )
            .id;
        await _select(tester, free);
        expect(find.text('Reservar'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('sheet-action')));
        await tester.pumpAndSettle();
        expect(find.text('Reserva directa'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('field-name')),
          'Titular demo ficha',
        );
        await tester.enterText(find.byKey(const ValueKey('field-id')), '7');
        await tester.enterText(find.byKey(const ValueKey('field-phone')), '8');
        await tester.tap(find.byKey(const ValueKey('form-submit')));
        await tester.pumpAndSettle();

        final created = store.book.activeFor(_friday, free)!;
        expect(created.status, ReservationStatus.confirmed);
        expect(_statusOf(tester, free), TableMapStatus.reserved);
        // La ficha pasa a ofrecer ver la reserva.
        expect(find.text('Ver'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('tab-Reservas')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<AdminList>),
            matching: find.text('Reservas'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('reservation-${created.id}')),
          80,
          // La lista de la sección, no la fila de segmentos ni la cabecera.
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.textContaining('Titular demo ficha'), findsWidgets);

        await _back(tester);
        await _open(tester, 'Mapa y disponibilidad');
        expect(_statusOf(tester, free), TableMapStatus.reserved);
        expect(find.textContaining('Titular demo ficha'), findsNothing);
      },
    );

    testWidgets('VIP pendiente sembrada: «Ver pago» abre la reserva y se '
        'verifica el prepago', (tester) async {
      final store = await _pumpApp(tester);
      // La siembra ocurre al consultar la noche por primera vez.
      await _open(tester, 'Administrador (demostración)');
      final pending = store.book
          .forNight(_friday)
          .singleWhere((r) => r.status == ReservationStatus.pendingPayment);
      expect(_statusOf(tester, pending.tableId), TableMapStatus.pendingPayment);
      expect(
        find.bySemanticsLabel(RegExp('^Reservas, 1 por revisar')),
        findsOneWidget,
      );

      await _select(tester, pending.tableId);
      expect(find.text('Ver pago'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheet-action')));
      await tester.pumpAndSettle();
      expect(find.text('Reserva ${pending.id}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('action-confirm-prepayment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog-confirm')));
      await tester.pumpAndSettle();
      expect(store.book.byId(pending.id)!.status, ReservationStatus.confirmed);

      await _back(tester);
      expect(_statusOf(tester, pending.tableId), TableMapStatus.reserved);
    });

    test(
      'sin datos (error de consulta) la mesa queda «Sin información»',
      () async {
        final controller = VenueMapController(
          _FailingRepository(),
          venue: sagsaVenue,
          clock: fixedClock,
        );
        addTearDown(controller.dispose);
        await controller.start();
        expect(controller.availabilityStatus, LoadStatus.failed);
        expect(
          TableMapStatus.from(
            controller.availabilityOf('M01'),
            table: sagsaVenue.tableById('M01')!,
          ),
          TableMapStatus.unknown,
        );
      },
    );
  });

  group('configuración por local', () {
    testWidgets(
      'el mismo mapa dibuja un local con otras mesas sin mezclar datos',
      (tester) async {
        final store = await _pumpApp(tester, config: _otherConfig);
        await _open(tester, 'Mapa y disponibilidad');
        expect(find.byType(CrystalTable), findsNWidgets(3));
        for (final id in ['A1', 'A2', 'P1']) {
          expect(find.byKey(ValueKey('table-$id')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('table-M01')), findsNothing);
        expect(
          find.bySemanticsLabel('Plano de Local de prueba, 3 mesas'),
          findsOneWidget,
        );
        expect(
          store.book.forNight(_friday).map((r) => r.tableId).toSet(),
          everyElement(isIn(['A1', 'A2', 'P1'])),
        );
        expect(tester.takeException(), isNull);
      },
    );

    test('el libro de un local rechaza mesas de otro', () {
      final book = ReservationBook(venue: _otherVenue, clock: fixedClock);
      expect(
        () => book.createDirect(
          night: _friday,
          tableId: 'M01',
          holder: const ReservationHolder(name: 'X', idNumber: '1', phone: '1'),
        ),
        throwsA(
          isA<ReservationException>().having(
            (e) => e.error,
            'error',
            ReservationError.unknownTable,
          ),
        ),
      );
    });

    test(
      'las consultas indican su local y el mapa rechaza las de otro',
      () async {
        final store = DemoReservationStore(
          venue: _otherVenue,
          latency: Duration.zero,
          clock: fixedClock,
        );
        final data = await store.availabilityFor(_friday);
        expect(data.venueId, 'test-local');
        expect(
          (await store.adminView.availabilityFor(_friday)).venueId,
          'test-local',
        );

        final controller = VenueMapController(
          store,
          venue: sagsaVenue,
          clock: fixedClock,
        );
        addTearDown(controller.dispose);
        await controller.start();
        expect(controller.availabilityStatus, LoadStatus.failed);
        expect(controller.availabilityOf('A1'), isNull);
      },
    );
  });

  test(
    'cada noche sembrada tiene una VIP pendiente de pago para la demo',
    () async {
      final store = DemoReservationStore(
        venue: sagsaVenue,
        latency: Duration.zero,
        clock: fixedClock,
      );
      for (var day = 9; day <= 25; day++) {
        final night = Night(DateTime.utc(2026, 10, day));
        await store.availabilityFor(night);
        expect(
          store.book
              .forNight(night)
              .where((r) => r.status == ReservationStatus.pendingPayment),
          hasLength(1),
          reason: night.id,
        );
      }
    },
  );
}

class _FailingRepository implements NightAvailabilityRepository {
  @override
  Future<NightAvailability> availabilityFor(Night night) =>
      Future.error(Exception('sin conexión'));
}

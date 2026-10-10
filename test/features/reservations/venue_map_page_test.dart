import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/app/app_theme.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/reservation.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';
import 'package:rumbaap/features/reservations/presentation/table_detail.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/reservations/presentation/table_widget.dart';
import 'package:rumbaap/features/reservations/presentation/venue_map_page.dart';

import 'fakes.dart';

final _iosAndAndroid = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// Monta la app con reloj fijo (miércoles 7 de octubre de 2026, 3:00 p. m.
/// en el local) y, salvo que se pida lo contrario, con «reducir movimiento»
/// activado: la animación ambiental es infinita y pumpAndSettle no
/// terminaría nunca.
Future<void> _pumpApp(
  WidgetTester tester,
  NightAvailabilityRepository repository, {
  Clock clock = fixedClock,
  bool reduceMotion = true,
}) async {
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    repository is DemoReservationStore
        ? RumbaapApp(store: repository, clock: clock)
        : _MapOnlyApp(repository: repository, clock: clock),
  );
}

/// La app recibe el almacén único de reservas. Para controlar a mano las
/// respuestas de la consulta, el mapa se abre desde un inicio mínimo con la
/// misma entrada «Mapa y disponibilidad».
class _MapOnlyApp extends StatelessWidget {
  const _MapOnlyApp({required this.repository, required this.clock});

  final NightAvailabilityRepository repository;
  final Clock clock;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.build(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    VenueMapPage(repository: repository, clock: clock),
              ),
            ),
            child: const Text('Mapa y disponibilidad'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openMap(
  WidgetTester tester, {
  NightAvailabilityRepository? repository,
  Clock clock = fixedClock,
}) async {
  await _pumpApp(
    tester,
    repository ?? DemoReservationStore(latency: Duration.zero, clock: clock),
    clock: clock,
  );
  await tester.tap(find.text('Mapa y disponibilidad'));
  await tester.pumpAndSettle();
}

Finder _table(String id) => find.byKey(ValueKey('table-$id'));

TableMapStatus _statusOf(WidgetTester tester, String id) =>
    tester.widget<TableWidget>(_table(id)).status;

Finder _pickerRow(String id) => find.byKey(ValueKey('picker-$id'));

/// Abre «Elegir mesa» y toca la fila de [id], desplazando la lista como lo
/// haría la persona si la fila no está a la vista.
Future<void> _pickFromList(WidgetTester tester, String id) async {
  await tester.tap(find.text('Elegir mesa'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    _pickerRow(id),
    80,
    scrollable: find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(_pickerRow(id));
  await tester.pumpAndSettle();
}

/// Ejecuta la acción tap a través del árbol semántico, como lo haría un
/// lector de pantalla (TalkBack/VoiceOver), y no mediante un toque simulado.
Future<void> _semanticTap(WidgetTester tester, Finder finder) async {
  final node = tester.getSemantics(finder);
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: 'El nodo «${node.label}» debe publicar SemanticsAction.tap.',
  );
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

Map<String, TableMapStatus> _allStatuses(WidgetTester tester) => {
  for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
};

Finder _inDetail(String text) =>
    find.descendant(of: find.byType(TableDetail), matching: find.text(text));

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  // Un toque que no alcanza su objetivo indicaría un control tapado.
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets(
    'se abre desde el inicio con 22 mesas y datos de demostración',
    (tester) async {
      await _openMap(tester);

      expect(find.text('Datos de demostración'), findsOneWidget);
      expect(find.byType(TableWidget), findsNWidgets(22));
      for (final table in VenueTables.all) {
        expect(_table(table.id), findsOneWidget);
      }
      // Fin de semana en curso según el reloj fijo.
      for (final chip in ['Vie 9 oct', 'Sáb 10 oct', 'Dom 11 oct']) {
        expect(find.text(chip), findsOneWidget);
      }
      // Leyenda con texto para cada estado.
      for (final status in TableMapStatus.values) {
        expect(find.text(status.label), findsWidgets);
      }

      // Regresión: cerrar el mapa sin haber usado el zoom no lanza errores.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Mapa y disponibilidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: _iosAndAndroid,
  );

  testWidgets(
    'seleccionar mesa normal muestra su detalle público y se cierra',
    (tester) async {
      await _openMap(tester);

      await tester.tap(_table('M05'));
      await tester.pumpAndSettle();

      expect(_inDetail('Mesa M05'), findsOneWidget);
      expect(_inDetail('Mesa normal'), findsOneWidget);
      expect(_inDetail('Lado occidental'), findsOneWidget);
      expect(_inDetail('Viernes 9 de octubre'), findsOneWidget);
      expect(_inDetail('Por confirmar'), findsOneWidget);
      expect(_inDetail(_statusOf(tester, 'M05').label), findsOneWidget);
      expect(tester.widget<TableWidget>(_table('M05')).selected, isTrue);

      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      expect(find.byType(TableDetail), findsNothing);
      expect(tester.widget<TableWidget>(_table('M05')).selected, isFalse);
    },
    variant: _iosAndAndroid,
  );

  testWidgets('tocar otra vez la mesa seleccionada la deselecciona', (
    tester,
  ) async {
    await _openMap(tester);
    final before = _statusOf(tester, 'M12');

    await tester.tap(_table('M12'));
    await tester.pumpAndSettle();
    expect(find.byType(TableDetail), findsOneWidget);

    await tester.tap(_table('M12'));
    await tester.pumpAndSettle();
    expect(find.byType(TableDetail), findsNothing);
    expect(_statusOf(tester, 'M12'), before);
  });

  testWidgets(
    'el detalle VIP muestra capacidad y condiciones conocidas',
    (tester) async {
      await _openMap(tester);

      await tester.tap(_table('VIP 2'));
      await tester.pumpAndSettle();

      expect(_inDetail('VIP 2'), findsOneWidget);
      expect(_inDetail('Mesa VIP'), findsOneWidget);
      expect(_inDetail('Hasta 20 personas'), findsOneWidget);
      expect(
        _inDetail('Consumo prepagado de 2.000.000 COP por mesa.'),
        findsOneWidget,
      );
    },
    variant: _iosAndAndroid,
  );

  testWidgets('cambiar de noche limpia la selección y muestra sus estados', (
    tester,
  ) async {
    await _openMap(tester);
    final firstNight = {
      for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
    };

    await tester.tap(_table('M05'));
    await tester.pumpAndSettle();
    expect(find.byType(TableDetail), findsOneWidget);

    await tester.tap(find.text('Sáb 10 oct'));
    await tester.pumpAndSettle();

    expect(find.byType(TableDetail), findsNothing);
    final secondNight = {
      for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
    };
    expect(secondNight, isNot(equals(firstNight)));
    expect(secondNight.values, isNot(contains(TableMapStatus.unknown)));

    await tester.tap(find.text('Vie 9 oct'));
    await tester.pumpAndSettle();
    expect({
      for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
    }, firstNight);
  });

  testWidgets('mientras carga, ninguna mesa aparece como disponible', (
    tester,
  ) async {
    final repository = ControlledRepository();
    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mapa y disponibilidad'));
    // No se usa pumpAndSettle: el indicador de carga sigue animándose.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Consultando disponibilidad…'), findsOneWidget);
    for (final table in VenueTables.all) {
      expect(_statusOf(tester, table.id), TableMapStatus.unknown);
    }
  });

  testWidgets('si falla la consulta se informa y nada aparece disponible', (
    tester,
  ) async {
    final repository = ControlledRepository();
    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mapa y disponibilidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository.request(nightA).completeError(Exception('sin conexión'));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo consultar la disponibilidad de esta noche.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    for (final table in VenueTables.all) {
      expect(_statusOf(tester, table.id), TableMapStatus.unknown);
    }

    await tester.tap(_table('M03'));
    await tester.pumpAndSettle();
    expect(_inDetail('Sin información'), findsOneWidget);
  });

  testWidgets('una mesa sin dato se muestra sin información', (tester) async {
    final repository = ControlledRepository();
    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mapa y disponibilidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository
        .request(nightA)
        .complete(
          availability(nightA, {
            for (final t in VenueTables.all)
              if (t.id != 'M03') t.id: TableAvailability.available,
          }),
        );
    await tester.pumpAndSettle();

    expect(_statusOf(tester, 'M03'), TableMapStatus.unknown);
    expect(_statusOf(tester, 'M04'), TableMapStatus.available);
  });

  group('noches y fines de semana', () {
    testWidgets(
      'se navega a fines de semana futuros y se vuelve al actual',
      (tester) async {
        await _openMap(tester);
        final previous = find.byTooltip('Fin de semana anterior');
        final next = find.byTooltip('Fin de semana siguiente');
        expect(
          tester
              .widget<IconButton>(
                find.ancestor(
                  of: find.byIcon(Icons.chevron_left_rounded),
                  matching: find.byType(IconButton),
                ),
              )
              .onPressed,
          isNull,
        );

        await tester.tap(_table('M05'));
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();

        for (final chip in ['Vie 16 oct', 'Sáb 17 oct', 'Dom 18 oct']) {
          expect(find.text(chip).hitTestable(), findsOneWidget);
        }
        expect(find.text('Vie 9 oct'), findsNothing);
        expect(find.byType(TableDetail), findsNothing);
        expect(
          _allStatuses(tester).values,
          isNot(contains(TableMapStatus.unknown)),
        );

        await tester.tap(previous);
        await tester.pumpAndSettle();
        expect(find.text('Vie 9 oct'), findsOneWidget);
      },
      variant: _iosAndAndroid,
    );

    testWidgets('la noche en curso se marca y es la única con mesas ocupadas', (
      tester,
    ) async {
      // Viernes 9 de octubre, 11:00 p. m. en el local.
      DateTime fridayNight() => venueInstant(2026, 10, 9, 23);
      await _openMap(tester, clock: fridayNight);

      expect(find.text('Vie 9 oct · En curso'), findsOneWidget);
      expect(_allStatuses(tester).values, contains(TableMapStatus.occupied));

      await tester.tap(find.text('Sáb 10 oct'));
      await tester.pumpAndSettle();
      expect(
        _allStatuses(tester).values,
        isNot(contains(TableMapStatus.occupied)),
      );
    });

    testWidgets('las noches terminadas no se ofrecen', (tester) async {
      // Domingo 11 de octubre, 4:00 p. m.: viernes y sábado ya cerraron.
      await _openMap(tester, clock: () => venueInstant(2026, 10, 11, 16));
      expect(find.text('Vie 9 oct'), findsNothing);
      expect(find.text('Sáb 10 oct'), findsNothing);
      expect(find.text('Dom 11 oct'), findsOneWidget);
    });
  });

  group('paso del tiempo con la pantalla abierta', () {
    testWidgets(
      'al cruzar las 03:00 se retira la noche terminada y su ocupación',
      (tester) async {
        // Sábado 10, 2:50 a. m.: la noche del viernes sigue en curso.
        var now = venueInstant(2026, 10, 10, 2, 50);
        await _openMap(tester, clock: () => now);
        expect(find.text('Vie 9 oct · En curso'), findsOneWidget);
        expect(_allStatuses(tester).values, contains(TableMapStatus.occupied));

        // Pasan 10 minutos con la pantalla abierta, sin tocar nada.
        now = venueInstant(2026, 10, 10, 3);
        await tester.pump(const Duration(minutes: 10));
        await tester.pumpAndSettle();

        expect(find.textContaining('Vie 9 oct'), findsNothing);
        expect(find.text('Sáb 10 oct'), findsOneWidget);
        expect(
          _allStatuses(tester).values,
          isNot(contains(TableMapStatus.occupied)),
        );
      },
    );

    testWidgets('al volver del segundo plano se recalcula la noche en curso', (
      tester,
    ) async {
      // Viernes 9, 8:00 p. m.: aún no abre.
      var now = venueInstant(2026, 10, 9, 20);
      final store = DemoReservationStore(
        latency: Duration.zero,
        clock: () => now,
      );
      await _openMap(tester, repository: store, clock: () => now);
      expect(find.text('Vie 9 oct'), findsOneWidget);
      expect(
        _allStatuses(tester).values,
        isNot(contains(TableMapStatus.occupied)),
      );

      // La app pasa a segundo plano y vuelve a las 11:00 p. m.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      now = venueInstant(2026, 10, 9, 23);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();

      expect(find.text('Vie 9 oct · En curso'), findsOneWidget);
      // La apertura no convierte reservas en llegadas por sí sola.
      expect(
        _allStatuses(tester).values,
        isNot(contains(TableMapStatus.occupied)),
      );

      // Mientras la app está en segundo plano, alguien del personal registra
      // una llegada; al volver, el mapa la refleja.
      final reserved = store.book
          .forNight(Night(DateTime.utc(2026, 10, 9)))
          .firstWhere((r) => r.status == ReservationStatus.confirmed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      store.book.markArrival(reserved.id);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_statusOf(tester, reserved.tableId), TableMapStatus.occupied);
    });
  });

  group('reservas de demostración', () {
    testWidgets(
      'una mesa en proceso deja de mostrarse así al vencer, sin tocar nada',
      (tester) async {
        var now = fixedClock();
        final store = DemoReservationStore(
          latency: Duration.zero,
          clock: () => now,
        );
        await _openMap(tester, repository: store, clock: () => now);
        final inProcess = store.book
            .forNight(Night(DateTime.utc(2026, 10, 9)))
            .firstWhere((r) => r.status == ReservationStatus.inProcess);
        expect(_statusOf(tester, inProcess.tableId), TableMapStatus.pending);

        now = now.add(const Duration(minutes: 10));
        await tester.pump(const Duration(minutes: 10));
        await tester.pumpAndSettle();
        expect(_statusOf(tester, inProcess.tableId), TableMapStatus.available);
      },
    );

    testWidgets('salir y volver al mapa conserva reservas y cambios', (
      tester,
    ) async {
      final store = DemoReservationStore(
        latency: Duration.zero,
        clock: fixedClock,
      );
      await _openMap(tester, repository: store);
      final friday = Night(DateTime.utc(2026, 10, 9));
      final reserved = store.book
          .forNight(friday)
          .firstWhere((r) => r.status == ReservationStatus.confirmed);
      store.book.revoke(reserved.id);
      final free = VenueTables.all.firstWhere(
        (t) => store.book.activeFor(friday, t.id) == null,
      );
      store.book.createDirect(
        night: friday,
        tableId: free.id,
        holder: const ReservationHolder(
          name: 'Titular demo X',
          idNumber: '0',
          phone: '0',
        ),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mapa y disponibilidad'));
      await tester.pumpAndSettle();

      expect(_statusOf(tester, reserved.tableId), TableMapStatus.available);
      expect(_statusOf(tester, free.id), TableMapStatus.reserved);
    });
  });

  group('estado pendiente', () {
    testWidgets(
      'normal «En proceso» y VIP «Pendiente de pago», también al lector',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final repository = ControlledRepository();
        await _pumpApp(tester, repository);
        await tester.tap(find.text('Mapa y disponibilidad'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        repository
            .request(nightA)
            .complete(
              availability(nightA, {
                for (final t in VenueTables.all)
                  t.id: TableAvailability.available,
                'M03': TableAvailability.pending,
                'VIP 1': TableAvailability.pending,
              }),
            );
        await tester.pumpAndSettle();

        expect(_statusOf(tester, 'M03'), TableMapStatus.pending);
        expect(_statusOf(tester, 'VIP 1'), TableMapStatus.pendingPayment);
        expect(
          tester.getSemantics(_table('M03')).label,
          'Mesa M03, En proceso',
        );
        expect(
          tester.getSemantics(_table('VIP 1')).label,
          'VIP 1, Pendiente de pago',
        );

        await tester.tap(_table('VIP 1'));
        await tester.pumpAndSettle();
        expect(_inDetail('Pendiente de pago'), findsOneWidget);

        await tester.tap(find.text('Elegir mesa'));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Mesa M03, En proceso, Lado occidental'),
          findsOneWidget,
        );
        semantics.dispose();
      },
      variant: _iosAndAndroid,
    );
  });

  group('animación', () {
    testWidgets('el mapa se anima si no se pide reducir el movimiento', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        DemoReservationStore(latency: Duration.zero, clock: fixedClock),
        reduceMotion: false,
      );
      await tester.tap(find.text('Mapa y disponibilidad'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(TableWidget), findsNWidgets(22));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('la animación se pausa si otra pantalla tapa el mapa', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        DemoReservationStore(latency: Duration.zero, clock: fixedClock),
        reduceMotion: false,
      );
      await tester.tap(find.text('Mapa y disponibilidad'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Otra pantalla')),
            ),
          );
      // Si la animación del mapa siguiera corriendo, pumpAndSettle no
      // terminaría nunca.
      await tester.pumpAndSettle();
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('la animación se pausa con la app en segundo plano', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        DemoReservationStore(latency: Duration.zero, clock: fixedClock),
        reduceMotion: false,
      );
      await tester.tap(find.text('Mapa y disponibilidad'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('con «reducir movimiento» el mapa queda quieto', (
      tester,
    ) async {
      await _openMap(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('acción semántica tap', () {
    testWidgets(
      'mapa: selecciona y muestra el detalle; repetirla deselecciona',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openMap(tester);
        final before = _allStatuses(tester);

        for (final id in ['M05', 'VIP 1']) {
          final label =
              '${id.startsWith('VIP') ? id : 'Mesa $id'}, '
              '${_statusOf(tester, id).label}';
          expect(tester.getSemantics(_table(id)).label, label);

          await _semanticTap(tester, _table(id));
          expect(find.byType(TableDetail), findsOneWidget);
          expect(
            tester.widget<TableDetail>(find.byType(TableDetail)).table.id,
            id,
          );
          expect(tester.widget<TableWidget>(_table(id)).selected, isTrue);

          await _semanticTap(tester, _table(id));
          expect(find.byType(TableDetail), findsNothing);
          expect(tester.widget<TableWidget>(_table(id)).selected, isFalse);
        }

        expect(_allStatuses(tester), before);
        semantics.dispose();
      },
      variant: _iosAndAndroid,
    );

    testWidgets(
      'lista: selecciona, cierra la hoja y reelegir mantiene la selección',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openMap(tester);
        final before = _allStatuses(tester);

        for (final id in ['M01', 'VIP 2']) {
          await tester.tap(find.text('Elegir mesa'));
          await tester.pumpAndSettle();
          await _semanticTap(tester, _pickerRow(id));

          expect(find.byType(BottomSheet), findsNothing);
          expect(
            tester.widget<TableDetail>(find.byType(TableDetail)).table.id,
            id,
          );
          expect(tester.widget<TableWidget>(_table(id)).selected, isTrue);

          // Reelegirla desde la lista no la deselecciona.
          await tester.tap(find.text('Elegir mesa'));
          await tester.pumpAndSettle();
          await _semanticTap(tester, _pickerRow(id));
          expect(find.byType(BottomSheet), findsNothing);
          expect(
            tester.widget<TableDetail>(find.byType(TableDetail)).table.id,
            id,
          );
          expect(tester.widget<TableWidget>(_table(id)).selected, isTrue);
        }

        expect(_allStatuses(tester), before);
        semantics.dispose();
      },
      variant: _iosAndAndroid,
    );
  });

  group('elegir mesa desde la lista', () {
    for (final id in ['M05', 'VIP 1']) {
      testWidgets(
        '$id: mismo detalle y selección que el mapa, sin cambiar estados',
        (tester) async {
          await _openMap(tester);
          final before = {
            for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
          };

          // Desde el mapa.
          await tester.tap(_table(id));
          await tester.pumpAndSettle();
          final fromMap = tester.widget<TableDetail>(find.byType(TableDetail));
          await tester.tap(find.byTooltip('Cerrar detalle'));
          await tester.pumpAndSettle();

          // Desde la lista.
          await _pickFromList(tester, id);
          expect(find.byType(BottomSheet), findsNothing);
          final fromList = tester.widget<TableDetail>(find.byType(TableDetail));
          expect(fromList.table.id, fromMap.table.id);
          expect(fromList.status, fromMap.status);
          expect(fromList.nightLabel, fromMap.nightLabel);
          expect(tester.widget<TableWidget>(_table(id)).selected, isTrue);
          expect({
            for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
          }, before);
        },
        variant: _iosAndAndroid,
      );
    }

    testWidgets(
      'las filas son accesibles, de al menos 48 px y muestran el estado',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _openMap(tester);
        await tester.tap(find.text('Elegir mesa'));
        await tester.pumpAndSettle();

        final row = _pickerRow('VIP 2');
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        final status = _statusOf(tester, 'VIP 2').label;
        expect(
          find.bySemanticsLabel('VIP 2, $status, Zona VIP elevada · norte'),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(status)),
          findsOneWidget,
        );
        semantics.dispose();
      },
      variant: _iosAndAndroid,
    );

    testWidgets('elegir la mesa ya seleccionada no la deselecciona', (
      tester,
    ) async {
      await _openMap(tester);
      await tester.tap(_table('VIP 2'));
      await tester.pumpAndSettle();

      await _pickFromList(tester, 'VIP 2');
      expect(_inDetail('VIP 2'), findsOneWidget);
    });

    testWidgets(
      'cambiar de noche actualiza la lista y limpia la selección anterior',
      (tester) async {
        await _openMap(tester);
        await _pickFromList(tester, 'M05');
        expect(find.byType(TableDetail), findsOneWidget);

        await tester.tap(find.text('Sáb 10 oct'));
        await tester.pumpAndSettle();
        expect(find.byType(TableDetail), findsNothing);

        await tester.tap(find.text('Elegir mesa'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(
            of: sheet,
            matching: find.text('Sábado 10 de octubre'),
          ),
          findsOneWidget,
        );
        for (final id in ['VIP 1', 'VIP 2', 'M01', 'M02']) {
          final tile = tester.widget<ListTile>(_pickerRow(id));
          expect(tile.selected, isFalse);
          expect(
            find.descendant(
              of: _pickerRow(id),
              matching: find.text(_statusOf(tester, id).label),
            ),
            findsOneWidget,
          );
        }
      },
    );
  });

  group('tamaños de pantalla', () {
    const sizes = <String, Size>{
      'móvil pequeño vertical': Size(320, 568),
      'móvil pequeño horizontal': Size(568, 320),
      'ventana 800×600': Size(800, 600),
      'tableta vertical': Size(820, 1180),
      'tableta horizontal': Size(1180, 820),
    };

    for (final entry in sizes.entries) {
      testWidgets(
        '${entry.key}: mapa y detalle sin desbordamientos',
        (tester) async {
          _setSize(tester, entry.value);
          await _openMap(tester);
          expect(tester.takeException(), isNull);

          for (final id in ['VIP 1', 'M05']) {
            await tester.tap(_table(id));
            await tester.pumpAndSettle();
            expect(find.byType(TableDetail), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          // Con el detalle abierto, la segunda noche sigue a la vista y se
          // puede tocar sin desplazar nada.
          final saturday = find.text('Sáb 10 oct');
          expect(saturday.hitTestable(), findsOneWidget);
          final screen = Offset.zero & entry.value;
          expect(
            screen.intersect(tester.getRect(saturday)),
            tester.getRect(saturday),
          );
          await tester.tap(saturday);
          await tester.pumpAndSettle();
          expect(find.byType(TableDetail), findsNothing);

          await _pickFromList(tester, 'VIP 2');
          expect(_inDetail('VIP 2'), findsOneWidget);
          expect(find.text('Elegir mesa').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byTooltip('Acercar'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        variant: _iosAndAndroid,
      );
    }

    testWidgets(
      'en móvil vertical el detalle va abajo y en tableta al lado',
      (tester) async {
        _setSize(tester, const Size(360, 740));
        await _openMap(tester);
        await tester.tap(_table('VIP 1'));
        await tester.pumpAndSettle();
        final phone = tester.getRect(find.byType(TableDetail));
        expect(phone.top, greaterThan(740 / 2));

        tester.view.physicalSize = const Size(820, 1180);
        await tester.pumpAndSettle();
        final tablet = tester.getRect(find.byType(TableDetail));
        expect(tablet.left, greaterThan(820 / 2));
        expect(tablet.top, lessThan(1180 / 2));
      },
      variant: _iosAndAndroid,
    );
  });
}

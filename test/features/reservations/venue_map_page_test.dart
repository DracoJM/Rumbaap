import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_night_availability_repository.dart';
import 'package:rumbaap/features/reservations/domain/night_availability.dart';
import 'package:rumbaap/features/reservations/domain/venue_table.dart';
import 'package:rumbaap/features/reservations/presentation/table_detail.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/reservations/presentation/table_widget.dart';

import 'fakes.dart';

final _iosAndAndroid = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

Future<void> _openMap(
  WidgetTester tester, {
  NightAvailabilityRepository? repository,
}) async {
  await tester.pumpWidget(
    RumbaapApp(
      availabilityRepository:
          repository ?? DemoNightAvailabilityRepository(latency: Duration.zero),
    ),
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
      expect(find.text('Viernes 16 de octubre'), findsOneWidget);
      expect(find.text('Sábado 17 de octubre'), findsOneWidget);
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
      expect(_inDetail('Viernes 16 de octubre'), findsOneWidget);
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

    await tester.tap(find.text('Sábado 17 de octubre'));
    await tester.pumpAndSettle();

    expect(find.byType(TableDetail), findsNothing);
    final secondNight = {
      for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
    };
    expect(secondNight, isNot(equals(firstNight)));
    expect(secondNight.values, isNot(contains(TableMapStatus.unknown)));

    await tester.tap(find.text('Viernes 16 de octubre'));
    await tester.pumpAndSettle();
    expect({
      for (final t in VenueTables.all) t.id: _statusOf(tester, t.id),
    }, firstNight);
  });

  testWidgets('mientras carga, ninguna mesa aparece como disponible', (
    tester,
  ) async {
    final repository = ControlledRepository();
    await tester.pumpWidget(RumbaapApp(availabilityRepository: repository));
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
    await tester.pumpWidget(RumbaapApp(availabilityRepository: repository));
    await tester.tap(find.text('Mapa y disponibilidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository.request('a').completeError(Exception('sin conexión'));
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
    await tester.pumpWidget(RumbaapApp(availabilityRepository: repository));
    await tester.tap(find.text('Mapa y disponibilidad'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    repository
        .request('a')
        .complete(
          availability('a', {
            for (final t in VenueTables.all)
              if (t.id != 'M03') t.id: TableAvailability.available,
          }),
        );
    await tester.pumpAndSettle();

    expect(_statusOf(tester, 'M03'), TableMapStatus.unknown);
    expect(_statusOf(tester, 'M04'), TableMapStatus.available);
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

        await tester.tap(find.text('Sábado 17 de octubre'));
        await tester.pumpAndSettle();
        expect(find.byType(TableDetail), findsNothing);

        await tester.tap(find.text('Elegir mesa'));
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        expect(
          find.descendant(
            of: sheet,
            matching: find.text('Sábado 17 de octubre'),
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
          final saturday = find.text('Sábado 17 de octubre');
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

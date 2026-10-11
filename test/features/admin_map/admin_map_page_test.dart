import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/app/app_theme.dart';
import 'package:rumbaap/features/admin_map/presentation/admin_map_page.dart';
import 'package:rumbaap/features/admin_map/presentation/crystal_table.dart';
import 'package:rumbaap/features/admin_map/presentation/crystal_venue_map.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';

final _iosAndAndroid = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

/// Sin animaciones del sistema la pantalla no programa fotogramas, así que
/// los tests pueden usar pumpAndSettle.
Future<void> _pumpMap(
  WidgetTester tester, {
  bool reduceMotion = true,
  Size? size = const Size(390, 844),
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.build(), home: const AdminMapPage()),
  );
  if (reduceMotion) await tester.pumpAndSettle();
}

Finder _table(String id) => find.byKey(ValueKey('crystal-table-$id'));
Finder _chip(String status) => find.byKey(ValueKey('status-chip-$status'));
Finder get _sheet => find.byKey(const ValueKey('table-sheet'));

double _opacityOf(WidgetTester tester, String id) => tester
    .widget<AnimatedOpacity>(
      find.descendant(of: _table(id), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void main() {
  testWidgets(
    'se abre desde el inicio y muestra la noche sin título de pantalla',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        RumbaapApp(store: DemoReservationStore(latency: Duration.zero)),
      );
      await tester.tap(find.text('Mapa del administrador'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Dom 11 oct'), findsOneWidget);
      expect(find.text('Noche desde las 22:00'), findsOneWidget);
      expect(find.byType(CrystalTable), findsNWidgets(22));
      expect(tester.takeException(), isNull);
    },
    variant: _iosAndAndroid,
  );

  testWidgets('las flechas cambian de noche y sus estados', (tester) async {
    await _pumpMap(tester);
    expect(find.text('3 Reservadas'), findsOneWidget);

    await tester.tap(find.byTooltip('Noche siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Lun 12 oct'), findsOneWidget);
    expect(find.text('Dom 11 oct'), findsNothing);

    await tester.tap(find.byTooltip('Noche anterior'));
    await tester.tap(find.byTooltip('Noche anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Sáb 10 oct'), findsOneWidget);
  }, variant: _iosAndAndroid);

  testWidgets('deslizar sobre la fecha cambia de noche', (tester) async {
    await _pumpMap(tester);

    await tester.drag(find.text('Dom 11 oct'), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Lun 12 oct'), findsOneWidget);

    await tester.drag(find.text('Lun 12 oct'), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Dom 11 oct'), findsOneWidget);

    // Un roce corto no cambia la noche.
    await tester.drag(find.text('Dom 11 oct'), const Offset(-12, 0));
    await tester.pumpAndSettle();
    expect(find.text('Dom 11 oct'), findsOneWidget);
  }, variant: _iosAndAndroid);

  testWidgets(
    'el resumen cuenta por estado y tocarlo filtra el mapa',
    (tester) async {
      await _pumpMap(tester);
      for (final label in [
        '15 Disponibles',
        '3 Reservadas',
        '1 En proceso',
        '1 Ocupadas',
        '1 Pago VIP',
        '1 Sin info',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(_chip('reserved'));
      await tester.pumpAndSettle();
      for (final id in ['M06', 'M13', 'VIP 2']) {
        expect(_opacityOf(tester, id), 1, reason: id);
      }
      for (final id in ['M07', 'M16', 'VIP 1']) {
        expect(_opacityOf(tester, id), 0.2, reason: id);
      }

      await tester.tap(_chip('reserved'));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'M07'), 1);
    },
    variant: _iosAndAndroid,
  );

  testWidgets('tocar una mesa la muestra en la ficha', (tester) async {
    await _pumpMap(tester);
    final sheet = find.descendant(of: _sheet, matching: find.byType(Text));
    expect(
      tester.widgetList<Text>(sheet).map((t) => t.data),
      containsAll(['Mesa M07', 'Disponible', 'Reservar']),
    );

    await tester.tap(_table('VIP 1'));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Text>(sheet).map((t) => t.data),
      containsAll(['Mesa VIP 1', 'Pago VIP pendiente', 'Ver pago']),
    );

    // Las franjas táctiles llegan hasta el borde de la vecina.
    final m02 = tester.getRect(_table('M02'));
    await tester.tapAt(Offset(m02.left + 2, m02.top + 1));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _sheet, matching: find.text('Mesa M02')),
      findsOneWidget,
    );
  }, variant: _iosAndAndroid);

  testWidgets(
    'la ficha se abre con la descripción y la acción completa',
    (tester) async {
      await _pumpMap(tester);
      expect(find.textContaining('Costado occidental'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Costado occidental'), findsOneWidget);
      expect(find.text('Crear reserva'), findsOneWidget);
      expect(find.text('Reservar'), findsNothing);

      await tester.tap(_table('M13'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Costado oriental'), findsOneWidget);
      expect(find.text('Ver reserva'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Costado oriental'), findsNothing);
      expect(find.text('Ver'), findsOneWidget);
    },
    variant: _iosAndAndroid,
  );

  testWidgets(
    'la barra inferior muestra las cinco secciones con Mapa activa',
    (tester) async {
      await _pumpMap(tester);
      for (final label in ['Mapa', 'Reservas', 'Entradas', 'Pedidos', 'Más']) {
        expect(find.text(label), findsOneWidget);
      }
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mapa')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          label: 'Mapa',
        ),
      );
      handle.dispose();
    },
    variant: _iosAndAndroid,
  );

  group('accesibilidad', () {
    testWidgets('cada mesa es un botón con su estado y acción tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpMap(tester);
      expect(
        tester.getSemantics(_table('M07')),
        matchesSemantics(
          label: 'Mesa M07, Disponible',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      final node = tester.getSemantics(_table('VIP 1'));
      expect(node.label, 'Mesa VIP 1, Pago VIP pendiente');
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.text('Mesa VIP 1'), findsOneWidget);
      handle.dispose();
    }, variant: _iosAndAndroid);

    testWidgets('los chips informan si el filtro está activo', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpMap(tester);
      expect(
        tester.getSemantics(_chip('reserved')),
        matchesSemantics(
          label: '3 Reservadas',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(_chip('reserved'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_chip('reserved')),
        matchesSemantics(
          label: '3 Reservadas',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('cumple las guías de área táctil y etiquetas', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpMap(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }, variant: _iosAndAndroid);
  });

  group('animaciones', () {
    testWidgets('con «reducir movimiento» no hay fotogramas pendientes', (
      tester,
    ) async {
      await _pumpMap(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('sin esa opción las luces se mueven y no reconstruyen mesas', (
      tester,
    ) async {
      await _pumpMap(tester, reduceMotion: false);
      await tester.pump(const Duration(milliseconds: 500));
      final before = tester.widget(_table('M07'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isTrue);
      // El reloj repinta capas, no reconstruye el árbol de mesas.
      expect(identical(tester.widget(_table('M07')), before), isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('tamaños de pantalla', () {
    const sizes = <String, Size>{
      'móvil pequeño': Size(320, 568),
      'móvil pequeño horizontal': Size(568, 320),
      'móvil grande': Size(430, 932),
      'tableta': Size(820, 1180),
    };
    for (final entry in sizes.entries) {
      testWidgets('sin errores de layout en ${entry.key}', (tester) async {
        await _pumpMap(tester, size: entry.value);
        await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, variant: _iosAndAndroid);
    }

    testWidgets('texto ampliado (200 %) en teléfono sin errores', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpMap(tester, size: const Size(360, 780));
      await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el final del plano puede quedar por encima de la ficha', (
      tester,
    ) async {
      await _pumpMap(tester, size: const Size(360, 640));
      await tester.drag(find.byType(CrystalTable).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      final mapBottom = tester.getRect(find.byType(CrystalVenueMap)).bottom;
      final sheetTop = tester.getRect(_sheet).top;
      expect(mapBottom, lessThan(sheetTop));
    });
  });
}

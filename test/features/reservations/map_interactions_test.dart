import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/reservations/presentation/admin/admin_page.dart';
import 'package:rumbaap/features/reservations/presentation/admin/direct_reservation_page.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_table.dart';
import 'package:rumbaap/features/reservations/presentation/map/crystal_venue_map.dart';
import 'package:rumbaap/features/reservations/presentation/map/glass_tab_bar.dart';
import 'package:rumbaap/features/reservations/presentation/map/table_sheet.dart';
import 'package:rumbaap/features/reservations/presentation/table_presentation.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';

import 'fakes.dart';

final _friday = Night(DateTime.utc(2026, 10, 9));

Future<DemoReservationStore> _open(
  WidgetTester tester,
  String entry, {
  Size size = const Size(411, 914),
  bool reduceMotion = true,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final store = DemoReservationStore(
    venue: sagsaVenue,
    latency: Duration.zero,
    clock: fixedClock,
  );
  await tester.pumpWidget(
    RumbaapApp(config: sagsaConfig, store: store, clock: fixedClock),
  );
  await tester.tap(find.text(entry));
  if (reduceMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
  return store;
}

const _admin = 'Administrador (demostración)';
const _public = 'Mapa y disponibilidad';

Finder _table(String id) => find.byKey(ValueKey('table-$id'));
Finder _tab(String label) => find.byKey(ValueKey('tab-$label'));

/// Selecciona la mesa con «Elegir mesa»: con texto grande o en pantallas
/// pequeñas la mesa puede quedar bajo la ficha o la barra.
Future<void> _pick(WidgetTester tester, String id) async {
  await tester.tap(find.byTooltip('Elegir mesa'));
  await tester.pumpAndSettle();
  final list = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(Scrollable),
  );
  final row = find.byKey(ValueKey('picker-$id'));
  // Desplaza la lista como lo haría la persona hasta que la fila se pueda
  // tocar. Con texto al 200 % y la fuente de los tests las filas son muy
  // altas, de ahí el margen de pasos.
  for (var i = 0; i < 120 && row.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(list.first, const Offset(0, -150));
    await tester.pumpAndSettle();
  }
  // ignore: avoid_print
  await tester.tap(row.hitTestable());
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsNothing, reason: 'fila $id tocada');
}

TableMapStatus _statusOf(WidgetTester tester, String id) =>
    tester.widget<CrystalTable>(_table(id)).status;

double _opacityOf(WidgetTester tester, String id) => tester
    .widget<AnimatedOpacity>(
      find.descendant(of: _table(id), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

/// Activa [finder] por el árbol semántico, como TalkBack o VoiceOver, sin
/// tocar la pantalla ni llamar al callback.
Future<void> _semanticTap(WidgetTester tester, Finder finder) async {
  final node = tester.getSemantics(finder);
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: '«${node.label}» debe publicar SemanticsAction.tap',
  );
  // El nodo puede no traer su dueño (p. ej. dentro de una barra que se
  // desplaza); la acción se envía al árbol semántico de la vista.
  final owner =
      node.owner ?? tester.binding.renderViews.first.owner!.semanticsOwner!;
  owner.performAction(node.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

void main() {
  group('navegador de noche', () {
    testWidgets('deslizar sobre la fecha cambia de noche y no retrocede '
        'antes de la primera', (tester) async {
      await _open(tester, _admin);
      expect(find.text('Vie 9 oct'), findsOneWidget);

      // Hacia atrás desde la primera noche: no hay noche anterior (M3).
      await tester.drag(find.text('Vie 9 oct'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Vie 9 oct'), findsOneWidget);

      await tester.drag(find.text('Vie 9 oct'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Sáb 10 oct'), findsOneWidget);

      // Un roce corto no cambia la noche.
      await tester.drag(find.text('Sáb 10 oct'), const Offset(-12, 0));
      await tester.pumpAndSettle();
      expect(find.text('Sáb 10 oct'), findsOneWidget);

      await tester.drag(find.text('Sáb 10 oct'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(find.text('Vie 9 oct'), findsOneWidget);
    }, variant: TargetPlatformVariant.mobile());
  });

  group('filtro del resumen por estado', () {
    testWidgets('el chip atenúa las demás mesas, anuncia su estado y se '
        'quita; no cambia disponibilidad ni reservas', (tester) async {
      final semantics = tester.ensureSemantics();
      final store = await _open(tester, _admin);
      final reservationsBefore = store.book.forNight(_friday).length;
      final statusesBefore = {
        for (final t in sagsaVenue.tables) t.id: _statusOf(tester, t.id),
      };
      final reserved = statusesBefore.entries
          .where((e) => e.value == TableMapStatus.reserved)
          .map((e) => e.key)
          .toSet();
      final chip = find.byKey(const ValueKey('status-chip-reserved'));
      // El chip está más allá del borde de la fila: se desplaza a la vista,
      // como lo haría el lector de pantalla.
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(chip),
        matchesSemantics(
          label: '${reserved.length} Reservadas',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      await _semanticTap(tester, chip);
      expect(
        tester.getSemantics(chip).getSemanticsData().flagsCollection.isToggled,
        isTrue,
      );
      for (final t in sagsaVenue.tables) {
        expect(
          _opacityOf(tester, t.id),
          reserved.contains(t.id) ? 1 : 0.2,
          reason: t.id,
        );
      }

      await _semanticTap(tester, chip);
      expect(
        tester.getSemantics(chip).getSemanticsData().flagsCollection.isToggled,
        isFalse,
      );
      for (final t in sagsaVenue.tables) {
        expect(_opacityOf(tester, t.id), 1, reason: t.id);
      }
      expect({
        for (final t in sagsaVenue.tables) t.id: _statusOf(tester, t.id),
      }, statusesBefore);
      expect(store.book.forNight(_friday), hasLength(reservationsBefore));
      semantics.dispose();
    }, variant: TargetPlatformVariant.mobile());
  });

  group('animación', () {
    testWidgets('las luces avanzan sin reconstruir las mesas en cada tick', (
      tester,
    ) async {
      await _open(tester, _public, reduceMotion: false);
      final tables = {
        for (final t in sagsaVenue.tables) t.id: tester.widget(_table(t.id)),
      };
      final map = tester.widget(find.byType(CrystalVenueMap));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.hasScheduledFrame, isTrue);
      // El reloj solo repinta las capas de luces: ni el mapa ni las mesas
      // se vuelven a construir.
      expect(
        identical(tester.widget(find.byType(CrystalVenueMap)), map),
        isTrue,
      );
      for (final t in sagsaVenue.tables) {
        expect(
          identical(tester.widget(_table(t.id)), tables[t.id]),
          isTrue,
          reason: t.id,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('móvil con la ficha abierta', () {
    for (final entry in [_public, _admin]) {
      testWidgets('$entry: el final del plano sigue siendo alcanzable', (
        tester,
      ) async {
        await _open(tester, entry, size: const Size(360, 640));
        await _pick(tester, 'M07');
        await tester.tap(find.bySemanticsLabel('Ver detalle de la mesa'));
        await tester.pumpAndSettle();

        // Se arrastra por la franja visible del plano, entre la cabecera y la
        // ficha.
        final viewport = tester.getRect(
          find
              .ancestor(
                of: find.byType(CrystalVenueMap),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final sheetTopBefore = tester.getRect(find.byType(TableSheet)).top;
        // Queda una franja del plano a la vista por la que desplazarse. En
        // los tests la fuente de prueba ensancha las etiquetas y la barra
        // ocupa más filas que en el teléfono, así que la franja es mínima.
        expect(sheetTopBefore - viewport.top, greaterThan(32));
        await tester.dragFrom(
          Offset(viewport.center.dx, viewport.top + 20),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        final mapBottom = tester.getRect(find.byType(CrystalVenueMap)).bottom;
        final sheetTop = tester.getRect(find.byType(TableSheet)).top;
        expect(mapBottom, lessThanOrEqualTo(sheetTop));
      });
    }
  });

  group('activación desde el árbol semántico (administración)', () {
    testWidgets(
      'activar una VIP la selecciona y muestra su ficha',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, _admin);
        await _semanticTap(tester, _table('VIP 2'));
        expect(tester.widget<CrystalTable>(_table('VIP 2')).selected, isTrue);
        expect(
          find.descendant(
            of: find.byType(TableSheet),
            matching: find.text('VIP 2'),
          ),
          findsOneWidget,
        );
        semantics.dispose();
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets(
      'la acción de la ficha abre la reserva directa',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final store = await _open(tester, _admin);
        final free = sagsaVenue.tables.firstWhere(
          (t) => !t.isVip && store.book.activeFor(_friday, t.id) == null,
        );
        await _semanticTap(tester, _table(free.id));
        // La acción corta «Reservar» se anuncia con su texto completo.
        await _semanticTap(tester, find.bySemanticsLabel('Crear reserva'));
        expect(find.byType(DirectReservationPage), findsOneWidget);
        semantics.dispose();
      },
      variant: TargetPlatformVariant.mobile(),
    );

    testWidgets('Mapa y Reservas se activan; las secciones en desarrollo no '
        'publican acción', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _admin);

      await _semanticTap(tester, _tab('Reservas'));
      expect(find.byType(SegmentedButton<AdminList>), findsOneWidget);
      expect(find.byType(CrystalVenueMap), findsNothing);

      await _semanticTap(tester, _tab('Mapa'));
      expect(find.byType(CrystalVenueMap), findsOneWidget);

      for (final label in ['Entradas', 'Pedidos', 'Más']) {
        final data = tester.getSemantics(_tab(label)).getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse, reason: label);
        expect(data.flagsCollection.isEnabled, isFalse, reason: label);
      }
      semantics.dispose();
    }, variant: TargetPlatformVariant.mobile());
  });

  group('texto ampliado (200 %) en la barra inferior', () {
    const sizes = {
      'móvil pequeño': Size(320, 568),
      'móvil pequeño horizontal': Size(568, 320),
    };
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name: las etiquetas usan la escala del sistema, se leen '
          'enteras y sus acciones siguen disponibles', (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, _admin, size: size, textScale: 2);
        await _pick(tester, 'M07');
        expect(tester.takeException(), isNull);

        final screen = Offset.zero & size;
        for (final label in [
          'Mapa',
          'Reservas',
          'Entradas',
          'Pedidos',
          'Más',
        ]) {
          final text = find.descendant(
            of: _tab(label),
            matching: find.text(label),
          );
          final paragraph = tester.renderObject<RenderParagraph>(text);
          // Escala efectiva: la del sistema, sin límite propio.
          expect(paragraph.textScaler.scale(11), 22, reason: label);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          // Etiquetas de una palabra: se leen en una sola línea, sin
          // partirse.
          expect(
            paragraph.size.height,
            lessThanOrEqualTo(
              paragraph.getMinIntrinsicHeight(double.infinity) + 0.5,
            ),
            reason: label,
          );
          // Se puede llegar a ella: está en pantalla, si hace falta tras
          // desplazar.
          await tester.ensureVisible(_tab(label));
          await tester.pumpAndSettle();
          expect(
            screen.intersect(tester.getRect(_tab(label))),
            tester.getRect(_tab(label)),
            reason: label,
          );
        }
        expect(tester.takeException(), isNull);

        await _semanticTap(tester, _tab('Reservas'));
        expect(find.byType(SegmentedButton<AdminList>), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    test('con la escala normal las cinco secciones van en una fila', () {
      const tabs = [
        GlassTab(icon: Icons.map, label: 'Mapa', onTap: _noop),
        GlassTab(icon: Icons.map, label: 'Reservas', onTap: _noop),
        GlassTab(icon: Icons.map, label: 'Entradas'),
        GlassTab(icon: Icons.map, label: 'Pedidos'),
        GlassTab(icon: Icons.map, label: 'Más'),
      ];
      // La fuente de los tests mide cada letra como un cuadrado del tamaño
      // del texto: «Reservas» a 11 ocupa 88. Los anchos son en esa medida.
      expect(
        GlassTabBar.columnsFor(tabs, width: 500, scaler: TextScaler.noScaling),
        5,
      );
      final big = GlassTabBar.columnsFor(
        tabs,
        width: 500,
        scaler: const TextScaler.linear(2),
      );
      expect(big, inInclusiveRange(1, 4));
    });
  });

  group('tamaños táctiles efectivos en móvil pequeño (320 × 568)', () {
    testWidgets('los controles miden al menos 48 × 48 y las filas de «Elegir '
        'mesa» al menos 48 de alto', (tester) async {
      await _open(tester, _admin, size: const Size(320, 568));
      await _pick(tester, 'M07');

      void atLeast48(Finder f, String what) {
        final s = tester.getSize(f);
        expect(s.width, greaterThanOrEqualTo(48), reason: '$what ancho');
        expect(s.height, greaterThanOrEqualTo(48), reason: '$what alto');
      }

      atLeast48(find.byType(BackButton), 'Volver');
      Finder button(String tooltip) => find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      atLeast48(button('Elegir mesa'), 'Elegir mesa');
      atLeast48(button('Noche anterior'), 'Noche anterior');
      atLeast48(button('Noche siguiente'), 'Noche siguiente');
      atLeast48(find.byKey(const ValueKey('status-chip-available')), 'chip');
      atLeast48(find.byKey(const ValueKey('sheet-action')), 'acción ficha');
      atLeast48(find.bySemanticsLabel('Ver detalle de la mesa'), 'abrir ficha');
      for (final label in ['Mapa', 'Reservas']) {
        atLeast48(_tab(label), label);
      }

      await tester.tap(find.byTooltip('Elegir mesa'));
      await tester.pumpAndSettle();
      for (final id in ['VIP 1', 'M01']) {
        final row = find.byKey(ValueKey('picker-$id'));
        expect(
          tester.getSize(row).height,
          greaterThanOrEqualTo(48),
          reason: id,
        );
        expect(
          tester.getSize(row).width,
          greaterThanOrEqualTo(280),
          reason: id,
        );
      }
    });

    testWidgets('las franjas del plano son las aprobadas a escala: menores de '
        '48 en este ancho (límite documentado)', (tester) async {
      await _open(tester, _public, size: const Size(320, 568));
      final mapWidth = tester.getSize(find.byType(CrystalVenueMap)).width;
      final scale = mapWidth / sagsaConfig.layout.size.width;
      // Tamaño en pantalla, con la escala del plano aplicada.
      final normal = tester.getRect(_table('M07')).size;
      expect(normal.width, closeTo(58 * scale, 0.5));
      expect(normal.height, closeTo(44 * scale, 0.5));
      expect(normal.height, lessThan(48));
      // La alternativa accesible sigue a la vista.
      expect(find.byTooltip('Elegir mesa').hitTestable(), findsOneWidget);
    });
  });
}

void _noop() {}

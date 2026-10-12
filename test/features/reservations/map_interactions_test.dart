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
import 'package:rumbaap/features/bar/presentation/bar_views.dart';
import 'package:rumbaap/features/tickets/presentation/admin_tickets.dart';
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
  await tester.ensureVisible(find.text(entry));
  await tester.pumpAndSettle();
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
const _public = 'Cliente demo A';

Finder _table(String id) => find.byKey(ValueKey('table-$id'));
Finder _tab(String label) => find.byKey(ValueKey('tab-$label'));

/// Selecciona la mesa con «Buscar mesa»: con texto grande o en pantallas
/// pequeñas la mesa puede quedar bajo la ficha o la barra.
Future<void> _pick(WidgetTester tester, String id) async {
  await tester.tap(find.byTooltip('Buscar mesa'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('table-search')), id);
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
    // Desde el borde inferior de la lista: el centro puede caer sobre el
    // campo de búsqueda, que no desplaza.
    await tester.dragFrom(
      Offset(
        tester.getCenter(list.first).dx,
        tester
                .getBottomLeft(list.first)
                .dy
                .clamp(0, tester.view.physicalSize.height) -
            24,
      ),
      const Offset(0, -150),
    );
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

    testWidgets('Mapa, Reservas, Entradas y Pedidos se activan desde el '
        'árbol semántico y se vuelve al mapa', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _admin);

      await _semanticTap(tester, _tab('Reservas'));
      expect(find.byType(SegmentedButton<AdminList>), findsOneWidget);
      expect(find.byType(CrystalVenueMap), findsNothing);

      await _semanticTap(tester, _tab('Mapa'));
      expect(find.byType(CrystalVenueMap), findsOneWidget);

      // Entradas (P25, sin terminar) navega a su sección por el árbol
      // semántico y se puede volver al mapa.
      await _semanticTap(tester, _tab('Entradas'));
      expect(find.byType(AdminTickets), findsOneWidget);
      expect(find.byType(CrystalVenueMap), findsNothing);
      await _semanticTap(tester, _tab('Mapa'));
      expect(find.byType(CrystalVenueMap), findsOneWidget);

      await _semanticTap(tester, _tab('Pedidos'));
      expect(find.byType(BarCorrections), findsOneWidget);
      expect(find.byType(CrystalVenueMap), findsNothing);
      await _semanticTap(tester, _tab('Mapa'));
      expect(find.byType(CrystalVenueMap), findsOneWidget);
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

        // La ficha cerrada no recorta la mesa, su estado ni su acción.
        final sheetTexts = find.descendant(
          of: find.byType(TableSheet),
          matching: find.byType(RichText),
        );
        expect(sheetTexts, findsWidgets);
        for (final element in sheetTexts.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final text = paragraph.text.toPlainText();
          // Se omiten los iconos (un glifo de la fuente de iconos) y el número
          // dentro del disco, que no escalan a propósito.
          final isIcon = text.runes.length == 1 && text.runes.first >= 0xE000;
          if (text.trim().isEmpty || isIcon || text == '07') continue;
          expect(paragraph.textScaler.scale(10), 20, reason: text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        }

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

        // Las secciones que no caben quedan en una fila que se desplaza:
        // la barra no crece en alto sobre el plano.
        expect(find.byKey(const ValueKey('tab-bar-scroll')), findsOneWidget);
        final tabTops = {
          for (final label in [
            'Mapa',
            'Reservas',
            'Entradas',
            'Pedidos',
            'Más',
          ])
            tester.getRect(_tab(label)).top.roundToDouble(),
        };
        expect(tabTops, hasLength(1));

        await _semanticTap(tester, _tab('Reservas'));
        expect(find.byType(SegmentedButton<AdminList>), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    test('el ancho de cada sección crece con la escala de texto', () {
      const tabs = [
        GlassTab(icon: Icons.map, label: 'Mapa', onTap: _noop),
        GlassTab(icon: Icons.map, label: 'Reservas', onTap: _noop),
        GlassTab(icon: Icons.map, label: 'Entradas'),
        GlassTab(icon: Icons.map, label: 'Pedidos'),
        GlassTab(icon: Icons.map, label: 'Más'),
      ];
      final normal = GlassTabBar.itemWidthFor(
        tabs,
        scaler: TextScaler.noScaling,
      );
      final big = GlassTabBar.itemWidthFor(
        tabs,
        scaler: const TextScaler.linear(2),
      );
      // La palabra más ancha cabe entera: el ancho crece con el texto en
      // lugar de partirla o reducirla.
      expect(big, greaterThan(normal * 1.8));
    });
  });

  group('«Buscar mesa» (P24)', () {
    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byKey(const ValueKey('table-search')), q);
      await tester.pumpAndSettle();
    }

    String count(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('table-search-count')))
        .data!;

    Finder rows() => find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('picker-'),
    );

    testWidgets('no repite el plano como listado: sin texto no hay filas; '
        'busca por número, zona y estado', (tester) async {
      await _open(tester, _admin);
      await tester.tap(find.byTooltip('Buscar mesa'));
      await tester.pumpAndSettle();
      expect(rows(), findsNothing);
      expect(count(tester), 'Escribe para buscar una mesa del plano.');

      await search(tester, '07');
      expect(find.byKey(const ValueKey('picker-M07')), findsOneWidget);
      expect(rows(), findsOneWidget);

      await search(tester, 'vip');
      expect(find.byKey(const ValueKey('picker-VIP 1')), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-VIP 2')), findsOneWidget);

      await search(tester, 'zzz');
      expect(rows(), findsNothing);
      expect(count(tester), 'Ninguna mesa coincide.');
    }, variant: TargetPlatformVariant.mobile());

    testWidgets('con un solo resultado, la tecla de buscar del teclado la '
        'selecciona y abre su ficha', (tester) async {
      await _open(tester, _admin);
      await tester.tap(find.byTooltip('Buscar mesa'));
      await tester.pumpAndSettle();
      await search(tester, 'M07');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.widget<CrystalTable>(_table('M07')).selected, isTrue);
    }, variant: TargetPlatformVariant.mobile());
  });

  testWidgets('«Buscar mesa» con texto al 200 %: el estado de cada fila se '
      'lee entero dentro de la fila', (tester) async {
    await _open(tester, _admin, size: const Size(320, 568), textScale: 2);
    await tester.tap(find.byTooltip('Buscar mesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('table-search')), 'VIP 1');
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('picker-VIP 1'));
    final status = find.descendant(
      of: row,
      matching: find.text(TableMapStatus.pendingPayment.label),
    );
    final paragraph = tester.renderObject<RenderParagraph>(status);
    expect(paragraph.textScaler.scale(10), 20);
    expect(paragraph.didExceedMaxLines, isFalse);
    final rowRect = tester.getRect(row);
    final statusRect = tester.getRect(status);
    expect(rowRect.intersect(statusRect), statusRect);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el final de las listas de Reservas queda por encima de la '
      'barra', (tester) async {
    await _open(tester, _admin, size: const Size(360, 640));
    await tester.tap(_tab('Reservas'));
    await tester.pumpAndSettle();
    final segment = find.descendant(
      of: find.byType(SegmentedButton<AdminList>),
      matching: find.text('Actividad'),
    );
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
    final last = find.textContaining('no es un registro de auditoría');
    final list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    // Hasta el final de la lista.
    await tester.drag(list, const Offset(0, -20000));
    await tester.pumpAndSettle();
    final barTop = tester.getRect(find.byType(GlassTabBar)).top;
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(barTop));
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
      atLeast48(button('Buscar mesa'), 'Buscar mesa');
      atLeast48(button('Noche anterior'), 'Noche anterior');
      atLeast48(button('Noche siguiente'), 'Noche siguiente');
      atLeast48(find.byKey(const ValueKey('status-chip-available')), 'chip');
      atLeast48(find.byKey(const ValueKey('sheet-action')), 'acción ficha');
      atLeast48(find.bySemanticsLabel('Ver detalle de la mesa'), 'abrir ficha');
      for (final label in ['Mapa', 'Reservas']) {
        atLeast48(_tab(label), label);
      }

      await tester.tap(find.byTooltip('Buscar mesa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('table-search')), '1');
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
      expect(find.byTooltip('Buscar mesa').hitTestable(), findsOneWidget);
    });
  });
}

void _noop() {}

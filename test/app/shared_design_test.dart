import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/bar/data/demo_bar_store.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';
import 'package:rumbaap/features/reservations/domain/night_schedule.dart';
import 'package:rumbaap/features/tickets/data/demo_ticket_store.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_config.dart';
import 'package:rumbaap/features/venues/sagsa/sagsa_venue.dart';
import 'package:rumbaap/theme/app_background.dart';

import '../features/reservations/fakes.dart';

/// Viernes 9 de octubre de 2026, 10:00 p. m.: noche en curso.
final _tonight = venueInstant(2026, 10, 9, 22);
final _friday = Night(DateTime.utc(2026, 10, 9));

void main() {
  late DemoTicketStore tickets;
  late DemoBarStore bar;

  /// App completa en 320 dp con el texto al 200 %: el caso más exigente.
  Future<void> pumpNarrow(
    WidgetTester tester, {
    double width = 320,
    double scale = 2,
  }) async {
    // Más alta que ancha para no activar la disposición horizontal.
    tester.view.physicalSize = Size(width, width > 568 ? 1000 : 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final reservations = DemoReservationStore(
      venue: sagsaVenue,
      latency: Duration.zero,
      clock: () => _tonight,
    );
    tickets = DemoTicketStore(
      venueId: sagsaVenue.id,
      venueTag: sagsaConfig.ticketTag,
      clock: () => _tonight,
      latency: Duration.zero,
    );
    bar = DemoBarStore(
      venue: sagsaVenue,
      menu: sagsaConfig.menu,
      clock: () => _tonight,
    );
    await tester.pumpWidget(
      RumbaapApp(
        config: sagsaConfig,
        store: reservations,
        tickets: tickets,
        bar: bar,
        clock: () => _tonight,
      ),
    );
    await tester.runAsync(() => reservations.availabilityFor(_friday));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
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
        const Offset(0, -200),
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
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await tapKey(tester, 'identity-$id');
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await reveal(tester, f);
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'selector de perfiles: fondo lineal sin discos, perfiles legibles y '
    'tocables en 320 dp con texto al 200 %',
    (tester) async {
      await pumpNarrow(tester);
      final background = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient = (background.decoration as BoxDecoration).gradient;
      expect(gradient, isA<LinearGradient>());
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('CLIENTE'), findsNothing);
      await tapKey(tester, 'identity-cliente-a');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'promotor: formulario de venta con nombre, teléfono y cédula en 320 dp '
    'al 200 %, y su detalle sin desbordes',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'promotor-1');
      await tapKey(tester, 'tab-Entradas');
      await type(tester, 'ticket-holder', 'Comprador demo');
      await type(tester, 'ticket-phone', '3001112233');
      await type(tester, 'ticket-id-number', '1020304050');
      await tapKey(tester, 'ticket-buy');
      expect(tester.takeException(), isNull);
      final p = tickets.purchasesBy('promotor-1').single;
      expect(p.buyerPhone, '3001112233');
      await reveal(tester, find.text('1020304050'));
      expect(find.text('1020304050'), findsOneWidget);
      await tapKey(tester, 'purchase-pay');
      await tapKey(tester, 'dialog-confirm');
      expect(find.byKey(const ValueKey('promoter-undelivered')), findsOne);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Barra: cliente sin cuenta, producto y confirmación en 320 dp al 200 %',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'barra-1');
      await tapKey(tester, 'bar-add-agua');
      final noAccount = find.text('Cliente sin cuenta');
      await reveal(tester, noAccount);
      await tester.ensureVisible(noAccount);
      await tester.pumpAndSettle();
      await tester.tap(noAccount);
      await tester.pumpAndSettle();
      await type(tester, 'bar-guest-name', 'Ana');
      await tapKey(tester, 'bar-paid');
      await tapKey(tester, 'bar-register');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapKey(tester, 'dialog-confirm');
      expect(bar.book.sales.single.customer!.name, 'Ana');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'barra de navegación del cliente: «Reservas» en una línea con nombre '
    'accesible «Mis reservas», y todas las secciones tocables en 320 dp al '
    '200 %',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'cliente-a');
      expect(find.text('Reservas'), findsOneWidget);
      expect(find.text('Mis reservas'), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Mis reservas'),
        findsOneWidget,
        reason: 'el lector de pantalla sigue anunciando el nombre completo',
      );
      semantics.dispose();
      for (final tab in ['Mis reservas', 'Entradas', 'Menú', 'Más', 'Mapa']) {
        await tapKey(tester, 'tab-$tab');
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'barra de navegación: los iconos y las etiquetas quedan alineados entre '
    'secciones aunque no quepan en una fila',
    (tester) async {
      await pumpNarrow(tester, width: 393, scale: 1);
      await enter(tester, 'cliente-a');
      final tops = [
        for (final tab in ['Mapa', 'Mis reservas', 'Entradas', 'Menú', 'Más'])
          tester.getTopLeft(find.byKey(ValueKey('tab-$tab'))).dy,
      ];
      expect(tops.toSet().length, 1);
      final label = tester.getTopLeft(find.text('Reservas')).dy;
      expect(label, tester.getTopLeft(find.text('Entradas')).dy);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'promotor: el título de la tarjeta no se pisa con la etiqueta «Noche» ni '
    'con texto al 200 %',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'promotor-1');
      await tapKey(tester, 'tab-Entradas');
      final title = tester.getRect(find.text('Entrada general'));
      final label = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('ticket-night')),
          matching: find.text('Noche'),
        ),
      );
      expect(title.overlaps(label), isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Más: la identidad va en una tarjeta y «Cambiar identidad» es la acción '
    'secundaria',
    (tester) async {
      await pumpNarrow(tester, width: 393, scale: 1);
      await enter(tester, 'cliente-a');
      await tapKey(tester, 'tab-Más');
      expect(find.byKey(const ValueKey('session-identity')), findsOneWidget);
      expect(find.text('Cliente demo A'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is OutlinedButton && w.key == const ValueKey('switch-identity'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'switch-identity');
      expect(find.byKey(const ValueKey('identity-cliente-a')), findsOneWidget);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Admin: el selector de listas ocupa el ancho disponible si cabe y se '
    'desplaza, sin reducir el texto, a 320 dp al 200 %; conserva la selección',
    (tester) async {
      // Con Ahem (cuadrados de 1 em, mucho más ancho que Roboto) 590 dp es el
      // ancho mínimo, por debajo del salto a la disposición horizontal, en el
      // que el selector cabe: solo sirve para ejercitar esa rama; no
      // representa ni 320 ni 393 dp con Roboto.
      await pumpNarrow(tester, width: 590, scale: 1);
      await enter(tester, 'admin-1');
      await tapKey(tester, 'tab-Reservas');
      final selector = find.byKey(const ValueKey('admin-list-selector'));
      expect(tester.getSize(selector).width, closeTo(590 - 32, 1));
      await tester.tap(find.text('Actividad'));
      await tester.pumpAndSettle();
      final button = tester.widget<SegmentedButton<dynamic>>(selector);
      expect(button.selected.single.toString(), contains('activity'));

      await pumpNarrow(tester);
      await enter(tester, 'admin-1');
      await tapKey(tester, 'tab-Reservas');
      expect(find.text('Pendientes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'barra de navegación a 320 dp al 200 %: la sección seleccionada se revela '
    'entera al pasar del mapa a Más y el desplazamiento manual se respeta',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'cliente-a');
      final bar = find.byKey(const ValueKey('tab-bar-scroll'));
      final more = find.byKey(const ValueKey('tab-Más'));
      expect(bar, findsOneWidget);
      // Al entrar, «Mapa» (seleccionada) está entera a la vista.
      Rect viewport() => tester.getRect(bar);
      bool inside(Rect r) =>
          r.left >= viewport().left - 0.5 && r.right <= viewport().right + 0.5;
      expect(
        inside(tester.getRect(find.byKey(const ValueKey('tab-Mapa')))),
        true,
      );

      // Se desplaza a mano hasta el final y se vuelve un poco atrás: «Más»
      // queda cortada por el borde, como en la captura nativa del defecto.
      await tester.drag(bar, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      await tester.drag(bar, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(inside(tester.getRect(more)), isFalse);
      final visibleX = viewport().right - 8;
      await tester.tapAt(Offset(visibleX, tester.getCenter(more).dy));
      await tester.pumpAndSettle();
      expect(find.text('Sesión de demostración'), findsOneWidget);
      expect(
        inside(tester.getRect(more)),
        isTrue,
        reason: 'la sección activa debe quedar entera a la vista',
      );

      // Sin cambio de selección, el desplazamiento manual no se pisa.
      await tester.drag(bar, const Offset(80, 0));
      await tester.pumpAndSettle();
      final after = tester.getRect(more).left;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getRect(more).left, after);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Admin → Actividad a 320 dp al 200 %: la etiqueta «Buscar» cabe y los '
    'criterios de búsqueda se leen en la ayuda',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'admin-1');
      await tapKey(tester, 'tab-Reservas');
      // A esta escala el selector se desplaza: «Actividad» se alcanza así.
      await tester.ensureVisible(find.text('Actividad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actividad'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('activity-search'));
      await reveal(tester, search);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      final label = find.descendant(of: search, matching: find.text('Buscar'));
      expect(label, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('activity-search')),
          matching: find.text('Por mesa, ID de reserva o titular'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Personal → Llegadas a 320 dp al 200 %: la etiqueta «Buscar» cabe y los '
    'criterios de búsqueda se leen en la ayuda',
    (tester) async {
      await pumpNarrow(tester);
      await enter(tester, 'personal-1');
      final search = find.byKey(const ValueKey('staff-search'));
      await reveal(tester, search);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      final label = find.descendant(of: search, matching: find.text('Buscar'));
      expect(label, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
      expect(
        find.descendant(
          of: search,
          matching: find.text('Por mesa, titular o ID de reserva'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );
}

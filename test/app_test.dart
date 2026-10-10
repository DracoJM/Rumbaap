import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumbaap/app/app.dart';
import 'package:rumbaap/features/reservations/data/demo_reservation_store.dart';

import 'features/reservations/fakes.dart';

void main() {
  Widget app() => RumbaapApp(
    availabilityRepository: DemoReservationStore(
      latency: Duration.zero,
      clock: fixedClock,
    ),
    clock: fixedClock,
  );

  testWidgets(
    'la app arranca en la pantalla inicial de Rumbaap',
    (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Rumbaap'), findsOneWidget);
      expect(find.text('Mapa y disponibilidad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  const sizes = <String, Size>{
    'móvil pequeño': Size(320, 568),
    'móvil pequeño horizontal': Size(568, 320),
    'tableta': Size(820, 1180),
  };

  for (final entry in sizes.entries) {
    testWidgets(
      'la pantalla inicial se muestra sin errores en ${entry.key}',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app());

        expect(find.text('Rumbaap'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.mobile(),
    );
  }
}

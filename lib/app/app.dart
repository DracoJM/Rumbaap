import 'package:flutter/material.dart';

import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import 'app_theme.dart';
import 'home_page.dart';

class RumbaapApp extends StatelessWidget {
  const RumbaapApp({super.key, required this.store, this.clock = systemClock});

  /// Fuente única de reservas de la ejecución: la leen la consulta pública y
  /// la vista del administrador.
  final DemoReservationStore store;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rumbaap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: HomePage(store: store, clock: clock),
    );
  }
}

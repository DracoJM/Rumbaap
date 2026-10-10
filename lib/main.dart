import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/reservations/data/demo_reservation_store.dart';

void main() {
  // Almacén de demostración único por ejecución, hasta que exista una fuente
  // de datos compartida.
  runApp(RumbaapApp(availabilityRepository: DemoReservationStore()));
}

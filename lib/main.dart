import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/reservations/data/demo_night_availability_repository.dart';

void main() {
  // Adaptador de demostración hasta que exista una fuente de datos compartida.
  runApp(RumbaapApp(availabilityRepository: DemoNightAvailabilityRepository()));
}

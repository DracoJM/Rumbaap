import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/reservations/domain/night_schedule.dart';
import 'features/venues/sagsa/sagsa_config.dart';

/// Hora del local SIMULADA solo para recorridos de prueba, p. ej.
/// `--dart-define=RUMBAAP_DEMO_NOW=2026-10-11T22:00` (hora de Colombia).
/// Sin ese valor la app usa el reloj real. Nunca cambia el reloj del equipo
/// ni las reglas de horario: solo el instante de partida, que luego avanza
/// al ritmo real. La app muestra «Hora simulada» mientras está activa.
const _demoNow = String.fromEnvironment('RUMBAAP_DEMO_NOW');

void main() {
  // Sagsa es hoy el único local configurado. La app crea un almacén de
  // demostración único por ejecución, hasta que exista una fuente de datos
  // compartida.
  final start = _demoNow.isEmpty ? null : DateTime.tryParse('${_demoNow}Z');
  Clock clock = systemClock;
  if (start != null) {
    final real = DateTime.now();
    final venueStart = start.subtract(VenueTime.utcOffset);
    clock = () => venueStart.add(DateTime.now().difference(real));
  }
  runApp(
    RumbaapApp(config: sagsaConfig, clock: clock, simulatedTime: start != null),
  );
}

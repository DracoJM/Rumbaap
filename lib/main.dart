import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/venues/sagsa/sagsa_config.dart';

void main() {
  // Sagsa es hoy el único local configurado. La app crea un almacén de
  // demostración único por ejecución, hasta que exista una fuente de datos
  // compartida.
  runApp(RumbaapApp(config: sagsaConfig));
}

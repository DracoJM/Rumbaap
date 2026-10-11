import '../../../theme/venues/sagsa.dart';
import '../../reservations/domain/venue_table.dart';
import '../venue_config.dart';
import 'sagsa_layout.dart';
import 'sagsa_venue.dart';

/// Configuración de Sagsa, el local de demostración disponible hoy.
///
/// Las condiciones vienen de las instrucciones del equipo
/// (`docs/business-rules/reservas-y-noches.md`); no se aplican a otros
/// locales.
final sagsaConfig = VenueConfig(
  venue: sagsaVenue,
  theme: sagsaTheme,
  layout: SagsaLayout.layout,
  terms: const {
    TableKind.regular: TableTerms(
      capacity: 'Por confirmar',
      conditions: [
        'Reserva sin costo ni prepago.',
        'Consumo de referencia de 400.000 COP; el personal valida la '
            'tolerancia.',
        'Confirmación automática al completar la reserva.',
      ],
    ),
    TableKind.vip: TableTerms(
      capacity: 'Hasta 20 personas',
      conditions: [
        'Consumo prepagado de 2.000.000 COP por mesa.',
        'Las dos mesas VIP juntas: hasta 40 personas y 4.000.000 COP; '
            'siguen siendo dos mesas.',
      ],
    ),
  },
);

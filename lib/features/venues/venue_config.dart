import 'package:flutter/widgets.dart';

import '../../theme/venue_theme.dart';
import '../reservations/domain/venue_table.dart';
import '../reservations/presentation/map/crystal_layout.dart';
import '../tickets/domain/ticket.dart';

/// Todo lo que la app necesita saber de un local para mostrarlo: identidad,
/// mesas y zonas ([venue]), tema, distribución del mapa y condiciones
/// conocidas de sus mesas. Cada local tiene su configuración en
/// `lib/features/venues/<local>/`; las pantallas no contienen datos de
/// ningún local.
class VenueConfig {
  VenueConfig({
    required this.venue,
    required this.theme,
    required this.layout,
    required this.terms,
    this.ticketProducts = const [],
    this.ticketTag = 'XX',
    this.capacity,
  }) {
    assert(
      venue.tables.every((t) => layout.placementOf(t.id) != null),
      'Toda mesa de ${venue.id} necesita posición en el mapa',
    );
    assert(
      venue.tables.every((t) => terms.containsKey(t.kind)),
      'Toda mesa de ${venue.id} necesita condiciones para su tipo',
    );
  }

  final Venue venue;
  final VenueTheme theme;
  final CrystalLayout layout;

  /// Condiciones confirmadas por el local para cada tipo de mesa.
  final Map<TableKind, TableTerms> terms;

  TableTerms termsOf(VenueTable table) => terms[table.kind]!;

  /// Entradas a la venta en la demo. Nombres y precios son de
  /// DEMOSTRACIÓN, no política del local.
  final List<TicketProduct> ticketProducts;

  /// Prefijo de 2 letras de las credenciales de entrada del local.
  final String ticketTag;

  /// Aforo del local, configurable por local. `null`: no configurado
  /// (`NOT DECIDED`). La ocupación física no se deduce de las entradas.
  final int? capacity;
}

/// Capacidad y condiciones de un tipo de mesa, tal como las confirmó el
/// local. Son textos del local, no reglas generales de Rumbaap.
class TableTerms {
  const TableTerms({required this.capacity, required this.conditions});

  final String capacity;
  final List<String> conditions;
}

/// Hace disponible la configuración del local a toda la interfaz.
class VenueScope extends InheritedWidget {
  const VenueScope({super.key, required this.config, required super.child});

  final VenueConfig config;

  static VenueConfig of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VenueScope>();
    assert(scope != null, 'Falta un VenueScope encima de este widget');
    return scope!.config;
  }

  /// Lectura sin suscribirse, válida también en `initState`: la
  /// configuración de un local no cambia durante la vida de una pantalla.
  static VenueConfig read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<VenueScope>();
    assert(scope != null, 'Falta un VenueScope encima de este widget');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(VenueScope old) => old.config != config;
}

import 'package:flutter/material.dart';

import '../../theme/night_neutrals.dart';
import '../../theme/venue_theme.dart';
import 'demo_identities.dart';

/// Sección «Más» de cada perspectiva: quién está en la sesión ficticia y
/// cómo cambiar de identidad.
class SessionPanel extends StatelessWidget {
  const SessionPanel({
    super.key,
    required this.identity,
    this.extras = const [],
  });

  final DemoIdentity identity;

  /// Contenido propio del perfil, antes de «Cambiar identidad» (por
  /// ejemplo, «Mi QR» del cliente).
  final List<Widget> extras;

  /// Vuelve a la entrada y descarta toda la pila de esta sesión (pantallas,
  /// formularios y titulares visibles). Las reservas siguen en el almacén.
  static void switchIdentity(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenueTheme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Sesión de demostración',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NightNeutrals.white,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.badge_outlined, color: venue.vip),
          title: Text(
            identity.name,
            style: const TextStyle(color: NightNeutrals.white),
          ),
          subtitle: Text(
            identity.profile.label,
            style: TextStyle(color: NightNeutrals.glass(0.7)),
          ),
        ),
        Text(
          'Identidad ficticia, sin contraseña ni autenticación real.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: NightNeutrals.glass(0.7),
          ),
        ),
        for (final w in extras) ...[const SizedBox(height: 12), w],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('switch-identity'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => switchIdentity(context),
          icon: const Icon(Icons.switch_account_outlined),
          label: const Text('Cambiar identidad'),
        ),
      ],
    );
  }
}

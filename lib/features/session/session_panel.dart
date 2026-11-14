import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

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
          style: theme.textTheme.titleMedium?.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: 12),
        // La identidad y su aviso van juntos en una sola tarjeta: el nombre
        // es lo principal y el aviso queda como texto de apoyo.
        Card(
          key: const ValueKey('session-identity'),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_outlined, color: venue.vip),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            identity.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            identity.profile.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Identidad ficticia, sin contraseña ni autenticación real.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final w in extras) ...[const SizedBox(height: 12), w],
        const SizedBox(height: 24),
        // Acción secundaria: cambiar de identidad no es la tarea principal.
        OutlinedButton.icon(
          key: const ValueKey('switch-identity'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => switchIdentity(context),
          icon: const Icon(Icons.switch_account_outlined),
          label: const Text('Cambiar identidad'),
        ),
      ],
    );
  }
}

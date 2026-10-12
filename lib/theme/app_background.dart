import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import 'venue_theme.dart';

/// Fondo común de las pantallas: grafito frío con un gradiente LINEAL muy
/// tenue (más claro arriba, con un velo mínimo del color del local). Sin
/// discos, brillos ni animación, para que el contenido y el cristal de la
/// navegación mantengan el contraste.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final venue = VenueTheme.of(context);
    final top = Color.alphaBlend(
      venue.primary.withValues(alpha: 0.04),
      AppColors.surface,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, venue.background],
          stops: const [0, 0.6],
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

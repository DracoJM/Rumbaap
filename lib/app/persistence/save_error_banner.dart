import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'demo_persistence.dart';

/// Aviso fijo cuando el guardado local falla: los cambios siguen en
/// memoria, pero se perderían al cerrar la app. Ofrece reintentar.
class SaveErrorBanner extends StatelessWidget {
  const SaveErrorBanner({
    super.key,
    required this.persistence,
    required this.child,
  });

  final DemoPersistence persistence;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: persistence,
      builder: (context, _) {
        if (persistence.error == null) return child;
        return Column(
          children: [
            Expanded(child: child),
            Material(
              key: const ValueKey('save-error'),
              color: AppColors.danger.withValues(alpha: 0.95),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'No se pudieron guardar los últimos cambios de la '
                          'demo. Siguen en pantalla; se perderían al cerrar.',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('save-retry'),
                        onPressed: persistence.retry,
                        child: const Text(
                          'Reintentar',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

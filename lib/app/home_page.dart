import 'package:flutter/material.dart';

import '../features/admin_map/presentation/admin_map_page.dart';
import '../features/reservations/data/demo_reservation_store.dart';
import '../features/reservations/domain/night_schedule.dart';
import '../features/reservations/presentation/admin/admin_page.dart';
import '../features/reservations/presentation/venue_map_page.dart';
import 'app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, this.clock = systemClock});

  final DemoReservationStore store;
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rumbaap',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: buttonStyle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VenueMapPage(
                          repository: store,
                          changes: store,
                          clock: clock,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Mapa y disponibilidad'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: buttonStyle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdminPage(store: store, clock: clock),
                      ),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Administrador (demostración)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminMapPage(),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Mapa del administrador'),
                  ),
                  const SizedBox(height: 24),
                  const _DemoNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Demostración: datos ficticios guardados solo en este '
              'teléfono mientras la app está abierta; se pierden al '
              'cerrarla. El acceso de administrador no tiene autenticación '
              'real.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

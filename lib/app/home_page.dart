import 'package:flutter/material.dart';

import '../features/reservations/domain/night_availability.dart';
import '../features/reservations/presentation/venue_map_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.availabilityRepository});

  final NightAvailabilityRepository availabilityRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rumbaap',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          VenueMapPage(repository: availabilityRepository),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mapa y disponibilidad'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../features/reservations/domain/night_availability.dart';
import 'app_theme.dart';
import 'home_page.dart';

class RumbaapApp extends StatelessWidget {
  const RumbaapApp({super.key, required this.availabilityRepository});

  final NightAvailabilityRepository availabilityRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rumbaap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: HomePage(availabilityRepository: availabilityRepository),
    );
  }
}

import 'package:flutter/material.dart';

import 'home_page.dart';

class RumbaapApp extends StatelessWidget {
  const RumbaapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Rumbaap',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

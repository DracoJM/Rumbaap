import 'package:flutter/material.dart';

import '../../../theme/night_neutrals.dart';
import 'glass.dart';

/// Barra inferior de cristal propuesta en la maqueta. Por ahora solo «Mapa»
/// tiene pantalla; las demás secciones no navegan.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key});

  static const _items = [
    (Icons.map_outlined, 'Mapa'),
    (Icons.event_available_outlined, 'Reservas'),
    (Icons.confirmation_number_outlined, 'Entradas'),
    (Icons.local_bar_outlined, 'Pedidos'),
    (Icons.more_horiz_rounded, 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    // El texto crece hasta un 130 %: con más, cinco etiquetas no caben.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: GlassPanel(
        radius: 32,
        blur: 20,
        saturation: 1.6,
        tint: const [0.1, 0.1],
        borderAlpha: 0.16,
        highlightAlpha: 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            children: [
              for (final (index, item) in _items.indexed)
                Expanded(
                  child: _TabItem(
                    icon: item.$1,
                    label: item.$2,
                    selected: index == 0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? NightNeutrals.white : NightNeutrals.glass(0.6);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        decoration: selected
            ? BoxDecoration(
                color: NightNeutrals.glass(0.16),
                borderRadius: BorderRadius.circular(24),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: ink),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

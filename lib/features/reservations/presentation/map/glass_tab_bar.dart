import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/venue_theme.dart';
import 'glass.dart';

/// Sección de la barra inferior. Sin [onTap] se muestra como pendiente de
/// desarrollo: atenuada, sin acción y anunciada así al lector de pantalla.
class GlassTab {
  const GlassTab({
    required this.icon,
    required this.label,
    this.selected = false,
    this.badge = 0,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// Aviso numérico, por ejemplo pagos VIP por verificar; 0 = ninguno.
  final int badge;
  final VoidCallback? onTap;
}

/// Barra inferior de cristal de la maqueta v7.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.tabs});

  /// Texto bajo las secciones todavía sin pantalla.
  static const pendingNote = 'En desarrollo';

  final List<GlassTab> tabs;

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
              for (final tab in tabs)
                Expanded(
                  child: _TabItem(key: ValueKey('tab-${tab.label}'), tab: tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({super.key, required this.tab});

  final GlassTab tab;

  @override
  Widget build(BuildContext context) {
    final enabled = tab.onTap != null;
    final ink = tab.selected
        ? NightNeutrals.white
        : NightNeutrals.glass(enabled ? 0.65 : 0.32);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: tab.selected,
      label: enabled
          ? (tab.badge > 0
                ? '${tab.label}, ${tab.badge} por revisar'
                : tab.label)
          : '${tab.label}, ${GlassTabBar.pendingNote.toLowerCase()}',
      excludeSemantics: true,
      onTap: tab.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tab.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          decoration: tab.selected
              ? BoxDecoration(
                  color: NightNeutrals.glass(0.16),
                  borderRadius: BorderRadius.circular(24),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge.count(
                count: tab.badge,
                isLabelVisible: tab.badge > 0,
                backgroundColor: VenueTheme.of(context).vip,
                textColor: NightNeutrals.vipCtaInk,
                child: Icon(tab.icon, size: 22, color: ink),
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
              ),
              if (!enabled)
                Text(
                  GlassTabBar.pendingNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, color: ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

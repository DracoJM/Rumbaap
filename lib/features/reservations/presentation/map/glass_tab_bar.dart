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

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const _noteStyle = TextStyle(fontSize: 8.5);

  /// Relleno horizontal de cada sección, a cada lado.
  static const _itemPadding = 4.0;

  @override
  Widget build(BuildContext context) {
    // Respeta el tamaño de texto del sistema: si las secciones no caben en
    // una fila a esa escala, la fila se desplaza en horizontal en lugar de
    // reducir el texto, ocultar etiquetas o crecer en alto sobre el plano.
    final scaler = MediaQuery.textScalerOf(context);
    return GlassPanel(
      radius: 28,
      blur: 20,
      saturation: 1.6,
      tint: const [0.1, 0.1],
      borderAlpha: 0.16,
      highlightAlpha: 0.35,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget item(GlassTab tab) =>
                _TabItem(key: ValueKey('tab-${tab.label}'), tab: tab);
            final itemWidth = itemWidthFor(tabs, scaler: scaler);
            if (itemWidth * tabs.length <= constraints.maxWidth) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final tab in tabs) Expanded(child: item(tab))],
              );
            }
            return SingleChildScrollView(
              key: const ValueKey('tab-bar-scroll'),
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tab in tabs)
                    SizedBox(width: itemWidth, child: item(tab)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ancho de cada sección para que ninguna palabra de sus textos se parta
  /// a la escala de texto efectiva.
  static double itemWidthFor(
    List<GlassTab> tabs, {
    required TextScaler scaler,
  }) {
    var widest = 0.0;
    void measure(String text, TextStyle style) {
      for (final word in text.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
    }

    for (final tab in tabs) {
      measure(tab.label, _labelStyle);
      if (tab.onTap == null) measure(pendingNote, _noteStyle);
    }
    return widest + 2 * _itemPadding + 2;
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
          padding: const EdgeInsets.symmetric(
            horizontal: GlassTabBar._itemPadding,
            vertical: 5,
          ),
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
              // Sin cortar el texto: las palabras caben enteras (ver
              // columnsFor) y la etiqueta puede ocupar dos líneas.
              Text(
                tab.label,
                textAlign: TextAlign.center,
                style: GlassTabBar._labelStyle.copyWith(color: ink),
              ),
              if (!enabled)
                Text(
                  GlassTabBar.pendingNote,
                  textAlign: TextAlign.center,
                  style: GlassTabBar._noteStyle.copyWith(color: ink),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

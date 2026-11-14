import 'package:flutter/material.dart';

import '../../../../theme/night_neutrals.dart';
import '../../../../theme/status_colors.dart';
import '../../../../theme/venue_theme.dart';
import '../../domain/venue_table.dart';
import '../table_presentation.dart';
import 'glass.dart';

/// Acción principal de la ficha, con su texto corto (ficha cerrada) y largo
/// (ficha abierta). [onPressed] `null` la muestra desactivada.
class SheetAction {
  const SheetAction({
    required this.label,
    required this.shortLabel,
    required this.onPressed,
    this.vip = false,
  });

  final String label;
  final String shortLabel;
  final VoidCallback? onPressed;

  /// Estilo dorado de las mesas VIP.
  final bool vip;
}

/// Ficha flotante de cristal de la mesa seleccionada, común a todas las
/// perspectivas. Cerrada muestra la mesa, su estado y la acción corta;
/// abierta añade [details] y la acción a lo ancho. Cada perspectiva decide
/// qué detalle y qué acción ofrece.
class TableSheet extends StatelessWidget {
  const TableSheet({
    super.key,
    required this.table,
    required this.badge,
    required this.status,
    required this.expanded,
    required this.animate,
    required this.onToggle,
    required this.details,
    this.action,
    this.onClose,
  });

  final VenueTable table;

  /// Texto del icono redondo, por ejemplo «07» o «VIP».
  final String badge;
  final TableMapStatus status;
  final bool expanded;
  final bool animate;
  final VoidCallback onToggle;
  final Widget details;
  final SheetAction? action;

  /// Quita la selección; `null` no muestra el botón de cerrar.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(StatusColors.of(context));
    // Con texto grande nada se recorta: los textos ocupan las líneas que
    // necesiten y la acción baja a su propia fila, a lo ancho.
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    final lines = largeText ? null : 1;
    final overflow = largeText ? null : TextOverflow.ellipsis;
    final header = <Widget>[
      _TableDot(label: badge, color: color),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              table.displayName,
              maxLines: lines,
              overflow: overflow,
              style: const TextStyle(
                fontSize: 17,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: NightNeutrals.white,
              ),
            ),
            Text(
              status.label,
              maxLines: lines,
              overflow: overflow,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ];
    final more = GlassIconButton(
      icon: Icons.keyboard_arrow_up_rounded,
      label: expanded ? 'Ocultar detalle de la mesa' : 'Ver detalle de la mesa',
      expanded: expanded,
      turns: expanded ? 0.5 : 0,
      animate: animate,
      onPressed: onToggle,
    );
    final close = onClose == null
        ? null
        : GlassIconButton(
            icon: Icons.close_rounded,
            label: 'Cerrar detalle',
            animate: animate,
            onPressed: onClose!,
          );
    final action = this.action;

    return Semantics(
      container: true,
      child: GlassPanel(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: expanded || largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [...header, ?close, more]),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 2, 8, 8),
                        child: details,
                      )
                    else
                      const SizedBox(height: 6),
                    if (action != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: GlassActionButton(
                          key: const ValueKey('sheet-action'),
                          label: action.label,
                          vip: action.vip,
                          onPressed: action.onPressed,
                        ),
                      ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      ...header,
                      if (action != null) ...[
                        const SizedBox(width: 10),
                        // Con texto grande cede espacio en lugar de desbordar,
                        // sin dejar huecos cuando el texto es corto.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.4,
                          ),
                          child: GlassActionButton(
                            key: const ValueKey('sheet-action'),
                            label: action.shortLabel,
                            semanticLabel: action.label,
                            vip: action.vip,
                            onPressed: action.onPressed,
                          ),
                        ),
                      ] else
                        ?close,
                      more,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _TableDot extends StatelessWidget {
  const _TableDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [NightNeutrals.glass(0.35), NightNeutrals.glass(0.06)],
            stops: const [0, 0.6],
          ),
          border: Border.all(color: color, width: 1.8),
        ),
        child: Text(
          label,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: NightNeutrals.white,
          ),
        ),
      ),
    );
  }
}

/// Botón principal claro sobre cristal; dorado en mesas VIP.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.vip = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool vip;

  /// Texto completo para el lector de pantalla cuando [label] es corto.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final venueVip = VenueTheme.of(context).vip;
    final colors = vip
        ? [Color.lerp(NightNeutrals.white, venueVip, 0.7)!, venueVip]
        : const [NightNeutrals.ctaTop, NightNeutrals.ctaBottom];
    final enabled = onPressed != null;
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: enabled
                    ? colors
                    : [NightNeutrals.glass(0.14), NightNeutrals.glass(0.08)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              // Con texto grande ocupa las líneas que necesite.
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: largeText ? null : 1,
                overflow: largeText ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: !enabled
                      ? NightNeutrals.glass(0.55)
                      : vip
                      ? NightNeutrals.vipCtaInk
                      : NightNeutrals.ctaInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de cristal con área táctil de 48.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.animate,
    this.expanded,
    this.turns = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool animate;

  /// Estado desplegado para el lector de pantalla; `null` si no aplica.
  final bool? expanded;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      expanded: expanded,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: NightNeutrals.glass(0.1),
                  border: Border.all(color: NightNeutrals.glass(0.14)),
                ),
                child: AnimatedRotation(
                  turns: turns,
                  duration: animate
                      ? const Duration(milliseconds: 250)
                      : Duration.zero,
                  child: Icon(
                    icon,
                    size: 22,
                    color: onPressed == null
                        ? NightNeutrals.glass(0.35)
                        : NightNeutrals.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

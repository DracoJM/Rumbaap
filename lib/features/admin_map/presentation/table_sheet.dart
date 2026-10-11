import 'package:flutter/material.dart';

import '../../../theme/night_neutrals.dart';
import '../../../theme/status_colors.dart';
import '../../../theme/venue_theme.dart';
import '../../reservations/domain/venue_table.dart';
import '../domain/admin_table_status.dart';
import 'admin_map_labels.dart';
import 'glass.dart';

/// Ficha flotante de la mesa seleccionada. Cerrada muestra la mesa, su
/// estado y la acción corta; abierta añade la descripción y la acción
/// completa a lo ancho.
class TableSheet extends StatelessWidget {
  const TableSheet({
    super.key,
    required this.table,
    required this.status,
    required this.expanded,
    required this.animate,
    required this.onToggle,
    required this.onAction,
  });

  final VenueTable table;
  final AdminTableStatus status;
  final bool expanded;
  final bool animate;
  final VoidCallback onToggle;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final color = status.colorIn(StatusColors.of(context));
    final header = <Widget>[
      _TableDot(label: table.sheetBadge, color: color),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              table.adminName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: NightNeutrals.white,
              ),
            ),
            Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final more = _MoreButton(
      expanded: expanded,
      animate: animate,
      onPressed: onToggle,
    );

    return Semantics(
      container: true,
      child: GlassPanel(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [...header, more]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 2, 8, 10),
                      child: Text(
                        table.adminDescription,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: NightNeutrals.glass(0.75),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: _ActionButton(
                        label: table.actionFor(status),
                        vip: table.isVip,
                        onPressed: onAction,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ...header,
                    const SizedBox(width: 10),
                    // Con texto grande cede espacio en lugar de desbordar.
                    Flexible(
                      child: _ActionButton(
                        label: table.shortActionFor(status),
                        vip: table.isVip,
                        onPressed: onAction,
                      ),
                    ),
                    more,
                  ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.vip,
    required this.onPressed,
  });

  final String label;
  final bool vip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final venueVip = VenueTheme.of(context).vip;
    final colors = vip
        ? [Color.lerp(NightNeutrals.white, venueVip, 0.7)!, venueVip]
        : const [NightNeutrals.ctaTop, NightNeutrals.ctaBottom];
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: vip ? NightNeutrals.vipCtaInk : NightNeutrals.ctaInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    required this.expanded,
    required this.animate,
    required this.onPressed,
  });

  final bool expanded;
  final bool animate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: 'Ver detalle de la mesa',
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NightNeutrals.glass(0.1),
              ),
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: animate
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 22,
                  color: NightNeutrals.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

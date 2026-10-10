import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_furniture_painter.dart';
import 'table_presentation.dart';
import 'venue_geometry.dart';

/// Mesa del mapa: mueble, identificador e ícono de estado. Solo informa del
/// toque; no decide nada sobre la mesa.
class TableWidget extends StatefulWidget {
  const TableWidget({
    super.key,
    required this.table,
    required this.status,
    required this.selected,
    required this.pulse,
    required this.onTap,
  });

  final VenueTable table;
  final TableMapStatus status;
  final bool selected;

  /// Animación compartida del mapa; las mesas en proceso «respiran» con ella.
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final box = VenueGeometry.boxOf(table);
    final rotation = VenueGeometry.rotationOf(table);
    final target = widget.selected ? 1.0 : (_hover ? 0.7 : 0.0);
    // El ícono de estado se coloca en la abertura del sofá.
    final badgeOffset = VenueGeometry.openingOf(table) * box * 0.36;
    final badge = table.isVip ? 30.0 : 24.0;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${table.displayName}, ${widget.status.label}',
      // excludeSemantics oculta la acción del GestureDetector interior, así
      // que la acción se publica aquí para lectores de pantalla.
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: widget.selected ? 1.08 : (_hover ? 1.05 : 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: SizedBox.square(
              dimension: box,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: target),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, emphasis, _) =>
                          _furniture(emphasis, rotation),
                    ),
                  ),
                  Text(
                    table.id,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: table.isVip ? 19 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      letterSpacing: 0.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: badgeOffset,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: CurvedAnimation(
                          parent: anim,
                          curve: Curves.easeOutBack,
                        ),
                        child: child,
                      ),
                      child: _StatusBadge(
                        key: ValueKey(widget.status),
                        status: widget.status,
                        size: badge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _furniture(double emphasis, double rotation) {
    TableFurniturePainter painter(double e) => TableFurniturePainter(
      kind: widget.table.kind,
      rotation: rotation,
      status: widget.status,
      emphasis: e,
      selected: widget.selected,
    );
    if (!widget.status.isPending) {
      return CustomPaint(painter: painter(emphasis));
    }
    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, _) {
        final wave = 0.5 + 0.5 * math.sin(widget.pulse.value * math.pi * 8);
        return CustomPaint(
          painter: painter(math.max(emphasis, 0.15 + 0.45 * wave)),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({super.key, required this.status, required this.size});

  final TableMapStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0E0C12),
        border: Border.all(color: status.color, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.45),
            blurRadius: math.max(4, size / 3),
          ),
        ],
      ),
      child: Icon(status.icon, size: size * 0.62, color: status.color),
    );
  }
}

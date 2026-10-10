import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_furniture_painter.dart';
import 'table_presentation.dart';
import 'venue_geometry.dart';

/// Mesa del mapa: mueble, identificador e ícono de estado. Solo informa del
/// toque; no decide nada sobre la mesa.
class TableWidget extends StatelessWidget {
  const TableWidget({
    super.key,
    required this.table,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final VenueTable table;
  final TableMapStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = VenueGeometry.boxOf(table);
    final rotation = VenueGeometry.rotationOf(table);
    // El ícono de estado se coloca en la abertura del sofá.
    final badgeOffset = VenueGeometry.openingOf(table) * box * 0.36;
    final badge = table.isVip ? 30.0 : 24.0;

    return Semantics(
      button: true,
      selected: selected,
      label: '${table.displayName}, ${status.label}',
      // excludeSemantics oculta la acción del GestureDetector interior, así
      // que la acción se publica aquí para lectores de pantalla.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.08 : 1,
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
                    tween: Tween(end: selected ? 1 : 0),
                    duration: const Duration(milliseconds: 220),
                    builder: (context, emphasis, _) => CustomPaint(
                      painter: TableFurniturePainter(
                        kind: table.kind,
                        rotation: rotation,
                        status: status,
                        emphasis: emphasis,
                        selected: selected,
                      ),
                    ),
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
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
                Transform.translate(
                  offset: badgeOffset,
                  child: _StatusBadge(status: status, size: badge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.size});

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

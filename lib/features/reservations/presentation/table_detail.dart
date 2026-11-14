import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

import '../../../theme/venue_theme.dart';
import '../../venues/venue_config.dart';
import '../domain/venue_table.dart';
import 'map/table_sheet.dart';
import 'table_presentation.dart';

/// Ficha pública de una mesa en la noche consultada: estado y datos
/// públicos del local. No muestra clientes ni reservas, y no ofrece
/// acciones sobre la mesa.
class TableDetail extends StatelessWidget {
  const TableDetail({
    super.key,
    required this.table,
    required this.status,
    required this.nightLabel,
    required this.onClose,
    required this.expanded,
    required this.onToggle,
    required this.animate,
    this.action,
  });

  final VenueTable table;
  final TableMapStatus status;
  final String nightLabel;
  final VoidCallback onClose;
  final bool expanded;
  final VoidCallback onToggle;
  final bool animate;

  /// Acción de la perspectiva (p. ej. «Reservar esta mesa» del cliente);
  /// `null` en la consulta sin acciones.
  final SheetAction? action;

  @override
  Widget build(BuildContext context) {
    final config = VenueScope.of(context);
    final terms = config.termsOf(table);
    return TableSheet(
      table: table,
      badge: config.layout.placementOf(table.id)?.label ?? table.id,
      status: status,
      expanded: expanded,
      animate: animate,
      onToggle: onToggle,
      onClose: onClose,
      action: action,
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            icon: Icons.table_restaurant_rounded,
            label: 'Tipo',
            value: table.kindLabel,
          ),
          InfoRow(
            icon: Icons.place_outlined,
            label: 'Ubicación',
            value: table.zoneLabel,
          ),
          InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Noche consultada',
            value: nightLabel,
          ),
          InfoRow(
            icon: Icons.people_outline_rounded,
            label: 'Capacidad',
            value: terms.capacity,
          ),
          const SizedBox(height: 6),
          const Text(
            'Condiciones',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in terms.conditions) Bullet(text: line),
        ],
      ),
    );
  }
}

/// Dato con icono y etiqueta, sobre cristal.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Bullet extends StatelessWidget {
  const Bullet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Icon(
              Icons.circle,
              size: 6,
              color: VenueTheme.of(context).vip,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

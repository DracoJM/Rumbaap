import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/night_availability.dart';
import 'table_detail.dart';
import 'table_picker.dart';
import 'table_presentation.dart';
import 'venue_map.dart';
import 'venue_map_controller.dart';

/// «Mapa y disponibilidad»: consulta de estados por noche.
class VenueMapPage extends StatefulWidget {
  const VenueMapPage({super.key, required this.repository});

  final NightAvailabilityRepository repository;

  /// Ancho a partir del cual el detalle va en un panel lateral en lugar de
  /// una hoja inferior (tabletas). En horizontal también se usa el panel
  /// lateral, para que la hoja inferior no deje el mapa sin altura.
  static const sidePanelBreakpoint = 600.0;

  @override
  State<VenueMapPage> createState() => _VenueMapPageState();
}

class _VenueMapPageState extends State<VenueMapPage> {
  late final VenueMapController _controller = VenueMapController(
    widget.repository,
  )..loadNights();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text('Mapa y disponibilidad'), _DemoDataTag()],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => switch (_controller.nightsStatus) {
            LoadStatus.loading => const _CenteredMessage(
              icon: null,
              text: 'Cargando noches…',
            ),
            LoadStatus.failed => _CenteredMessage(
              icon: Icons.error_outline_rounded,
              text: 'No se pudieron cargar las noches.',
              onRetry: _controller.retry,
            ),
            LoadStatus.ready when _controller.nights.isEmpty =>
              const _CenteredMessage(
                icon: Icons.event_busy_rounded,
                text: 'No hay noches para consultar.',
              ),
            LoadStatus.ready => _content(),
          },
        ),
      ),
    );
  }

  Widget _content() {
    final c = _controller;
    final selected = c.selectedTable;
    final detail = selected == null
        ? null
        : TableDetail(
            key: ValueKey('detail-${selected.id}'),
            table: selected,
            status: TableMapStatus.from(c.availabilityOf(selected.id)),
            nightLabel: c.night?.label ?? '',
            onClose: c.clearSelection,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= VenueMapPage.sidePanelBreakpoint ||
            constraints.maxWidth > constraints.maxHeight;
        final mapArea = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NightSelector(
              nights: c.nights,
              selectedId: c.night?.id,
              onSelected: c.selectNight,
            ),
            // «Elegir mesa» va en la cabecera y no sobre el mapa, para no
            // tapar mesas ni los controles de zoom en pantallas pequeñas.
            Row(
              children: [
                const Expanded(child: _Legend()),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _PickTableButton(
                    onPressed: () => showTablePicker(context, c),
                  ),
                ),
              ],
            ),
            if (c.availabilityStatus == LoadStatus.failed)
              _InlineError(onRetry: c.retry),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VenueMap(
                      statusOf: (id) =>
                          TableMapStatus.from(c.availabilityOf(id)),
                      selectedTableId: c.selectedTableId,
                      onTableTap: c.toggleTable,
                    ),
                  ),
                  if (c.availabilityStatus == LoadStatus.loading)
                    const Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(child: _LoadingPill()),
                    ),
                ],
              ),
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mapArea),
              if (detail != null)
                SizedBox(
                  width: math.min(360, constraints.maxWidth * 0.45),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(left: BorderSide(color: AppColors.border)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
                      child: detail,
                    ),
                  ),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: mapArea),
            if (detail != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.5,
                ),
                child: _BottomSheetPanel(child: detail),
              ),
          ],
        );
      },
    );
  }
}

class _DemoDataTag extends StatelessWidget {
  const _DemoDataTag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: AppColors.amber,
        ),
        const SizedBox(width: 4),
        Text(
          'Datos de demostración',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.amberSoft),
        ),
      ],
    );
  }
}

class _NightSelector extends StatelessWidget {
  const _NightSelector({
    required this.nights,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Night> nights;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Wrap en lugar de una fila desplazable: todas las noches quedan a la
    // vista aunque el ancho se reduzca (por ejemplo, con el panel abierto).
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final night in nights)
            ChoiceChip(
              key: ValueKey('night-${night.id}'),
              label: Text(night.label),
              selected: night.id == selectedId,
              onSelected: (_) {
                if (night.id != selectedId) onSelected(night.id);
              },
            ),
        ],
      ),
    );
  }
}

class _PickTableButton extends StatelessWidget {
  const _PickTableButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.format_list_bulleted_rounded),
      label: const Text('Elegir mesa'),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          for (final status in TableMapStatus.values)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(status.icon, size: 16, color: status.color),
                  const SizedBox(width: 4),
                  Text(status.label, style: style),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No se pudo consultar la disponibilidad de esta noche.',
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Consultando disponibilidad…'),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetPanel extends StatelessWidget {
  const _BottomSheetPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: child,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.text,
    this.onRetry,
  });

  /// `null` muestra un indicador de carga.
  final IconData? icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}

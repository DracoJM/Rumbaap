import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../domain/venue_table.dart';
import 'table_presentation.dart';
import 'table_widget.dart';
import 'venue_geometry.dart';
import 'venue_painter.dart';

/// Plano con zoom y desplazamiento. Recibe los estados, la mesa
/// seleccionada y el callback de toque; no guarda estado de negocio.
class VenueMap extends StatefulWidget {
  const VenueMap({
    super.key,
    required this.statusOf,
    required this.selectedTableId,
    required this.onTableTap,
  });

  final TableMapStatus Function(VenueTable table) statusOf;
  final String? selectedTableId;
  final ValueChanged<String> onTableTap;

  @override
  State<VenueMap> createState() => _VenueMapState();
}

class _VenueMapState extends State<VenueMap> with TickerProviderStateMixin {
  static const _maxScale = 5.0;

  /// Ciclo de la iluminación ambiental y del pulso de las mesas en proceso.
  /// Los tickers se silencian solos cuando la pantalla queda cubierta por
  /// otra ruta o la app pasa a segundo plano.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  final _transform = TransformationController();
  late final AnimationController _zoomAnim;
  late final CurvedAnimation _zoomCurve;
  Matrix4Tween? _zoomTween;

  @override
  void initState() {
    super.initState();
    // Se crean aquí y no de forma perezosa: si nunca se usara el zoom, el
    // primer acceso ocurriría en dispose(), con el elemento ya desactivado.
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => _transform.value = _zoomTween!.evaluate(_zoomCurve));
    _zoomCurve = CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta el ajuste del sistema «reducir movimiento».
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _zoomCurve.dispose();
    _zoomAnim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _zoomAnim.forward(from: 0);
  }

  void _zoom(double factor, Size viewport) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, _maxScale);
    final f = next / current;
    final c = viewport.center(Offset.zero);
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    _animateTo(m * _transform.value);
  }

  @override
  Widget build(BuildContext context) {
    final venue = SizedBox.fromSize(
      size: VenueGeometry.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: VenuePainter(pulse: _pulse)),
            ),
          ),
          for (final table in VenueTables.all)
            Positioned.fromRect(
              rect: VenueGeometry.boundsOf(table),
              child: TableWidget(
                key: ValueKey('table-${table.id}'),
                table: table,
                status: widget.statusOf(table),
                selected: table.id == widget.selectedTableId,
                pulse: _pulse,
                onTap: () => widget.onTableTap(table.id),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(48),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FittedBox(child: venue),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: _ZoomControls(
                // En vertical miden 144 px; si el mapa es más bajo (teléfono
                // pequeño en horizontal), se colocan en fila.
                axis: viewport.height >= 220 ? Axis.vertical : Axis.horizontal,
                onZoomIn: () => _zoom(1.6, viewport),
                onZoomOut: () => _zoom(1 / 1.6, viewport),
                onReset: () => _animateTo(Matrix4.identity()),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.axis,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: AppColors.text,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add_rounded, 'Acercar', onZoomIn),
          button(Icons.center_focus_strong_rounded, 'Ver todo', onReset),
          button(Icons.remove_rounded, 'Alejar', onZoomOut),
        ],
      ),
    );
  }
}

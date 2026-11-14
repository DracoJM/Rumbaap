import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/app_theme.dart';
import '../../reservations/presentation/admin/admin_widgets.dart';

/// Resultado de abrir el lector: un código leído, o la petición expresa de
/// escribir la credencial a mano. Volver atrás (cancelar) devuelve `null`,
/// que NO es una petición de escribir: el puesto no debe mover el foco.
sealed class ScanOutcome {
  const ScanOutcome();
}

final class ScannedCode extends ScanOutcome {
  const ScannedCode(this.code);
  final String code;
}

final class ManualEntryRequested extends ScanOutcome {
  const ManualEntryRequested();
}

/// Abre la cámara para leer UN QR. `null` si la persona vuelve atrás.
typedef CredentialScan = Future<ScanOutcome?> Function(BuildContext context);

/// Lectura real con la cámara (pantalla completa).
Future<ScanOutcome?> scanCredentialWithCamera(BuildContext context) =>
    Navigator.of(context).push<ScanOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CredentialScannerPage(),
      ),
    );

/// Lector de QR con la cámara trasera.
///
/// Solo se abre cuando el personal pulsa «Leer QR con la cámara». Lee un
/// único QR por intento: la primera lectura válida cierra la pantalla y las
/// demás (el lector avisa varias veces por segundo) se ignoran. No guarda
/// imágenes ni registra el código: lo devuelve al puesto, que lo consulta
/// en `TicketGateway` igual que si se hubiera escrito.
///
/// La cámara se detiene al salir de la app y se reanuda al volver, y se
/// libera al cerrar la pantalla.
class CredentialScannerPage extends StatefulWidget {
  const CredentialScannerPage({super.key});

  @override
  State<CredentialScannerPage> createState() => _CredentialScannerPageState();
}

class _CredentialScannerPageState extends State<CredentialScannerPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  StreamSubscription<BarcodeCapture>? _subscription;

  /// Ya se entregó una lectura: el intento terminó.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(
      _onCapture,
      // Un fotograma que no se pudo analizar no detiene la lectura.
      onError: (Object _) {},
    );
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sin permiso no hay cámara que pausar; tras una lectura, no se reanuda.
    if (_done || !_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  void _onCapture(BarcodeCapture capture) {
    if (_done || !mounted) return;
    String? code;
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (b.format == BarcodeFormat.qrCode && raw != null && raw.isNotEmpty) {
        code = raw;
        break;
      }
    }
    if (code == null) return;
    _done = true;
    unawaited(_controller.stop());
    Navigator.of(context).pop(ScannedCode(code));
  }

  Future<void> _retry() async {
    await _controller.stop();
    if (!mounted || _done) return;
    await _controller.start();
  }

  void _typeInstead() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(const ManualEntryRequested());
  }

  @override
  void dispose() {
    _done = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Leer QR')),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: MobileScanner(
                key: const ValueKey('scanner-camera'),
                controller: _controller,
                placeholderBuilder: (_) => const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorBuilder: (context, error) =>
                    _CameraProblem(error: error, onRetry: _retry),
                overlayBuilder: (context, constraints) {
                  final side = constraints.biggest.shortestSide * 0.7;
                  return IgnorePointer(
                    child: Center(
                      child: Container(
                        width: side,
                        height: side,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Con texto grande el panel se desplaza en lugar de tapar la
            // cámara.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.4),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Apunta al QR de la entrada. Solo se lee el código: no '
                      'se guardan fotos.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('scanner-type-instead'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _typeInstead,
                      icon: const Icon(Icons.keyboard_rounded),
                      label: const Text('Escribir la credencial'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sin permiso, sin cámara o con un fallo: se explica y siempre queda la
/// escritura manual (botón de la pantalla).
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, text, canRetry) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
        Icons.no_photography_outlined,
        'La app no tiene permiso para usar la cámara. Puedes permitirlo en '
            'los ajustes del teléfono o escribir la credencial.',
        true,
      ),
      MobileScannerErrorCode.unsupported => (
        Icons.no_photography_outlined,
        'Este teléfono no tiene una cámara disponible. Escribe la credencial.',
        false,
      ),
      _ => (
        Icons.error_outline_rounded,
        'No se pudo usar la cámara. Reintenta o escribe la credencial.',
        true,
      ),
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            key: ValueKey('scanner-error-${error.errorCode.name}'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoticeBox(icon: icon, color: AppColors.amber, text: text),
              if (canRetry) ...[
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey('scanner-retry'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

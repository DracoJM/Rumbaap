import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Plataforma de cámara falsa para pruebas de widgets: sustituye al canal
/// nativo de `mobile_scanner` (que no existe en `flutter test`). Permite
/// simular permisos, fallos, lecturas (también repetidas) y comprobar que
/// la cámara se detiene y se libera. No decodifica imágenes: entrega el
/// texto que la prueba indique, como haría el lector nativo.
class FakeScannerPlatform extends MobileScannerPlatform {
  final _barcodes = StreamController<BarcodeCapture?>.broadcast();

  /// Error que dará el próximo `start`; `null` para arrancar bien.
  MobileScannerErrorCode? nextStartError;

  int starts = 0;
  int stops = 0;
  int disposes = 0;
  bool running = false;

  /// El lector nativo detecta un código (como un fotograma).
  void emit(String raw, {BarcodeFormat format = BarcodeFormat.qrCode}) =>
      _barcodes.add(
        BarcodeCapture(
          barcodes: [Barcode(rawValue: raw, format: format)],
        ),
      );

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() =>
      const ColoredBox(key: ValueKey('fake-camera'), color: Colors.grey);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    final error = nextStartError;
    if (error != null) {
      nextStartError = null;
      throw MobileScannerException(
        errorCode: error,
        errorDetails: MobileScannerErrorDetails(message: error.message),
      );
    }
    running = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(480, 640),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<void> pause() async => running = false;

  @override
  Future<void> dispose() async {
    disposes++;
    running = false;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> setFocusPoint(Offset position) async {}

  @override
  Future<void> resetZoomScale() async {}

  @override
  Future<void> setZoomScale(double zoomScale) async {}
}

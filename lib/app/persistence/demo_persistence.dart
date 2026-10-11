import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento clave-valor de la demostración. La app usa
/// [SharedPrefsDemoStorage]; las pruebas, uno en memoria que puede fallar.
abstract interface class DemoStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Datos ficticios de la demo en el teléfono (`SharedPreferencesAsync`).
/// NO es el almacenamiento de producción (`NOT DECIDED`).
class SharedPrefsDemoStorage implements DemoStorage {
  SharedPrefsDemoStorage() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Clave del estado de un local. Cada local guarda aparte; las cuentas de
/// un local comparten su estado (cada vista lee su proyección).
String demoStorageKey(String venueId) => 'rumbaap.demo.v1.$venueId';

/// Guarda el estado tras cada cambio, sin esperar al cierre de la app.
///
/// Las escrituras van en serie: nunca hay dos a la vez, y cada una toma el
/// estado del momento en que empieza, así una escritura antigua no puede
/// terminar después y pisar una más nueva. Si falla, se informa y se
/// reintenta; el estado en memoria no se toca.
class DemoPersistence extends ChangeNotifier {
  DemoPersistence({
    required this.storage,
    required this.key,
    required this.encode,
  });

  final DemoStorage storage;
  final String key;

  /// Serializa el estado ACTUAL (se llama al empezar cada escritura).
  final String Function() encode;

  bool _writing = false;
  bool _dirty = false;
  Object? _error;

  /// Último fallo de escritura, si el estado guardado va por detrás.
  Object? get error => _error;
  bool get pending => _writing || _dirty;

  void markDirty() {
    _dirty = true;
    if (!_writing) _drain();
  }

  /// Vuelve a intentar tras un fallo.
  Future<void> retry() {
    _dirty = true;
    return _writing ? Future.value() : _drain();
  }

  /// Espera a que no quede nada por guardar (cierre ordenado, pruebas).
  Future<void> flush() async {
    while (_writing || (_dirty && _error == null)) {
      if (!_writing) await _drain();
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await storage.write(key, encode());
          if (_error != null) {
            _error = null;
            notifyListeners();
          }
        } catch (e) {
          _error = e;
          notifyListeners();
          return;
        }
      }
    } finally {
      _writing = false;
    }
  }
}

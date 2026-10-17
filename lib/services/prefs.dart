import 'package:shared_preferences/shared_preferences.dart';

/// Acceso único a las preferencias del dispositivo.
///
/// Se carga una vez y todos los almacenes la comparten. Si la plataforma no
/// tiene almacenamiento (por ejemplo, un navegador en modo privado estricto),
/// devuelve `null` y la app sigue funcionando sólo en memoria.
class Prefs {
  Prefs._();

  static SharedPreferences? _instance;
  static Future<SharedPreferences?>? _loading;

  static SharedPreferences? get instance => _instance;

  static Future<SharedPreferences?> load() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= SharedPreferences.getInstance()
        .then<SharedPreferences?>((p) {
          _instance = p;
          return p;
        })
        .catchError((Object _) => null);
  }

  /// Borra todas las claves que cumplen [test].
  static Future<void> removeWhere(bool Function(String key) test) async {
    final prefs = await load();
    if (prefs == null) return;
    for (final key in prefs.getKeys().where(test).toList()) {
      try {
        await prefs.remove(key);
      } catch (_) {}
    }
  }
}

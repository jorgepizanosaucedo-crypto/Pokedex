import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'karen_controller.dart';
import 'music_service.dart';
import 'prefs.dart';
import 'sound_service.dart';

/// Ajustes del dispositivo: música, efectos, consejos de Karen y si la ficha
/// muestra el sprite animado o el arte oficial.
///
/// Antes se perdían al cerrar la app; ahora se guardan y se aplican a los
/// servicios al arrancar.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _key = 'settings.v1';

  bool _music = true;
  bool _sounds = true;
  bool _karen = true;
  bool _animated = true;

  bool get music => _music;
  bool get sounds => _sounds;
  bool get karen => _karen;

  /// La ficha muestra al Pokémon en movimiento (sprite de combate animado).
  bool get animated => _animated;

  Future<void> load() async {
    final prefs = await Prefs.load();
    try {
      final raw = prefs?.getString(_key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _music = json['music'] as bool? ?? true;
        _sounds = json['sounds'] as bool? ?? true;
        _karen = json['karen'] as bool? ?? true;
        _animated = json['animated'] as bool? ?? true;
      }
    } catch (_) {}
    _apply();
    notifyListeners();
  }

  Future<void> setMusic(bool value) async {
    await _update(() => _music = value);
    await MusicService.instance.setEnabled(value);
  }

  Future<void> setSounds(bool value) => _update(() => _sounds = value);

  Future<void> setKaren(bool value) => _update(() => _karen = value);

  Future<void> setAnimated(bool value) => _update(() => _animated = value);

  /// Vuelve a los valores de fábrica.
  Future<void> reset() async {
    _music = true;
    _sounds = true;
    _karen = true;
    _animated = true;
    _apply();
    notifyListeners();
    await MusicService.instance.setEnabled(true);
    final prefs = await Prefs.load();
    try {
      await prefs?.remove(_key);
    } catch (_) {}
  }

  Future<void> _update(void Function() change) async {
    change();
    _apply();
    notifyListeners();
    final prefs = await Prefs.load();
    try {
      await prefs?.setString(
        _key,
        jsonEncode({
          'music': _music,
          'sounds': _sounds,
          'karen': _karen,
          'animated': _animated,
        }),
      );
    } catch (_) {}
  }

  /// Lleva los ajustes a los servicios. La música se enciende aparte porque
  /// necesita esperar al reproductor.
  void _apply() {
    SoundService.instance.enabled = _sounds;
    KarenController.instance.setEnabled(_karen);
    if (!_music) MusicService.instance.setEnabled(false);
  }
}

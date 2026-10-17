import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'music_service.dart';

enum Sfx { tap, open, swipe, shiny, start, voice }

/// Efectos de sonido de la interfaz y gritos (cries) de los Pokémon.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;
  final AudioPlayer _cryPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _next = 0;

  Future<void> play(Sfx sfx, {double volume = 0.6}) async {
    if (!enabled) return;
    if (sfx == Sfx.tap) HapticFeedback.selectionClick();
    final player = _sfxPool[_next];
    _next = (_next + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/${sfx.name}.wav'), volume: volume);
    } catch (_) {
      // El audio es decorativo; si la plataforma no lo soporta, se ignora.
    }
  }

  Future<void> playCry(String? url, {double volume = 0.45}) async {
    if (!enabled || url == null) return;
    HapticFeedback.mediumImpact();
    // El tema de fondo se aparta para que el grito se oiga limpio.
    MusicService.instance.duck();
    try {
      await _cryPlayer.stop();
      await _cryPlayer.play(UrlSource(url), volume: volume);
    } catch (_) {}
  }
}

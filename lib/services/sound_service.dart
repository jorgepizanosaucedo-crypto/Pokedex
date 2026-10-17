import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'music_service.dart';
import 'sfx/sfx_engine.dart';

enum Sfx {
  tap,
  open,
  swipe,
  shiny,
  start,
  voice,
  // Combate contra Karen (ver tools/generate_battle_sfx.py).
  hit,
  hitSuper,
  hitWeak,
  whoosh,
  buff,
  debuff,
  heal,
  faint,
  miss,
}

/// Efectos de sonido de la interfaz y gritos (cries) de los Pokémon.
///
/// Escucha el ciclo de vida de la app: con la pestaña oculta o la app en
/// segundo plano no suena nada. Antes la música se pausaba pero los gritos
/// automáticos de la ficha seguían sonando con la pestaña cerrada.
class SoundService with WidgetsBindingObserver {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool enabled = true;
  bool _foreground = true;
  bool _observing = false;
  final AudioPlayer _cryPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _next = 0;

  /// `false` mientras la pestaña está oculta o la app en segundo plano.
  bool get foreground => _foreground;

  static String _asset(Sfx sfx) => 'assets/sounds/${sfx.name}.wav';

  /// Empieza a escuchar el ciclo de vida de la app.
  void init() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Deja los efectos listos en memoria (en web; en el resto no hace falta).
  Future<void> preload() => SfxEngine.preload(Sfx.values.map(_asset));

  /// Se llama en cada toque: el navegador no deja sonar nada hasta entonces.
  void unlock() {
    if (_foreground) SfxEngine.unlock();
  }

  Future<void> play(Sfx sfx, {double volume = 0.6}) async {
    if (!enabled || !_foreground) return;
    if (sfx == Sfx.tap) HapticFeedback.selectionClick();
    if (SfxEngine.play(_asset(sfx), volume)) return;
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
    if (!enabled || !_foreground || url == null) return;
    HapticFeedback.mediumImpact();
    // El tema de fondo se aparta para que el grito se oiga limpio.
    MusicService.instance.duck();
    try {
      await _cryPlayer.stop();
      await _cryPlayer.play(UrlSource(url), volume: volume);
    } catch (_) {}
  }

  /// Corta el grito que esté sonando.
  Future<void> stopCry() async {
    try {
      await _cryPlayer.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible == _foreground) return;
    _foreground = visible;
    if (visible) {
      SfxEngine.unlock();
    } else {
      stopCry();
      SfxEngine.suspend();
      for (final p in _sfxPool) {
        p.stop().catchError((_) {});
      }
    }
  }
}

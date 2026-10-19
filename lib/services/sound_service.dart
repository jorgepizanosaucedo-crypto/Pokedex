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
  // Interfaz (ver tools/generate_ui_sfx.py): cada acción suena distinto.
  card,
  chip,
  chipOff,
  sheetUp,
  back,
  favOn,
  favOff,
  tab,
  dice,
  toggle,
  morph,
  mega,
  success,
  error,
  battleStart,
  // Uno por tipo: suena al abrir la ficha de un Pokémon de ese tipo.
  typeNormal,
  typeFire,
  typeWater,
  typeGrass,
  typeElectric,
  typeIce,
  typeFighting,
  typePoison,
  typeGround,
  typeFlying,
  typePsychic,
  typeBug,
  typeRock,
  typeGhost,
  typeDragon,
  typeDark,
  typeSteel,
  typeFairy;

  /// El sonido de un tipo de la PokeAPI (`fire` → [Sfx.typeFire]).
  static Sfx? forType(String? type) {
    if (type == null || type.isEmpty) return null;
    final name = 'type${type[0].toUpperCase()}${type.substring(1)}';
    for (final s in Sfx.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  bool get isTypeSound => name.startsWith('type');
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

  /// Empieza a escuchar el ciclo de vida de la app y, en el navegador, si la
  /// pestaña se ve o no.
  void init() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    SfxEngine.watchVisibility(_setForeground);
  }

  /// Deja los efectos listos en memoria (en web; en el resto no hace falta).
  /// Primero los de la interfaz, que suenan desde el primer toque; luego los
  /// de los tipos, que no hacen falta hasta abrir una ficha.
  Future<void> preload() async {
    await SfxEngine.preload(Sfx.values.where((s) => !s.isTypeSound).map(_asset));
    await SfxEngine.preload(Sfx.values.where((s) => s.isTypeSound).map(_asset));
  }

  /// Se llama en cada toque: el navegador no deja sonar nada hasta entonces.
  void unlock() {
    if (_foreground) SfxEngine.unlock();
  }

  /// Al abrir la ficha: el sonido de su tipo principal.
  Future<void> playType(String? type, {double volume = 0.45}) async {
    final sfx = Sfx.forType(type);
    if (sfx != null) await play(sfx, volume: volume);
  }

  Future<void> play(Sfx sfx, {double volume = 0.6}) async {
    if (!enabled || !_foreground) return;
    switch (sfx) {
      case Sfx.tap || Sfx.chip || Sfx.chipOff || Sfx.tab || Sfx.toggle || Sfx.back:
        HapticFeedback.selectionClick();
      case Sfx.card || Sfx.favOn || Sfx.dice:
        HapticFeedback.lightImpact();
      case Sfx.error:
        HapticFeedback.vibrate();
      default:
        break;
    }
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
      // El grito baja de internet: si mientras tanto se ocultó la app, ya no
      // suena (antes arrancaba con la pestaña en segundo plano).
      if (!_foreground) return;
      await _cryPlayer.play(UrlSource(url), volume: volume);
      if (!_foreground) await _cryPlayer.stop();
    } catch (_) {}
  }

  /// Corta el grito que esté sonando.
  Future<void> stopCry() async {
    try {
      await _cryPlayer.stop();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _setForeground(state == AppLifecycleState.resumed);

  /// Con la app oculta se corta el grito que suene y no suena nada más hasta
  /// que vuelva a verse.
  void _setForeground(bool visible) {
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

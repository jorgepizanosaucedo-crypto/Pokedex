import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Temas de ambiente en bucle, con su propio interruptor independiente de los
/// efectos de sonido.
///
/// La pista cambia según el Pokémon que se esté viendo: cada grupo de tipos
/// tiene su ambiente, y los legendarios y singulares tienen uno solemne. Los
/// cambios se hacen con fundido cruzado para que nunca haya un corte seco.
class MusicService with WidgetsBindingObserver {
  MusicService._();
  static final MusicService instance = MusicService._();

  /// Pista del mapa: la que suena en la lista y mientras no hay nada abierto.
  static const String overworld = 'theme';

  static const double _baseVolume = 0.3;
  static const Duration _step = Duration(milliseconds: 50);

  /// Grupos de tipos. Los que no aparecen usan el tema del mapa, que es
  /// neutro, en lugar de forzar un ambiente que no les pega.
  static const Map<String, String> _byType = {
    'fire': 'fire',
    'fighting': 'fire',
    'water': 'water',
    'ice': 'water',
    'grass': 'grass',
    'bug': 'grass',
    'electric': 'electric',
    'flying': 'electric',
    'dark': 'dark',
    'ghost': 'dark',
    'poison': 'dark',
  };

  /// Qué pista le toca a un Pokémon. Ser legendario manda sobre el tipo.
  static String trackFor(String type, {bool legendary = false}) {
    if (legendary) return 'legendary';
    return _byType[type] ?? overworld;
  }

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool _started = false;
  String _track = overworld;
  String? _pending;
  double _volume = 0;
  Timer? _fade;
  Timer? _unduck;

  bool get enabled => _enabled;
  String get track => _track;

  void init() => WidgetsBinding.instance.addObserver(this);

  /// Arranca la música la primera vez que se puede.
  ///
  /// Los navegadores no permiten reproducir audio hasta que el usuario
  /// interactúa con la página, así que esto se llama también en cada toque:
  /// si el intento falla se deja listo para volver a probar en el siguiente.
  Future<void> ensureStarted() async {
    if (_started || !_enabled) return;
    _started = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('music/$_track.mp3'), volume: 0);
      _volume = 0;
      _fadeTo(_baseVolume, const Duration(milliseconds: 2400));
    } catch (_) {
      _started = false;
    }
  }

  /// Cambia de ambiente con un fundido cruzado.
  Future<void> switchTo(String track) async {
    if (track == _track && _started) return;
    _track = track;
    if (!_enabled) return;
    if (!_started) return ensureStarted();

    _pending = track;
    _fadeTo(0, const Duration(milliseconds: 420));
    // Esperamos a que se apague antes de cambiar de archivo: si durante ese
    // rato llega otro cambio, sólo se aplica el último.
    Timer(const Duration(milliseconds: 440), () async {
      if (_pending != track) return;
      _pending = null;
      try {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('music/$track.mp3'), volume: 0);
        _volume = 0;
        _fadeTo(_baseVolume, const Duration(milliseconds: 1100));
      } catch (_) {}
    });
  }

  /// Vuelve al tema del mapa (al salir de una ficha).
  Future<void> backToOverworld() => switchTo(overworld);

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) {
      _fade?.cancel();
      _unduck?.cancel();
      try {
        await _player.pause();
      } catch (_) {}
      return;
    }
    if (!_started) {
      await ensureStarted();
      return;
    }
    try {
      await _player.resume();
      _fadeTo(_baseVolume, const Duration(milliseconds: 900));
    } catch (_) {}
  }

  /// Baja el tema un momento para que se oiga el grito del Pokémon.
  void duck({Duration hold = const Duration(milliseconds: 1500)}) {
    if (!_enabled || !_started || _pending != null) return;
    _unduck?.cancel();
    _fadeTo(_baseVolume * 0.2, const Duration(milliseconds: 160));
    _unduck = Timer(hold, () {
      if (_pending == null) _fadeTo(_baseVolume, const Duration(milliseconds: 900));
    });
  }

  void _fadeTo(double target, Duration duration) {
    _fade?.cancel();
    final steps = math.max(1, duration.inMilliseconds ~/ _step.inMilliseconds);
    final from = _volume;
    var i = 0;
    _fade = Timer.periodic(_step, (timer) {
      i++;
      _volume = (from + (target - from) * (i / steps)).clamp(0.0, 1.0);
      _player.setVolume(_volume).catchError((_) {});
      if (i >= steps) timer.cancel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled || !_started) return;
    try {
      if (state == AppLifecycleState.resumed) {
        _player.resume();
      } else {
        _player.pause();
      }
    } catch (_) {}
  }
}

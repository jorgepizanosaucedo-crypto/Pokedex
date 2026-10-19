import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Efectos con Web Audio.
///
/// Con `audioplayers` cada efecto creaba un elemento `<audio>` y volvía a
/// pedir el archivo: la vocecita de Karen (un sonido por letra) trababa el
/// teléfono y los primeros efectos llegaban tarde o no sonaban. Aquí cada
/// archivo se descarga y decodifica una sola vez al arrancar, y reproducirlo
/// es crear un nodo, que no cuesta nada.
class SfxEngine {
  SfxEngine._();

  static web.AudioContext? _context;
  static final Map<String, web.AudioBuffer> _buffers = {};

  static web.AudioContext? get _ctx {
    try {
      return _context ??= web.AudioContext();
    } catch (_) {
      return null;
    }
  }

  /// Descarga y decodifica los efectos. Se puede hacer antes del primer
  /// gesto: el contexto nace suspendido pero sí decodifica.
  static Future<void> preload(Iterable<String> assets) async {
    final ctx = _ctx;
    if (ctx == null) return;
    await Future.wait([
      for (final asset in assets)
        if (!_buffers.containsKey(asset)) _load(ctx, asset),
    ]);
  }

  static Future<void> _load(web.AudioContext ctx, String asset) async {
    try {
      final url = ui_web.assetManager.getAssetUrl(asset);
      final response = await web.window.fetch(url.toJS).toDart;
      final data = await response.arrayBuffer().toDart;
      _buffers[asset] = await ctx.decodeAudioData(data).toDart;
    } catch (_) {
      // Sin ese efecto, `SoundService` prueba con `audioplayers`.
    }
  }

  /// El navegador sólo deja sonar audio después de un gesto: se llama en
  /// cada toque y reanuda el contexto si estaba suspendido.
  static void unlock() {
    final ctx = _ctx;
    if (ctx != null && ctx.state != 'running') ctx.resume();
  }

  /// Avisa cuando la pestaña se oculta o vuelve a verse.
  ///
  /// Se escucha al navegador directamente (`visibilitychange` y `pagehide`):
  /// el ciclo de vida de Flutter no siempre llega en web, y entonces los
  /// gritos seguían sonando con la pestaña en segundo plano.
  static void watchVisibility(void Function(bool visible) onChange) {
    try {
      web.document.addEventListener(
        'visibilitychange',
        ((web.Event _) => onChange(!web.document.hidden)).toJS,
      );
      web.window.addEventListener('pagehide', ((web.Event _) => onChange(false)).toJS);
    } catch (_) {}
  }

  /// Con la pestaña oculta se suspende: nada suena de fondo.
  static void suspend() {
    final ctx = _context;
    if (ctx != null && ctx.state == 'running') ctx.suspend();
  }

  static bool play(String asset, double volume) {
    final buffer = _buffers[asset];
    final ctx = _context;
    if (buffer == null || ctx == null) return false;
    // Antes del primer gesto se descarta: si se encolara, al desbloquear
    // sonaría todo de golpe.
    if (ctx.state != 'running') {
      ctx.resume();
      return true;
    }
    try {
      final gain = ctx.createGain()..gain.value = volume;
      gain.connect(ctx.destination);
      final source = ctx.createBufferSource()..buffer = buffer;
      source.connect(gain);
      source.start();
    } catch (_) {
      return false;
    }
    return true;
  }
}

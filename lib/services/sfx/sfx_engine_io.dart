/// Fuera del navegador `audioplayers` ya reproduce los efectos sin retraso.
class SfxEngine {
  SfxEngine._();

  static Future<void> preload(Iterable<String> assets) async {}

  static void unlock() {}

  static void suspend() {}

  /// `false`: que lo reproduzca `audioplayers`.
  static bool play(String asset, double volume) => false;
}

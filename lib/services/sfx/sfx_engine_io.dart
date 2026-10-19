/// Fuera del navegador `audioplayers` ya reproduce los efectos sin retraso.
class SfxEngine {
  SfxEngine._();

  static Future<void> preload(Iterable<String> assets) async {}

  static void unlock() {}

  static void suspend() {}

  /// Fuera del navegador basta con el ciclo de vida de Flutter.
  static void watchVisibility(void Function(bool visible) onChange) {}

  /// `false`: que lo reproduzca `audioplayers`.
  static bool play(String asset, double volume) => false;
}

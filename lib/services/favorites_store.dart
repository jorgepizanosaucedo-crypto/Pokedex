import 'package:flutter/foundation.dart';

import 'prefs.dart';

/// Equipo del entrenador: Pokémon marcados como favoritos, guardados en el
/// dispositivo.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  static const _key = 'favorite_ids';
  final Set<int> _ids = {};

  int get count => _ids.length;
  bool contains(int id) => _ids.contains(id);

  /// Ids en orden de Pokédex.
  List<int> get sorted => _ids.toList()..sort();

  Future<void> load() async {
    final prefs = await Prefs.load();
    try {
      final stored = prefs?.getStringList(_key) ?? const <String>[];
      _ids
        ..clear()
        ..addAll(stored.map(int.tryParse).whereType<int>());
    } catch (_) {}
    notifyListeners();
  }

  /// Devuelve `true` si quedó en el equipo.
  bool toggle(int id) {
    final added = _ids.add(id);
    if (!added) _ids.remove(id);
    notifyListeners();
    _persist();
    return added;
  }

  Future<void> clear() async {
    _ids.clear();
    notifyListeners();
    final prefs = await Prefs.load();
    try {
      await prefs?.remove(_key);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await Prefs.load();
    try {
      await prefs?.setStringList(_key, [for (final id in sorted) '$id']);
    } catch (_) {}
  }
}

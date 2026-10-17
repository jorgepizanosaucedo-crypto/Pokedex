import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../theme/app_theme.dart';
import 'pokeapi_service.dart';
import 'prefs.dart';

/// Qué tipos tiene cada Pokémon, para toda la Pokédex de golpe.
///
/// Si cada tarjeta pidiera `/pokemon/{id}` sólo para saber de qué color
/// pintarse, serían más de mil peticiones compitiendo con las imágenes. Esto
/// se arma con 18 —una por tipo— y se guarda en el dispositivo: desde la
/// segunda vez, las tarjetas salen con su color al instante.
class TypeIndex extends ChangeNotifier {
  TypeIndex._();
  static final TypeIndex instance = TypeIndex._();

  static const String _key = '${PokeApiService.cachePrefix}type_index.v1';

  final Map<int, List<String>> _types = {};
  bool _ready = false;
  bool _loading = false;

  bool get ready => _ready;

  /// Tipos de un Pokémon, en orden, o `null` si el índice aún no está.
  List<String>? typesOf(int id) => _types[id];

  /// Tipo principal, o `null` si aún no se sabe.
  String? primaryOf(int id) {
    final types = _types[id];
    return types == null || types.isEmpty ? null : types.first;
  }

  Future<void> load() async {
    if (_ready || _loading) return;
    _loading = true;

    final prefs = await Prefs.load();
    final stored = prefs?.getString(_key);
    if (stored != null) {
      try {
        final map = jsonDecode(stored) as Map<String, dynamic>;
        map.forEach((id, types) => _types[int.parse(id)] = List<String>.from(types as List));
        _finish();
        return;
      } catch (_) {
        _types.clear();
      }
    }

    // Cada tipo dice en qué hueco se coloca; así respetamos el orden real.
    final slots = <int, Map<int, String>>{};
    var complete = true;

    await Future.wait(
      kTypeStyles.keys.map((type) async {
        try {
          for (final member in await PokeApiService.instance.getTypeEntries(type)) {
            (slots[member.id] ??= {})[member.slot] = type;
          }
        } catch (_) {
          // Si un tipo falla, los demás siguen: la tarjeta sólo pierde color.
          complete = false;
        }
      }),
    );

    for (final entry in slots.entries) {
      final ordered = entry.value.keys.toList()..sort();
      _types[entry.key] = [for (final slot in ordered) entry.value[slot]!];
    }

    if (complete && _types.isNotEmpty) {
      try {
        await prefs?.setString(
          _key,
          jsonEncode({for (final e in _types.entries) '${e.key}': e.value}),
        );
      } catch (_) {}
    }
    _finish();
  }

  void _finish() {
    _loading = false;
    _ready = true;
    notifyListeners();
  }

  /// Olvida el índice (al borrar la caché). Se vuelve a armar al pedirlo.
  void reset() {
    _types.clear();
    _ready = false;
    _loading = false;
    notifyListeners();
  }
}

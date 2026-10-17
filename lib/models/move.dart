/// Un movimiento (`GET /move/{name}/`) con lo que necesitan la pestaña de
/// movimientos y el combate contra Karen.
class MoveInfo {
  final String name;

  /// Nombre en español (o en inglés si la PokeAPI no lo tiene).
  final String label;
  final String type;

  /// `physical`, `special` o `status`.
  final String damageClass;
  final int? power;
  final int? accuracy;
  final int pp;
  final int priority;
  final String description;

  /// Estado que puede causar (`burn`, `paralysis`, `sleep`…) y su probabilidad.
  final String? ailment;
  final int ailmentChance;

  /// Porcentaje que cura al usuario (Recuperación: 50).
  final int healing;

  /// A quién afecta: `user`, `selected-pokemon`, `all-opponents`…
  final String target;

  /// Cambios de características: estadística → etapas (+2, -1…).
  final Map<String, int> statChanges;
  final int statChance;

  const MoveInfo({
    required this.name,
    required this.label,
    required this.type,
    required this.damageClass,
    required this.power,
    required this.accuracy,
    required this.pp,
    required this.priority,
    required this.description,
    required this.ailment,
    required this.ailmentChance,
    required this.healing,
    required this.target,
    required this.statChanges,
    required this.statChance,
  });

  factory MoveInfo.fromJson(Map<String, dynamic> json) {
    String? pick(List? list, String key) {
      final rows = (list ?? const []).whereType<Map>().toList();
      for (final lang in ['es', 'en']) {
        final match = rows.where((e) => e['language']?['name'] == lang);
        if (match.isNotEmpty) return match.last[key] as String?;
      }
      return null;
    }

    final name = json['name'] as String;
    final meta = json['meta'] as Map? ?? const {};
    final ailment = meta['ailment']?['name'] as String?;
    return MoveInfo(
      name: name,
      label: pick(json['names'] as List?, 'name') ?? name,
      type: json['type']?['name'] as String? ?? 'normal',
      damageClass: json['damage_class']?['name'] as String? ?? 'status',
      power: json['power'] as int?,
      accuracy: json['accuracy'] as int?,
      pp: json['pp'] as int? ?? 0,
      priority: json['priority'] as int? ?? 0,
      description: (pick(json['flavor_text_entries'] as List?, 'flavor_text') ?? '')
          .replaceAll(RegExp(r'[\n\f\r]+'), ' ')
          .trim(),
      ailment: ailment == null || ailment == 'none' || ailment == 'unknown' ? null : ailment,
      ailmentChance: meta['ailment_chance'] as int? ?? 0,
      healing: meta['healing'] as int? ?? 0,
      target: json['target']?['name'] as String? ?? 'selected-pokemon',
      statChanges: {
        for (final c in (json['stat_changes'] as List? ?? const []).whereType<Map>())
          c['stat']['name'] as String: c['change'] as int,
      },
      statChance: meta['stat_chance'] as int? ?? 0,
    );
  }

  bool get isDamaging => damageClass != 'status' && (power ?? 0) > 0;

  /// Afecta al propio Pokémon (Danza Espada, Recuperación…).
  bool get targetsSelf => target == 'user' || target == 'users-field' || target == 'user-and-allies';
}

/// Habilidad (`GET /ability/{name}/`), con nombre y descripción en español.
class AbilityInfo {
  final String name;
  final String label;
  final String description;

  const AbilityInfo({required this.name, required this.label, required this.description});

  factory AbilityInfo.fromJson(Map<String, dynamic> json) {
    String? pick(List? list, String key) {
      final rows = (list ?? const []).whereType<Map>().toList();
      for (final lang in ['es', 'en']) {
        final match = rows.where((e) => e['language']?['name'] == lang);
        if (match.isNotEmpty) return match.last[key] as String?;
      }
      return null;
    }

    final name = json['name'] as String;
    return AbilityInfo(
      name: name,
      label: pick(json['names'] as List?, 'name') ?? name,
      description: (pick(json['flavor_text_entries'] as List?, 'flavor_text') ??
              pick(json['effect_entries'] as List?, 'short_effect') ??
              '')
          .replaceAll(RegExp(r'[\n\f\r]+'), ' ')
          .trim(),
    );
  }
}

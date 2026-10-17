/// Modelos que convierten las respuestas JSON de la PokeAPI en objetos Dart.
library;

int _idFromUrl(String url) {
  final parts = url.split('/')..removeWhere((p) => p.isEmpty);
  return int.parse(parts.last);
}

String artworkUrl(int id, {bool shiny = false}) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${shiny ? 'shiny/' : ''}$id.png';

/// Elemento ligero de `GET /pokemon?limit=&offset=`.
class PokemonListItem {
  final int id;
  final String name;

  const PokemonListItem({required this.id, required this.name});

  factory PokemonListItem.fromJson(Map<String, dynamic> json) =>
      PokemonListItem(id: _idFromUrl(json['url'] as String), name: json['name'] as String);

  String get imageUrl => artworkUrl(id);
}

class PokemonStat {
  final String name;
  final int value;

  const PokemonStat({required this.name, required this.value});

  factory PokemonStat.fromJson(Map<String, dynamic> json) =>
      PokemonStat(name: json['stat']['name'] as String, value: json['base_stat'] as int);
}

class PokemonAbility {
  final String name;
  final bool isHidden;

  const PokemonAbility({required this.name, required this.isHidden});

  factory PokemonAbility.fromJson(Map<String, dynamic> json) => PokemonAbility(
    name: json['ability']['name'] as String,
    isHidden: json['is_hidden'] as bool? ?? false,
  );
}

/// Objeto completo de `GET /pokemon/{id}/` (ej. https://pokeapi.co/api/v2/pokemon/1/).
class Pokemon {
  final int id;
  final String name;
  final int height; // decímetros
  final int weight; // hectogramos
  final int baseExperience;
  final List<String> types;
  final List<PokemonStat> stats;
  final List<PokemonAbility> abilities;
  final String imageUrl;
  final String shinyImageUrl;
  final String? cryUrl;
  final int movesCount;

  const Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.imageUrl,
    required this.shinyImageUrl,
    required this.cryUrl,
    required this.movesCount,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final artwork = (json['sprites']?['other']?['official-artwork'] ?? {}) as Map<String, dynamic>;
    final cries = (json['cries'] ?? {}) as Map<String, dynamic>;
    final types = (json['types'] as List).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));

    return Pokemon(
      id: id,
      name: json['name'] as String,
      height: json['height'] as int? ?? 0,
      weight: json['weight'] as int? ?? 0,
      baseExperience: json['base_experience'] as int? ?? 0,
      types: types.map((t) => t['type']['name'] as String).toList(),
      stats: (json['stats'] as List).map((s) => PokemonStat.fromJson(s)).toList(),
      abilities: (json['abilities'] as List).map((a) => PokemonAbility.fromJson(a)).toList(),
      imageUrl: artwork['front_default'] as String? ?? artworkUrl(id),
      shinyImageUrl: artwork['front_shiny'] as String? ?? artworkUrl(id, shiny: true),
      cryUrl: (cries['latest'] ?? cries['legacy']) as String?,
      movesCount: (json['moves'] as List?)?.length ?? 0,
    );
  }

  String get primaryType => types.first;
  double get heightMeters => height / 10;
  double get weightKg => weight / 10;
  int get totalStats => stats.fold(0, (sum, s) => sum + s.value);
}

/// Datos de `GET /pokemon-species/{id}/`: descripción, categoría y cadena evolutiva.
class PokemonSpecies {
  final String description;
  final String genus;
  final String? evolutionChainUrl;
  final int captureRate;
  final bool isLegendary;
  final bool isMythical;
  final String? habitat;

  const PokemonSpecies({
    required this.description,
    required this.genus,
    required this.evolutionChainUrl,
    required this.captureRate,
    required this.isLegendary,
    required this.isMythical,
    required this.habitat,
  });

  factory PokemonSpecies.fromJson(Map<String, dynamic> json) {
    T? pickLang<T>(List list, String key) {
      for (final lang in ['es', 'en']) {
        final match = list.cast<Map<String, dynamic>>().where((e) => e['language']['name'] == lang);
        if (match.isNotEmpty) return match.last[key] as T?;
      }
      return null;
    }

    final rawText = pickLang<String>(json['flavor_text_entries'] as List, 'flavor_text') ?? '';
    return PokemonSpecies(
      description: rawText.replaceAll(RegExp(r'[\n\f\r]+'), ' ').replaceAll('  ', ' ').trim(),
      genus: pickLang<String>(json['genera'] as List, 'genus') ?? '',
      evolutionChainUrl: json['evolution_chain']?['url'] as String?,
      captureRate: json['capture_rate'] as int? ?? 0,
      isLegendary: json['is_legendary'] as bool? ?? false,
      isMythical: json['is_mythical'] as bool? ?? false,
      habitat: json['habitat']?['name'] as String?,
    );
  }
}

/// Un paso de la cadena evolutiva (`GET /evolution-chain/{id}/`).
class EvolutionStep {
  final int id;
  final String name;
  final String? condition;

  const EvolutionStep({required this.id, required this.name, this.condition});

  String get imageUrl => artworkUrl(id);

  /// Aplana el árbol evolutivo en etapas (cada etapa puede tener ramas, ej. Eevee).
  static List<List<EvolutionStep>> parseChain(Map<String, dynamic> json) {
    final stages = <List<EvolutionStep>>[];
    var current = [json['chain'] as Map<String, dynamic>];
    while (current.isNotEmpty) {
      stages.add(
        current.map((node) {
          final details = (node['evolution_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          return EvolutionStep(
            id: _idFromUrl(node['species']['url'] as String),
            name: node['species']['name'] as String,
            condition: details.isEmpty ? null : _describe(details.first),
          );
        }).toList(),
      );
      current = current
          .expand((node) => (node['evolves_to'] as List).cast<Map<String, dynamic>>())
          .toList();
    }
    return stages;
  }

  static String _describe(Map<String, dynamic> d) {
    final trigger = d['trigger']?['name'] as String?;
    final time = switch (d['time_of_day']) {
      'day' => ' de día',
      'night' => ' de noche',
      _ => '',
    };
    if (d['min_level'] != null) return 'Nv. ${d['min_level']}$time';
    if (d['item'] != null) return _item(d['item']['name'] as String);
    if (d['held_item'] != null) {
      final item = _item(d['held_item']['name'] as String);
      return trigger == 'trade' ? 'Intercambio con $item' : 'Con $item$time';
    }
    if (d['min_happiness'] != null) return 'Amistad$time';
    if (d['min_affection'] != null) return 'Afecto';
    if (d['known_move'] != null) return 'Con ${_pretty(d['known_move']['name'] as String)}';
    if (d['location'] != null) return 'Lugar especial';
    return switch (trigger) {
      'trade' => 'Intercambio',
      'level-up' => 'Subir nivel$time',
      'use-item' => 'Usar objeto',
      null => '',
      final String other => _pretty(other),
    };
  }

  /// Objetos de evolución más comunes, en español; el resto queda tal cual.
  static String _item(String name) => switch (name) {
    'fire-stone' => 'Piedra fuego',
    'water-stone' => 'Piedra agua',
    'thunder-stone' => 'Piedra trueno',
    'leaf-stone' => 'Piedra hoja',
    'moon-stone' => 'Piedra lunar',
    'sun-stone' => 'Piedra solar',
    'shiny-stone' => 'Piedra día',
    'dusk-stone' => 'Piedra noche',
    'dawn-stone' => 'Piedra alba',
    'ice-stone' => 'Piedra hielo',
    'oval-stone' => 'Piedra oval',
    'kings-rock' => 'Roca del rey',
    'metal-coat' => 'Revestimiento metálico',
    'dragon-scale' => 'Escama dragón',
    'up-grade' => 'Mejora',
    'dubious-disc' => 'Disco extraño',
    'protector' => 'Protector',
    'electirizer' => 'Electrizador',
    'magmarizer' => 'Magmatizador',
    'reaper-cloth' => 'Tela terrible',
    'razor-claw' => 'Garra afilada',
    'razor-fang' => 'Colmillo agudo',
    'prism-scale' => 'Escama bella',
    'deep-sea-tooth' => 'Diente marino',
    'deep-sea-scale' => 'Escama marina',
    'sachet' => 'Saquito fragante',
    'whipped-dream' => 'Dulce de nata',
    _ => _pretty(name),
  };

  static String _pretty(String s) =>
      s.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

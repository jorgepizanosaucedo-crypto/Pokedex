/// Modelos que convierten las respuestas JSON de la PokeAPI en objetos Dart.
library;

int _idFromUrl(String url) {
  final parts = url.split('/')..removeWhere((p) => p.isEmpty);
  return int.parse(parts.last);
}

String artworkUrl(int id, {bool shiny = false}) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${shiny ? 'shiny/' : ''}$id.png';

/// Elemento ligero de `GET /pokemon?limit=&offset=`.
///
/// La misma lista trae, después de los 1025, las variantes (megas, formas
/// regionales, gigamax…) con ids de 10001 en adelante. Para esas, [dexId] es
/// el número de su especie y [speciesName] su nombre.
class PokemonListItem {
  final int id;
  final String name;
  /// Número de Pokédex nacional (el de la especie en las variantes).
  final int dexId;
  final String? speciesName;

  const PokemonListItem({required this.id, required this.name, int? dexId, this.speciesName})
    : dexId = dexId ?? id;

  factory PokemonListItem.fromJson(Map<String, dynamic> json) =>
      PokemonListItem(id: _idFromUrl(json['url'] as String), name: json['name'] as String);

  bool get isForm => id > 10000;

  String get imageUrl => artworkUrl(id);
}

class PokemonStat {
  final String name;
  final int value;

  /// Puntos de esfuerzo que da al ser derrotado.
  final int effort;

  const PokemonStat({required this.name, required this.value, this.effort = 0});

  factory PokemonStat.fromJson(Map<String, dynamic> json) => PokemonStat(
    name: json['stat']['name'] as String,
    value: json['base_stat'] as int,
    effort: json['effort'] as int? ?? 0,
  );
}

/// Cómo aprende un movimiento.
enum LearnMethod { level, machine, egg, tutor, other }

/// Un movimiento que puede aprender, en la versión más reciente en la que
/// aparece el Pokémon (ver [Pokemon.fromJson]).
class PokemonMoveRef {
  final String name;
  final String url;
  final LearnMethod method;
  final int level;

  /// Grupo de versiones de la PokeAPI del que sale ("scarlet-violet").
  final String version;

  const PokemonMoveRef({
    required this.name,
    required this.url,
    required this.method,
    this.level = 0,
    this.version = '',
  });
}

/// Grupos de versiones, del que más interesa al que menos. Escarlata y
/// Púrpura manda; las entregas con sistemas de movimientos raros van al final.
const List<String> _versionRank = [
  'scarlet-violet',
  'the-teal-mask',
  'the-indigo-disk',
  'sword-shield',
  'the-isle-of-armor',
  'the-crown-tundra',
  'brilliant-diamond-shining-pearl',
  'ultra-sun-ultra-moon',
  'sun-moon',
  'omega-ruby-alpha-sapphire',
  'x-y',
  'black-2-white-2',
  'black-white',
  'heartgold-soulsilver',
  'platinum',
  'diamond-pearl',
  'firered-leafgreen',
  'emerald',
  'ruby-sapphire',
  'crystal',
  'gold-silver',
  'yellow',
  'red-blue',
  'legends-za',
  'legends-arceus',
  'lets-go-pikachu-lets-go-eevee',
];

int _rankOf(String group) {
  final i = _versionRank.indexOf(group);
  return i < 0 ? _versionRank.length : i;
}

/// Movimientos de una sola versión: la mejor en la que sale este Pokémon.
/// Mezclar versiones daría movimientos que ya no aprende.
List<PokemonMoveRef> _parseMoves(List? raw) {
  if (raw == null) return const [];
  final entries = raw.whereType<Map>().where((m) => m['move'] is Map).toList();
  var best = _versionRank.length + 1;
  var bestName = '';
  for (final m in entries) {
    for (final d in (m['version_group_details'] as List? ?? const []).whereType<Map>()) {
      final name = d['version_group']?['name'] as String? ?? '';
      final r = _rankOf(name);
      if (r < best) {
        best = r;
        bestName = name;
      }
    }
  }
  final out = <PokemonMoveRef>[];
  for (final m in entries) {
    final move = m['move'] as Map;
    final seen = <LearnMethod>{};
    for (final d in (m['version_group_details'] as List? ?? const []).whereType<Map>()) {
      if (_rankOf(d['version_group']?['name'] as String? ?? '') != best) continue;
      final method = switch (d['move_learn_method']?['name']) {
        'level-up' => LearnMethod.level,
        'machine' => LearnMethod.machine,
        'egg' => LearnMethod.egg,
        'tutor' => LearnMethod.tutor,
        _ => LearnMethod.other,
      };
      // Por nivel puede aprenderlo dos veces (al evolucionar y a nivel 30).
      if (!seen.add(method) && method != LearnMethod.level) continue;
      out.add(
        PokemonMoveRef(
          name: move['name'] as String,
          url: move['url'] as String,
          method: method,
          level: d['level_learned_at'] as int? ?? 0,
          version: bestName,
        ),
      );
    }
  }
  return out;
}

/// Una forma de la misma variante que sólo cambia de aspecto (y a veces de
/// tipo): los 18 tipos de Arceus, las letras de Unown, los diseños de Vivillon…
class FormRef {
  final String name;
  final String url;

  const FormRef(this.name, this.url);
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

  /// Sprite animado de Pokémon Showdown (GIF en movimiento), normal y shiny.
  /// Faltan en unos pocos de la novena generación: ahí se queda el arte.
  final String? animatedUrl;
  final String? animatedShinyUrl;

  /// Especie a la que pertenece: en las variantes (megas, regionales…) el id
  /// del Pokémon es de 10001 en adelante y la especie es la de siempre.
  final int speciesId;
  final String speciesName;

  /// Formas de aspecto de esta variante (ver [FormRef]). La primera es ella.
  final List<FormRef> forms;

  final List<PokemonMoveRef> moves;

  /// Arte propio de una forma de aspecto (Arceus de tipo Fuego, por ejemplo).
  /// `null` = el arte normal del [id].
  final String? formArt;
  final String? formShinyArt;

  /// Nombre de la forma de aspecto que se está mostrando, si es una.
  final String? formName;

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
    this.animatedUrl,
    this.animatedShinyUrl,
    int? speciesId,
    String? speciesName,
    this.forms = const [],
    this.moves = const [],
    this.formArt,
    this.formShinyArt,
    this.formName,
  }) : speciesId = speciesId ?? id,
       speciesName = speciesName ?? name;

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final artwork = json['sprites']?['other']?['official-artwork'] as Map? ?? const {};
    final cries = json['cries'] as Map? ?? const {};
    final showdown = json['sprites']?['other']?['showdown'] as Map? ?? const {};
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
      animatedUrl: showdown['front_default'] as String?,
      animatedShinyUrl: showdown['front_shiny'] as String?,
      speciesId: json['species'] is Map ? _idFromUrl(json['species']['url'] as String) : id,
      speciesName: json['species'] is Map ? json['species']['name'] as String : null,
      forms: [
        for (final f in (json['forms'] as List? ?? const []).whereType<Map>())
          FormRef(f['name'] as String, f['url'] as String),
      ],
      moves: _parseMoves(json['moves'] as List?),
    );
  }

  /// Esta misma variante con el aspecto de una forma (`GET /pokemon-form/`).
  Pokemon withForm(Map<String, dynamic> form) {
    final sprites = form['sprites'] as Map? ?? const {};
    final art = sprites['other']?['official-artwork'] as Map? ?? const {};
    final showdown = sprites['other']?['showdown'] as Map? ?? const {};
    final formTypes = (form['types'] as List? ?? const []).cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (a['slot'] as int).compareTo(b['slot'] as int));
    return Pokemon(
      id: id,
      name: name,
      height: height,
      weight: weight,
      baseExperience: baseExperience,
      types: formTypes.isEmpty ? types : [for (final t in formTypes) t['type']['name'] as String],
      stats: stats,
      abilities: abilities,
      imageUrl: art['front_default'] as String? ?? imageUrl,
      shinyImageUrl: art['front_shiny'] as String? ?? shinyImageUrl,
      cryUrl: cryUrl,
      movesCount: movesCount,
      animatedUrl: showdown['front_default'] as String? ?? animatedUrl,
      animatedShinyUrl: showdown['front_shiny'] as String? ?? animatedShinyUrl,
      speciesId: speciesId,
      speciesName: speciesName,
      forms: forms,
      moves: moves,
      formArt: art['front_default'] as String?,
      formShinyArt: art['front_shiny'] as String?,
      formName: form['name'] as String?,
    );
  }

  /// Es una variante (mega, regional…) y no la forma base de su especie.
  bool get isVariant => id != speciesId;

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

  /// Variantes de la especie (la base, megas, regionales, gigamax…).
  final List<({String name, int id, bool isDefault})> varieties;

  /// Octavos de probabilidad de ser hembra; -1 = sin género.
  final int genderRate;
  final List<String> eggGroups;
  final int hatchCounter;
  final String? growthRate;
  final bool isBaby;

  const PokemonSpecies({
    required this.description,
    required this.genus,
    required this.evolutionChainUrl,
    required this.captureRate,
    required this.isLegendary,
    required this.isMythical,
    required this.habitat,
    this.varieties = const [],
    this.genderRate = -1,
    this.eggGroups = const [],
    this.hatchCounter = 0,
    this.growthRate,
    this.isBaby = false,
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
      varieties: [
        for (final v in (json['varieties'] as List? ?? const []).whereType<Map>())
          (
            name: v['pokemon']['name'] as String,
            id: _idFromUrl(v['pokemon']['url'] as String),
            isDefault: v['is_default'] as bool? ?? false,
          ),
      ],
      genderRate: json['gender_rate'] as int? ?? -1,
      eggGroups: [
        for (final g in (json['egg_groups'] as List? ?? const []).whereType<Map>())
          g['name'] as String,
      ],
      hatchCounter: json['hatch_counter'] as int? ?? 0,
      growthRate: json['growth_rate']?['name'] as String?,
      isBaby: json['is_baby'] as bool? ?? false,
    );
  }
}

/// Un paso de la cadena evolutiva (`GET /evolution-chain/{id}/`).
class EvolutionStep {
  final int id;
  final String name;

  /// Etiqueta corta para la flecha ("Nv. 16", "Piedra agua").
  final String? condition;

  /// La condición completa, para leerla en una frase: "al usarle una Piedra
  /// agua", "al subir de nivel con mucha amistad de día".
  final String? howTo;

  /// Objeto que hace falta (nombre de la API), para enseñar su dibujo.
  final String? item;

  /// Si no basta con subir de nivel: piedras, intercambios, amistad, lugares…
  final bool special;

  /// De quién evoluciona (`null` en la primera etapa).
  final int? parentId;
  final String? parentName;

  const EvolutionStep({
    required this.id,
    required this.name,
    this.parentId,
    this.parentName,
    this.condition,
    this.howTo,
    this.item,
    this.special = false,
  });

  String get imageUrl => artworkUrl(id);

  /// Aplana el árbol evolutivo en etapas (cada etapa puede tener ramas, ej. Eevee).
  static List<List<EvolutionStep>> parseChain(Map<String, dynamic> json) {
    final stages = <List<EvolutionStep>>[];
    // Cada nodo va con su padre, para poder decir "X evoluciona en Y".
    var current = <(Map<String, dynamic>, Map<String, dynamic>?)>[
      (json['chain'] as Map<String, dynamic>, null),
    ];
    while (current.isNotEmpty) {
      stages.add(
        current.map((pair) {
          final (node, parent) = pair;
          final details = (node['evolution_details'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          // La PokeAPI guarda cómo evolucionaba en cada juego; `is_default`
          // marca el método actual (Leafeon: antes una roca musgo, hoy la
          // Piedra hoja). Sin marca, el último registrado.
          final d = details.isEmpty
              ? null
              : details.firstWhere((e) => e['is_default'] == true, orElse: () => details.last);
          final how = d == null ? null : describe(d);
          return EvolutionStep(
            id: _idFromUrl(node['species']['url'] as String),
            name: node['species']['name'] as String,
            parentId: parent == null ? null : _idFromUrl(parent['species']['url'] as String),
            parentName: parent?['species']['name'] as String?,
            condition: how?.short,
            howTo: how?.sentence,
            item: how?.item,
            special: how?.special ?? false,
          );
        }).toList(),
      );
      current = [
        for (final (node, _) in current)
          for (final child in (node['evolves_to'] as List).cast<Map<String, dynamic>>())
            (child, node),
      ];
    }
    return stages;
  }

  /// Traduce un `evolution_details` a una etiqueta corta y a una frase.
  static ({String short, String sentence, String? item, bool special}) describe(
    Map<String, dynamic> d,
  ) {
    String? nameOf(String key) => (d[key] as Map?)?['name'] as String?;

    final trigger = nameOf('trigger');
    final item = nameOf('item');
    final held = nameOf('held_item');
    final time = switch (d['time_of_day']) {
      'day' => 'de día',
      'night' => 'de noche',
      'dusk' => 'al atardecer',
      _ => null,
    };

    // Condiciones extra, en el orden en que se leen mejor.
    final extras = <String>[
      if (d['min_happiness'] != null) 'con mucha amistad',
      if (d['min_affection'] != null) 'con mucho afecto',
      if (d['min_beauty'] != null) 'con mucha belleza',
      if (nameOf('known_move') != null) 'conociendo ${_move(nameOf('known_move')!)}',
      if (nameOf('known_move_type') != null)
        'conociendo un movimiento de tipo ${_typeName(nameOf('known_move_type')!)}',
      if (held != null && trigger != 'trade') 'mientras lleva ${_withArticle(held)}',
      if (d['near_special_rock'] == true || nameOf('location') != null) 'en un lugar especial',
      if (d['needs_overworld_rain'] == true) 'mientras llueve',
      if (d['turn_upside_down'] == true) 'con la consola boca abajo',
      if (nameOf('party_species') != null)
        'con ${_displayName(nameOf('party_species')!)} en el equipo',
      if (nameOf('party_type') != null)
        'con un Pokémon de tipo ${_typeName(nameOf('party_type')!)} en el equipo',
      if (d['relative_physical_stats'] == 1) 'si su Ataque supera a su Defensa',
      if (d['relative_physical_stats'] == -1) 'si su Defensa supera a su Ataque',
      if (d['relative_physical_stats'] == 0) 'si su Ataque y su Defensa son iguales',
      ?time,
      if (d['gender'] == 1) '(sólo hembras)',
      if (d['gender'] == 2) '(sólo machos)',
    ];
    String join(String base) => [base, ...extras].join(' ');

    final level = d['min_level'] as int?;
    switch (trigger) {
      case 'use-item' when item != null:
        return (
          short: _item(item),
          sentence: join('al usarle ${_withArticle(item)}'),
          item: item,
          special: true,
        );
      case 'trade':
        final partner = nameOf('trade_species');
        final base = [
          'al intercambiarlo',
          if (held != null) 'mientras lleva ${_withArticle(held)}',
          if (partner != null) 'por un ${_displayName(partner)}',
        ].join(' ');
        return (
          short: held != null ? 'Intercambio con ${_item(held)}' : 'Intercambio',
          sentence: join(base),
          item: held,
          special: true,
        );
      case 'level-up' || 'in-battle-level-up' || null:
        if (level != null) {
          final s = level <= 1 ? 'al subir de nivel' : 'al llegar al nivel $level';
          return (
            short: 'Nv. $level${time == null ? '' : ' $time'}',
            sentence: join(trigger == 'in-battle-level-up' ? '$s durante un combate' : s),
            item: held,
            special: extras.isNotEmpty,
          );
        }
        final short = d['min_happiness'] != null
            ? 'Amistad${time == null ? '' : ' $time'}'
            : d['min_affection'] != null
            ? 'Afecto'
            : nameOf('known_move') != null
            ? 'Con ${_move(nameOf('known_move')!)}'
            : nameOf('known_move_type') != null
            ? 'Mov. ${_typeName(nameOf('known_move_type')!)}'
            : held != null
            ? 'Con ${_item(held)}'
            : d['near_special_rock'] == true || nameOf('location') != null
            ? 'Lugar especial'
            : 'Subir nivel';
        return (
          short: short,
          sentence: join('al subir de nivel'),
          item: held,
          special: extras.isNotEmpty,
        );
    }

    final move = nameOf('used_move') ?? nameOf('known_move');
    final (short, sentence) = switch (trigger) {
      'shed' => ('Hueco libre', 'al evolucionar Nincada, si hay hueco en el equipo y una Poké Ball de sobra'),
      'spin' => ('Girar', 'al dar vueltas con el personaje mientras lleva un confite'),
      'tower-of-darkness' => ('Torre Siniestra', 'al superar la Torre del Puño Siniestro'),
      'tower-of-waters' => ('Torre Fluida', 'al superar la Torre del Puño Fluido'),
      'three-critical-hits' => ('3 críticos', 'al asestar tres golpes críticos en un mismo combate'),
      'take-damage' => ('Recibir daño', 'tras recibir mucho daño y pasar bajo el arco de piedra de las Ruinas'),
      'agile-style-move' => (
        'Estilo rápido',
        'al usar ${move == null ? 'su movimiento' : _move(move)} 20 veces en estilo rápido',
      ),
      'strong-style-move' => (
        'Estilo fuerte',
        'al usar ${move == null ? 'su movimiento' : _move(move)} 20 veces en estilo fuerte',
      ),
      'recoil-damage' => ('Retroceso', 'al perder 294 PS por daño de retroceso sin debilitarse'),
      'use-move' => (
        'Usar movimiento',
        'al usar ${move == null ? 'cierto movimiento' : _move(move)} 20 veces',
      ),
      'three-defeated-bisharp' => ('3 Bisharp', 'al derrotar a tres Bisharp que lleven el Filo del General'),
      'gimmighoul-coins' => ('999 monedas', 'al reunir 999 monedas de Gimmighoul y subir de nivel'),
      'meltan-candies' => ('400 caramelos', 'con 400 caramelos de Meltan en Pokémon GO'),
      _ => (_pretty(trigger), 'de una forma especial'),
    };
    return (short: short, sentence: join(sentence), item: null, special: true);
  }

  static String _displayName(String api) =>
      api.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  static const Map<String, String> _types = {
    'normal': 'Normal', 'fire': 'Fuego', 'water': 'Agua', 'electric': 'Eléctrico', //
    'grass': 'Planta', 'ice': 'Hielo', 'fighting': 'Lucha', 'poison': 'Veneno',
    'ground': 'Tierra', 'flying': 'Volador', 'psychic': 'Psíquico', 'bug': 'Bicho',
    'rock': 'Roca', 'ghost': 'Fantasma', 'dragon': 'Dragón', 'dark': 'Siniestro',
    'steel': 'Acero', 'fairy': 'Hada',
  };

  static String _typeName(String t) => _types[t] ?? _pretty(t);

  /// Movimientos que aparecen en evoluciones, en español.
  static String _move(String name) => switch (name) {
    'ancient-power' => 'Poder Pasado',
    'mimic' => 'Mimético',
    'double-hit' => 'Doble Golpe',
    'rollout' => 'Desenrollar',
    'stomp' => 'Pisotón',
    'dragon-pulse' => 'Pulso Dragón',
    'rage-fist' => 'Puño Furia',
    'barb-barrage' => 'Mil Púas Tóxicas',
    'psyshield-bash' => 'Asalto Barrera',
    'twin-beam' => 'Rayo Gemelo',
    'hyper-drill' => 'Taladradora',
    'dragon-cheer' => 'Ánimo Dragón',
    _ => _pretty(name),
  };

  /// Objetos de evolución, en español; el resto queda tal cual.
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
    'sweet-apple' => 'Manzana dulce',
    'tart-apple' => 'Manzana ácida',
    'syrupy-apple' => 'Manzana melosa',
    'cracked-pot' => 'Tetera agrietada',
    'chipped-pot' => 'Tetera rota',
    'galarica-cuff' => 'Brazal galanoga',
    'galarica-wreath' => 'Corona galanoga',
    'black-augurite' => 'Mineral negro',
    'peat-block' => 'Bloque de turba',
    'linking-cord' => 'Cordón unión',
    'auspicious-armor' => 'Armadura de la fortuna',
    'malicious-armor' => 'Armadura de la ruina',
    'unremarkable-teacup' => 'Cuenco mediocre',
    'masterpiece-teacup' => 'Cuenco exquisito',
    'metal-alloy' => 'Metal compuesto',
    'scroll-of-darkness' => 'Manuscrito Siniestro',
    'scroll-of-waters' => 'Manuscrito Fluido',
    'leaders-crest' => 'Filo del General',
    _ => _pretty(name),
  };

  /// "una Piedra agua", "un Protector": el artículo según el objeto.
  static String _withArticle(String item) {
    final label = _item(item);
    const masculine = {
      'kings-rock': false,
      'metal-coat': true,
      'up-grade': false,
      'dubious-disc': true,
      'protector': true,
      'electirizer': true,
      'magmarizer': true,
      'razor-fang': true,
      'deep-sea-tooth': true,
      'sachet': true,
      'whipped-dream': true,
      'galarica-cuff': true,
      'black-augurite': true,
      'peat-block': true,
      'linking-cord': true,
      'unremarkable-teacup': true,
      'masterpiece-teacup': true,
      'metal-alloy': true,
      'scroll-of-darkness': true,
      'scroll-of-waters': true,
      'leaders-crest': true,
    };
    return '${masculine[item] == true ? 'un' : 'una'} $label';
  }

  static String _pretty(String s) =>
      s.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

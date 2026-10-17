/// Datos fijos de la Pokédex que la PokeAPI no da en una sola petición:
/// generaciones, categorías especiales, parientes paradoja, megapiedras y
/// los nombres en español de las formas.
///
/// Para filtrar por generación o por categoría haría falta pedir la especie
/// de los 1025 Pokémon; estas listas no cambian, así que van aquí.
library;

import '../theme/app_theme.dart';

class Generation {
  final int number;
  final String roman;
  final String region;
  final int first;
  final int last;

  const Generation(this.number, this.roman, this.region, this.first, this.last);

  bool contains(int dexId) => dexId >= first && dexId <= last;
  String get label => 'Gen $roman · $region';
}

const List<Generation> kGenerations = [
  Generation(1, 'I', 'Kanto', 1, 151),
  Generation(2, 'II', 'Johto', 152, 251),
  Generation(3, 'III', 'Hoenn', 252, 386),
  Generation(4, 'IV', 'Sinnoh', 387, 493),
  Generation(5, 'V', 'Teselia', 494, 649),
  Generation(6, 'VI', 'Kalos', 650, 721),
  Generation(7, 'VII', 'Alola', 722, 809),
  Generation(8, 'VIII', 'Galar', 810, 905),
  Generation(9, 'IX', 'Paldea', 906, 1025),
];

Generation? generationOf(int dexId) {
  for (final g in kGenerations) {
    if (g.contains(dexId)) return g;
  }
  return null;
}

Set<int> _ranges(List<(int, int)> ranges) => {
  for (final (a, b) in ranges)
    for (var i = a; i <= b; i++) i,
};

/// Categorías de la Pokédex. Las de especie se filtran por número; las de
/// forma (megas, regionales…) muestran las variantes de la PokeAPI.
enum DexCategory {
  starter('Iniciales', 'Los tres de cada región, con sus evoluciones'),
  legendary('Legendarios', 'Los de las leyendas de cada región'),
  mythical('Singulares', 'Los que sólo se conseguían en eventos'),
  pseudo('Pseudolegendarios', 'Dragones de tres etapas con 600 puntos'),
  ultraBeast('Ultraentes', 'Llegados de otra dimensión (Alola)'),
  paradox('Paradoja', 'Versiones del pasado y del futuro (Paldea)'),
  baby('Bebés', 'Preevoluciones que nacen de un huevo'),
  fossil('Fósiles', 'Revividos a partir de un fósil'),
  regional('Formas regionales', 'Alola, Galar, Hisui y Paldea'),
  mega('Megaevoluciones', 'Con su megapiedra, sólo en combate'),
  gmax('Gigamax', 'Gigantes de Galar'),
  otherForms('Otras formas', 'Formas alternativas, Origen, Primigenio…');

  final String label;
  final String hint;

  const DexCategory(this.label, this.hint);

  /// Las que listan variantes (ids 10001 en adelante) en lugar de especies.
  bool get isForm => this == regional || this == mega || this == gmax || this == otherForms;
}

final Map<DexCategory, Set<int>> kCategoryIds = {
  DexCategory.starter: _ranges([
    (1, 9), (152, 160), (252, 260), (387, 395), (495, 503), //
    (650, 658), (722, 730), (810, 818), (906, 914),
  ]),
  DexCategory.legendary: {
    144, 145, 146, 150, 243, 244, 245, 249, 250, 377, 378, 379, 380, 381, 382, 383, 384, //
    480, 481, 482, 483, 484, 485, 486, 487, 488, 638, 639, 640, 641, 642, 643, 644, 645,
    646, 716, 717, 718, 772, 773, 785, 786, 787, 788, 789, 790, 791, 792, 800, 888, 889,
    890, 891, 892, 894, 895, 896, 897, 898, 905, 1001, 1002, 1003, 1004, 1007, 1008,
    1014, 1015, 1016, 1017, 1024,
  },
  DexCategory.mythical: {
    151, 251, 385, 386, 489, 490, 491, 492, 493, 494, 647, 648, 649, 719, 720, 721, 801, //
    802, 807, 808, 809, 893, 1025,
  },
  DexCategory.pseudo: _ranges([
    (147, 149), (246, 248), (371, 373), (374, 376), (443, 445), //
    (633, 635), (704, 706), (782, 784), (885, 887), (996, 998),
  ]),
  DexCategory.ultraBeast: {793, 794, 795, 796, 797, 798, 799, 803, 804, 805, 806},
  DexCategory.paradox: {
    984, 985, 986, 987, 988, 989, 990, 991, 992, 993, 994, 995, 1005, 1006, 1009, 1010, //
    1020, 1021, 1022, 1023,
  },
  DexCategory.baby: {
    172, 173, 174, 175, 236, 238, 239, 240, 298, 360, 406, 433, 438, 439, 440, 446, 447, //
    458, 848,
  },
  DexCategory.fossil: {
    138, 139, 140, 141, 142, 345, 346, 347, 348, 408, 409, 410, 411, 564, 565, 566, 567, //
    696, 697, 698, 699, 880, 881, 882, 883,
  },
};

/// Clase de forma, deducida del nombre de la variante en la PokeAPI.
enum FormKind { base, mega, gmax, primal, regional, other }

FormKind formKindOf(String apiName) {
  if (apiName.contains('-mega')) return FormKind.mega;
  if (apiName.endsWith('-gmax')) return FormKind.gmax;
  if (apiName.endsWith('-primal')) return FormKind.primal;
  if (RegExp(r'-(alola|galar|hisui|paldea)').hasMatch(apiName)) return FormKind.regional;
  return FormKind.other;
}

DexCategory? categoryOfForm(String apiName) => switch (formKindOf(apiName)) {
  FormKind.mega => DexCategory.mega,
  FormKind.gmax => DexCategory.gmax,
  FormKind.regional => DexCategory.regional,
  _ => DexCategory.otherForms,
};

/// Un Pokémon paradoja y su pariente de hoy.
class ParadoxLink {
  final int paradox;
  final int modern;

  /// `true` = del pasado; `false` = del futuro.
  final bool ancient;

  const ParadoxLink(this.paradox, this.modern, {required this.ancient});
}

const List<ParadoxLink> kParadoxLinks = [
  ParadoxLink(984, 232, ancient: true),
  ParadoxLink(985, 39, ancient: true),
  ParadoxLink(986, 591, ancient: true),
  ParadoxLink(987, 200, ancient: true),
  ParadoxLink(988, 637, ancient: true),
  ParadoxLink(989, 82, ancient: true),
  ParadoxLink(990, 232, ancient: false),
  ParadoxLink(991, 225, ancient: false),
  ParadoxLink(992, 297, ancient: false),
  ParadoxLink(993, 635, ancient: false),
  ParadoxLink(994, 637, ancient: false),
  ParadoxLink(995, 248, ancient: false),
  ParadoxLink(1005, 373, ancient: true),
  ParadoxLink(1006, 282, ancient: false),
  ParadoxLink(1006, 475, ancient: false),
  ParadoxLink(1007, 967, ancient: true),
  ParadoxLink(1008, 967, ancient: false),
  ParadoxLink(1009, 245, ancient: true),
  ParadoxLink(1010, 640, ancient: false),
  ParadoxLink(1020, 244, ancient: true),
  ParadoxLink(1021, 243, ancient: true),
  ParadoxLink(1022, 639, ancient: false),
  ParadoxLink(1023, 638, ancient: false),
];

/// Parientes paradoja de un Pokémon (en las dos direcciones).
List<({int id, String label})> paradoxRelatives(int dexId) => [
  for (final l in kParadoxLinks)
    if (l.modern == dexId)
      (id: l.paradox, label: l.ancient ? 'Del pasado' : 'Del futuro')
    else if (l.paradox == dexId)
      (id: l.modern, label: 'Versión actual'),
];

/// Megapiedras (y prismas) con su nombre en español.
const Map<String, (String item, String label)> kMegaStones = {
  'venusaur-mega': ('venusaurite', 'Venusaurita'),
  'charizard-mega-x': ('charizardite-x', 'Charizardita X'),
  'charizard-mega-y': ('charizardite-y', 'Charizardita Y'),
  'blastoise-mega': ('blastoisinite', 'Blastoisita'),
  'beedrill-mega': ('beedrillite', 'Beedrillita'),
  'pidgeot-mega': ('pidgeotite', 'Pidgeotita'),
  'alakazam-mega': ('alakazite', 'Alakazamita'),
  'slowbro-mega': ('slowbronite', 'Slowbronita'),
  'gengar-mega': ('gengarite', 'Gengarita'),
  'kangaskhan-mega': ('kangaskhanite', 'Kangaskhanita'),
  'pinsir-mega': ('pinsirite', 'Pinsirita'),
  'gyarados-mega': ('gyaradosite', 'Gyaradosita'),
  'aerodactyl-mega': ('aerodactylite', 'Aerodactylita'),
  'mewtwo-mega-x': ('mewtwonite-x', 'Mewtwoita X'),
  'mewtwo-mega-y': ('mewtwonite-y', 'Mewtwoita Y'),
  'ampharos-mega': ('ampharosite', 'Ampharosita'),
  'steelix-mega': ('steelixite', 'Steelixita'),
  'scizor-mega': ('scizorite', 'Scizorita'),
  'heracross-mega': ('heracronite', 'Heracrossita'),
  'houndoom-mega': ('houndoominite', 'Houndoomita'),
  'tyranitar-mega': ('tyranitarite', 'Tyranitarita'),
  'sceptile-mega': ('sceptilite', 'Sceptilita'),
  'blaziken-mega': ('blazikenite', 'Blazikenita'),
  'swampert-mega': ('swampertite', 'Swampertita'),
  'gardevoir-mega': ('gardevoirite', 'Gardevoirita'),
  'sableye-mega': ('sablenite', 'Sableynita'),
  'mawile-mega': ('mawilite', 'Mawilita'),
  'aggron-mega': ('aggronite', 'Aggronita'),
  'medicham-mega': ('medichamite', 'Medichamita'),
  'manectric-mega': ('manectite', 'Manectricita'),
  'sharpedo-mega': ('sharpedonite', 'Sharpedonita'),
  'camerupt-mega': ('cameruptite', 'Cameruptita'),
  'altaria-mega': ('altarianite', 'Altarianita'),
  'banette-mega': ('banettite', 'Banettita'),
  'absol-mega': ('absolite', 'Absolita'),
  'glalie-mega': ('glalitite', 'Glalita'),
  'salamence-mega': ('salamencite', 'Salamencita'),
  'metagross-mega': ('metagrossite', 'Metagrossita'),
  'latias-mega': ('latiasite', 'Latiasita'),
  'latios-mega': ('latiosite', 'Latiosita'),
  'lopunny-mega': ('lopunnite', 'Lopunnita'),
  'garchomp-mega': ('garchompite', 'Garchompita'),
  'lucario-mega': ('lucarionite', 'Lucarionita'),
  'abomasnow-mega': ('abomasite', 'Abomasnowita'),
  'gallade-mega': ('galladite', 'Galladita'),
  'audino-mega': ('audinite', 'Audinita'),
  'diancie-mega': ('diancite', 'Diancita'),
  'kyogre-primal': ('blue-orb', 'Prisma azul'),
  'groudon-primal': ('red-orb', 'Prisma rojo'),
};

/// Cómo se consigue una forma especial, en una frase.
String? specialFormHowTo(String apiName) {
  final stone = kMegaStones[apiName];
  if (apiName == 'rayquaza-mega') {
    return 'Megaevoluciona sin megapiedra: le basta con conocer Ascenso del Dragón.';
  }
  return switch (formKindOf(apiName)) {
    FormKind.mega =>
      'Megaevoluciona en combate si lleva ${stone == null ? 'su megapiedra' : 'la ${stone.$2}'} '
          'y su entrenador tiene un Megaaro.',
    FormKind.primal =>
      'Regresión primigenia: cambia al entrar en combate llevando el ${stone?.$2 ?? 'prisma'}.',
    FormKind.gmax =>
      'Se gigamaxiza en Galar si tiene el Factor Gigamax: crece y cambia de aspecto durante '
          'tres turnos.',
    _ => null,
  };
}

/// Sprite del objeto en el repositorio de PokeAPI.
String itemSpriteUrl(String item) =>
    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/$item.png';

/// Palabras de los nombres de forma, en español.
const Map<String, String> _formWords = {
  'mega': 'Mega',
  'gmax': 'Gigamax',
  'primal': 'Primigenio',
  'alola': 'de Alola',
  'galar': 'de Galar',
  'hisui': 'de Hisui',
  'paldea': 'de Paldea',
  'origin': 'Forma Origen',
  'altered': 'Forma Modificada',
  'sky': 'Forma Cielo',
  'land': 'Forma Tierra',
  'therian': 'Forma Tótem',
  'incarnate': 'Forma Avatar',
  'attack': 'Forma Ataque',
  'defense': 'Forma Defensa',
  'speed': 'Forma Velocidad',
  'normal': 'Forma Normal',
  'combat-breed': 'Raza Combatiente',
  'blaze-breed': 'Raza Ardiente',
  'aqua-breed': 'Raza Acuática',
  'crowned': 'Rey de los Héroes',
  'eternamax': 'Dinamax Infinito',
  'black': 'Negro',
  'white': 'Blanco',
  'ultra': 'Ultra',
  'dusk-mane': 'Melena Crepuscular',
  'dawn-wings': 'Alas del Alba',
  'school': 'Forma Banco',
  'complete': 'Forma Completa',
  'unbound': 'Desatado',
  'resolute': 'Forma Brío',
  'pirouette': 'Forma Danza',
  'zen': 'Modo Daruma',
  'blade': 'Forma Filo',
  'busted': 'Encubierta rota',
  'hangry': 'Forma Voraz',
  'noice': 'Cara Deshielo',
  'female': 'Hembra',
  'male': 'Macho',
  'starter': 'Compañero',
  'totem': 'Dominante',
  'stellar': 'Teracristal Astral',
  'terastal': 'Forma Teracristal',
  'hero': 'Forma Heroica',
  'roaming': 'Forma Andante',
  'family-of-three': 'Familia de tres',
  'midnight': 'Forma Nocturna',
  'dusk': 'Forma Crepuscular',
  'low-key': 'Forma Grave',
  'rainy': 'Forma Lluvia',
  'snowy': 'Forma Nieve',
  'sunny': 'Forma Sol',
  'sandy': 'Tronco Arena',
  'trash': 'Tronco Basura',
  'fan': 'Forma Ventilador',
  'frost': 'Forma Frío',
  'heat': 'Forma Calor',
  'mow': 'Forma Corte',
  'wash': 'Forma Lavado',
  'rapid-strike': 'Estilo Fluido',
  'ice': 'Jinete Glacial',
  'shadow': 'Jinete Espectral',
  'wellspring-mask': 'Máscara Fuente',
  'hearthflame-mask': 'Máscara Horno',
  'cornerstone-mask': 'Máscara Cimiento',
  'bloodmoon': 'Luna Carmesí',
};

/// Nombre de una forma sin el de la especie: "Mega X", "de Alola", "Tipo Fuego".
String formLabel(String apiName, String speciesName) {
  var rest = apiName;
  if (rest.startsWith('$speciesName-')) rest = rest.substring(speciesName.length + 1);
  if (rest == apiName && !apiName.contains('-')) return 'Normal';
  if (rest == speciesName || rest.isEmpty) return 'Normal';
  if (kTypeStyles.containsKey(rest)) return 'Tipo ${kTypeStyles[rest]!.label}';
  final direct = _formWords[rest];
  if (direct != null) return direct;
  // "mega-x" → "Mega X"; "paldea-combat-breed" → "de Paldea · Raza Combatiente".
  if (rest.startsWith('mega-')) return 'Mega ${rest.substring(5).toUpperCase()}';
  for (final region in ['alola', 'galar', 'hisui', 'paldea']) {
    if (rest.startsWith('$region-')) {
      final tail = rest.substring(region.length + 1);
      return '${_formWords[region]} · ${_formWords[tail] ?? capitalize(tail)}';
    }
  }
  return capitalize(rest);
}

/// Nombre completo para una tarjeta: "Charizard Mega X", "Vulpix de Alola".
String formDisplayName(String apiName, String speciesName) {
  final label = formLabel(apiName, speciesName);
  final base = displayName(speciesName);
  if (label == 'Normal') return base;
  if (label.startsWith('Mega')) return 'Mega $base${label.substring(4)}';
  return '$base $label';
}

/// Tabla de tipos de la sexta generación en adelante.
///
/// Sólo se guardan los cruces que no son neutros: lo que no aparece vale 1.
library;

const Map<String, Map<String, double>> _chart = {
  'normal': {'rock': 0.5, 'ghost': 0, 'steel': 0.5},
  'fire': {
    'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 2, 'bug': 2, 'rock': 0.5, 'dragon': 0.5, //
    'steel': 2,
  },
  'water': {'fire': 2, 'water': 0.5, 'grass': 0.5, 'ground': 2, 'rock': 2, 'dragon': 0.5},
  'electric': {
    'water': 2, 'electric': 0.5, 'grass': 0.5, 'ground': 0, 'flying': 2, 'dragon': 0.5, //
  },
  'grass': {
    'fire': 0.5, 'water': 2, 'grass': 0.5, 'poison': 0.5, 'ground': 2, 'flying': 0.5, //
    'bug': 0.5, 'rock': 2, 'dragon': 0.5, 'steel': 0.5,
  },
  'ice': {
    'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 0.5, 'ground': 2, 'flying': 2, //
    'dragon': 2, 'steel': 0.5,
  },
  'fighting': {
    'normal': 2, 'ice': 2, 'poison': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, //
    'rock': 2, 'ghost': 0, 'dark': 2, 'steel': 2, 'fairy': 0.5,
  },
  'poison': {
    'grass': 2, 'poison': 0.5, 'ground': 0.5, 'rock': 0.5, 'ghost': 0.5, 'steel': 0, //
    'fairy': 2,
  },
  'ground': {
    'fire': 2, 'electric': 2, 'grass': 0.5, 'poison': 2, 'flying': 0, 'bug': 0.5, //
    'rock': 2, 'steel': 2,
  },
  'flying': {'electric': 0.5, 'grass': 2, 'fighting': 2, 'bug': 2, 'rock': 0.5, 'steel': 0.5},
  'psychic': {'fighting': 2, 'poison': 2, 'psychic': 0.5, 'dark': 0, 'steel': 0.5},
  'bug': {
    'fire': 0.5, 'grass': 2, 'fighting': 0.5, 'poison': 0.5, 'flying': 0.5, 'psychic': 2, //
    'ghost': 0.5, 'dark': 2, 'steel': 0.5, 'fairy': 0.5,
  },
  'rock': {
    'fire': 2, 'ice': 2, 'fighting': 0.5, 'ground': 0.5, 'flying': 2, 'bug': 2, 'steel': 0.5, //
  },
  'ghost': {'normal': 0, 'psychic': 2, 'ghost': 2, 'dark': 0.5},
  'dragon': {'dragon': 2, 'steel': 0.5, 'fairy': 0},
  'dark': {'fighting': 0.5, 'psychic': 2, 'ghost': 2, 'dark': 0.5, 'fairy': 0.5},
  'steel': {
    'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'ice': 2, 'rock': 2, 'steel': 0.5, 'fairy': 2, //
  },
  'fairy': {
    'fire': 0.5, 'fighting': 2, 'poison': 0.5, 'dragon': 2, 'dark': 2, 'steel': 0.5, //
  },
};

/// Todos los tipos, en el orden de los juegos.
const List<String> kAllTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', //
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
];

/// Multiplicador de un ataque de tipo [attack] contra un Pokémon de [defender].
double effectiveness(String attack, List<String> defender) {
  var m = 1.0;
  for (final d in defender) {
    m *= _chart[attack]?[d] ?? 1;
  }
  return m;
}

/// Cuánto le hace cada tipo de ataque a un Pokémon de estos tipos, agrupado
/// por multiplicador (4, 2, 0.5, 0.25, 0). Los neutros no se incluyen.
Map<double, List<String>> defensiveProfile(List<String> types) {
  final out = <double, List<String>>{};
  for (final attack in kAllTypes) {
    final m = effectiveness(attack, types);
    if (m != 1) (out[m] ??= []).add(attack);
  }
  return out;
}

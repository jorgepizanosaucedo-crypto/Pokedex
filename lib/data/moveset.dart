import '../models/move.dart';
import '../models/pokemon.dart';

// Reglas del combate contra Karen para que sea fiel a los juegos: qué
// movimientos sabe cada Pokémon y cómo se resuelve cada movimiento.

/// Nivel al que pelea el Pokémon en el combate.
const int kBattleLevel = 50;

/// Los movimientos que sabe un Pokémon de nivel [level] en los juegos.
///
/// Es la regla que usan los juegos para un Pokémon salvaje o regalado: los
/// últimos cuatro movimientos distintos que aprende subiendo de nivel hasta
/// ese nivel, en el orden en que los aprende. Un Charizard de nivel 50 en
/// Escarlata y Púrpura sabe Cuchillada, Lanzallamas, Cara Susto y Giro
/// Fuego, y nada que no pueda aprender.
List<String> defaultMoveset(List<PokemonMoveRef> pool, {int level = kBattleLevel}) {
  final byLevel = [
    for (final (i, m) in pool.indexed)
      if (m.method == LearnMethod.level && m.level <= level) (i, m),
  ]..sort((a, b) {
      final c = a.$2.level.compareTo(b.$2.level);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final names = <String>[];
  for (final (_, m) in byLevel) {
    // Si lo aprende dos veces, cuenta la última.
    names
      ..remove(m.name)
      ..add(m.name);
  }
  if (names.length > 4) return names.sublist(names.length - 4);
  if (names.isNotEmpty) return names;
  // Sin movimientos por nivel en esa versión: los primeros que aprenda.
  return pool.map((m) => m.name).toSet().take(4).toList();
}

/// Cómo se aprende, en corto: "Nv. 36", "Evo.", "MT", "Huevo", "Tutor".
String learnLabel(PokemonMoveRef ref) => switch (ref.method) {
      LearnMethod.level => ref.level == 0 ? 'Evo.' : 'Nv. ${ref.level <= 1 ? 1 : ref.level}',
      LearnMethod.machine => 'MT',
      LearnMethod.egg => 'Huevo',
      LearnMethod.tutor => 'Tutor',
      LearnMethod.other => 'Otro',
    };

/// Nombre del juego del que salen los movimientos de la PokeAPI.
String versionLabel(String group) => _versionNames[group] ?? '';

const Map<String, String> _versionNames = {
  'scarlet-violet': 'Escarlata y Púrpura',
  'the-teal-mask': 'Escarlata y Púrpura (La máscara turquesa)',
  'the-indigo-disk': 'Escarlata y Púrpura (El disco índigo)',
  'sword-shield': 'Espada y Escudo',
  'the-isle-of-armor': 'Espada y Escudo (La isla de la armadura)',
  'the-crown-tundra': 'Espada y Escudo (Las nieves de la corona)',
  'brilliant-diamond-shining-pearl': 'Diamante Brillante y Perla Reluciente',
  'ultra-sun-ultra-moon': 'Ultrasol y Ultraluna',
  'sun-moon': 'Sol y Luna',
  'omega-ruby-alpha-sapphire': 'Rubí Omega y Zafiro Alfa',
  'x-y': 'X e Y',
  'black-2-white-2': 'Negro 2 y Blanco 2',
  'black-white': 'Negro y Blanco',
  'heartgold-soulsilver': 'Oro HeartGold y Plata SoulSilver',
  'platinum': 'Platino',
  'diamond-pearl': 'Diamante y Perla',
  'firered-leafgreen': 'Rojo Fuego y Verde Hoja',
  'emerald': 'Esmeralda',
  'ruby-sapphire': 'Rubí y Zafiro',
  'crystal': 'Cristal',
  'gold-silver': 'Oro y Plata',
  'yellow': 'Amarillo',
  'red-blue': 'Rojo y Azul',
  'legends-za': 'Leyendas Pokémon: Z-A',
  'legends-arceus': 'Leyendas Pokémon: Arceus',
  'lets-go-pikachu-lets-go-eevee': "Let's Go, Pikachu! y Let's Go, Eevee!",
};

/// Cómo se resuelve un movimiento en el combate.
enum BattleMoveKind {
  /// Daño normal con la fórmula de los juegos.
  damage,

  /// Daño fijo: Sísmico y Tinieblas (el nivel), Furia Dragón (40)…
  fixed,

  /// Le quita la mitad de los PS que le quedan (Superdiente).
  halfHp,

  /// Fulminante: si acierta, debilita de un golpe (Fisura, Guillotina…).
  ohko,

  /// Devuelve el daño recibido (Contraataque, Manto Espejo…). Karen no hace
  /// daño de verdad, así que fallan, como en los juegos sin daño previo.
  reactive,

  /// Movimientos de estado.
  status,
}

const Set<String> _fixed = {'seismic-toss', 'night-shade', 'dragon-rage', 'sonic-boom', 'psywave'};
const Set<String> _halfHp = {'super-fang', 'natures-madness', 'ruination'};
const Set<String> _ohko = {'fissure', 'guillotine', 'horn-drill', 'sheer-cold'};
const Set<String> _reactive = {
  'counter',
  'mirror-coat',
  'metal-burst',
  'bide',
  'comeuppance',
  'endeavor',
  'final-gambit',
};

BattleMoveKind battleKindOf(MoveInfo m) {
  if (_ohko.contains(m.name)) return BattleMoveKind.ohko;
  if (_fixed.contains(m.name)) return BattleMoveKind.fixed;
  if (_halfHp.contains(m.name)) return BattleMoveKind.halfHp;
  if (_reactive.contains(m.name)) return BattleMoveKind.reactive;
  return m.damageClass == 'status' ? BattleMoveKind.status : BattleMoveKind.damage;
}

/// Potencia para la fórmula de daño. Los de potencia variable (Bola Voltio,
/// Azote, Patada Baja…) dependen de peso, velocidad o PS que aquí no
/// existen: se usa un valor típico de 60.
int battlePowerOf(MoveInfo m) => (m.power ?? 0) > 0 ? m.power! : 60;

/// Daño de los movimientos de daño fijo a nivel [level].
int fixedDamageOf(MoveInfo m, {int level = kBattleLevel}) => switch (m.name) {
      'dragon-rage' => 40,
      'sonic-boom' => 20,
      _ => level,
    };

/// Texto corto para el botón del movimiento.
String battleTagOf(MoveInfo m) => switch (battleKindOf(m)) {
      BattleMoveKind.damage => 'Pot. ${(m.power ?? 0) > 0 ? m.power : 'var.'}',
      BattleMoveKind.fixed => 'Daño fijo',
      BattleMoveKind.halfHp => 'Mitad de PS',
      BattleMoveKind.ohko => 'Fulminante',
      BattleMoveKind.reactive => 'Contraataque',
      BattleMoveKind.status => 'Estado',
    };

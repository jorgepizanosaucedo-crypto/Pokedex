import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/data/moveset.dart';
import 'package:pokedex_app/models/move.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/account.dart';
import 'package:pokedex_app/services/sound_service.dart';
import 'package:pokedex_app/theme/app_theme.dart';

PokemonMoveRef lv(String name, int level) => PokemonMoveRef(
  name: name,
  url: '',
  method: LearnMethod.level,
  level: level,
  version: 'scarlet-violet',
);

PokemonMoveRef tm(String name) =>
    PokemonMoveRef(name: name, url: '', method: LearnMethod.machine, version: 'scarlet-violet');

MoveInfo move(String name, {String damageClass = 'physical', int? power = 80}) => MoveInfo(
  name: name,
  label: name,
  type: 'normal',
  damageClass: damageClass,
  power: power,
  accuracy: 100,
  pp: 10,
  priority: 0,
  description: '',
  ailment: null,
  ailmentChance: 0,
  healing: 0,
  target: 'selected-pokemon',
  statChanges: const {},
  statChance: 0,
);

void main() {
  group('Movimientos como en el juego', () {
    // Charizard en Escarlata y Púrpura, tal como viene de la PokeAPI.
    final charizard = [
      lv('air-slash', 0),
      lv('dragon-claw', 1),
      lv('ember', 1),
      lv('growl', 1),
      lv('heat-wave', 1),
      lv('scratch', 1),
      lv('smokescreen', 1),
      lv('dragon-breath', 12),
      lv('fire-fang', 19),
      lv('slash', 24),
      lv('flamethrower', 30),
      lv('scary-face', 39),
      lv('fire-spin', 46),
      lv('inferno', 54),
      lv('flare-blitz', 62),
      tm('earthquake'),
      tm('solar-beam'),
    ];

    test('a nivel 50 sabe los últimos cuatro que aprende subiendo de nivel', () {
      expect(defaultMoveset(charizard), ['slash', 'flamethrower', 'scary-face', 'fire-spin']);
    });

    test('no mete MT ni movimientos de más nivel', () {
      final moves = defaultMoveset(charizard);
      expect(moves, isNot(contains('earthquake')));
      expect(moves, isNot(contains('inferno')));
      expect(moves, isNot(contains('flare-blitz')));
    });

    test('con pocos movimientos usa los que tiene (Magikarp)', () {
      expect(
        defaultMoveset([lv('splash', 1), lv('tackle', 15), lv('flail', 25)]),
        ['splash', 'tackle', 'flail'],
      );
    });

    test('si lo aprende dos veces, cuenta la última', () {
      expect(
        defaultMoveset([lv('tackle', 1), lv('growl', 5), lv('tackle', 30)]),
        ['growl', 'tackle'],
      );
    });

    test('etiquetas de cómo se aprende y de qué juego', () {
      expect(learnLabel(lv('air-slash', 0)), 'Evo.');
      expect(learnLabel(lv('flamethrower', 30)), 'Nv. 30');
      expect(learnLabel(tm('earthquake')), 'MT');
      expect(versionLabel('scarlet-violet'), 'Escarlata y Púrpura');
      expect(versionLabel('algo-nuevo'), '');
    });

    test('la PokeAPI dice de qué juego salen los movimientos', () {
      final pokemon = Pokemon.fromJson({
        'id': 25,
        'name': 'pikachu',
        'types': [
          {
            'slot': 1,
            'type': {'name': 'electric'},
          },
        ],
        'stats': [],
        'abilities': [],
        'moves': [
          {
            'move': {'name': 'thunderbolt', 'url': 'u'},
            'version_group_details': [
              {
                'level_learned_at': 36,
                'move_learn_method': {'name': 'level-up'},
                'version_group': {'name': 'scarlet-violet'},
              },
              {
                'level_learned_at': 26,
                'move_learn_method': {'name': 'level-up'},
                'version_group': {'name': 'red-blue'},
              },
            ],
          },
        ],
      });
      expect(pokemon.moves.single.version, 'scarlet-violet');
      expect(pokemon.moves.single.level, 36);
    });
  });

  group('Cómo se resuelve cada movimiento en el combate', () {
    test('tipo de movimiento', () {
      expect(battleKindOf(move('tackle')), BattleMoveKind.damage);
      expect(battleKindOf(move('splash', damageClass: 'status', power: null)), BattleMoveKind.status);
      expect(battleKindOf(move('seismic-toss', power: null)), BattleMoveKind.fixed);
      expect(battleKindOf(move('fissure', power: null)), BattleMoveKind.ohko);
      expect(battleKindOf(move('counter', power: null)), BattleMoveKind.reactive);
      expect(battleKindOf(move('super-fang', power: null)), BattleMoveKind.halfHp);
    });

    test('potencia variable, daño fijo y etiquetas', () {
      expect(battlePowerOf(move('flail', power: null)), 60);
      expect(battlePowerOf(move('thunderbolt', power: 90)), 90);
      expect(fixedDamageOf(move('seismic-toss', power: null)), kBattleLevel);
      expect(fixedDamageOf(move('dragon-rage', power: null)), 40);
      expect(battleTagOf(move('thunderbolt', power: 90)), 'Pot. 90');
      expect(battleTagOf(move('electro-ball', damageClass: 'special', power: null)), 'Pot. var.');
      expect(battleTagOf(move('splash', damageClass: 'status', power: null)), 'Estado');
    });
  });

  group('Cuenta', () {
    test('errores de Firebase en español', () {
      expect(Account.messageForCode('email-already-in-use'), contains('Ya hay una cuenta'));
      expect(Account.messageForCode('invalid-credential'), 'Correo o contraseña incorrectos.');
      expect(Account.messageForCode('weak-password'), contains('6 caracteres'));
      expect(Account.messageForCode('otra-cosa'), 'No se pudo completar. Inténtalo de nuevo.');
    });

    test('forma de correo', () {
      expect(Account.looksLikeEmail('jorge@ucol.mx'), isTrue);
      expect(Account.looksLikeEmail('  ash@pueblo.paleta  '), isTrue);
      expect(Account.looksLikeEmail('jorge@'), isFalse);
      expect(Account.looksLikeEmail('sin arroba'), isFalse);
    });
  });

  group('Sonidos', () {
    test('cada uno de los 18 tipos tiene su sonido', () {
      for (final type in kTypeStyles.keys) {
        expect(Sfx.forType(type), isNotNull, reason: type);
      }
      expect(Sfx.forType('fire'), Sfx.typeFire);
      expect(Sfx.forType(null), isNull);
    });

    test('todos los efectos tienen su archivo en assets/sounds', () {
      for (final sfx in Sfx.values) {
        expect(File('assets/sounds/${sfx.name}.wav').existsSync(), isTrue, reason: sfx.name);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/data/dex_data.dart';
import 'package:pokedex_app/data/type_chart.dart';
import 'package:pokedex_app/models/move.dart';
import 'package:pokedex_app/models/pokemon.dart';

void main() {
  group('tabla de tipos', () {
    test('multiplica los dos tipos del defensor', () {
      expect(effectiveness('ice', ['dragon', 'flying']), 4);
      expect(effectiveness('electric', ['ground']), 0);
      expect(effectiveness('fire', ['water', 'rock']), 0.25);
      expect(effectiveness('normal', ['grass']), 1);
    });

    test('perfil defensivo de Charizard', () {
      final profile = defensiveProfile(['fire', 'flying']);
      expect(profile[4], ['rock']);
      expect(profile[0], ['ground']);
      expect(profile[2], containsAll(['water', 'electric']));
      expect(profile[0.25], containsAll(['grass', 'bug']));
    });
  });

  group('formas', () {
    test('nombres en español', () {
      expect(formLabel('charizard-mega-x', 'charizard'), 'Mega X');
      expect(formLabel('giratina-origin', 'giratina'), 'Forma Origen');
      expect(formLabel('arceus-fire', 'arceus'), 'Tipo Fuego');
      expect(formLabel('vulpix-alola', 'vulpix'), 'de Alola');
      expect(formLabel('tauros-paldea-aqua-breed', 'tauros'), 'de Paldea · Raza Acuática');
      expect(formLabel('pikachu', 'pikachu'), 'Normal');
    });

    test('nombre completo para tarjetas', () {
      expect(formDisplayName('charizard-mega-y', 'charizard'), 'Mega Charizard Y');
      expect(formDisplayName('meowth-galar', 'meowth'), 'Meowth de Galar');
      expect(formDisplayName('kyogre-primal', 'kyogre'), 'Kyogre Primigenio');
    });

    test('clase de forma', () {
      expect(formKindOf('venusaur-mega'), FormKind.mega);
      expect(formKindOf('snorlax-gmax'), FormKind.gmax);
      expect(formKindOf('groudon-primal'), FormKind.primal);
      expect(formKindOf('zorua-hisui'), FormKind.regional);
      expect(formKindOf('dialga-origin'), FormKind.other);
    });

    test('cómo se consigue una mega', () {
      expect(specialFormHowTo('charizard-mega-x'), contains('Charizardita X'));
      expect(specialFormHowTo('rayquaza-mega'), contains('Ascenso del Dragón'));
      expect(specialFormHowTo('vulpix-alola'), isNull);
    });

    test('parientes paradoja en las dos direcciones', () {
      expect(paradoxRelatives(243).single.id, 1021); // Raikou → Electrofuria
      expect(paradoxRelatives(1021).single.id, 243);
      expect(paradoxRelatives(637).map((r) => r.id), containsAll([988, 994]));
    });
  });

  test('generaciones por número', () {
    expect(generationOf(1)!.region, 'Kanto');
    expect(generationOf(493)!.number, 4);
    expect(generationOf(1025)!.region, 'Paldea');
  });

  group('evoluciones', () {
    Map<String, dynamic> chain(List<Map<String, dynamic>> details) => {
      'chain': {
        'species': {'name': 'eevee', 'url': 'https://pokeapi.co/api/v2/pokemon-species/133/'},
        'evolution_details': [],
        'evolves_to': [
          {
            'species': {'name': 'leafeon', 'url': 'https://pokeapi.co/api/v2/pokemon-species/470/'},
            'evolution_details': details,
            'evolves_to': [],
          },
        ],
      },
    };

    test('usa el método marcado como actual y recuerda de quién viene', () {
      final step = EvolutionStep.parseChain(
        chain([
          {
            'trigger': {'name': 'level-up'},
            'location': {'name': 'eterna-forest'},
            'near_special_rock': true,
          },
          {
            'trigger': {'name': 'use-item'},
            'item': {'name': 'leaf-stone'},
            'is_default': true,
          },
        ]),
      )[1].single;
      expect(step.condition, 'Piedra hoja');
      expect(step.howTo, 'al usarle una Piedra hoja');
      expect(step.item, 'leaf-stone');
      expect(step.special, isTrue);
      expect(step.parentId, 133);
    });

    test('describe condiciones combinadas', () {
      final step = EvolutionStep.parseChain(
        chain([
          {
            'trigger': {'name': 'level-up'},
            'known_move_type': {'name': 'fairy'},
            'min_happiness': 160,
          },
        ]),
      )[1].single;
      expect(step.howTo, 'al subir de nivel con mucha amistad conociendo un movimiento de tipo Hada');
    });

    test('un nivel normal no es especial', () {
      final step = EvolutionStep.parseChain(
        chain([
          {
            'trigger': {'name': 'level-up'},
            'min_level': 16,
          },
        ]),
      )[1].single;
      expect(step.howTo, 'al llegar al nivel 16');
      expect(step.special, isFalse);
    });
  });

  group('movimientos', () {
    test('se quedan con la versión más reciente', () {
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
            'move': {'name': 'thunderbolt', 'url': 'u1'},
            'version_group_details': [
              {
                'level_learned_at': 26,
                'move_learn_method': {'name': 'level-up'},
                'version_group': {'name': 'red-blue'},
              },
              {
                'level_learned_at': 36,
                'move_learn_method': {'name': 'level-up'},
                'version_group': {'name': 'scarlet-violet'},
              },
            ],
          },
          {
            'move': {'name': 'old-move', 'url': 'u2'},
            'version_group_details': [
              {
                'level_learned_at': 0,
                'move_learn_method': {'name': 'machine'},
                'version_group': {'name': 'red-blue'},
              },
            ],
          },
        ],
      });
      expect(pokemon.moves, hasLength(1));
      expect(pokemon.moves.single.name, 'thunderbolt');
      expect(pokemon.moves.single.level, 36);
      expect(pokemon.moves.single.method, LearnMethod.level);
    });

    test('lee un movimiento en español', () {
      final move = MoveInfo.fromJson({
        'name': 'flamethrower',
        'names': [
          {
            'name': 'Flamethrower',
            'language': {'name': 'en'},
          },
          {
            'name': 'Lanzallamas',
            'language': {'name': 'es'},
          },
        ],
        'type': {'name': 'fire'},
        'damage_class': {'name': 'special'},
        'power': 90,
        'accuracy': 100,
        'pp': 15,
        'meta': {
          'ailment': {'name': 'burn'},
          'ailment_chance': 10,
        },
        'target': {'name': 'selected-pokemon'},
        'stat_changes': [],
      });
      expect(move.label, 'Lanzallamas');
      expect(move.isDamaging, isTrue);
      expect(move.ailment, 'burn');
      expect(move.targetsSelf, isFalse);
    });
  });

  test('las variantes saben de qué especie son', () {
    final mega = Pokemon.fromJson({
      'id': 10034,
      'name': 'charizard-mega-x',
      'species': {'name': 'charizard', 'url': 'https://pokeapi.co/api/v2/pokemon-species/6/'},
      'types': [
        {
          'slot': 1,
          'type': {'name': 'fire'},
        },
        {
          'slot': 2,
          'type': {'name': 'dragon'},
        },
      ],
      'stats': [],
      'abilities': [],
    });
    expect(mega.speciesId, 6);
    expect(mega.isVariant, isTrue);
    expect(mega.types, ['fire', 'dragon']);
  });
}

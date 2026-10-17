import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/models/pokemon.dart';

/// Respuesta recortada de https://pokeapi.co/api/v2/pokemon/1/ con los campos
/// que la app realmente lee.
const _bulbasaurJson = <String, dynamic>{
  'id': 1,
  'name': 'bulbasaur',
  'height': 7,
  'weight': 69,
  'base_experience': 64,
  'types': [
    {
      'slot': 2,
      'type': {'name': 'poison'},
    },
    {
      'slot': 1,
      'type': {'name': 'grass'},
    },
  ],
  'stats': [
    {
      'base_stat': 45,
      'stat': {'name': 'hp'},
    },
    {
      'base_stat': 49,
      'stat': {'name': 'attack'},
    },
  ],
  'abilities': [
    {
      'is_hidden': false,
      'ability': {'name': 'overgrow'},
    },
    {
      'is_hidden': true,
      'ability': {'name': 'chlorophyll'},
    },
  ],
  'sprites': {
    'other': {
      'official-artwork': {
        'front_default': 'https://example.test/1.png',
        'front_shiny': 'https://example.test/shiny/1.png',
      },
    },
  },
  'cries': {'latest': 'https://example.test/1.ogg'},
  'moves': [
    {'move': 'razor-wind'},
    {'move': 'swords-dance'},
  ],
};

void main() {
  group('Pokemon.fromJson', () {
    final pokemon = Pokemon.fromJson(_bulbasaurJson);

    test('lee los campos básicos', () {
      expect(pokemon.id, 1);
      expect(pokemon.name, 'bulbasaur');
      expect(pokemon.baseExperience, 64);
      expect(pokemon.movesCount, 2);
      expect(pokemon.cryUrl, 'https://example.test/1.ogg');
    });

    test('ordena los tipos por su slot', () {
      expect(pokemon.types, ['grass', 'poison']);
      expect(pokemon.primaryType, 'grass');
    });

    test('convierte decímetros y hectogramos a metros y kilos', () {
      expect(pokemon.heightMeters, 0.7);
      expect(pokemon.weightKg, 6.9);
    });

    test('suma las estadísticas base', () {
      expect(pokemon.totalStats, 94);
    });

    test('marca la habilidad oculta', () {
      expect(pokemon.abilities.map((a) => a.isHidden), [false, true]);
    });
  });

  test('PokemonListItem saca el id de la url', () {
    final item = PokemonListItem.fromJson({
      'name': 'ditto',
      'url': 'https://pokeapi.co/api/v2/pokemon/132/',
    });
    expect(item.id, 132);
    expect(item.imageUrl, contains('/132.png'));
  });

  test('EvolutionStep aplana la cadena en etapas', () {
    final stages = EvolutionStep.parseChain({
      'chain': {
        'species': {'name': 'charmander', 'url': 'https://pokeapi.co/api/v2/pokemon-species/4/'},
        'evolution_details': [],
        'evolves_to': [
          {
            'species': {
              'name': 'charmeleon',
              'url': 'https://pokeapi.co/api/v2/pokemon-species/5/',
            },
            'evolution_details': [
              {
                'min_level': 16,
                'trigger': {'name': 'level-up'},
              },
            ],
            'evolves_to': [
              {
                'species': {
                  'name': 'charizard',
                  'url': 'https://pokeapi.co/api/v2/pokemon-species/6/',
                },
                'evolution_details': [
                  {
                    'min_level': 36,
                    'trigger': {'name': 'level-up'},
                  },
                ],
                'evolves_to': [],
              },
            ],
          },
        ],
      },
    });

    expect(stages.length, 3);
    expect(stages.map((s) => s.single.name), ['charmander', 'charmeleon', 'charizard']);
    expect(stages[1].single.condition, 'Nv. 16');
  });

  test('PokemonSpecies prefiere el texto en español y lo limpia', () {
    final species = PokemonSpecies.fromJson({
      'flavor_text_entries': [
        {
          'flavor_text': 'A strange seed.',
          'language': {'name': 'en'},
        },
        {
          'flavor_text': 'Una\nsemilla\fextraña.',
          'language': {'name': 'es'},
        },
      ],
      'genera': [
        {
          'genus': 'Pokémon Semilla',
          'language': {'name': 'es'},
        },
      ],
      'evolution_chain': {'url': 'https://pokeapi.co/api/v2/evolution-chain/1/'},
      'capture_rate': 45,
      'is_legendary': false,
      'is_mythical': false,
      'habitat': {'name': 'grassland'},
    });

    expect(species.description, 'Una semilla extraña.');
    expect(species.genus, 'Pokémon Semilla');
    expect(species.captureRate, 45);
    expect(species.habitat, 'grassland');
  });
}

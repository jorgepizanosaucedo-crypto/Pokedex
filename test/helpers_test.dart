import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/profile_store.dart';
import 'package:pokedex_app/theme/app_theme.dart';

void main() {
  group('displayName', () {
    test('capitaliza los nombres normales', () {
      expect(displayName('bulbasaur'), 'Bulbasaur');
      expect(displayName('tapu-koko'), 'Tapu Koko');
    });

    test('arregla los nombres con símbolos', () {
      expect(displayName('nidoran-f'), 'Nidoran ♀');
      expect(displayName('mr-mime'), 'Mr. Mime');
      expect(displayName('farfetchd'), "Farfetch'd");
      expect(displayName('ho-oh'), 'Ho-Oh');
    });
  });

  test('displayName usa el nombre de la especie, no el de la forma', () {
    expect(displayName('giratina-altered'), 'Giratina');
    expect(displayName('maushold-family-of-four'), 'Maushold');
    expect(displayName('zygarde-50'), 'Zygarde');
  });

  test('dexNumber rellena con ceros', () {
    expect(dexNumber(7), '#0007');
    expect(dexNumber(1025), '#1025');
  });

  test('initialsOf toma la primera y la última palabra', () {
    expect(ProfileStore.initialsOf('Jorge Luis Pizano'), 'JP');
    expect(ProfileStore.initialsOf('  ash  '), 'A');
    expect(ProfileStore.initialsOf(''), '?');
  });

  test('cada tipo tiene un color con texto blanco legible', () {
    for (final style in kTypeStyles.values) {
      // Luminancia ≤ 0.30 = contraste de 3:1 o más con el blanco.
      expect(style.color.computeLuminance(), lessThanOrEqualTo(0.30), reason: style.label);
    }
  });

  group('condiciones de evolución', () {
    Map<String, dynamic> chainWith(Map<String, dynamic> details) => {
      'chain': {
        'species': {'name': 'pikachu', 'url': 'https://pokeapi.co/api/v2/pokemon-species/25/'},
        'evolution_details': [],
        'evolves_to': [
          {
            'species': {'name': 'raichu', 'url': 'https://pokeapi.co/api/v2/pokemon-species/26/'},
            'evolution_details': [details],
            'evolves_to': [],
          },
        ],
      },
    };

    test('traduce las piedras', () {
      final stages = EvolutionStep.parseChain(
        chainWith({
          'item': {'name': 'thunder-stone'},
          'trigger': {'name': 'use-item'},
          'time_of_day': '',
        }),
      );
      expect(stages[1].single.condition, 'Piedra trueno');
    });

    test('amistad con momento del día', () {
      final stages = EvolutionStep.parseChain(
        chainWith({
          'min_happiness': 160,
          'trigger': {'name': 'level-up'},
          'time_of_day': 'night',
        }),
      );
      expect(stages[1].single.condition, 'Amistad de noche');
    });

    test('intercambio con objeto', () {
      final stages = EvolutionStep.parseChain(
        chainWith({
          'held_item': {'name': 'metal-coat'},
          'trigger': {'name': 'trade'},
          'time_of_day': '',
        }),
      );
      expect(stages[1].single.condition, 'Intercambio con Revestimiento metálico');
    });
  });
}

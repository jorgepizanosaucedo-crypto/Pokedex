import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/pokemon.dart';
import 'prefs.dart';

/// Un Pokémon dentro de la lista de un tipo, con el hueco que ese tipo ocupa.
class TypeMember {
  final int id;
  final int slot;

  const TypeMember({required this.id, required this.slot});
}

/// Cliente HTTP de la PokeAPI usando Dio.
///
/// Dos niveles de caché:
/// - En memoria, para cada respuesta: desplazarse o volver atrás no repite
///   peticiones.
/// - En el dispositivo, sólo para la lista de nombres (no cambia nunca): a
///   partir de la segunda vez la Pokédex aparece al instante.
class PokeApiService {
  PokeApiService._();
  static final PokeApiService instance = PokeApiService._();

  /// Prefijo de todo lo que se guarda como caché: así se borra de una vez.
  static const String cachePrefix = 'cache.';
  static const String _listKey = '${cachePrefix}pokemon_list.v1';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://pokeapi.co/api/v2/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ),
  );

  final Map<int, Future<Pokemon>> _pokemonCache = {};
  final Map<int, Future<PokemonSpecies>> _speciesCache = {};
  final Map<String, Future<List<List<EvolutionStep>>>> _evolutionCache = {};
  final Map<String, Future<List<TypeMember>>> _typeCache = {};

  /// Lo que ya llegó, para pintar sin esperar a un `Future`.
  final Map<int, Pokemon> _ready = {};
  final Map<int, String> _names = {};

  Pokemon? peek(int id) => _ready[id];

  /// Nombre de la API de un Pokémon, si la lista ya llegó.
  String? nameOf(int id) => _names[id];

  final Map<String, Future<List<PokemonListItem>>> _listCache = {};

  /// `GET /pokemon?limit=&offset=` → lista de Pokémon.
  ///
  /// La primera llamada la hace el splash; la Pokédex recibe el mismo
  /// `Future`, así que cuando aparece la lista normalmente ya llegó.
  Future<List<PokemonListItem>> getPokemonList({int limit = 151, int offset = 0}) {
    final key = '$_listKey.$offset.$limit';
    return _listCache[key] ??= _loadList(key, limit, offset).catchError((Object e) {
      _listCache.remove(key);
      throw e;
    });
  }

  Future<List<PokemonListItem>> _loadList(String key, int limit, int offset) async {
    final prefs = await Prefs.load();
    final stored = prefs?.getString(key);
    if (stored != null) {
      try {
        final rows = jsonDecode(stored) as List;
        return _remember([
          for (final row in rows)
            PokemonListItem(id: (row as List)[0] as int, name: row[1] as String),
        ]);
      } catch (_) {
        // Caché dañada: se vuelve a pedir.
      }
    }

    final response = await _dio.get<Map<String, dynamic>>(
      'pokemon',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final results = response.data!['results'] as List;
    final list = results.map((e) => PokemonListItem.fromJson(e as Map<String, dynamic>)).toList();
    try {
      await prefs?.setString(
        key,
        jsonEncode([
          for (final p in list) [p.id, p.name],
        ]),
      );
    } catch (_) {}
    return _remember(list);
  }

  List<PokemonListItem> _remember(List<PokemonListItem> list) {
    for (final item in list) {
      _names[item.id] = item.name;
    }
    return list;
  }

  /// `GET /pokemon/{id}/` → objeto [Pokemon].
  Future<Pokemon> getPokemon(int id) {
    return _pokemonCache[id] ??= _dio
        .get<Map<String, dynamic>>('pokemon/$id/')
        .then((r) {
          final pokemon = Pokemon.fromJson(r.data!);
          _ready[id] = pokemon;
          return pokemon;
        })
        .catchError((Object e) {
          _pokemonCache.remove(id);
          throw e;
        });
  }

  /// `GET /pokemon-species/{id}/` → descripción y datos de especie.
  Future<PokemonSpecies> getSpecies(int id) {
    return _speciesCache[id] ??= _dio
        .get<Map<String, dynamic>>('pokemon-species/$id/')
        .then((r) => PokemonSpecies.fromJson(r.data!))
        .catchError((Object e) {
          _speciesCache.remove(id);
          throw e;
        });
  }

  /// `GET /evolution-chain/{id}/` → etapas evolutivas.
  Future<List<List<EvolutionStep>>> getEvolutionChain(String url) {
    return _evolutionCache[url] ??= _dio
        .get<Map<String, dynamic>>(url)
        .then((r) => EvolutionStep.parseChain(r.data!))
        .catchError((Object e) {
          _evolutionCache.remove(url);
          throw e;
        });
  }

  /// Pide por adelantado lo que la ficha de [id] va a necesitar, sin esperar
  /// ni avisar si falla: es sólo para que al llegar ya esté.
  void prefetch(int id) {
    getPokemon(id).then((_) {}, onError: (Object _) {});
    getSpecies(id).then((_) {}, onError: (Object _) {});
  }

  /// `GET /type/{name}/` → qué Pokémon tienen ese tipo y en qué posición.
  ///
  /// La posición importa: el tipo del primer hueco es el que da el color a la
  /// tarjeta. Con estas 18 peticiones se arma la lista entera, en lugar de
  /// pedir el detalle de los más de mil Pokémon uno por uno.
  Future<List<TypeMember>> getTypeEntries(String type) {
    return _typeCache[type] ??= _dio
        .get<Map<String, dynamic>>('type/$type/')
        .then((r) {
          final list = (r.data!['pokemon'] as List).cast<Map<String, dynamic>>();
          return list
              .map(
                (e) => TypeMember(
                  id: PokemonListItem.fromJson(e['pokemon'] as Map<String, dynamic>).id,
                  slot: e['slot'] as int? ?? 1,
                ),
              )
              .toList();
        })
        .catchError((Object e) {
          _typeCache.remove(type);
          throw e;
        });
  }

  /// Sólo los ids, para filtrar la lista por tipo.
  Future<Set<int>> getTypeMembers(String type) =>
      getTypeEntries(type).then((list) => list.map((e) => e.id).toSet());

  /// Olvida todas las respuestas, en memoria y en el dispositivo.
  Future<void> clearCache() async {
    _listCache.clear();
    _pokemonCache.clear();
    _speciesCache.clear();
    _evolutionCache.clear();
    _typeCache.clear();
    _ready.clear();
    await Prefs.removeWhere((key) => key.startsWith(cachePrefix));
  }

  static String friendlyError(Object error) {
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout =>
          'La PokeAPI tardó demasiado en responder. Inténtalo de nuevo.',
        DioExceptionType.connectionError =>
          'No hay conexión a internet. Revisa tu red e inténtalo de nuevo.',
        DioExceptionType.badResponse =>
          'La PokeAPI respondió con un error (${error.response?.statusCode}). Inténtalo en un momento.',
        _ => 'No se pudo conectar con la PokeAPI. Revisa tu conexión.',
      };
    }
    return 'Algo salió mal al leer los datos. Inténtalo de nuevo.';
  }
}

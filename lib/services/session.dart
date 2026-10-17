import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'favorites_store.dart';
import 'karen_controller.dart';
import 'music_service.dart';
import 'pokeapi_service.dart';
import 'profile_store.dart';
import 'settings_store.dart';
import 'type_index.dart';

/// Cerrar sesión y borrar datos, en un solo sitio para que ninguna pantalla
/// se olvide de limpiar algo.
class Session {
  Session._();

  /// Cierra la sesión: borra del dispositivo el perfil, la foto y el equipo.
  /// Los ajustes y lo descargado se quedan.
  static Future<void> signOut() async {
    KarenController.instance.reset();
    await Future.wait([ProfileStore.instance.clear(), FavoritesStore.instance.clear()]);
    MusicService.instance.backToOverworld();
  }

  /// Borra lo descargado: respuestas de la PokeAPI e imágenes, en memoria y
  /// en disco. No cierra la sesión; todo se vuelve a bajar al usarlo.
  ///
  /// Con [reload] el índice de tipos se vuelve a pedir enseguida, porque la
  /// lista sigue en pantalla y lo necesita para pintar los colores.
  static Future<void> clearDownloads({bool reload = true}) async {
    await PokeApiService.instance.clearCache();
    TypeIndex.instance.reset();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (!kIsWeb) {
      try {
        await DefaultCacheManager().emptyCache();
      } catch (_) {}
    }
    if (reload) TypeIndex.instance.load();
  }

  /// Todo lo anterior y además los ajustes: queda como recién instalada.
  static Future<void> wipeEverything() async {
    await signOut();
    // Se vuelve al registro: nada que repintar, así que no se descarga nada
    // hasta que se vuelva a entrar.
    await clearDownloads(reload: false);
    await SettingsStore.instance.reset();
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/pokemon.dart';

/// Resolución a la que se usa el arte oficial.
enum ArtTier {
  /// 256 px: lista, equipo, cadena evolutiva y acompañantes de Karen.
  thumb,

  /// El PNG original (475 px): la ficha.
  full,
}

/// Todo el arte oficial pasa por aquí, para que la misma imagen tenga
/// siempre la misma clave de caché y se reutilice entre pantallas.
///
/// Por qué así:
/// - El arte son PNG de 475×475, casi 900 KB cada uno ya decodificado. En la
///   lista se decodifican a 256 px: caben cuatro veces más en memoria y
///   bajar deprisa no obliga a decodificar de nuevo lo que ya se vio.
/// - La ficha pinta primero la miniatura (que ya está en memoria porque la
///   tarjeta la cargó) y encima funde el original cuando llega. Nunca queda
///   un hueco vacío.
/// - En Android y escritorio las descargas se guardan en disco
///   (`cached_network_image`); en web se apoya en la caché del navegador.
class Artwork {
  Artwork._();

  static const int thumbPx = 256;

  static ImageProvider<Object> _network(String url) {
    if (kIsWeb) return NetworkImage(url);
    return CachedNetworkImageProvider(url);
  }

  static ImageProvider<Object> provider(
    int id, {
    bool shiny = false,
    ArtTier tier = ArtTier.thumb,
  }) {
    final base = _network(artworkUrl(id, shiny: shiny));
    return tier == ArtTier.thumb ? ResizeImage(base, width: thumbPx) : base;
  }

  /// Empieza a descargar y decodificar sin mostrar nada. Los errores se
  /// ignoran: si falla, el widget lo volverá a intentar al dibujarse.
  static void prefetch(
    BuildContext context,
    int id, {
    bool shiny = false,
    ArtTier tier = ArtTier.thumb,
  }) {
    if (id <= 0) return;
    precacheImage(
      provider(id, shiny: shiny, tier: tier),
      context,
      onError: (_, _) {},
    );
  }
}

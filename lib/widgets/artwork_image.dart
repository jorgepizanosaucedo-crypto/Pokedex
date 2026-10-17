import 'package:flutter/material.dart';

import '../services/artwork.dart';
import '../theme/app_theme.dart';
import 'pokeball.dart';

/// Arte oficial de un Pokémon.
///
/// - Mientras llega se ve una pokébola tenue del color que se le pase, y el
///   dibujo entra con un fundido corto; si ya estaba en memoria aparece de
///   golpe, sin fundido.
/// - Con [tier] `full` y [thumbUnderlay], pinta primero la miniatura (que la
///   lista ya dejó en memoria) y la cambia por el original cuando llega:
///   la ficha nunca muestra un hueco.
class ArtworkImage extends StatelessWidget {
  final int id;
  final double size;
  final bool shiny;
  final ArtTier tier;
  final bool thumbUnderlay;
  final Color? placeholderColor;

  /// Arte propio de una forma de aspecto. Debajo se sigue viendo la
  /// miniatura normal del [id] mientras llega.
  final String? url;

  const ArtworkImage({
    super.key,
    required this.id,
    required this.size,
    this.shiny = false,
    this.tier = ArtTier.thumb,
    this.thumbUnderlay = false,
    this.placeholderColor,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    if (tier == ArtTier.full && thumbUnderlay) {
      final fallback = ArtworkImage(
        id: id,
        size: size,
        shiny: shiny,
        placeholderColor: placeholderColor,
      );
      return SizedBox.square(
        dimension: size,
        child: Image(
          image: Artwork.provider(id, shiny: shiny, tier: ArtTier.full, url: url),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSync) => frame == null ? fallback : child,
          errorBuilder: (context, error, stack) => fallback,
        ),
      );
    }

    final tone = placeholderColor ?? AppColors.ink;
    final placeholder = Center(
      child: Pokeball(size: size * 0.34, color: tone.withValues(alpha: 0.18)),
    );

    return SizedBox.square(
      dimension: size,
      child: Image(
        image: Artwork.provider(id, shiny: shiny, tier: tier, url: url),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: frame == null ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: placeholder,
              ),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stack) => Center(
          child: Icon(
            Icons.catching_pokemon_rounded,
            size: size * 0.36,
            color: tone.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

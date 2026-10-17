import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/dex_data.dart';
import '../models/pokemon.dart';
import '../services/favorites_store.dart';
import '../services/type_index.dart';
import '../theme/app_theme.dart';
import 'artwork_image.dart';
import 'pokeball.dart';
import 'type_chip.dart';

/// Tarjeta de la lista.
///
/// No pide nada a la red: los tipos salen de [TypeIndex], que ya los tiene
/// todos. Lo único que se descarga es la imagen.
///
/// El nombre y los tipos van en una columna a la izquierda y el arte a la
/// derecha, cada uno en su espacio: antes el dibujo tapaba los tipos.
class PokemonCard extends StatefulWidget {
  final PokemonListItem item;
  final VoidCallback onTap;

  /// Para que Karen ilumine esta tarjeta durante la guía.
  final GlobalKey? anchorKey;

  const PokemonCard({super.key, required this.item, required this.onTap, this.anchorKey});

  /// Etiqueta del `Hero` del arte, compartida con la ficha.
  static String heroTag(int id) => 'art-$id';

  @override
  State<PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<PokemonCard> {
  bool _pressed = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final id = widget.item.id;
    final types = TypeIndex.instance.typesOf(id);
    final known = types != null && types.isNotEmpty;
    final color = known ? typeStyle(types.first).color : const Color(0xFFC9CDD8);
    final favorite = FavoritesStore.instance.contains(id);
    final item = widget.item;
    final name = item.isForm && item.speciesName != null
        ? formDisplayName(item.name, item.speciesName!)
        : displayName(item.name);
    final typeNames = types?.map((t) => typeStyle(t).label).join(' y ');

    return Semantics(
      button: true,
      label: [name, 'número ${item.dexId}', ?typeNames, if (favorite) 'en tu equipo'].join(', '),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: KeyedSubtree(
        key: widget.anchorKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : (_hover ? 1.02 : 1),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.1)!, color],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: _hover ? 0.34 : 0.2),
                      blurRadius: _hover ? 16 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: LayoutBuilder(
                    builder: (context, box) => _content(box, name, types, favorite),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BoxConstraints box, String name, List<String>? types, bool favorite) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final art = math.max(0.0, math.min(h * 0.74, w * 0.47));

    return Stack(
      children: [
        Positioned(
          right: -w * 0.1,
          bottom: -w * 0.1,
          child: Pokeball(size: w * 0.6, color: Colors.white.withValues(alpha: 0.16)),
        ),
        Positioned(
          right: 4,
          bottom: 2,
          child: Hero(
            tag: PokemonCard.heroTag(widget.item.id),
            child: ArtworkImage(id: widget.item.id, size: art, placeholderColor: Colors.white),
          ),
        ),
        Positioned(
          top: 10,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (favorite) ...[
                const Icon(Icons.favorite_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                dexNumber(widget.item.dexId),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 26,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              height: 1.2,
              shadows: [Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 54,
          width: w * 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (types != null)
                for (final t in types)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TypeChip(type: t, compact: true),
                    ),
                  )
              else
                // Hueco del mismo alto mientras llega el índice, para que las
                // tarjetas no den un salto al pintarse.
                for (final width in const [58.0, 48.0])
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    width: width,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta vacía mientras llega la lista: misma forma, late despacio.
class PokemonCardSkeleton extends StatefulWidget {
  final int index;

  const PokemonCardSkeleton({super.key, required this.index});

  @override
  State<PokemonCardSkeleton> createState() => _PokemonCardSkeletonState();
}

class _PokemonCardSkeletonState extends State<PokemonCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform((_c.value + widget.index * 0.13) % 1.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.05 + t * 0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Positioned(
                  right: -box.maxWidth * 0.1,
                  bottom: -box.maxWidth * 0.1,
                  child: Pokeball(
                    size: box.maxWidth * 0.6,
                    color: AppColors.ink.withValues(alpha: 0.05 + t * 0.03),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bone(86, 14),
                      const SizedBox(height: 14),
                      _bone(58, 18),
                      const SizedBox(height: 5),
                      _bone(48, 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bone(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
    ),
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pokemon.dart';
import '../services/artwork.dart';
import '../services/favorites_store.dart';
import '../services/karen_controller.dart';
import '../services/music_service.dart';
import '../services/pokeapi_service.dart';
import '../services/sound_service.dart';
import '../services/type_index.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/artwork_image.dart';
import '../widgets/karen_overlay.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sparkle.dart';
import '../widgets/stats_view.dart';
import '../widgets/type_chip.dart';

/// Ficha completa de un Pokémon. Se puede deslizar a izquierda y derecha
/// para recorrer la lista desde la que se abrió, como las páginas de un álbum.
class DetailScreen extends StatefulWidget {
  final List<PokemonListItem> entries;
  final int initialIndex;

  const DetailScreen({super.key, required this.entries, required this.initialIndex});

  /// Ruta con fundido; el arte vuela desde la tarjeta con un `Hero`.
  static Route<void> route(List<PokemonListItem> entries, int initialIndex) =>
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => DetailScreen(entries: entries, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    // Al cerrar la ficha, el ambiente vuelve al tema del mapa.
    MusicService.instance.backToOverworld();
    super.dispose();
  }

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.entries.length) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KarenBottomInset(
      value: 0,
      // En escritorio y web también se pasa de ficha con las flechas.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.ink,
            body: PageView.builder(
              controller: _controller,
              // En web y escritorio también se desliza arrastrando con el
              // ratón: la ficha lo anuncia ("desliza") y antes sólo servía
              // con el dedo.
              scrollBehavior: ScrollConfiguration.of(context)
                  .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              itemCount: widget.entries.length,
              onPageChanged: (index) {
                SoundService.instance.play(Sfx.swipe, volume: 0.4);
                HapticFeedback.selectionClick();
                setState(() => _index = index);
              },
              itemBuilder: (context, index) => _PokemonDetail(
                key: ValueKey(widget.entries[index].id),
                entry: widget.entries[index],
                hasNext: index < widget.entries.length - 1,
                hasPrevious: index > 0,
                neighbours: [
                  if (index > 0) widget.entries[index - 1].id,
                  if (index < widget.entries.length - 1) widget.entries[index + 1].id,
                ],
                // El PageView construye también las fichas vecinas: sólo la que
                // se está mirando cambia la música, llama a Karen o lanza gritos.
                active: index == _index,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Abre la ficha de un Pokémon suelto (usado por la cadena evolutiva).
void openPokemonById(BuildContext context, int id, String name) {
  SoundService.instance.play(Sfx.open, volume: 0.5);
  Artwork.prefetch(context, id, tier: ArtTier.full);
  PokeApiService.instance.prefetch(id);
  Navigator.of(context).push(DetailScreen.route([PokemonListItem(id: id, name: name)], 0));
}

class _PokemonDetail extends StatefulWidget {
  final PokemonListItem entry;
  final bool hasNext;
  final bool hasPrevious;
  final bool active;
  final List<int> neighbours;

  const _PokemonDetail({
    super.key,
    required this.entry,
    required this.hasNext,
    required this.hasPrevious,
    required this.active,
    required this.neighbours,
  });

  @override
  State<_PokemonDetail> createState() => _PokemonDetailState();
}

class _PokemonDetailState extends State<_PokemonDetail> with TickerProviderStateMixin {
  /// Cada cuánto el Pokémon se mueve y suelta su grito por su cuenta.
  static const Duration _roarEvery = Duration(seconds: 14);

  late Future<Pokemon> _future = PokeApiService.instance.getPokemon(widget.entry.id);

  /// Flotación continua del arte oficial.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  /// Presentación: el Pokémon entra desde el costado de la ficha.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  /// Sacudida del rugido.
  late final AnimationController _roar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  Timer? _roarTimer;
  Pokemon? _pokemon;
  bool _announced = false;
  bool _shiny = false;
  int _sparkle = 0;

  @override
  void initState() {
    super.initState();
    _pokemon = PokeApiService.instance.peek(widget.entry.id);
    // Si el arte llega volando desde la tarjeta, no hace falta la entrada.
    if (_pokemon != null || widget.active) _entrance.value = 1;
    _listen();
  }

  /// Los efectos se encadenan al futuro en vez de hacerse durante el build.
  void _listen() {
    _future.then(
      (pokemon) {
        if (!mounted) return;
        _pokemon = pokemon;
        _activate();
      },
      onError: (Object _) {
        if (mounted && widget.active) KarenController.instance.onNetworkError();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active) _prefetchAround();
  }

  @override
  void didUpdateWidget(covariant _PokemonDetail old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _entrance.forward(from: 0);
      _prefetchAround();
      _activate();
    } else if (!widget.active && old.active) {
      _roarTimer?.cancel();
    }
  }

  /// Lo que la ficha vecina va a necesitar, para que al deslizar ya esté, y
  /// el variocolor de esta, para que el botón responda al instante.
  void _prefetchAround() {
    final id = widget.entry.id;
    Artwork.prefetch(context, id, tier: ArtTier.full);
    Artwork.prefetch(context, id, shiny: true, tier: ArtTier.full);
    for (final n in widget.neighbours) {
      Artwork.prefetch(context, n);
      Artwork.prefetch(context, n, tier: ArtTier.full);
      PokeApiService.instance.prefetch(n);
    }
  }

  @override
  void dispose() {
    _roarTimer?.cancel();
    _float.dispose();
    _entrance.dispose();
    _roar.dispose();
    super.dispose();
  }

  /// Lo que pasa cuando esta ficha es la que se está mirando: cambia el
  /// ambiente musical, Karen comenta algo y el Pokémon empieza a moverse solo.
  void _activate() {
    final pokemon = _pokemon;
    if (!widget.active || pokemon == null) return;

    _startRoarCycle(pokemon);
    if (_announced) return;
    _announced = true;

    // La especie dice si es legendario, y eso manda sobre el tipo.
    PokeApiService.instance
        .getSpecies(pokemon.id)
        .then((species) {
          if (!mounted) return;
          final legendary = species.isLegendary || species.isMythical;
          MusicService.instance.switchTo(
            MusicService.trackFor(pokemon.primaryType, legendary: legendary),
          );
          KarenController.instance.onPokemonOpened(
            id: pokemon.id,
            displayName: displayName(pokemon.name),
            type: pokemon.primaryType,
            total: pokemon.totalStats,
            legendary: legendary,
          );
        })
        .catchError((Object _) {
          if (mounted) {
            MusicService.instance.switchTo(MusicService.trackFor(pokemon.primaryType));
          }
        });
  }

  /// Cada tanto el Pokémon se sacude y grita, para que la ficha no esté quieta.
  void _startRoarCycle(Pokemon pokemon) {
    _roarTimer?.cancel();
    if (pokemon.cryUrl == null) return;
    _roarTimer = Timer.periodic(_roarEvery, (_) {
      if (!mounted || !widget.active) return;
      _playCry(pokemon);
    });
  }

  void _playCry(Pokemon pokemon) {
    _roar.forward(from: 0);
    SoundService.instance.playCry(pokemon.cryUrl);
  }

  void _toggleShiny(Pokemon pokemon) {
    setState(() {
      _shiny = !_shiny;
      if (_shiny) _sparkle++;
    });
    if (_shiny) {
      SoundService.instance.play(Sfx.shiny, volume: 0.6);
      HapticFeedback.mediumImpact();
      KarenController.instance.onShiny(pokemon.id, displayName(pokemon.name));
    } else {
      SoundService.instance.play(Sfx.tap, volume: 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pokemon>(
      future: _future,
      initialData: _pokemon,
      builder: (context, snap) {
        final pokemon = snap.data;
        // Mientras llega la ficha ya se sabe el tipo (por el índice), así
        // que el fondo sale de su color y no gris.
        final knownType = pokemon?.primaryType ?? TypeIndex.instance.primaryOf(widget.entry.id);
        final color = knownType == null ? const Color(0xFF6C7080) : typeStyle(knownType).color;

        return AmbientBackground(
          color: color,
          animate: widget.active,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  id: widget.entry.id,
                  name: widget.entry.name,
                  hasNext: widget.hasNext,
                  hasPrevious: widget.hasPrevious,
                ),
                if (snap.hasError && pokemon == null)
                  Expanded(
                    child: _DetailError(
                      message: PokeApiService.friendlyError(snap.error!),
                      onRetry: () {
                        setState(
                          () => _future = PokeApiService.instance.getPokemon(widget.entry.id),
                        );
                        _listen();
                      },
                    ),
                  )
                else if (pokemon == null) ...[
                  // Lo que ya se sabe desde la lista se pinta al instante: el
                  // dibujo (la miniatura ya está en memoria), el nombre y los
                  // tipos. Sólo el contenido de la hoja espera a la red.
                  _ArtworkLoading(id: widget.entry.id, active: widget.active),
                  Expanded(child: _SheetLoading(entry: widget.entry)),
                ] else ...[
                  _Artwork(
                    pokemon: pokemon,
                    active: widget.active,
                    shiny: _shiny,
                    sparkle: _sparkle,
                    float: _float,
                    entrance: _entrance,
                    roar: _roar,
                    onToggleShiny: () => _toggleShiny(pokemon),
                    onCry: () => _playCry(pokemon),
                  ),
                  Expanded(
                    child: _InfoSheet(pokemon: pokemon, active: widget.active),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final int id;
  final String name;
  final bool hasNext;
  final bool hasPrevious;

  const _TopBar({
    required this.id,
    required this.name,
    required this.hasNext,
    required this.hasPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Text(
            dexNumber(id),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Pista de que la ficha se puede deslizar.
          if (hasPrevious || hasNext)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  if (hasPrevious)
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  Text(
                    'desliza',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasNext)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
          _FavoriteButton(id: id, name: name),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final int id;
  final String name;

  const _FavoriteButton({required this.id, required this.name});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    final added = FavoritesStore.instance.toggle(widget.id);
    SoundService.instance.play(added ? Sfx.shiny : Sfx.tap, volume: added ? 0.45 : 0.3);
    HapticFeedback.lightImpact();
    if (added) {
      _c.forward(from: 0);
      KarenController.instance.onFavorite(widget.id, displayName(widget.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final active = FavoritesStore.instance.contains(widget.id);
        return IconButton(
          tooltip: active ? 'Quitar de mi equipo' : 'Añadir a mi equipo',
          onPressed: _toggle,
          icon: AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              // Latido al añadir.
              final pulse = 1 + math.sin(_c.value * math.pi) * 0.45;
              return Transform.scale(scale: pulse, child: child);
            },
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: active ? const Color(0xFFFF5E78) : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// Zona superior: arte oficial flotando sobre una pokébola que gira,
/// con el número de Pokédex en marca de agua y el interruptor shiny.
///
/// El Pokémon entra desde el costado de la ficha a modo de presentación, y
/// cada tanto se sacude cuando suelta su grito.
class _Artwork extends StatelessWidget {
  final Pokemon pokemon;
  final bool active;
  final bool shiny;
  final int sparkle;
  final AnimationController float;
  final AnimationController entrance;
  final AnimationController roar;
  final VoidCallback onToggleShiny;
  final VoidCallback onCry;

  const _Artwork({
    required this.pokemon,
    required this.active,
    required this.shiny,
    required this.sparkle,
    required this.float,
    required this.entrance,
    required this.roar,
    required this.onToggleShiny,
    required this.onCry,
  });

  @override
  Widget build(BuildContext context) {
    final layout = Layout.of(context);
    final height = layout.artworkHeight;

    // En pantallas anchas los controles (grito, shiny) se alinean con la
    // hoja de abajo en vez de irse a las orillas de la ventana.
    return ContentWidth(
      maxWidth: kSheetMaxWidth,
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SpinningPokeball(
              size: height * 0.92,
              color: Colors.white.withValues(alpha: 0.12),
              animate: active,
            ),
            // Número gigante de fondo; se encoge si no cabe (los de cuatro
            // cifras se salían de la pantalla).
            SizedBox(
              width: math.min(MediaQuery.sizeOf(context).width, kSheetMaxWidth) - 32,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  pokemon.id.toString().padLeft(3, '0'),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: height * 0.52,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.11),
                    letterSpacing: -4,
                    height: 1,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([float, entrance, roar]),
              builder: (_, child) {
                // Entrada: llega desde la derecha, girando un poco al frenar.
                final e = Curves.easeOutCubic.transform(entrance.value);
                final slide = (1 - e) * height * 0.9;
                final tilt = (1 - e) * 0.18;

                // Rugido: sacudida que se apaga, con un golpe de escala.
                final r = roar.isAnimating || roar.value > 0 ? roar.value : 0.0;
                final shake = math.sin(r * math.pi * 7) * (1 - r) * 10;
                final punch = 1 + math.sin(r * math.pi) * 0.07;

                return Transform.translate(
                  offset: Offset(slide + shake, math.sin(float.value * math.pi) * 9 - 4),
                  child: Transform.rotate(
                    angle: tilt + shake * 0.004,
                    child: Transform.scale(scale: punch * (0.82 + 0.18 * e), child: child),
                  ),
                );
              },
              child: GestureDetector(
                onTap: onCry,
                child: Hero(
                  tag: PokemonCard.heroTag(pokemon.id),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    // Primero la miniatura que ya está en memoria y encima el
                    // original cuando llega: nunca queda el hueco vacío.
                    child: ArtworkImage(
                      key: ValueKey(shiny),
                      id: pokemon.id,
                      size: height * 0.78,
                      shiny: shiny,
                      tier: ArtTier.full,
                      thumbUnderlay: true,
                      placeholderColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SparkleBurst(trigger: sparkle),
            // Interruptor shiny.
            Positioned(
              right: 16,
              bottom: 4,
              child: _ShinyToggle(active: shiny, onTap: onToggleShiny),
            ),
            if (pokemon.cryUrl != null)
              Positioned(
                left: 18,
                bottom: 8,
                child: Row(
                  children: [
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Toca para oír su grito',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Zona del arte mientras llega la ficha: la misma pokébola y la
/// miniatura que ya cargó la tarjeta.
class _ArtworkLoading extends StatelessWidget {
  final int id;
  final bool active;

  const _ArtworkLoading({required this.id, required this.active});

  @override
  Widget build(BuildContext context) {
    final height = Layout.of(context).artworkHeight;
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SpinningPokeball(
            size: height * 0.92,
            color: Colors.white.withValues(alpha: 0.12),
            animate: active,
          ),
          Hero(
            tag: PokemonCard.heroTag(id),
            child: ArtworkImage(
              id: id,
              size: height * 0.78,
              tier: ArtTier.full,
              thumbUnderlay: true,
              placeholderColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja blanca mientras llega la ficha: nombre y tipos ya se conocen.
class _SheetLoading extends StatelessWidget {
  final PokemonListItem entry;

  const _SheetLoading({required this.entry});

  @override
  Widget build(BuildContext context) {
    final types = TypeIndex.instance.typesOf(entry.id) ?? const <String>[];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: ContentWidth(
        maxWidth: kSheetMaxWidth,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName(entry.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [for (final t in types) TypeChip(type: t, onColor: false)],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SpinningPokeball(
                  size: 40,
                  color: AppColors.ink.withValues(alpha: 0.12),
                  period: const Duration(milliseconds: 1400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShinyToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _ShinyToggle({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFD54F) : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: active ? 0 : 0.35)),
          boxShadow: active
              ? [const BoxShadow(color: Color(0x66FFD54F), blurRadius: 16, offset: Offset(0, 4))]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: active ? const Color(0xFF6B4E00) : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'Shiny',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF6B4E00) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja blanca inferior con nombre, tipos y las tres pestañas de contenido.
class _InfoSheet extends StatelessWidget {
  final Pokemon pokemon;
  final bool active;

  const _InfoSheet({required this.pokemon, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = typeStyle(pokemon.primaryType).color;
    final accent = readableOn(color);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: ContentWidth(
        maxWidth: kSheetMaxWidth,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Asidero decorativo.
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName(pokemon.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: pokemon.types
                                .map((t) => TypeChip(type: t, onColor: false))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    _TotalBadge(total: pokemon.totalStats, color: accent),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TabBar(
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(width: 3, color: accent),
                  borderRadius: BorderRadius.circular(3),
                ),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: AppColors.line,
                // Sin el resaltado beige de Material al tocar.
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                labelColor: AppColors.ink,
                unselectedLabelColor: AppColors.muted,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                onTap: (_) => SoundService.instance.play(Sfx.tap, volume: 0.3),
                tabs: const [
                  Tab(text: 'Datos'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Evolución'),
                ],
              ),
              Expanded(
                // Las pestañas se cambian tocándolas: deslizar a los lados pasa
                // al siguiente Pokémon (antes los dos gestos se peleaban).
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DataTab(pokemon: pokemon, accent: accent, active: active),
                    _StatsTab(pokemon: pokemon, color: color),
                    _EvolutionTab(pokemon: pokemon, accent: accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Número protagonista: la suma de las seis estadísticas base.
class _TotalBadge extends StatelessWidget {
  final int total;
  final Color color;

  const _TotalBadge({required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedValue(
          value: total.toDouble(),
          duration: const Duration(milliseconds: 900),
          builder: (t) => Text(
            t.round().toString(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color, height: 1),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'TOTAL BASE',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// Pestaña «Datos»: descripción de la especie, medidas y habilidades.
class _DataTab extends StatefulWidget {
  final Pokemon pokemon;
  final Color accent;
  final bool active;

  const _DataTab({required this.pokemon, required this.accent, required this.active});

  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  /// La especie no se pide hasta que esta ficha es la que se está mirando:
  /// al deslizar deprisa, las vecinas lanzarían peticiones que nadie ve.
  Future<PokemonSpecies>? _species;

  @override
  void initState() {
    super.initState();
    // En initState todavía no se puede llamar a setState.
    if (widget.active) {
      _species = PokeApiService.instance.getSpecies(widget.pokemon.id);
    }
  }

  @override
  void didUpdateWidget(covariant _DataTab old) {
    super.didUpdateWidget(old);
    // Después de didUpdateWidget siempre viene un build: no hace falta setState.
    if (widget.active && _species == null) {
      _species = PokeApiService.instance.getSpecies(widget.pokemon.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pokemon;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        FutureBuilder<PokemonSpecies>(
          future: _species,
          builder: (context, snap) {
            final species = snap.data;
            if (species == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snap.hasError)
                    const Text(
                      'No se pudo cargar la descripción de la especie.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    )
                  else
                    ...List.generate(
                      3,
                      (i) => Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        height: 9.5,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (species.isLegendary || species.isMythical)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Badge(
                      label: species.isMythical ? 'Pokémon singular' : 'Pokémon legendario',
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFFB7892A),
                    ),
                  ),
                if (species.genus.isNotEmpty)
                  Text(
                    species.genus,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.accent,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  species.description.isEmpty
                      ? 'Sin descripción registrada en la Pokédex.'
                      : species.description,
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3C4053)),
                ),
                const SizedBox(height: 16),
                _MetricGrid(
                  metrics: [
                    _Metric(
                      'Altura',
                      '${p.heightMeters.toStringAsFixed(1)} m',
                      Icons.height_rounded,
                    ),
                    _Metric(
                      'Peso',
                      '${p.weightKg.toStringAsFixed(1)} kg',
                      Icons.monitor_weight_rounded,
                    ),
                    _Metric(
                      'Exp. base',
                      p.baseExperience > 0 ? '${p.baseExperience}' : '—',
                      Icons.trending_up_rounded,
                    ),
                    _Metric('Movimientos', '${p.movesCount}', Icons.sports_martial_arts_rounded),
                    _Metric(
                      'Captura',
                      '${(species.captureRate / 255 * 100).round()} %',
                      Icons.catching_pokemon_rounded,
                    ),
                    _Metric(
                      'Hábitat',
                      species.habitat == null
                          ? 'Desconocido'
                          : kHabitats[species.habitat] ?? capitalize(species.habitat!),
                      Icons.forest_rounded,
                    ),
                  ],
                  accent: widget.accent,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Habilidades'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: p.abilities
              .map(
                (a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (a.isHidden)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.visibility_off_rounded, size: 14, color: widget.accent),
                        ),
                      Text(
                        capitalize(a.name),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: widget.accent,
                        ),
                      ),
                      if (a.isHidden)
                        Text(
                          '  oculta',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.accent.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;

  const _Metric(this.label, this.value, this.icon);
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> metrics;
  final Color accent;

  const _MetricGrid({required this.metrics, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      // Tres por fila y alto fijo: antes eran casillas altas con el texto
      // diminuto en medio.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 82,
      ),
      itemBuilder: (context, i) {
        final m = metrics[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(m.icon, size: 18, color: accent),
              const SizedBox(height: 4),
              // Los valores largos ("Orilla del agua") se encogen un poco en
              // lugar de cortarse con puntos suspensivos.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  m.value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
              Text(
                m.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Pokemon pokemon;
  final Color color;

  const _StatsTab({required this.pokemon, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: StatRadar(stats: pokemon.stats, color: color),
          ),
        ),
        const SizedBox(height: 6),
        const _SectionTitle('Estadísticas base'),
        const SizedBox(height: 11),
        StatBars(stats: pokemon.stats, color: color),
      ],
    );
  }
}

/// Pestaña «Evolución»: etapas en fila, con la condición de cada cambio.
class _EvolutionTab extends StatefulWidget {
  final Pokemon pokemon;
  final Color accent;

  const _EvolutionTab({required this.pokemon, required this.accent});

  @override
  State<_EvolutionTab> createState() => _EvolutionTabState();
}

class _EvolutionTabState extends State<_EvolutionTab> {
  late final Future<List<List<EvolutionStep>>> _chain = _loadChain();

  Future<List<List<EvolutionStep>>> _loadChain() async {
    final species = await PokeApiService.instance.getSpecies(widget.pokemon.id);
    final url = species.evolutionChainUrl;
    if (url == null) return const [];
    return PokeApiService.instance.getEvolutionChain(url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<EvolutionStep>>>(
      future: _chain,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'No se pudo cargar la cadena evolutiva.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13.5),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Center(
            child: SpinningPokeball(
              size: 48,
              color: widget.accent.withValues(alpha: 0.35),
              period: const Duration(milliseconds: 1400),
            ),
          );
        }
        final stages = snap.data!;
        if (stages.length <= 1) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 40,
                    color: AppColors.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${displayName(widget.pokemon.name)} no evoluciona.',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Esta especie no tiene formas anteriores ni posteriores.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        // Con sitio de sobra la cadena se lee mejor en fila; en un teléfono
        // en vertical se apila.
        final inRow = Layout.of(context).fitsEvolutionRow && stages.length <= 3;

        final blocks = <Widget>[
          for (final (i, stage) in stages.indexed) ...[
            if (i > 0) _EvolutionArrow(accent: widget.accent, stage: stage, horizontal: inRow),
            Wrap(
              direction: inRow ? Axis.vertical : Axis.horizontal,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: stage
                  .map(
                    (step) => _EvolutionNode(
                      step: step,
                      current: step.id == widget.pokemon.id,
                      accent: widget.accent,
                    ),
                  )
                  .toList(),
            ),
          ],
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
          children: [
            if (inRow)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: blocks,
              )
            else
              ...blocks,
          ],
        );
      },
    );
  }
}

class _EvolutionArrow extends StatelessWidget {
  final Color accent;
  final List<EvolutionStep> stage;
  final bool horizontal;

  const _EvolutionArrow({required this.accent, required this.stage, required this.horizontal});

  @override
  Widget build(BuildContext context) {
    // Si todas las ramas comparten condición, se muestra una sola vez.
    final conditions = stage.map((s) => s.condition).whereType<String>().toSet();
    final label = conditions.length == 1 ? conditions.first : null;

    return Padding(
      padding: horizontal
          ? const EdgeInsets.symmetric(horizontal: 4)
          : const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            horizontal ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
            size: 17,
            color: accent.withValues(alpha: 0.6),
          ),
          if (label != null && label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _EvolutionNode extends StatelessWidget {
  final EvolutionStep step;
  final bool current;
  final Color accent;

  const _EvolutionNode({required this.step, required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: current ? null : () => openPokemonById(context, step.id, step.name),
      child: MouseRegion(
        cursor: current ? MouseCursor.defer : SystemMouseCursors.click,
        child: Container(
          width: 108,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          decoration: BoxDecoration(
            color: current ? accent.withValues(alpha: 0.08) : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: current ? accent.withValues(alpha: 0.55) : AppColors.line,
              width: current ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              ArtworkImage(
                id: step.id,
                size: 60,
                placeholderColor: typeStyle(TypeIndex.instance.primaryOf(step.id)).color,
              ),
              const SizedBox(height: 6),
              // Se encoge si no cabe en vez de cortarse ("Charmand…").
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  displayName(step.name),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: current ? accent : AppColors.ink,
                  ),
                ),
              ),
              Text(
                dexNumber(step.id),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 1.2,
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dex_data.dart';
import '../data/moveset.dart';
import '../data/type_chart.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../services/artwork.dart';
import '../services/favorites_store.dart';
import '../services/karen_controller.dart';
import '../services/music_service.dart';
import '../services/pokeapi_service.dart';
import '../services/profile_store.dart';
import '../services/settings_store.dart';
import '../services/sound_service.dart';
import '../services/type_index.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_background.dart';
import '../widgets/animated_sprite.dart';
import '../widgets/artwork_image.dart';
import '../widgets/karen_overlay.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sparkle.dart';
import '../widgets/stats_view.dart';
import '../widgets/type_chip.dart';
import 'battle_screen.dart';

part 'detail_forms.dart';
part 'detail_tabs.dart';

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
    // Al salir de la ficha se corta el grito que esté sonando (antes seguía
    // sonando ya en la lista) y el ambiente vuelve al tema del mapa.
    SoundService.instance.stopCry();
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
                KarenController.instance.onSwipe();
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
  SoundService.instance.play(Sfx.card, volume: 0.5);
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

  /// Saludo: dos saltitos al terminar de entrar, como si se presentara.
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// Transformación al cambiar de forma.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  Timer? _roarTimer;
  Timer? _tourTimer;
  Pokemon? _pokemon;

  /// Forma elegida en la tira de formas (`null` = la que se abrió).
  Pokemon? _variant;
  String? _formKey;
  bool _loadingForm = false;
  FormKind _morphKind = FormKind.other;
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
      _tourTimer?.cancel();
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
    _tourTimer?.cancel();
    _float.dispose();
    _entrance.dispose();
    _roar.dispose();
    _hop.dispose();
    _morph.dispose();
    super.dispose();
  }

  String get _selectedFormKey =>
      _formKey ?? (_pokemon == null ? 'v:${widget.entry.id}' : _formKeyOf(_pokemon!));

  /// Cambia a otra forma de la especie con un destello, o abre la ficha del
  /// pariente paradoja.
  Future<void> _selectForm(_FormOption option) async {
    if (option.isLink) {
      openPokemonById(context, option.linkId!, option.linkName ?? '');
      return;
    }
    if (option.key == _selectedFormKey || _loadingForm) return;
    final previous = _formKey;
    SoundService.instance.play(Sfx.chip, volume: 0.38);
    setState(() {
      _formKey = option.key;
      _loadingForm = true;
    });
    try {
      final api = PokeApiService.instance;
      final next = option.formName != null
          ? await api.getPokemonInForm(option.pokemonId, option.formName!)
          : await api.getPokemon(option.pokemonId);
      if (!mounted || _formKey != option.key) return;
      final isEntry = option.formName == null && option.pokemonId == widget.entry.id;
      setState(() {
        _variant = isEntry ? null : next;
        _loadingForm = false;
        _morphKind = option.kind;
      });
      _morph.forward(from: 0);
      final big = option.kind == FormKind.mega ||
          option.kind == FormKind.gmax ||
          option.kind == FormKind.primal;
      SoundService.instance.play(big ? Sfx.mega : Sfx.morph, volume: big ? 0.6 : 0.5);
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) SoundService.instance.playCry(next.cryUrl);
      });
      _startRoarCycle(next);
      if (option.kind != FormKind.base) {
        KarenController.instance.onFormChanged(option.kind.name, next.id, _fullName(next));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _formKey = previous;
        _loadingForm = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar esa forma. Revisa tu conexión.')),
      );
    }
  }

  void _openBattle(Pokemon pokemon) {
    SoundService.instance.play(Sfx.battleStart, volume: 0.55);
    _roarTimer?.cancel();
    SoundService.instance.stopCry();
    Navigator.of(context)
        .push(BattleScreen.route(pokemon, shiny: _shiny))
        .then((_) {
          if (mounted && widget.active) _startRoarCycle(_variant ?? pokemon);
        });
  }

  /// Lo que pasa cuando esta ficha es la que se está mirando: cambia el
  /// ambiente musical, Karen comenta algo y el Pokémon empieza a moverse solo.
  void _activate() {
    final pokemon = _pokemon;
    if (!widget.active || pokemon == null) return;

    _startRoarCycle(pokemon);
    // Cada tipo se presenta con su propio sonido: chisporroteo si es de
    // fuego, burbujas si es de agua, un zumbido si es bicho…
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted && widget.active) SoundService.instance.playType(pokemon.primaryType);
    });
    // Se presenta con un par de saltitos cuando termina de entrar.
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted && widget.active) _hop.forward(from: 0);
    });
    if (_announced) return;
    _announced = true;

    // La primera ficha que se abre trae su propia guía.
    final karen = KarenController.instance;
    final profile = ProfileStore.instance;
    final tourPending =
        karen.enabled && profile.tutorialDone && !profile.detailTourDone && !karen.inTour;
    if (tourPending) {
      _tourTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted && widget.active && !karen.inTour) {
          karen.startTour(kind: KarenTour.detail);
        }
      });
    }

    // La especie dice si es legendario, y eso manda sobre el tipo.
    PokeApiService.instance
        .getSpecies(pokemon.speciesId)
        .then((species) {
          if (!mounted) return;
          final legendary = species.isLegendary || species.isMythical;
          MusicService.instance.switchTo(
            MusicService.trackFor(pokemon.primaryType, legendary: legendary),
          );
          if (tourPending) return;
          KarenController.instance.onPokemonOpened(
            id: pokemon.id,
            displayName: _fullName(pokemon),
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
      // Con la app oculta ni se mueve ni grita.
      if (!mounted || !widget.active || !SoundService.instance.foreground) return;
      _playCry(pokemon);
    });
  }

  void _playCry(Pokemon pokemon, {bool tapped = false}) {
    _roar.forward(from: 0);
    SoundService.instance.playCry(pokemon.cryUrl);
    if (tapped) KarenController.instance.onCry(pokemon.id, _fullName(pokemon));
  }

  void _toggleAnimated(Pokemon pokemon) {
    final settings = SettingsStore.instance;
    final next = !settings.animated;
    settings.setAnimated(next);
    SoundService.instance.play(next ? Sfx.toggle : Sfx.chipOff, volume: 0.42);
    HapticFeedback.selectionClick();
    if (next) {
      _hop.forward(from: 0);
      KarenController.instance.onAnimated(pokemon.id, _fullName(pokemon));
    }
  }

  void _toggleShiny(Pokemon pokemon) {
    setState(() {
      _shiny = !_shiny;
      if (_shiny) _sparkle++;
    });
    if (_shiny) {
      SoundService.instance.play(Sfx.shiny, volume: 0.6);
      HapticFeedback.mediumImpact();
      KarenController.instance.onShiny(pokemon.id, _fullName(pokemon));
    } else {
      SoundService.instance.play(Sfx.chipOff, volume: 0.38);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pokemon>(
      future: _future,
      initialData: _pokemon,
      builder: (context, snap) {
        // La forma elegida manda; si no, la que se abrió.
        final pokemon = _variant ?? snap.data;
        // Mientras llega la ficha ya se sabe el tipo (por el índice), así
        // que el fondo sale de su color y no gris.
        final knownType = pokemon?.primaryType ?? TypeIndex.instance.primaryOf(widget.entry.id);
        final color = knownType == null ? const Color(0xFF6C7080) : typeStyle(knownType).color;

        final layout = Layout.of(context);
        final wide = layout.isWide;
        // En pantalla ancha el arte tiene su propia columna y puede crecer;
        // apilado se limita para dejar sitio a la hoja.
        final artHeight = wide
            ? math.min(layout.size.height * 0.62, 440.0)
            : layout.artworkHeight;

        final Widget art;
        final Widget sheet;
        if (pokemon == null) {
          // Lo que ya se sabe desde la lista se pinta al instante: el dibujo
          // (la miniatura ya está en memoria), el nombre y los tipos. Sólo el
          // contenido de la hoja espera a la red.
          art = _ArtworkLoading(id: widget.entry.id, active: widget.active, height: artHeight);
          sheet = _SheetLoading(entry: widget.entry, wide: wide);
        } else {
          art = _Artwork(
            pokemon: pokemon,
            // El Hero sólo para la forma que se abrió: así vuela desde la
            // tarjeta y no choca con el de otra ficha.
            heroTag: _variant == null ? PokemonCard.heroTag(widget.entry.id) : null,
            morph: _morph,
            morphKind: _morphKind,
            active: widget.active,
            height: artHeight,
            shiny: _shiny,
            sparkle: _sparkle,
            float: _float,
            entrance: _entrance,
            roar: _roar,
            hop: _hop,
            onToggleShiny: () => _toggleShiny(pokemon),
            onToggleAnimated: () => _toggleAnimated(pokemon),
            onCry: () => _playCry(pokemon, tapped: true),
          );
          sheet = _InfoSheet(
            pokemon: pokemon,
            active: widget.active,
            wide: wide,
            selectedFormKey: _selectedFormKey,
            loadingForm: _loadingForm,
            onSelectForm: _selectForm,
          );
        }

        final error = snap.hasError && pokemon == null;
        final topBar = _TopBar(
          id: widget.entry.id,
          dexId: pokemon?.speciesId ?? widget.entry.dexId,
          name: widget.entry.name,
          onBattle: pokemon == null ? null : () => _openBattle(pokemon),
          hasNext: widget.hasNext,
          hasPrevious: widget.hasPrevious,
          active: widget.active,
        );

        return AmbientBackground(
          color: color,
          animate: widget.active,
          // En un teléfono basta con menos orbes: es un repintado a pantalla
          // completa por fotograma.
          orbCount: layout.isCompact ? 6 : 10,
          child: SafeArea(
            bottom: false,
            child: error
                ? Column(
                    children: [
                      topBar,
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
                      ),
                    ],
                  )
                : wide
                // Computadora: arte a la izquierda e información a la derecha,
                // todo dentro de un ancho razonable. Antes la hoja blanca se
                // estiraba de orilla a orilla del monitor.
                ? ContentWidth(
                    maxWidth: kDetailWideMaxWidth,
                    child: Column(
                      children: [
                        topBar,
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: Center(child: art)),
                              SizedBox(
                                width: 470,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
                                  child: sheet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(children: [topBar, art, Expanded(child: sheet)]),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final int id;
  final int dexId;
  final String name;
  final VoidCallback? onBattle;
  final bool hasNext;
  final bool hasPrevious;

  /// Sólo la ficha que se está mirando lleva las claves de la guía.
  final bool active;

  const _TopBar({
    required this.id,
    required this.dexId,
    required this.name,
    required this.onBattle,
    required this.hasNext,
    required this.hasPrevious,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 0),
      child: Row(
        children: [
          IconButton(
            key: KarenTargets.keyIf(active, 'back'),
            tooltip: 'Volver',
            onPressed: () {
              SoundService.instance.play(Sfx.back, volume: 0.42);
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Text(
            dexNumber(dexId),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Pista de que la ficha se puede deslizar (en el teléfono no cabe
          // junto al botón de combate).
          if ((hasPrevious || hasNext) && !Layout.of(context).isCompact)
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
          _BattleButton(key: KarenTargets.keyIf(active, 'battle'), onPressed: onBattle),
          const SizedBox(width: 4),
          _FavoriteButton(key: KarenTargets.keyIf(active, 'fav'), id: id, name: name),
        ],
      ),
    );
  }
}

/// Botón de "Combate": abre el combate contra Karen con este Pokémon.
class _BattleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BattleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Combatir contra Karen',
      child: Material(
        color: Colors.white.withValues(alpha: onPressed == null ? 0.12 : 0.22),
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_kabaddi_rounded, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Combate',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final int id;
  final String name;

  const _FavoriteButton({super.key, required this.id, required this.name});

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
    SoundService.instance.play(added ? Sfx.favOn : Sfx.favOff, volume: added ? 0.5 : 0.4);
    HapticFeedback.lightImpact();
    final name = displayName(widget.name);
    if (added) {
      _c.forward(from: 0);
      KarenController.instance.onFavorite(
        widget.id,
        name,
        teamSize: FavoritesStore.instance.count,
      );
    } else {
      KarenController.instance.onUnfavorite(widget.id, name);
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

/// Zona superior: el Pokémon flotando sobre una pokébola que gira, con el
/// número de Pokédex en marca de agua y los botones Animado y Shiny.
///
/// El Pokémon está vivo: entra desde el costado y se presenta con dos
/// saltitos, respira, se lanza hacia delante cuando suelta su grito, y con
/// "Animado" se ve su sprite de combate en movimiento.
class _Artwork extends StatelessWidget {
  final Pokemon pokemon;
  final String? heroTag;
  final AnimationController morph;
  final FormKind morphKind;
  final bool active;
  final double height;
  final bool shiny;
  final int sparkle;
  final AnimationController float;
  final AnimationController entrance;
  final AnimationController roar;
  final AnimationController hop;
  final VoidCallback onToggleShiny;
  final VoidCallback onToggleAnimated;
  final VoidCallback onCry;

  const _Artwork({
    required this.pokemon,
    required this.heroTag,
    required this.morph,
    required this.morphKind,
    required this.active,
    required this.height,
    required this.shiny,
    required this.sparkle,
    required this.float,
    required this.entrance,
    required this.roar,
    required this.hop,
    required this.onToggleShiny,
    required this.onToggleAnimated,
    required this.onCry,
  });

  @override
  Widget build(BuildContext context) {
    final artSize = height * 0.78;
    final hasSprite = pokemon.animatedUrl != null;

    // Primero la miniatura que ya está en memoria y encima el original
    // cuando llega: nunca queda el hueco vacío.
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: ArtworkImage(
        key: ValueKey('${pokemon.id}-${pokemon.formName}-$shiny'),
        id: pokemon.id,
        url: shiny ? pokemon.formShinyArt : pokemon.formArt,
        size: artSize,
        shiny: shiny,
        tier: ArtTier.full,
        thumbUnderlay: true,
        placeholderColor: Colors.white,
      ),
    );
    final official = heroTag == null ? image : Hero(tag: heroTag!, child: image);

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
            LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: math.max(0, box.maxWidth - 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    pokemon.speciesId.toString().padLeft(3, '0'),
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
            ),
            AnimatedBuilder(
              animation: Listenable.merge([float, entrance, roar, hop, morph]),
              builder: (_, child) {
                // Entrada: llega desde la derecha, girando un poco al frenar.
                final e = Curves.easeOutCubic.transform(entrance.value);
                final slide = (1 - e) * height * 0.9;
                final tilt = (1 - e) * 0.18;

                // Respiración: se estira y se encoge muy poco, apoyado en el
                // suelo.
                final b = Curves.easeInOut.transform(float.value);

                // Saludo: dos saltitos que se van apagando.
                final h = hop.value;
                final jump = h > 0 && h < 1 ? math.sin(h * math.pi * 2).abs() * (1 - h * 0.5) : 0.0;

                // Grito: se lanza hacia delante, salta y se sacude.
                final r = roar.isAnimating || roar.value > 0 ? roar.value : 0.0;
                final shake = math.sin(r * math.pi * 7) * (1 - r) * 10;
                final lunge = math.sin(r * math.pi);
                // Transformación: se encoge en un destello y vuelve con rebote.
                final m = morph.value;
                final pop = m > 0 && m < 1 ? 1 + math.sin(m * math.pi) * 0.18 * (1 - m) - 0.1 * (1 - m) : 1.0;
                final grow = (0.82 + 0.18 * e) * (1 + lunge * 0.12) * pop;

                return Transform.translate(
                  offset: Offset(
                    slide + shake,
                    math.sin(float.value * math.pi) * 7 - 4 - jump * 22 - lunge * 14,
                  ),
                  child: Transform.rotate(
                    angle: tilt + shake * 0.004,
                    child: Transform.scale(
                      scaleX: grow * (1 - b * 0.012 + jump * 0.03),
                      scaleY: grow * (1 + b * 0.022 - jump * 0.02),
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                key: KarenTargets.keyIf(active, 'art'),
                onTap: onCry,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ListenableBuilder(
                    listenable: SettingsStore.instance,
                    builder: (context, _) => SettingsStore.instance.animated && hasSprite
                        ? AnimatedSprite(
                            key: ValueKey('sprite-${pokemon.id}-${pokemon.formName}-$shiny'),
                            url: shiny ? pokemon.animatedShinyUrl : pokemon.animatedUrl,
                            size: artSize,
                            fallback: official,
                          )
                        : official,
                  ),
                ),
              ),
            ),
            SparkleBurst(trigger: sparkle),
            _MorphBurst(animation: morph, kind: morphKind, size: height * 1.1),
            // Animado y Shiny.
            Positioned(
              right: 16,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSprite) ...[
                    ListenableBuilder(
                      listenable: SettingsStore.instance,
                      builder: (context, _) => _PillToggle(
                        key: KarenTargets.keyIf(active, 'anim'),
                        label: 'Animado',
                        icon: Icons.directions_run_rounded,
                        active: SettingsStore.instance.animated,
                        activeColor: Colors.white,
                        activeInk: AppColors.ink,
                        onTap: onToggleAnimated,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _PillToggle(
                    key: KarenTargets.keyIf(active, 'shiny'),
                    label: 'Shiny',
                    icon: Icons.auto_awesome_rounded,
                    active: shiny,
                    activeColor: const Color(0xFFFFD54F),
                    activeInk: const Color(0xFF6B4E00),
                    onTap: onToggleShiny,
                  ),
                ],
              ),
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
                      'Tócalo para oír su grito',
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

  final double height;

  const _ArtworkLoading({required this.id, required this.active, required this.height});

  @override
  Widget build(BuildContext context) {
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
  final bool wide;

  const _SheetLoading({required this.entry, required this.wide});

  @override
  Widget build(BuildContext context) {
    final types = TypeIndex.instance.typesOf(entry.id) ?? const <String>[];
    return Container(
      decoration: _sheetDecoration(wide),
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

/// Botón con forma de píldora sobre el arte (Animado, Shiny).
class _PillToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color activeInk;
  final VoidCallback onTap;

  const _PillToggle({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.activeInk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: active,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: active ? 0 : 0.35)),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: active ? activeInk : Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? activeInk : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja blanca inferior con nombre, tipos y las tres pestañas de contenido.
/// La hoja blanca: pegada abajo en el teléfono, y en pantalla ancha una
/// tarjeta flotante con todas las esquinas redondeadas.
BoxDecoration _sheetDecoration(bool wide) => BoxDecoration(
  color: AppColors.surface,
  borderRadius: wide
      ? BorderRadius.circular(26)
      : const BorderRadius.vertical(top: Radius.circular(26)),
  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -5))],
);

class _InfoSheet extends StatelessWidget {
  final Pokemon pokemon;
  final bool active;
  final bool wide;
  final String selectedFormKey;
  final bool loadingForm;
  final ValueChanged<_FormOption> onSelectForm;

  const _InfoSheet({
    required this.pokemon,
    required this.active,
    required this.wide,
    required this.selectedFormKey,
    required this.loadingForm,
    required this.onSelectForm,
  });

  @override
  Widget build(BuildContext context) {
    final color = typeStyle(pokemon.primaryType).color;
    final accent = readableOn(color);
    final formLabel = _formLabelOf(pokemon);

    return Container(
      decoration: _sheetDecoration(wide),
      clipBehavior: wide ? Clip.antiAlias : Clip.none,
      child: ContentWidth(
        maxWidth: kSheetMaxWidth,
        child: DefaultTabController(
          length: 4,
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName(pokemon.speciesName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              if (formLabel != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      formLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Wrap(
                              key: ValueKey(pokemon.types.join()),
                              spacing: 6,
                              children: pokemon.types
                                  .map((t) => TypeChip(type: t, onColor: false))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TotalBadge(total: pokemon.totalStats, color: accent),
                  ],
                ),
              ),
              _FormStrip(
                pokemon: pokemon,
                selectedKey: selectedFormKey,
                loading: loadingForm,
                accent: accent,
                active: active,
                onSelect: onSelectForm,
              ),
              const SizedBox(height: 4),
              TabBar(
                key: KarenTargets.keyIf(active, 'tabs'),
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
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                onTap: (index) {
                  SoundService.instance.play(Sfx.tab, volume: 0.4);
                  KarenController.instance.onTab(index);
                },
                // Cuatro pestañas en un teléfono: el texto se encoge si no
                // cabe en lugar de cortarse.
                tabs: [
                  for (final label in const ['Datos', 'Stats', 'Evolución', 'Movimientos'])
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label))),
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
                    _EvolutionTab(
                      pokemon: pokemon,
                      accent: accent,
                      active: active,
                      onSelectForm: onSelectForm,
                    ),
                    _MovesTab(pokemon: pokemon, accent: accent),
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
      _species = PokeApiService.instance.getSpecies(widget.pokemon.speciesId);
    }
  }

  @override
  void didUpdateWidget(covariant _DataTab old) {
    super.didUpdateWidget(old);
    // Después de didUpdateWidget siempre viene un build: no hace falta setState.
    if (widget.active && _species == null) {
      _species = PokeApiService.instance.getSpecies(widget.pokemon.speciesId);
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
                _BreedingSection(species: species, pokemon: p, accent: widget.accent),
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
          children: [for (final a in p.abilities) _AbilityChip(ability: a, accent: widget.accent)],
        ),
        const SizedBox(height: 6),
        const Text(
          'Toca una habilidad para ver qué hace.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
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
        _WeaknessSection(types: pokemon.types),
      ],
    );
  }
}

/// Pestaña «Evolución»: etapas en fila, con la condición de cada cambio.
class _EvolutionTab extends StatefulWidget {
  final Pokemon pokemon;
  final Color accent;
  final bool active;
  final ValueChanged<_FormOption> onSelectForm;

  const _EvolutionTab({
    required this.pokemon,
    required this.accent,
    required this.active,
    required this.onSelectForm,
  });

  @override
  State<_EvolutionTab> createState() => _EvolutionTabState();
}

class _EvolutionTabState extends State<_EvolutionTab> {
  late final Future<List<List<EvolutionStep>>> _chain = _loadChain();
  late final Future<PokemonSpecies> _species = PokeApiService.instance.getSpecies(
    widget.pokemon.speciesId,
  );

  Future<List<List<EvolutionStep>>> _loadChain() async {
    final species = await PokeApiService.instance.getSpecies(widget.pokemon.speciesId);
    final url = species.evolutionChainUrl;
    if (url == null) return const [];
    final stages = await PokeApiService.instance.getEvolutionChain(url);
    _announceSpecial(url, stages);
    return stages;
  }

  /// Si la cadena tiene una evolución con truco, Karen lo cuenta (una vez).
  void _announceSpecial(String url, List<List<EvolutionStep>> stages) {
    if (!widget.active) return;
    for (final stage in stages.skip(1)) {
      for (final step in stage) {
        if (step.special && step.howTo != null && step.parentName != null) {
          KarenController.instance.onSpecialEvolution(
            url,
            _EvolutionNotes.sentence(step),
            [step.parentId!, step.id],
          );
          return;
        }
      }
    }
  }

  Widget _specialForms() => FutureBuilder<PokemonSpecies>(
    future: _species,
    builder: (context, snap) => snap.data == null
        ? const SizedBox.shrink()
        : _SpecialForms(
            species: snap.data!,
            speciesName: widget.pokemon.speciesName,
            accent: widget.accent,
            onSelect: widget.onSelectForm,
          ),
  );

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
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Padding(
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
                    '${displayName(widget.pokemon.speciesName)} no evoluciona.',
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
              _specialForms(),
            ],
          );
        }

        // Con sitio de sobra la cadena se lee mejor en fila; en un teléfono
        // en vertical se apila.
        // Con muchas ramas (Eevee) se reparten en filas aunque sobre sitio.
        final inRow =
            Layout.of(context).fitsEvolutionRow &&
            stages.length <= 3 &&
            stages.every((stage) => stage.length <= 3);

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
                      current: step.id == widget.pokemon.speciesId,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _EvolutionNotes(stages: stages, accent: widget.accent),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _specialForms()),
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

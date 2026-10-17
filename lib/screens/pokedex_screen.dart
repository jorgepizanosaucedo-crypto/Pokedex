import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../data/dex_data.dart';
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
import '../widgets/karen_overlay.dart';
import '../widgets/pokeball.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/trainer_avatar.dart';
import 'detail_screen.dart';
import 'login_screen.dart';

/// Pantalla principal: la lista completa de la Pokédex nacional con buscador,
/// filtro por tipo y favoritos.
///
/// La lista de nombres llega en una sola petición; el detalle de cada Pokémon
/// lo pide su propia tarjeta sólo cuando entra en pantalla.
class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

/// Número de tipos: todos, sólo un tipo (puros) o dos.
enum TypeCount {
  any('Todos'),
  mono('Monotipo (puros)'),
  dual('Doble tipo');

  final String label;
  const TypeCount(this.label);
}

enum DexSort {
  number('Número'),
  numberDesc('Número, al revés'),
  name('Nombre A-Z'),
  nameDesc('Nombre Z-A');

  final String label;
  const DexSort(this.label);
}

/// Los filtros de la hoja "Filtros" (el tipo y el equipo van aparte).
class DexFilters {
  final int? generation;
  final DexCategory? category;
  final TypeCount typeCount;
  final DexSort sort;

  const DexFilters({
    this.generation,
    this.category,
    this.typeCount = TypeCount.any,
    this.sort = DexSort.number,
  });

  DexFilters copyWith({
    int? Function()? generation,
    DexCategory? Function()? category,
    TypeCount? typeCount,
    DexSort? sort,
  }) => DexFilters(
    generation: generation == null ? this.generation : generation(),
    category: category == null ? this.category : category(),
    typeCount: typeCount ?? this.typeCount,
    sort: sort ?? this.sort,
  );

  int get activeCount =>
      (generation != null ? 1 : 0) +
      (category != null ? 1 : 0) +
      (typeCount != TypeCount.any ? 1 : 0) +
      (sort != DexSort.number ? 1 : 0);
}

/// Nombre de una tarjeta: el de la especie, o "Mega Charizard X" en una variante.
String itemLabel(PokemonListItem item) => item.isForm && item.speciesName != null
    ? formDisplayName(item.name, item.speciesName!)
    : displayName(item.name);

class _PokedexScreenState extends State<PokedexScreen> {
  static const _dexSize = PokeApiService.dexSize;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late Future<List<PokemonListItem>> _future;
  List<PokemonListItem> _all = const [];

  String _query = '';
  String? _type;
  Set<int>? _typeMembers;
  bool _loadingType = false;
  bool _onlyFavorites = false;
  DexFilters _filters = const DexFilters();

  /// Hasta cuándo las tarjetas entran animadas: sólo la primera pantalla, una
  /// vez. Antes cada tarjeta esperaba su turno también al desplazarse.
  DateTime _introUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Para que Karen no comente dos veces el mismo vacío o el mismo error.
  String? _lastEmpty;
  bool _errorAnnounced = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // El índice de tipos pinta las tarjetas sin que cada una pida nada.
    TypeIndex.instance.addListener(_onTypesReady);
    TypeIndex.instance.load();
    // En Android y escritorio el tema puede arrancar sin esperar un gesto.
    MusicService.instance.ensureStarted();
    FavoritesStore.instance.addListener(_onFavoritesChanged);

    // La hoja de perfil puede pedir que se repita la guía: se vuelve arriba
    // para que se vea lo que Karen va señalando.
    KarenTourLauncher.handler = () {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      // Al repetir la guía, la de la ficha vuelve a salir con el siguiente
      // Pokémon que se abra.
      ProfileStore.instance.resetDetailTour();
      KarenController.instance.startTour();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      KarenController.instance.welcome(firstTime: !ProfileStore.instance.tutorialDone);
    });
  }

  @override
  void dispose() {
    FavoritesStore.instance.removeListener(_onFavoritesChanged);
    TypeIndex.instance.removeListener(_onTypesReady);
    KarenTourLauncher.handler = null;
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() => setState(() {});

  void _onTypesReady() {
    if (mounted) setState(() {});
  }

  Future<List<PokemonListItem>> _load() async {
    final list = await PokeApiService.instance.getPokemonList();
    _all = list;
    _introUntil = DateTime.now().add(const Duration(milliseconds: 700));
    _errorAnnounced = false;
    return list;
  }

  Future<void> _selectType(String? type) async {
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    if (type == null) {
      setState(() {
        _type = null;
        _typeMembers = null;
        _loadingType = false;
      });
      return;
    }
    setState(() {
      _type = type;
      _loadingType = true;
    });
    try {
      final members = await PokeApiService.instance.getTypeMembers(type);
      if (mounted && _type == type) {
        setState(() {
          _typeMembers = members;
          _loadingType = false;
        });
        final sample = (members.where((id) => id <= _dexSize).toList()..sort()).take(2).toList();
        KarenController.instance.onTypeSelected(type, sample);
      }
    } catch (_) {
      if (mounted && _type == type) {
        setState(() {
          _type = null;
          _typeMembers = null;
          _loadingType = false;
        });
        _snack('No se pudo cargar el tipo ${typeStyle(type).label}. Revisa tu conexión.');
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
    );
  }

  List<PokemonListItem> get _visible => _filtered(_filters);

  /// La lista con la búsqueda y todos los filtros aplicados.
  ///
  /// La hoja de filtros también la usa para decir cuántos saldrían antes de
  /// cerrarla.
  List<PokemonListItem> _filtered(DexFilters f) {
    final q = _query.trim().toLowerCase();
    // "25", "025" y "#025" encuentran a Pikachu, y sale el primero.
    final number = int.tryParse(q.replaceAll('#', ''));
    final favorites = FavoritesStore.instance;
    final category = f.category;
    final forms = PokeApiService.instance.forms;

    // Las categorías de forma listan variantes; buscar por nombre también
    // las incluye ("raichu" encuentra a Raichu y a Raichu de Alola).
    final Iterable<PokemonListItem> source;
    if (category != null && category.isForm) {
      source = forms.where((i) => categoryOfForm(i.name) == category);
    } else if (category == null && q.isNotEmpty) {
      source = [..._all, ...forms];
    } else {
      source = _all;
    }
    final speciesSet = category == null || category.isForm ? null : kCategoryIds[category];

    final list = source.where((item) {
      if (_onlyFavorites && !favorites.contains(item.id)) return false;
      if (_typeMembers != null && !_typeMembers!.contains(item.id)) return false;
      if (speciesSet != null && !speciesSet.contains(item.dexId)) return false;
      if (f.generation != null && generationOf(item.dexId)?.number != f.generation) return false;
      if (f.typeCount != TypeCount.any) {
        final count = TypeIndex.instance.typesOf(item.id)?.length;
        if (count != null && count != (f.typeCount == TypeCount.mono ? 1 : 2)) return false;
      }
      if (q.isEmpty) return true;
      if (number != null) {
        // Por número: el que empieza así (25 → 25, 250…), no el que lo
        // contiene en medio (125, 225).
        return item.dexId.toString().startsWith(number.toString());
      }
      return item.name.contains(q) || itemLabel(item).toLowerCase().contains(q);
    }).toList();

    int byNumber(PokemonListItem a, PokemonListItem b) {
      final c = a.dexId.compareTo(b.dexId);
      return c != 0 ? c : a.id.compareTo(b.id);
    }

    switch (f.sort) {
      case DexSort.number:
        list.sort(byNumber);
      case DexSort.numberDesc:
        list.sort((a, b) => byNumber(b, a));
      case DexSort.name:
        list.sort((a, b) => itemLabel(a).compareTo(itemLabel(b)));
      case DexSort.nameDesc:
        list.sort((a, b) => itemLabel(b).compareTo(itemLabel(a)));
    }
    if (number != null) {
      // El número exacto siempre arriba, luego sus formas, luego el resto.
      int rank(PokemonListItem i) => i.dexId == number ? (i.isForm ? 1 : 0) : 2;
      final ranked = list.indexed.toList()
        ..sort((a, b) {
          final r = rank(a.$2).compareTo(rank(b.$2));
          return r != 0 ? r : a.$1.compareTo(b.$1);
        });
      return [for (final (_, item) in ranked) item];
    }
    return list;
  }

  void _setFilters(DexFilters next) {
    final before = _filters;
    setState(() => _filters = next);
    _toTop();
    final karen = KarenController.instance;
    if (next.generation != null && next.generation != before.generation) {
      karen.onGeneration(next.generation!);
    } else if (next.category != null && next.category != before.category) {
      final sample = _filtered(next).take(3).map((i) => i.id).toList();
      karen.onCategory(next.category!.name, sample);
    } else if (next.typeCount != before.typeCount && next.typeCount != TypeCount.any) {
      karen.onTypeCount(dual: next.typeCount == TypeCount.dual);
    }
  }

  /// Al cambiar la búsqueda o los filtros, la lista vuelve arriba: antes,
  /// con la lista desplazada, el Pokémon buscado quedaba fuera de la vista.
  void _toTop() {
    if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
  }

  void _openFilters() {
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _FilterSheet(
        initial: _filters,
        onChanged: _setFilters,
        countFor: (f) => _filtered(f).length,
      ),
    );
  }

  void _open(List<PokemonListItem> list, int index) {
    SoundService.instance.play(Sfx.open, volume: 0.5);
    final id = list[index].id;
    // El original empieza a bajar ya: la transición le da ventaja.
    Artwork.prefetch(context, id, tier: ArtTier.full);
    PokeApiService.instance.prefetch(id);
    Navigator.of(context).push(DetailScreen.route(list, index));
  }

  void _toggleTeam() {
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    setState(() => _onlyFavorites = !_onlyFavorites);
    if (_onlyFavorites) {
      final team = FavoritesStore.instance;
      final sample = _all.where((item) => team.contains(item.id)).take(3).map((i) => i.id).toList();
      KarenController.instance.onTeamShown(team.count, sample);
    }
  }

  void _openRandom() {
    final list = _visible.isEmpty ? _all : _visible;
    if (list.isEmpty) return;
    SoundService.instance.play(Sfx.swipe, volume: 0.5);
    HapticFeedback.mediumImpact();
    final index = math.Random().nextInt(list.length);
    KarenController.instance.onRandom(list[index].id, itemLabel(list[index]));
    _open(list, index);
  }

  @override
  Widget build(BuildContext context) {
    // Karen se asoma por encima del botón "Al azar", no encima de él.
    return KarenBottomInset(
      value: 76,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          key: KarenTargets.key('random'),
          onPressed: _openRandom,
          backgroundColor: AppColors.pokeRed,
          foregroundColor: Colors.white,
          elevation: 3,
          highlightElevation: 6,
          tooltip: 'Abrir un Pokémon cualquiera',
          icon: const Icon(Icons.casino_rounded),
          label: const Text('Al azar', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: FutureBuilder<List<PokemonListItem>>(
          future: _future,
          builder: (context, snap) {
            return CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              // Construye (y por tanto descarga) unas filas por debajo de lo
              // que se ve: al bajar, las imágenes ya están.
              scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
              slivers: [
                _buildHeader(snap),
                if (snap.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Builder(
                      builder: (context) {
                        if (!_errorAnnounced) {
                          _errorAnnounced = true;
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => KarenController.instance.onNetworkError(),
                          );
                        }
                        return _ErrorState(
                          message: PokeApiService.friendlyError(snap.error!),
                          onRetry: () => setState(() => _future = _load()),
                        );
                      },
                    ),
                  )
                else if (!snap.hasData || _loadingType)
                  _buildSkeleton()
                else
                  _buildGrid(),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncSnapshot<List<PokemonListItem>> snap) {
    final count = snap.hasData ? _visible.length : 0;
    final chips = _activeChips();

    return SliverAppBar(
      pinned: true,
      toolbarHeight: 62,
      backgroundColor: AppColors.pokeRed,
      foregroundColor: Colors.white,
      elevation: 0,
      // Al bajar, una sombra suave separa la cabecera de las tarjetas que
      // pasan por debajo (antes se cortaban en seco bajo los filtros).
      scrolledUnderElevation: 3,
      shadowColor: const Color(0x401B1D2A),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      // Título y botones van dentro del mismo ancho que la cuadrícula: en una
      // pantalla ancha antes quedaban pegados a las orillas de la ventana,
      // lejos de todo lo demás.
      title: ContentWidth(
        maxWidth: kGridMaxWidth,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pokédex',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        snap.hasData
                            ? '$count ${count == 1 ? 'resultado' : 'resultados'} · PokeAPI'
                            : 'Conectando con la PokeAPI…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _FavoritesToggle(
                  key: KarenTargets.key('team'),
                  active: _onlyFavorites,
                  onPressed: _toggleTeam,
                ),
                Row(
                  key: KarenTargets.key('sound'),
                  mainAxisSize: MainAxisSize.min,
                  children: const [_MusicToggle(), _SoundToggle()],
                ),
                const SizedBox(width: 6),
                // Avatar del entrenador: abre su perfil. La clave va en el
                // avatar para que el foco de la guía lo rodee sólo a él.
                ListenableBuilder(
                  listenable: ProfileStore.instance,
                  builder: (context, _) => KeyedSubtree(
                    key: KarenTargets.key('avatar'),
                    child: TrainerAvatar(
                      photo: ProfileStore.instance.photo,
                      initials: ProfileStore.instance.initials,
                      size: 36,
                      ring: Colors.white,
                      fill: Colors.white.withValues(alpha: 0.18),
                      tooltip: 'Tu perfil',
                      onTap: () => showTrainerSheet(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF04E2A), AppColors.pokeRed, Color(0xFFA81F05)],
              ),
            ),
          ),
          Positioned(
            top: -74,
            right: -46,
            // Quieta: girando, la lista nunca dejaba de pedir fotogramas, y
            // en el teléfono eso se notaba al desplazarse.
            child: SpinningPokeball(
              size: 170,
              color: Colors.white.withValues(alpha: 0.13),
              animate: false,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(chips.isEmpty ? 106 : 146),
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Column(
            children: [
              ContentWidth(
                maxWidth: kGridMaxWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: KeyedSubtree(
                          key: KarenTargets.key('search'),
                          child: _SearchField(
                            controller: _search,
                            onChanged: (v) {
                              setState(() => _query = v);
                              _toTop();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        key: KarenTargets.key('filters'),
                        active: _filters.activeCount,
                        onPressed: _openFilters,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ContentWidth(
                maxWidth: kGridMaxWidth,
                child: KeyedSubtree(
                  key: KarenTargets.key('types'),
                  child: _TypeFilterBar(selected: _type, onSelected: _selectType),
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                ContentWidth(
                  maxWidth: kGridMaxWidth,
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: chips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => chips[i],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Filtros activos, cada uno con su cruz para quitarlo.
  List<Widget> _activeChips() {
    final f = _filters;
    final gen = f.generation == null ? null : kGenerations[f.generation! - 1];
    return [
      if (gen != null)
        _ActiveChip(
          label: gen.label,
          onRemove: () => _setFilters(f.copyWith(generation: () => null)),
        ),
      if (f.category != null)
        _ActiveChip(
          label: f.category!.label,
          onRemove: () => _setFilters(f.copyWith(category: () => null)),
        ),
      if (f.typeCount != TypeCount.any)
        _ActiveChip(
          label: f.typeCount.label,
          onRemove: () => _setFilters(f.copyWith(typeCount: TypeCount.any)),
        ),
      if (f.sort != DexSort.number)
        _ActiveChip(
          label: 'Orden: ${f.sort.label}',
          onRemove: () => _setFilters(f.copyWith(sort: DexSort.number)),
        ),
    ];
  }

  /// Centra la cuadrícula en pantallas anchas en lugar de estirarla. Queda
  /// alineada con el buscador y la cabecera, que usan el mismo ancho.
  EdgeInsets _gridPadding(BuildContext context) {
    final side = math.max(0.0, (MediaQuery.sizeOf(context).width - kGridMaxWidth) / 2) + 12;
    return EdgeInsets.fromLTRB(side, 8, side, 0);
  }

  /// Dos columnas en un teléfono, seis en una pantalla ancha.
  SliverGridDelegate get _gridDelegate => SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: Layout.of(context).cardMaxExtent,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.4,
  );

  Widget _buildSkeleton() => SliverPadding(
    padding: _gridPadding(context),
    sliver: SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, i) => PokemonCardSkeleton(index: i),
        childCount: 12,
      ),
    ),
  );

  Widget _buildGrid() {
    final list = _visible;
    if (list.isEmpty) {
      // Karen sólo opina si la lista quedó vacía por una búsqueda o un filtro,
      // no cuando el equipo todavía está sin estrenar; y una vez por búsqueda.
      final key = '${_query.trim()}|$_type|${_filters.generation}|${_filters.category}|${_filters.typeCount}';
      if (!_onlyFavorites && _lastEmpty != key) {
        _lastEmpty = key;
        WidgetsBinding.instance.addPostFrameCallback((_) => KarenController.instance.onNoResults());
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          onlyFavorites: _onlyFavorites,
          teamIsEmpty: FavoritesStore.instance.count == 0,
          onClear: _filters.activeCount > 0 || _type != null || _query.isNotEmpty
              ? () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _filters = const DexFilters();
                  });
                  _selectType(null);
                }
              : null,
        ),
      );
    }
    final animateUntil = _introUntil;
    final showAnchor =
        !_onlyFavorites && _type == null && _query.trim().isEmpty && _filters.activeCount == 0;
    return SliverPadding(
      padding: _gridPadding(context),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          // Las tarjetas se reciclan al desplazarse; mantenerlas vivas fuera de
          // pantalla sólo gasta memoria.
          addAutomaticKeepAlives: false,
          childCount: list.length,
          (context, index) {
            final card = PokemonCard(
              key: ValueKey(list[index].id),
              item: list[index],
              anchorKey: showAnchor && index == 0 ? KarenTargets.key('card') : null,
              onTap: () => _open(list, index),
            );
            // Sólo la primera pantalla entra escalonada, y una sola vez.
            if (index >= 12 || DateTime.now().isAfter(animateUntil)) return card;
            return _FadeInUp(
              delay: Duration(milliseconds: 40 * index),
              child: card,
            );
          },
        ),
      ),
    );
  }
}

/// Buscador por nombre o número de Pokédex.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0A1B1D2A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o número…',
          hintStyle: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

/// Carrusel de tipos. El tipo activo se reconoce por color, icono y texto.
class _TypeFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _TypeFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final types = kTypeStyles.keys.toList();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: types.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterPill(
              label: 'Todos',
              icon: Icons.apps_rounded,
              color: AppColors.ink,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final type = types[i - 1];
          final style = typeStyle(type);
          return _FilterPill(
            label: style.label,
            icon: style.icon,
            color: style.color,
            active: selected == type,
            onTap: () => onSelected(selected == type ? null : type),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: active ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : AppColors.line),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onPressed;

  const _FavoritesToggle({super.key, required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final count = FavoritesStore.instance.count;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: active ? 'Ver todos' : 'Ver sólo favoritos',
              onPressed: onPressed,
              icon: Icon(active ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.pokeRed,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Interruptor de la música de ambiente, aparte de los efectos. Se guarda
/// en los ajustes: ya no se pierde al cerrar la app.
class _MusicToggle extends StatelessWidget {
  const _MusicToggle();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => IconButton(
        tooltip: settings.music ? 'Quitar la música' : 'Poner la música',
        onPressed: () => settings.setMusic(!settings.music),
        icon: Icon(settings.music ? Icons.music_note_rounded : Icons.music_off_rounded),
      ),
    );
  }
}

class _SoundToggle extends StatelessWidget {
  const _SoundToggle();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => IconButton(
        tooltip: settings.sounds ? 'Silenciar efectos' : 'Activar efectos',
        onPressed: () async {
          await settings.setSounds(!settings.sounds);
          if (settings.sounds) SoundService.instance.play(Sfx.tap, volume: 0.4);
        },
        icon: Icon(settings.sounds ? Icons.volume_up_rounded : Icons.volume_off_rounded),
      ),
    );
  }
}

/// Entrada escalonada: la tarjeta aparece subiendo y aclarándose.
class _FadeInUp extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeInUp({required this.child, required this.delay});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, child) => Opacity(
      opacity: _anim.value,
      child: Transform.translate(offset: Offset(0, (1 - _anim.value) * 22), child: child),
    ),
    child: widget.child,
  );
}

class _EmptyState extends StatelessWidget {
  final bool onlyFavorites;
  final bool teamIsEmpty;
  final VoidCallback? onClear;

  const _EmptyState({required this.onlyFavorites, required this.teamIsEmpty, this.onClear});

  @override
  Widget build(BuildContext context) {
    // Con el equipo filtrado por tipo o búsqueda, "tu equipo está vacío" era
    // mentira: el equipo existe, sólo que nadie coincide.
    final (title, hint) = switch ((onlyFavorites, teamIsEmpty)) {
      (true, true) => (
        'Tu equipo está vacío',
        'Abre un Pokémon y toca el corazón para añadirlo a tu equipo.',
      ),
      (true, false) => (
        'Nadie de tu equipo coincide',
        'Quita el filtro o la búsqueda para ver a tu equipo completo.',
      ),
      _ => ('Sin resultados', 'Prueba con otro nombre, número o tipo.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pokeball(size: 96, color: AppColors.ink.withValues(alpha: 0.1)),
          const SizedBox(height: 22),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('Quitar búsqueda y filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.muted),
          const SizedBox(height: 18),
          const Text(
            'No hay conexión con la Pokédex',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.pokeRed),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Botón de la hoja de filtros, junto al buscador. Lleva la cuenta de los
/// filtros activos.
class _FilterButton extends StatelessWidget {
  final int active;
  final VoidCallback onPressed;

  const _FilterButton({super.key, required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final on = active > 0;
    return Tooltip(
      message: 'Filtros: generación, categoría, monotipo y orden',
      child: Material(
        color: on ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? AppColors.ink : AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 19, color: on ? Colors.white : AppColors.ink),
                const SizedBox(width: 6),
                Text(
                  on ? 'Filtros · $active' : 'Filtros',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : AppColors.ink,
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

class _ActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.only(left: 11, right: 6),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.close_rounded, size: 15, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Hoja de filtros: generación, número de tipos, categoría y orden. Los
/// cambios se aplican al momento y el botón dice cuántos quedan.
class _FilterSheet extends StatefulWidget {
  final DexFilters initial;
  final ValueChanged<DexFilters> onChanged;
  final int Function(DexFilters) countFor;

  const _FilterSheet({required this.initial, required this.onChanged, required this.countFor});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DexFilters _f = widget.initial;

  void _set(DexFilters next) {
    SoundService.instance.play(Sfx.tap, volume: 0.3);
    setState(() => _f = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.countFor(_f);
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.86),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(
                'Filtros',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  const _SheetTitle('Generación'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Choice(
                        label: 'Todas',
                        selected: _f.generation == null,
                        onTap: () => _set(_f.copyWith(generation: () => null)),
                      ),
                      for (final g in kGenerations)
                        _Choice(
                          label: g.label,
                          selected: _f.generation == g.number,
                          onTap: () => _set(
                            _f.copyWith(generation: () => _f.generation == g.number ? null : g.number),
                          ),
                        ),
                    ],
                  ),
                  const _SheetTitle('Tipos'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in TypeCount.values)
                        _Choice(
                          label: t.label,
                          selected: _f.typeCount == t,
                          onTap: () => _set(_f.copyWith(typeCount: t)),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Combínalo con un tipo de la barra: Fuego + Monotipo son los de fuego puro.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
                    ),
                  ),
                  const _SheetTitle('Categoría'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Choice(
                        label: 'Todas',
                        selected: _f.category == null,
                        onTap: () => _set(_f.copyWith(category: () => null)),
                      ),
                      for (final c in DexCategory.values)
                        _Choice(
                          label: c.label,
                          tooltip: c.hint,
                          icon: c.isForm ? Icons.auto_awesome_motion_rounded : null,
                          selected: _f.category == c,
                          onTap: () =>
                              _set(_f.copyWith(category: () => _f.category == c ? null : c)),
                        ),
                    ],
                  ),
                  const _SheetTitle('Ordenar por'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final o in DexSort.values)
                        _Choice(
                          label: o.label,
                          selected: _f.sort == o,
                          onTap: () => _set(_f.copyWith(sort: o)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _f.activeCount == 0 ? null : () => _set(const DexFilters()),
                    child: const Text('Limpiar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pokeRed,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Ver $count Pokémon',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

class _SheetTitle extends StatelessWidget {
  final String text;

  const _SheetTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final IconData? icon;

  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : AppColors.muted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

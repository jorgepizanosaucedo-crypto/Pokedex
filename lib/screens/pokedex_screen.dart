import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

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

class _PokedexScreenState extends State<PokedexScreen> {
  static const _dexSize = 1025;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late Future<List<PokemonListItem>> _future;
  List<PokemonListItem> _all = const [];

  String _query = '';
  String? _type;
  Set<int>? _typeMembers;
  bool _loadingType = false;
  bool _onlyFavorites = false;

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
    final list = await PokeApiService.instance.getPokemonList(limit: _dexSize);
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

  List<PokemonListItem> get _visible {
    final q = _query.trim().toLowerCase();
    // "25", "025" y "#025" encuentran a Pikachu.
    final number = int.tryParse(q.replaceAll('#', ''));
    final favorites = FavoritesStore.instance;
    return _all.where((item) {
      if (_onlyFavorites && !favorites.contains(item.id)) return false;
      if (_typeMembers != null && !_typeMembers!.contains(item.id)) return false;
      if (q.isEmpty) return true;
      if (number != null) return item.id.toString().contains(number.toString());
      return item.name.contains(q) || displayName(item.name).toLowerCase().contains(q);
    }).toList();
  }

  void _open(List<PokemonListItem> list, int index) {
    SoundService.instance.play(Sfx.open, volume: 0.5);
    final id = list[index].id;
    // El original empieza a bajar ya: la transición le da ventaja.
    Artwork.prefetch(context, id, tier: ArtTier.full);
    PokeApiService.instance.prefetch(id);
    Navigator.of(context).push(DetailScreen.route(list, index));
  }

  void _openRandom() {
    final list = _visible.isEmpty ? _all : _visible;
    if (list.isEmpty) return;
    SoundService.instance.play(Sfx.swipe, volume: 0.5);
    HapticFeedback.mediumImpact();
    final index = math.Random().nextInt(list.length);
    KarenController.instance.onRandom(list[index].id, displayName(list[index].name));
    _open(list, index);
  }

  @override
  Widget build(BuildContext context) {
    // Karen se asoma por encima del botón "Al azar", no encima de él.
    return KarenBottomInset(
      value: 76,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
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
      titleSpacing: 16,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // El título va en el toolbar, no en un FlexibleSpaceBar: así no depende
      // del rango de colapso y nunca se desvanece.
      title: Column(
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
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
      actions: [
        _FavoritesToggle(
          key: KarenTargets.key('team'),
          active: _onlyFavorites,
          onPressed: () {
            SoundService.instance.play(Sfx.tap, volume: 0.35);
            setState(() => _onlyFavorites = !_onlyFavorites);
          },
        ),
        Row(
          key: KarenTargets.key('sound'),
          mainAxisSize: MainAxisSize.min,
          children: const [_MusicToggle(), _SoundToggle()],
        ),
        // Avatar del entrenador: abre su perfil.
        ListenableBuilder(
          listenable: ProfileStore.instance,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(6, 13, 14, 13),
            // La clave va en el avatar y no en el relleno: así el foco de la
            // guía lo rodea a él, sin salirse por la orilla de la pantalla.
            child: KeyedSubtree(
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
        ),
      ],
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
            child: SpinningPokeball(size: 170, color: Colors.white.withValues(alpha: 0.13)),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(106),
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Column(
            children: [
              ContentWidth(
                maxWidth: kGridMaxWidth,
                child: Padding(
                  key: KarenTargets.key('search'),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SearchField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Centra la cuadrícula en pantallas anchas en lugar de estirarla.
  EdgeInsets _gridPadding(BuildContext context) {
    final side = ((MediaQuery.sizeOf(context).width - kGridMaxWidth) / 2).clamp(12.0, 400.0);
    return EdgeInsets.fromLTRB(side, 8, side, 0);
  }

  /// Dos columnas en un teléfono, seis en una pantalla ancha.
  static const SliverGridDelegate _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 200,
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
      final key = '${_query.trim()}|$_type';
      if (!_onlyFavorites && _lastEmpty != key) {
        _lastEmpty = key;
        WidgetsBinding.instance.addPostFrameCallback((_) => KarenController.instance.onNoResults());
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          onlyFavorites: _onlyFavorites,
          teamIsEmpty: FavoritesStore.instance.count == 0,
        ),
      );
    }
    final animateUntil = _introUntil;
    final showAnchor = !_onlyFavorites && _type == null && _query.trim().isEmpty;
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

  const _EmptyState({required this.onlyFavorites, required this.teamIsEmpty});

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

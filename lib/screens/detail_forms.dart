part of 'detail_screen.dart';

/// Una opción de la tira de formas de la ficha.
class _FormOption {
  /// `v:<id>` para una variante, `f:<nombre>` para una forma de aspecto y
  /// `p:<id>` para un pariente paradoja.
  final String key;
  final String label;

  /// Pokémon (variante) que hay que pedir para mostrarla.
  final int pokemonId;

  /// Forma de aspecto (`/pokemon-form/`), si sólo cambia el dibujo y el tipo.
  final String? formName;
  final FormKind kind;

  /// Los parientes paradoja no transforman: abren la ficha del otro.
  final int? linkId;
  final String? linkName;

  const _FormOption({
    required this.key,
    required this.label,
    required this.pokemonId,
    required this.kind,
    this.formName,
    this.linkId,
    this.linkName,
  });

  bool get isLink => linkId != null;
}

/// Clave de la forma que muestra [pokemon].
String _formKeyOf(Pokemon pokemon) =>
    pokemon.formName != null ? 'f:${pokemon.formName}' : 'v:${pokemon.id}';

/// Etiqueta de la forma de un Pokémon ya cargado ("Mega X", "Tipo Fuego"),
/// o `null` si es la forma normal.
String? _formLabelOf(Pokemon pokemon) {
  final name = pokemon.formName ?? pokemon.name;
  if (pokemon.formName == null && !pokemon.isVariant) return null;
  final label = formLabel(name, pokemon.speciesName);
  return label == 'Normal' ? null : label;
}

/// Nombre completo para Karen y el combate: "Mega Charizard X".
String _fullName(Pokemon pokemon) =>
    formDisplayName(pokemon.formName ?? pokemon.name, pokemon.speciesName);

/// Todas las formas de una especie: variantes (megas, regionales, gigamax,
/// Origen…), formas de aspecto de la variante normal (los 18 tipos de Arceus,
/// las letras de Unown…) y, al final, sus parientes paradoja.
List<_FormOption> _formOptions(PokemonSpecies species, Pokemon? base, Pokemon shown) {
  final speciesName = shown.speciesName;
  final options = <_FormOption>[
    for (final v in species.varieties)
      _FormOption(
        key: 'v:${v.id}',
        label: formLabel(v.name, speciesName),
        pokemonId: v.id,
        kind: v.isDefault ? FormKind.base : formKindOf(v.name),
      ),
  ];
  if (base != null && base.forms.length > 1) {
    for (final f in base.forms.skip(1)) {
      // Algunas formas de aspecto repiten una variante con otro nombre.
      if (species.varieties.any((v) => v.name == f.name)) continue;
      options.add(
        _FormOption(
          key: 'f:${f.name}',
          label: formLabel(f.name, speciesName),
          pokemonId: base.id,
          formName: f.name,
          kind: formKindOf(f.name) == FormKind.other ? FormKind.other : formKindOf(f.name),
        ),
      );
    }
  }
  for (final r in paradoxRelatives(shown.speciesId)) {
    final name = PokeApiService.instance.nameOf(r.id) ?? '';
    options.add(
      _FormOption(
        key: 'p:${r.id}',
        label: '${r.label}: ${displayName(name)}',
        pokemonId: r.id,
        kind: FormKind.other,
        linkId: r.id,
        linkName: name,
      ),
    );
  }
  return options;
}

/// Tira de formas bajo el nombre. No aparece si la especie sólo tiene una.
class _FormStrip extends StatefulWidget {
  final Pokemon pokemon;
  final String selectedKey;
  final bool loading;
  final Color accent;
  final bool active;
  final ValueChanged<_FormOption> onSelect;

  const _FormStrip({
    required this.pokemon,
    required this.selectedKey,
    required this.loading,
    required this.accent,
    required this.active,
    required this.onSelect,
  });

  @override
  State<_FormStrip> createState() => _FormStripState();
}

class _FormStripState extends State<_FormStrip> {
  late Future<List<_FormOption>> _options = _load();
  int _species = 0;

  Future<List<_FormOption>> _load() async {
    _species = widget.pokemon.speciesId;
    final api = PokeApiService.instance;
    final species = await api.getSpecies(widget.pokemon.speciesId);
    final defaultId = species.varieties
        .firstWhere((v) => v.isDefault, orElse: () => (name: '', id: widget.pokemon.speciesId, isDefault: true))
        .id;
    Pokemon? base;
    try {
      base = await api.getPokemon(defaultId);
    } catch (_) {}
    return _formOptions(species, base, widget.pokemon);
  }

  @override
  void didUpdateWidget(covariant _FormStrip old) {
    super.didUpdateWidget(old);
    if (widget.pokemon.speciesId != _species) _options = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_FormOption>>(
      future: _options,
      builder: (context, snap) {
        final options = snap.data ?? const <_FormOption>[];
        if (options.length <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            key: KarenTargets.keyIf(widget.active, 'forms'),
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final o = options[i];
                return _FormChip(
                  option: o,
                  selected: o.key == widget.selectedKey,
                  loading: widget.loading && o.key == widget.selectedKey,
                  accent: widget.accent,
                  onTap: () => widget.onSelect(o),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Color e icono de cada clase de forma.
({Color color, IconData icon}) _formStyle(_FormOption o) {
  if (o.isLink) {
    return (
      color: const Color(0xFF8D6E63),
      icon: o.label.startsWith('Del futuro') ? Icons.rocket_launch_rounded : Icons.history_rounded,
    );
  }
  return switch (o.kind) {
    FormKind.mega => (color: const Color(0xFF8E44AD), icon: Icons.auto_awesome_rounded),
    FormKind.gmax => (color: const Color(0xFFD7263D), icon: Icons.open_in_full_rounded),
    FormKind.primal => (color: const Color(0xFF1565C0), icon: Icons.waves_rounded),
    FormKind.regional => (color: const Color(0xFF2E7D32), icon: Icons.public_rounded),
    FormKind.base => (color: AppColors.ink, icon: Icons.catching_pokemon_rounded),
    FormKind.other => (color: const Color(0xFF00838F), icon: Icons.change_circle_rounded),
  };
}

class _FormChip extends StatelessWidget {
  final _FormOption option;
  final bool selected;
  final bool loading;
  final Color accent;
  final VoidCallback onTap;

  const _FormChip({
    required this.option,
    required this.selected,
    required this.loading,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _formStyle(option);
    final color = style.color;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.only(left: 4, right: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: color),
                      )
                    : _FormThumb(option: option),
              ),
              const SizedBox(width: 4),
              Icon(style.icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura de una forma. Las de aspecto piden su dibujo a la PokeAPI.
class _FormThumb extends StatelessWidget {
  final _FormOption option;

  const _FormThumb({required this.option});

  @override
  Widget build(BuildContext context) {
    final formName = option.formName;
    if (formName == null) {
      return ArtworkImage(id: option.pokemonId, size: 38);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: PokeApiService.instance.getForm(formName),
      builder: (context, snap) {
        final sprites = snap.data?['sprites'] as Map?;
        final url =
            sprites?['other']?['official-artwork']?['front_default'] as String? ??
            sprites?['front_default'] as String?;
        if (url == null) return ArtworkImage(id: option.pokemonId, size: 38);
        return Image.network(
          url,
          width: 38,
          height: 38,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => ArtworkImage(id: option.pokemonId, size: 38),
        );
      },
    );
  }
}

/// Destello al transformarse: un anillo que se abre y un fogonazo. En las
/// megas el anillo es arcoíris, en gigamax rojo y en Primigenio azul.
class _MorphBurst extends StatelessWidget {
  final Animation<double> animation;
  final FormKind kind;
  final double size;

  const _MorphBurst({required this.animation, required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.square(size),
            painter: _MorphPainter(t: t, kind: kind),
          );
        },
      ),
    );
  }
}

class _MorphPainter extends CustomPainter {
  final double t;
  final FormKind kind;

  _MorphPainter({required this.t, required this.kind});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Fogonazo central.
    final flash = (1 - t * 1.6).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawCircle(
        c,
        r * (0.4 + t),
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: flash), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r * (0.4 + t))),
      );
    }

    // Anillos que se abren.
    final colors = switch (kind) {
      FormKind.mega => const [
        Color(0xFFFF5252),
        Color(0xFFFFD740),
        Color(0xFF69F0AE),
        Color(0xFF40C4FF),
        Color(0xFFE040FB),
        Color(0xFFFF5252),
      ],
      FormKind.gmax => const [Color(0xFFFF1744), Color(0xFFFF80AB), Color(0xFFFF1744)],
      FormKind.primal => const [Color(0xFF2979FF), Color(0xFFFF3D00), Color(0xFF2979FF)],
      _ => const [Colors.white, Color(0xFFB3E5FC), Colors.white],
    };
    for (var i = 0; i < 3; i++) {
      final k = (t - i * 0.12).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final radius = r * 0.25 + r * 0.85 * Curves.easeOut.transform(k);
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - k) + 1
          ..shader = SweepGradient(
            colors: [for (final col in colors) col.withValues(alpha: 1 - k)],
            transform: GradientRotation(t * 6),
          ).createShader(rect),
      );
    }

    // Chispas que salen disparadas.
    final rand = math.Random(kind.index);
    for (var i = 0; i < 18; i++) {
      final angle = i / 18 * math.pi * 2 + rand.nextDouble() * 0.3;
      final dist = r * (0.3 + 0.8 * Curves.easeOut.transform(t)) * (0.7 + rand.nextDouble() * 0.5);
      final p = c + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.drawCircle(
        p,
        3.5 * (1 - t) + 0.5,
        Paint()..color = colors[i % colors.length].withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MorphPainter old) => old.t != t || old.kind != kind;
}

/// Formas especiales de la especie (mega, gigamax, primigenio) en la pestaña
/// de evolución, con cómo se consiguen.
class _SpecialForms extends StatelessWidget {
  final PokemonSpecies species;
  final String speciesName;
  final Color accent;
  final ValueChanged<_FormOption> onSelect;

  const _SpecialForms({
    required this.species,
    required this.speciesName,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final special = species.varieties
        .where((v) => specialFormHowTo(v.name) != null)
        .toList();
    if (special.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const _SectionTitle('Megaevolución, gigamax y más'),
        const SizedBox(height: 10),
        for (final v in special)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NoteCard(
              color: _formStyle(
                _FormOption(key: '', label: '', pokemonId: v.id, kind: formKindOf(v.name)),
              ).color,
              leading: ArtworkImage(id: v.id, size: 52),
              title: formDisplayName(v.name, speciesName),
              text: specialFormHowTo(v.name)!,
              item: kMegaStones[v.name]?.$1,
              action: 'Ver',
              onTap: () => onSelect(
                _FormOption(
                  key: 'v:${v.id}',
                  label: formLabel(v.name, speciesName),
                  pokemonId: v.id,
                  kind: formKindOf(v.name),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de nota: dibujo, título, una frase y, si hace falta, el objeto.
class _NoteCard extends StatelessWidget {
  final Color color;
  final Widget leading;
  final String title;
  final String text;
  final String? item;
  final String? action;
  final VoidCallback? onTap;

  const _NoteCard({
    required this.color,
    required this.leading,
    required this.title,
    required this.text,
    this.item,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF3C4053)),
                    ),
                  ],
                ),
              ),
              if (item != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Objeto necesario',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Image.network(
                      itemSpriteUrl(item!),
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.inventory_2_rounded, size: 18, color: color),
                    ),
                  ),
                ),
              ],
              if (action != null && item == null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

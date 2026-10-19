part of 'detail_screen.dart';

// ------------------------------------------------------------ debilidades

/// Qué le hace cada tipo de ataque, agrupado: ×4, ×2, ×½, ×¼ y ×0.
class _WeaknessSection extends StatelessWidget {
  final List<String> types;

  const _WeaknessSection({required this.types});

  @override
  Widget build(BuildContext context) {
    final profile = defensiveProfile(types);
    const groups = [
      (4.0, 'Muy débil', '×4', Color(0xFFC62828)),
      (2.0, 'Débil', '×2', Color(0xFFE65100)),
      (0.5, 'Resiste', '×½', Color(0xFF2E7D32)),
      (0.25, 'Resiste mucho', '×¼', Color(0xFF1B5E20)),
      (0.0, 'Inmune', '×0', Color(0xFF455A64)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const _SectionTitle('Debilidades y resistencias'),
        const SizedBox(height: 4),
        const Text(
          'Cuánto daño le hace cada tipo de ataque.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        for (final (mult, label, badge, color) in groups)
          if (profile[mult] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: [
                            for (final t in profile[mult]!)
                              TypeChip(type: t, onColor: false, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// -------------------------------------------------------------- cría

const Map<String, String> _eggGroups = {
  'monster': 'Monstruo',
  'water1': 'Agua 1',
  'water2': 'Agua 2',
  'water3': 'Agua 3',
  'bug': 'Bicho',
  'flying': 'Volador',
  'ground': 'Campo',
  'fairy': 'Hada',
  'plant': 'Planta',
  'humanshape': 'Humanoide',
  'mineral': 'Mineral',
  'indeterminate': 'Amorfo',
  'ditto': 'Ditto',
  'dragon': 'Dragón',
  'no-eggs': 'Sin huevos',
};

const Map<String, String> _growthRates = {
  'slow': 'Lento',
  'medium': 'Medio',
  'fast': 'Rápido',
  'medium-slow': 'Parabólico',
  'slow-then-very-fast': 'Errático',
  'fast-then-very-slow': 'Fluctuante',
};

/// 0.875 → "87.5"; 0.5 → "50".
String _percent(double fraction) {
  final v = fraction * 100;
  return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Género, grupos huevo, eclosión, crecimiento, generación y puntos de esfuerzo.
class _BreedingSection extends StatelessWidget {
  final PokemonSpecies species;
  final Pokemon pokemon;
  final Color accent;

  const _BreedingSection({required this.species, required this.pokemon, required this.accent});

  @override
  Widget build(BuildContext context) {
    final gen = generationOf(pokemon.speciesId);
    final evs = [
      for (final s in pokemon.stats)
        if (s.effort > 0) '+${s.effort} ${kStatLabels[s.name] ?? s.name}',
    ];
    final female = species.genderRate < 0 ? null : species.genderRate / 8;

    Widget row(IconData icon, String label, Widget value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Text value(String text) =>
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SectionTitle('Cría y crecimiento'),
        const SizedBox(height: 10),
        row(
          Icons.wc_rounded,
          'Género',
          female == null
              ? value('Sin género')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 7,
                        child: Row(
                          children: [
                            if (female < 1)
                              Expanded(
                                flex: ((1 - female) * 100).round(),
                                child: Container(color: const Color(0xFF4A8FD9)),
                              ),
                            if (female > 0)
                              Expanded(
                                flex: (female * 100).round(),
                                child: Container(color: const Color(0xFFEB6FA6)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '♂ ${_percent(1 - female)} %   ♀ ${_percent(female)} %',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
        row(
          Icons.egg_rounded,
          'Grupo huevo',
          value(species.eggGroups.map((g) => _eggGroups[g] ?? capitalize(g)).join(' · ')),
        ),
        if (species.hatchCounter > 0)
          row(
            Icons.directions_walk_rounded,
            'Eclosión',
            value('${species.hatchCounter} ciclos (≈ ${species.hatchCounter * 257} pasos)'),
          ),
        if (species.growthRate != null)
          row(
            Icons.show_chart_rounded,
            'Crecimiento',
            value(_growthRates[species.growthRate] ?? capitalize(species.growthRate!)),
          ),
        if (gen != null) row(Icons.public_rounded, 'Generación', value(gen.label)),
        if (evs.isNotEmpty) row(Icons.fitness_center_rounded, 'Da al vencerlo', value(evs.join(', '))),
        if (species.isBaby) row(Icons.child_care_rounded, 'Etapa', value('Pokémon bebé')),
      ],
    );
  }
}

// --------------------------------------------------------- habilidades

/// Habilidad con su nombre en español. Al tocarla explica qué hace.
class _AbilityChip extends StatelessWidget {
  final PokemonAbility ability;
  final Color accent;

  const _AbilityChip({required this.ability, required this.accent});

  void _open(BuildContext context) {
    SoundService.instance.play(Sfx.sheetUp, volume: 0.4);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _InfoSheetModal(
        child: FutureBuilder<AbilityInfo>(
          future: PokeApiService.instance.getAbility(ability.name),
          builder: (context, snap) {
            final info = snap.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ability.isHidden ? Icons.visibility_off_rounded : Icons.bolt_rounded,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info?.label ?? capitalize(ability.name),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (ability.isHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Habilidad oculta: sólo la tienen algunos ejemplares.',
                      style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 12),
                if (snap.hasError)
                  const Text(
                    'No se pudo cargar la descripción.',
                    style: TextStyle(color: AppColors.muted),
                  )
                else if (info == null)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Text(
                    info.description.isEmpty ? 'Sin descripción.' : info.description,
                    style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF3C4053)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ability.isHidden)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.visibility_off_rounded, size: 14, color: accent),
                ),
              FutureBuilder<AbilityInfo>(
                future: PokeApiService.instance.getAbility(ability.name),
                builder: (context, snap) => Text(
                  snap.data?.label ?? capitalize(ability.name),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: accent),
                ),
              ),
              if (ability.isHidden)
                Text(
                  '  oculta',
                  style: TextStyle(fontSize: 11.5, color: accent.withValues(alpha: 0.75)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded, size: 13, color: accent.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja blanca pequeña para explicar algo (habilidad, movimiento).
class _InfoSheetModal extends StatelessWidget {
  final Widget child;

  const _InfoSheetModal({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------- cómo evoluciona

/// Frases de cómo evoluciona cada paso de la cadena. Las que no son sólo
/// subir de nivel (piedras, intercambios, amistad, lugares…) van resaltadas
/// y con el dibujo del objeto.
class _EvolutionNotes extends StatelessWidget {
  final List<List<EvolutionStep>> stages;
  final Color accent;

  const _EvolutionNotes({required this.stages, required this.accent});

  static String sentence(EvolutionStep step) =>
      '${displayName(step.parentName ?? '')} evoluciona en ${displayName(step.name)} ${step.howTo}';

  @override
  Widget build(BuildContext context) {
    final steps = [
      for (final stage in stages.skip(1))
        for (final step in stage)
          if (step.howTo != null && step.parentName != null) step,
    ];
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const _SectionTitle('¿Cómo evoluciona?'),
        const SizedBox(height: 10),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: step.special
                ? _NoteCard(
                    color: accent,
                    leading: ArtworkImage(id: step.id, size: 44),
                    title: step.item != null ? 'Evolución por objeto' : 'Evolución especial',
                    text: '${sentence(step)}.',
                    item: step.item,
                  )
                : Row(
                    children: [
                      Icon(Icons.trending_up_rounded, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${sentence(step)}.',
                          style: const TextStyle(fontSize: 12.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------- movimientos

const Map<LearnMethod, String> _methodLabels = {
  LearnMethod.level: 'Por nivel',
  LearnMethod.machine: 'MT',
  LearnMethod.egg: 'Huevo',
  LearnMethod.tutor: 'Tutor',
  LearnMethod.other: 'Otros',
};

/// Pestaña «Movimientos»: lo que aprende, por nivel, MT, huevo y tutor. Cada
/// fila pide los datos de su movimiento sólo cuando se ve.
class _MovesTab extends StatefulWidget {
  final Pokemon pokemon;
  final Color accent;

  const _MovesTab({required this.pokemon, required this.accent});

  @override
  State<_MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<_MovesTab> {
  late Future<List<PokemonMoveRef>> _moves = _load();
  LearnMethod _method = LearnMethod.level;

  /// Las megas y algunas formas no traen movimientos: se usan los de la base.
  Future<List<PokemonMoveRef>> _load() async {
    if (widget.pokemon.moves.isNotEmpty) return widget.pokemon.moves;
    if (!widget.pokemon.isVariant) return const [];
    final base = await PokeApiService.instance.getPokemon(widget.pokemon.speciesId);
    return base.moves;
  }

  @override
  void didUpdateWidget(covariant _MovesTab old) {
    super.didUpdateWidget(old);
    if (old.pokemon.id != widget.pokemon.id) _moves = _load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PokemonMoveRef>>(
      future: _moves,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: snap.hasError
                ? const Text(
                    'No se pudieron cargar los movimientos.',
                    style: TextStyle(color: AppColors.muted),
                  )
                : SpinningPokeball(size: 40, color: widget.accent.withValues(alpha: 0.35)),
          );
        }
        final all = snap.data!;
        if (all.isEmpty) {
          return const Center(
            child: Text(
              'La PokeAPI no tiene movimientos para esta forma.',
              style: TextStyle(color: AppColors.muted),
            ),
          );
        }
        final methods = [
          for (final m in LearnMethod.values)
            if (all.any((r) => r.method == m)) m,
        ];
        final method = methods.contains(_method) ? _method : methods.first;
        final rows = all.where((r) => r.method == method).toList();
        if (method == LearnMethod.level) {
          rows.sort((a, b) => a.level.compareTo(b.level));
        } else {
          rows.sort((a, b) => a.name.compareTo(b.name));
        }
        return Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                children: [
                  for (final m in methods)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          '${_methodLabels[m]} · ${all.where((r) => r.method == m).length}',
                        ),
                        selected: m == method,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: m == method ? Colors.white : AppColors.ink,
                        ),
                        selectedColor: widget.accent,
                        backgroundColor: AppColors.background,
                        side: BorderSide(color: m == method ? widget.accent : AppColors.line),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          SoundService.instance.play(Sfx.chip, volume: 0.36);
                          setState(() => _method = m);
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (versionLabel(all.first.version).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Según Pokémon ${versionLabel(all.first.version)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                itemCount: rows.length,
                itemBuilder: (context, i) => _MoveRow(
                  key: ValueKey('${rows[i].name}-${rows[i].level}-${rows[i].method}'),
                  ref: rows[i],
                  accent: widget.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Icono de la clase de daño: físico, especial o de estado.
IconData _classIcon(String damageClass) => switch (damageClass) {
  'physical' => Icons.sports_mma_rounded,
  'special' => Icons.blur_circular_rounded,
  _ => Icons.auto_fix_high_rounded,
};

String _classLabel(String damageClass) => switch (damageClass) {
  'physical' => 'Físico',
  'special' => 'Especial',
  _ => 'Estado',
};

class _MoveRow extends StatelessWidget {
  final PokemonMoveRef ref;
  final Color accent;

  const _MoveRow({super.key, required this.ref, required this.accent});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MoveInfo>(
      future: PokeApiService.instance.getMove(ref.name),
      builder: (context, snap) {
        final m = snap.data;
        final level = ref.method == LearnMethod.level
            ? (ref.level == 0 ? 'Evo.' : ref.level <= 1 ? '1' : '${ref.level}')
            : null;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: m == null ? null : () => _showMove(context, m, accent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Row(
              children: [
                if (level != null)
                  SizedBox(
                    width: 38,
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    m?.label ?? capitalize(ref.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (m != null) ...[
                  TypeChip(type: m.type, onColor: false, compact: true),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: _classLabel(m.damageClass),
                    child: Icon(_classIcon(m.damageClass), size: 16, color: AppColors.muted),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      m.power?.toString() ?? '—',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ] else
                  const SizedBox(
                    width: 90,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showMove(BuildContext context, MoveInfo m, Color accent) {
  SoundService.instance.play(Sfx.sheetUp, volume: 0.4);
  Widget stat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    ),
  );
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _InfoSheetModal(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.label,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              TypeChip(type: m.type, onColor: false),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(_classIcon(m.damageClass), size: 15, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(
                _classLabel(m.damageClass),
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Potencia', m.power?.toString() ?? '—'),
              stat('Precisión', m.accuracy == null ? '—' : '${m.accuracy} %'),
              stat('PP', '${m.pp}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            m.description.isEmpty ? 'Sin descripción.' : m.description,
            style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF3C4053)),
          ),
        ],
      ),
    ),
  );
}

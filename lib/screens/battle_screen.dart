import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dex_data.dart';
import '../data/type_chart.dart';
import '../models/move.dart';
import '../models/pokemon.dart';
import '../services/battle_lines.dart';
import '../services/karen_controller.dart';
import '../services/pokeapi_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_sprite.dart';
import '../widgets/artwork_image.dart';
import '../widgets/attack_effect.dart';
import '../widgets/type_chip.dart';

/// Combate de práctica contra Karen.
///
/// El Pokémon usa cuatro de sus movimientos reales (de la PokeAPI) y Karen,
/// disfrazada de un tipo, recibe los golpes: el daño sale de la fórmula de
/// los juegos (nivel 50, STAB, tabla de tipos, críticos), así que sirve para
/// aprender qué es súper eficaz y qué no. Ella contesta con "movimientos" de
/// broma que no hacen daño de verdad.
class BattleScreen extends StatefulWidget {
  final Pokemon pokemon;
  final bool shiny;

  const BattleScreen({super.key, required this.pokemon, this.shiny = false});

  static Route<void> route(Pokemon pokemon, {bool shiny = false}) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => BattleScreen(pokemon: pokemon, shiny: shiny),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.08, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _Popup {
  final int id;
  final String text;
  final Color color;
  final bool onKaren;

  _Popup(this.id, this.text, this.color, {required this.onKaren});
}

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
  static const int _level = 50;
  static const int _karenMaxHp = 180;

  /// Defensa de Karen (la de un Pokémon con 70 de base a nivel 50).
  static const double _karenDefense = 90;

  final math.Random _rand = math.Random();

  late String _costume = kAllTypes[_rand.nextInt(kAllTypes.length)];
  int _hp = _karenMaxHp;
  bool _fainted = false;
  bool _busy = true;
  int _wins = 0;
  bool _saidLowHp = false;

  String? _ailment;
  int _ailmentTurns = 0;
  final Map<String, int> _karenStages = {};
  final Map<String, int> _pokeStages = {};

  List<PokemonMoveRef> _pool = const [];
  List<MoveInfo> _moves = const [];
  bool _loadingMoves = true;

  String _message = '';
  String _karenLine = '';
  int _lineStamp = 0;

  final List<_Popup> _popups = [];
  int _popupId = 0;

  // Animación del efecto en curso.
  String _fxType = 'normal';
  bool _fxPhysical = false;
  bool _fxFromKaren = false;
  int _statDirection = 1;
  bool _statOnKaren = true;

  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _statFx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final AnimationController _lunge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _karenHit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final AnimationController _pokeHit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final AnimationController _faint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final AnimationController _dodge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  Pokemon get _p => widget.pokemon;
  String get _name => formDisplayName(_p.formName ?? _p.name, _p.speciesName);
  String get _costumeLabel => typeStyle(_costume).label;

  @override
  void initState() {
    super.initState();
    // Fuera del build: avisar a Karen redibuja la capa de encima.
    scheduleMicrotask(() => KarenController.instance.suppress(true));
    _message = '¡Karen te reta a un combate!';
    _loadMoves();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _say(_pickLine(kBattleStart));
    });
  }

  @override
  void dispose() {
    final won = _wins > 0;
    final name = _name;
    final id = _p.id;
    scheduleMicrotask(() {
      KarenController.instance.suppress(false);
      KarenController.instance.onBattleEnded(won: won, name: name, id: id);
    });
    for (final c in [_idle, _fx, _statFx, _lunge, _karenHit, _pokeHit, _shake, _faint, _dodge, _enter]) {
      c.dispose();
    }
    super.dispose();
  }

  // --------------------------------------------------------- movimientos

  Future<void> _loadMoves({bool reroll = false}) async {
    setState(() => _loadingMoves = true);
    final api = PokeApiService.instance;
    try {
      if (_pool.isEmpty) {
        var pool = _p.moves;
        if (pool.isEmpty && _p.isVariant) pool = (await api.getPokemon(_p.speciesId)).moves;
        _pool = pool;
      }
      final names = <String>{};
      if (_pool.isEmpty) {
        names.addAll(['tackle', 'growl']);
      } else if (!reroll) {
        // Los últimos que aprende por nivel (los más fuertes) y alguno de MT.
        final byLevel = _pool.where((m) => m.method == LearnMethod.level).toList()
          ..sort((a, b) => b.level.compareTo(a.level));
        names.addAll(byLevel.take(9).map((m) => m.name));
        final machines = _pool.where((m) => m.method == LearnMethod.machine).toList()..shuffle(_rand);
        names.addAll(machines.take(4).map((m) => m.name));
      } else {
        final all = _pool.map((m) => m.name).toSet().toList()..shuffle(_rand);
        names.addAll(all.take(10));
      }
      final infos = <MoveInfo>[];
      await Future.wait(
        names.map((n) async {
          try {
            infos.add(await api.getMove(n));
          } catch (_) {}
        }),
      );
      if (!mounted) return;
      setState(() {
        _moves = _chooseFour(infos, shuffle: reroll);
        _loadingMoves = false;
        _busy = _fainted;
        if (_moves.isNotEmpty && !_fainted) _message = '¿Qué hará $_name?';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMoves = false;
        _message = 'No se pudieron cargar los movimientos. Revisa tu conexión.';
      });
    }
  }

  /// Tres de daño (de tipos distintos si se puede, los mejores primero) y
  /// uno de estado, para que el combate tenga variedad.
  List<MoveInfo> _chooseFour(List<MoveInfo> infos, {bool shuffle = false}) {
    double score(MoveInfo m) =>
        (m.power ?? 0) * (_p.types.contains(m.type) ? 1.5 : 1) * ((m.accuracy ?? 100) / 100);
    final damaging = infos.where((m) => m.isDamaging).toList();
    if (shuffle) {
      damaging.shuffle(_rand);
    } else {
      damaging.sort((a, b) => score(b).compareTo(score(a)));
    }
    final status = infos
        .where((m) => !m.isDamaging && (m.statChanges.isNotEmpty || m.ailment != null || m.healing > 0))
        .toList()
      ..shuffle(_rand);

    final picked = <MoveInfo>[];
    final types = <String>{};
    for (final m in damaging) {
      if (picked.length == 3) break;
      if (types.add(m.type)) picked.add(m);
    }
    for (final m in damaging) {
      if (picked.length == 3) break;
      if (!picked.contains(m)) picked.add(m);
    }
    if (status.isNotEmpty) picked.add(status.first);
    for (final m in damaging) {
      if (picked.length == 4) break;
      if (!picked.contains(m)) picked.add(m);
    }
    return picked.take(4).toList();
  }

  // -------------------------------------------------------------- turnos

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  String _fill(String text, {String move = '', String stat = ''}) => text
      .replaceAll('{name}', _name)
      .replaceAll('{type}', _costumeLabel)
      .replaceAll('{move}', move)
      .replaceAll('{stat}', stat);

  final Map<List<String>, List<String>> _bags = {};

  /// Saca una frase sin repetir hasta haberlas dicho todas.
  String _pickLine(List<String> lines) {
    final bag = _bags.putIfAbsent(lines, () => []);
    if (bag.isEmpty) bag.addAll(List.of(lines)..shuffle(_rand));
    return bag.removeLast();
  }

  void _say(String text, {String move = '', String stat = ''}) {
    if (!mounted) return;
    SoundService.instance.play(Sfx.voice, volume: 0.25);
    setState(() {
      _karenLine = _fill(text, move: move, stat: stat);
      _lineStamp++;
    });
  }

  void _setMessage(String text) {
    if (mounted) setState(() => _message = text);
  }

  void _popup(String text, Color color, {bool onKaren = true}) {
    final popup = _Popup(_popupId++, text, color, onKaren: onKaren);
    setState(() => _popups.add(popup));
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _popups.remove(popup));
    });
  }

  int _stat(String name) {
    final base = _p.stats.where((s) => s.name == name).firstOrNull?.value ?? 60;
    return ((2 * base + 31) * _level / 100).floor() + 5;
  }

  static double _stageMul(int s) => s >= 0 ? (2 + s) / 2 : 2 / (2 - s);

  double _effOf(MoveInfo m) => effectiveness(m.type, [_costume]);

  Future<void> _use(MoveInfo m) async {
    if (_busy || _fainted) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    _setMessage('¡$_name usó ${m.label}!');
    await _wait(500);
    if (!mounted) return;

    final targetsKaren = !m.targetsSelf;
    final missed = targetsKaren && m.accuracy != null && _rand.nextInt(100) >= m.accuracy!;
    if (missed) {
      await _miss(m);
    } else if (m.isDamaging) {
      await _attack(m);
    } else {
      await _statusMove(m);
    }
    if (!mounted) return;
    if (_hp <= 0) return _knockOut();
    await _endOfTurn();
    if (!mounted) return;
    if (_hp <= 0) return _knockOut();
    await _karenTurn();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = '¿Qué hará $_name?';
    });
  }

  Future<void> _miss(MoveInfo m) async {
    _fxType = m.type;
    _fxPhysical = m.damageClass == 'physical';
    _fxFromKaren = false;
    SoundService.instance.play(Sfx.whoosh, volume: 0.5);
    if (_fxPhysical) _lunge.forward(from: 0);
    _dodge.forward(from: 0);
    await _wait(300);
    SoundService.instance.play(Sfx.miss, volume: 0.5);
    _setMessage('¡Karen lo esquivó! El ataque falló.');
    _say(_pickLine(kMiss), move: m.label);
    await _wait(1300);
  }

  Future<void> _attack(MoveInfo m) async {
    final physical = m.damageClass == 'physical';
    _fxType = m.type;
    _fxPhysical = physical;
    _fxFromKaren = false;
    SoundService.instance.play(Sfx.whoosh, volume: 0.5);
    if (physical) {
      _lunge.forward(from: 0);
      await _wait(180);
    }
    _fx.forward(from: 0);
    await _wait(physical ? 300 : 540);
    if (!mounted) return;

    final eff = _effOf(m);
    if (eff == 0) {
      SoundService.instance.play(Sfx.miss, volume: 0.4);
      _setMessage('No afecta a Karen… (el tipo $_costumeLabel es inmune)');
      _say(_pickLine(kHitImmune), move: m.label);
      await _wait(1500);
      return;
    }

    final crit = _rand.nextInt(16) == 0;
    final stab = _p.types.contains(m.type) ? 1.5 : 1.0;
    final atkStat = physical ? 'attack' : 'special-attack';
    final defStat = physical ? 'defense' : 'special-defense';
    final a = _stat(atkStat) * _stageMul(_pokeStages[atkStat] ?? 0);
    final d = _karenDefense * (crit ? 1 : _stageMul(_karenStages[defStat] ?? 0));
    final raw = ((2 * _level / 5 + 2) * m.power! * a / d) / 50 + 2;
    final damage = math.max(1, (raw * stab * eff * (crit ? 1.5 : 1) * (0.85 + _rand.nextDouble() * 0.15)).round());

    setState(() => _hp = math.max(0, _hp - damage));
    _karenHit.forward(from: 0);
    if (eff > 1 || crit) _shake.forward(from: 0);
    SoundService.instance.play(
      eff > 1 || crit ? Sfx.hitSuper : (eff < 1 ? Sfx.hitWeak : Sfx.hit),
      volume: 0.6,
    );
    HapticFeedback.heavyImpact();
    _popup('-$damage', eff > 1 ? const Color(0xFFFF5252) : Colors.white);
    await _wait(450);
    if (!mounted) return;

    final parts = [
      if (crit) '¡Un golpe crítico!',
      if (eff >= 4) '¡Es superefectivo! (×4)' else if (eff > 1) '¡Es súper eficaz!',
      if (eff < 1) 'No es muy eficaz…',
    ];
    _setMessage(parts.isEmpty ? 'Karen recibió $damage de daño.' : '${parts.join(' ')} ($damage de daño)');
    if (_hp > 0 && _hp < _karenMaxHp * 0.3 && !_saidLowHp) {
      _saidLowHp = true;
      _say(_pickLine(kLowHp));
    } else {
      _say(
        _pickLine(
          crit
              ? kHitCrit
              : eff > 1
              ? kHitSuper
              : eff < 1
              ? kHitWeak
              : kHitNormal,
        ),
        move: m.label,
      );
    }
    await _wait(1300);
    if (!mounted || _hp <= 0) return;

    // Efectos secundarios: quemar, paralizar, bajar defensa…
    if (m.ailment != null && _ailment == null && m.ailmentChance > 0 && _rand.nextInt(100) < m.ailmentChance) {
      await _applyAilment(m.ailment!);
    }
    if (m.statChanges.isNotEmpty && m.statChance > 0 && _rand.nextInt(100) < m.statChance) {
      await _applyStats(m);
    }
  }

  Future<void> _statusMove(MoveInfo m) async {
    if (m.healing > 0 && m.targetsSelf) {
      _statDirection = 0;
      _statOnKaren = false;
      _statFx.forward(from: 0);
      SoundService.instance.play(Sfx.heal, volume: 0.5);
      _setMessage('¡$_name recuperó salud!');
      _say(_pickLine(kHealed));
      await _wait(1500);
      return;
    }
    if (m.statChanges.isNotEmpty) {
      if (!m.targetsSelf) {
        _fxType = m.type;
        _fxPhysical = false;
        _fxFromKaren = false;
        _fx.forward(from: 0);
        await _wait(500);
      }
      await _applyStats(m);
      return;
    }
    if (m.ailment != null && !m.targetsSelf) {
      _fxType = m.type;
      _fxPhysical = false;
      _fxFromKaren = false;
      _fx.forward(from: 0);
      await _wait(550);
      if (_ailment != null) {
        _setMessage('No tuvo efecto: Karen ya tiene un problema de estado.');
        _say('¡Ya tengo bastante con lo que tengo, gracias!');
        await _wait(1300);
        return;
      }
      await _applyAilment(m.ailment!);
      return;
    }
    _setMessage('Pero no pasó nada…');
    _say(_pickLine(kNothing), move: m.label);
    await _wait(1400);
  }

  Future<void> _applyStats(MoveInfo m) async {
    final onSelf = m.targetsSelf;
    final stages = onSelf ? _pokeStages : _karenStages;
    final lines = <String>[];
    var up = true;
    String? firstStat;
    m.statChanges.forEach((stat, change) {
      stages[stat] = ((stages[stat] ?? 0) + change).clamp(-6, 6);
      final label = kStatNames[stat] ?? stat;
      firstStat ??= label;
      up = change > 0;
      final how = change.abs() >= 2 ? 'mucho' : '';
      final who = onSelf ? 'de $_name' : 'de Karen';
      lines.add('¡${label == 'Defensa' || label == 'Velocidad' || label == 'Precisión' || label == 'Evasión' ? 'La' : 'El'} $label $who ${change > 0 ? 'subió' : 'bajó'}${how.isEmpty ? '' : ' $how'}!');
    });
    // Subir lo propio o bajar lo de Karen se ve en quien lo recibe.
    _statOnKaren = !onSelf;
    _statDirection = up ? 1 : -1;
    _statFx.forward(from: 0);
    SoundService.instance.play(up ? Sfx.buff : Sfx.debuff, volume: 0.5);
    _setMessage(lines.join(' '));
    if (onSelf && up) {
      _say(_pickLine(kStatUp), stat: firstStat ?? '');
    } else if (!onSelf && !up) {
      _say(_pickLine(kStatDown), stat: (firstStat ?? '').toLowerCase());
    }
    await _wait(1500);
  }

  Future<void> _applyAilment(String ailment) async {
    final lines = kAilment[ailment];
    if (lines == null) {
      _setMessage('Karen se siente rara…');
      await _wait(900);
      return;
    }
    setState(() {
      _ailment = ailment;
      _ailmentTurns = switch (ailment) {
        'sleep' => 1 + _rand.nextInt(3),
        'confusion' => 2 + _rand.nextInt(3),
        'trap' => 4,
        _ => 0,
      };
    });
    _statOnKaren = true;
    _statDirection = -1;
    _statFx.forward(from: 0);
    SoundService.instance.play(Sfx.debuff, volume: 0.5);
    _setMessage(kAilmentMessage[ailment] ?? 'Karen se siente rara…');
    _say(_pickLine(lines));
    await _wait(1500);
  }

  Future<void> _endOfTurn() async {
    final tick = kAilmentTick[_ailment];
    if (tick == null) return;
    final damage = math.max(1, _karenMaxHp ~/ (_ailment == 'poison' ? 8 : 16));
    setState(() => _hp = math.max(0, _hp - damage));
    _karenHit.forward(from: 0);
    SoundService.instance.play(Sfx.hitWeak, volume: 0.45);
    _popup('-$damage', const Color(0xFFFFAB40));
    _setMessage(tick);
    if (_ailment == 'trap' && --_ailmentTurns <= 0) {
      await _wait(900);
      setState(() => _ailment = null);
      _setMessage('¡Karen se liberó!');
    }
    await _wait(1100);
  }

  Future<void> _karenTurn() async {
    await _wait(350);
    if (!mounted) return;
    switch (_ailment) {
      case 'sleep':
        if (--_ailmentTurns <= 0) {
          setState(() => _ailment = null);
          _setMessage(kKarenWakes.first);
          await _wait(1100);
        } else {
          _setMessage(_pickLine(kKarenAsleep));
          await _wait(1300);
          return;
        }
      case 'freeze':
        if (_rand.nextInt(5) == 0) {
          setState(() => _ailment = null);
          _setMessage(kKarenThaws.first);
          await _wait(1100);
        } else {
          _setMessage(kKarenFrozen.first);
          await _wait(1300);
          return;
        }
      case 'paralysis':
        if (_rand.nextInt(4) == 0) {
          _setMessage(kKarenParalyzed.first);
          await _wait(1300);
          return;
        }
      case 'infatuation':
        if (_rand.nextBool()) {
          _setMessage('Karen está enamorada de $_name. ¡No se atreve a moverse!');
          await _wait(1300);
          return;
        }
      case 'confusion':
        if (--_ailmentTurns <= 0) {
          setState(() => _ailment = null);
          _setMessage('¡Karen ya no está confundida!');
          await _wait(1000);
        } else if (_rand.nextInt(3) == 0) {
          final damage = math.max(1, _karenMaxHp ~/ 12);
          setState(() => _hp = math.max(0, _hp - damage));
          _karenHit.forward(from: 0);
          SoundService.instance.play(Sfx.hitWeak, volume: 0.45);
          _popup('-$damage', const Color(0xFFFF80AB));
          _setMessage(kKarenHurtsSelf.first);
          await _wait(1300);
          if (_hp <= 0) return _knockOut();
          return;
        }
    }
    if (!mounted || _hp <= 0) return;

    final (message, line, action) = kKarenMoves[_rand.nextInt(kKarenMoves.length)];
    _setMessage(message);
    await _wait(450);
    if (!mounted) return;
    switch (action) {
      case KarenAction.heal:
        final heal = math.min(_karenMaxHp - _hp, (_karenMaxHp * 0.15).round());
        setState(() => _hp += heal);
        _statOnKaren = true;
        _statDirection = 0;
        _statFx.forward(from: 0);
        SoundService.instance.play(Sfx.heal, volume: 0.5);
        if (heal > 0) _popup('+$heal', const Color(0xFF69F0AE));
      case KarenAction.lowerAttack:
        for (final s in ['attack', 'special-attack']) {
          _pokeStages[s] = ((_pokeStages[s] ?? 0) - 1).clamp(-6, 6);
        }
        _statOnKaren = false;
        _statDirection = -1;
        _statFx.forward(from: 0);
        SoundService.instance.play(Sfx.debuff, volume: 0.5);
      case KarenAction.miss:
        _fxType = 'normal';
        _fxPhysical = false;
        _fxFromKaren = true;
        _fx.forward(from: 0);
        SoundService.instance.play(Sfx.whoosh, volume: 0.45);
        await _wait(520);
        _pokeHit.forward(from: 0);
        SoundService.instance.play(Sfx.hitWeak, volume: 0.4);
        _popup('0', Colors.white, onKaren: false);
      case KarenAction.nothing:
        break;
    }
    _say(line);
    await _wait(1500);
    if (!mounted) return;
    if (action == KarenAction.lowerAttack) {
      _setMessage('El ataque de $_name bajó un poco.');
      await _wait(900);
    }
  }

  Future<void> _knockOut() async {
    SoundService.instance.play(Sfx.faint, volume: 0.6);
    HapticFeedback.heavyImpact();
    setState(() {
      _fainted = true;
      _wins++;
      _message = '¡Karen se debilitó! ¡$_name gana!';
    });
    _faint.forward(from: 0);
    await _wait(500);
    _say(_pickLine(kFaint));
    if (mounted) setState(() => _busy = false);
  }

  void _rematch() {
    final others = kAllTypes.where((t) => t != _costume).toList();
    SoundService.instance.play(Sfx.heal, volume: 0.5);
    setState(() {
      _costume = others[_rand.nextInt(others.length)];
      _hp = _karenMaxHp;
      _fainted = false;
      _busy = false;
      _ailment = null;
      _saidLowHp = false;
      _karenStages.clear();
      _pokeStages.clear();
      _message = '¡Karen vuelve al combate!';
    });
    _faint.reverse();
    _say(_pickLine(kRematch));
  }

  void _pickCostume() {
    if (_busy && !_fainted) return;
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Disfraz de Karen',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige de qué tipo se disfraza y prueba qué movimientos le hacen más daño.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 8,
                children: [
                  for (final t in kAllTypes)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(t),
                      child: Opacity(
                        opacity: t == _costume ? 0.45 : 1,
                        child: TypeChip(type: t, onColor: false),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((type) {
      if (type == null || !mounted || type == _costume) return;
      setState(() => _costume = type);
      SoundService.instance.play(Sfx.shiny, volume: 0.45);
      _statOnKaren = true;
      _statDirection = 0;
      _statFx.forward(from: 0);
      _say(_pickLine(kCostume));
    });
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final color = typeStyle(_p.primaryType).color;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        for (var i = 0; i < 4; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i)): () {
            if (i < _moves.length) _use(_moves[i]);
          },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.night,
          body: SafeArea(
            child: ContentWidth(
              maxWidth: 980,
              child: Column(
                children: [
                  Expanded(child: _arena(color)),
                  _panel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arena(Color color) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final compact = w < 600;
        final karenH = math.min(h * 0.62, compact ? 230.0 : 300.0);
        final spriteSize = math.min(h * 0.46, compact ? 190.0 : 240.0);
        final karenPos = Offset(w * (compact ? 0.74 : 0.7), h * 0.46);
        final pokePos = Offset(w * (compact ? 0.27 : 0.3), h * 0.72);
        final karenCenter = karenPos + Offset(0, -karenH * 0.1);

        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final s = _shake.value;
            final dx = s > 0 && s < 1 ? math.sin(s * math.pi * 10) * (1 - s) * 9 : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            child: Stack(
              children: [
                // Cielo y suelo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(color, const Color(0xFF8FD3FF), 0.55)!,
                          const Color(0xFFE6F4EA),
                          const Color(0xFFB9DFA8),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
                _platform(karenPos + Offset(0, karenH * 0.42), karenH * 1.1),
                _platform(pokePos + Offset(0, spriteSize * 0.38), spriteSize * 1.3),
                // Karen.
                Positioned(
                  left: karenPos.dx - karenH * 0.4,
                  top: karenPos.dy - karenH * 0.55,
                  width: karenH * 0.8,
                  height: karenH,
                  child: _karen(karenH),
                ),
                // El Pokémon, de espaldas como en los juegos.
                Positioned(
                  left: pokePos.dx - spriteSize / 2,
                  top: pokePos.dy - spriteSize / 2,
                  width: spriteSize,
                  height: spriteSize,
                  child: _pokemon(spriteSize, karenPos - pokePos),
                ),
                // Efectos.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_fx, _statFx]),
                      builder: (context, _) => CustomPaint(
                        painter: AttackEffectPainter(
                          type: _fxType,
                          t: _fx.value,
                          from: _fxFromKaren ? karenCenter : pokePos,
                          to: _fxFromKaren ? pokePos : karenCenter,
                          physical: _fxPhysical,
                          scale: _fxFromKaren ? spriteSize * 0.5 : karenH * 0.5,
                        ),
                        foregroundPainter: StatEffectPainter(
                          t: _statFx.value,
                          center: _statOnKaren ? karenCenter : pokePos,
                          scale: _statOnKaren ? karenH * 0.6 : spriteSize * 0.7,
                          direction: _statDirection,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final p in _popups)
                  _PopupText(
                    key: ValueKey(p.id),
                    popup: p,
                    at: p.onKaren
                        ? karenPos + Offset(0, -karenH * 0.45)
                        : pokePos + Offset(0, -spriteSize * 0.4),
                  ),
                // Barra de Karen.
                Positioned(
                  left: 12,
                  top: 12,
                  width: math.min(w * 0.52, 280),
                  child: _karenCard(),
                ),
                // Ficha del Pokémon.
                Positioned(
                  right: 12,
                  bottom: 12,
                  width: math.min(w * 0.44, 250),
                  child: _pokemonCard(),
                ),
                // Lo que dice Karen.
                Positioned(
                  left: 12,
                  top: 86,
                  width: math.min(w * (compact ? 0.5 : 0.42), 330),
                  child: _bubble(),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: IconButton(
                    tooltip: 'Salir del combate',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _platform(Offset center, double width) => Positioned(
    left: center.dx - width / 2,
    top: center.dy - width * 0.12,
    width: width,
    height: width * 0.24,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(width / 2, width * 0.12)),
        gradient: const RadialGradient(
          colors: [Color(0xFF9CCC65), Color(0xFF7CB342)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
    ),
  );

  Widget _karen(double height) {
    final tint = switch (_ailment) {
      'burn' => const Color(0xFFFF7043),
      'freeze' => const Color(0xFF4FC3F7),
      'poison' => const Color(0xFFAB47BC),
      'paralysis' => const Color(0xFFFFEE58),
      _ => null,
    };
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _karenHit, _faint, _dodge, _enter]),
      builder: (context, child) {
        final bob = math.sin(_idle.value * math.pi * 2) * 4;
        final h = _karenHit.value;
        final hitting = h > 0 && h < 1;
        final shakeX = hitting ? math.sin(h * math.pi * 8) * (1 - h) * 12 : 0.0;
        final blink = hitting && h < 0.6 && (h * 12).floor().isEven;
        final f = Curves.easeIn.transform(_faint.value);
        final d = _dodge.value;
        final dodgeX = d > 0 && d < 1 ? math.sin(d * math.pi) * height * 0.3 : 0.0;
        final enter = Curves.easeOutBack.transform(_enter.value);
        final paralyzedJitter = _ailment == 'paralysis' && (_idle.value * 30).floor() % 7 == 0 ? 3.0 : 0.0;

        Widget figure = child!;
        if (tint != null) {
          figure = ColorFiltered(
            colorFilter: ColorFilter.mode(tint.withValues(alpha: 0.35), BlendMode.srcATop),
            child: figure,
          );
        }
        return Opacity(
          opacity: blink ? 0.25 : 1,
          child: Transform.translate(
            offset: Offset(
              shakeX + dodgeX + paralyzedJitter + (1 - enter) * height,
              (_fainted || f > 0 ? f * height * 0.25 : bob),
            ),
            child: Transform.rotate(
              angle: f * 1.35,
              alignment: Alignment.bottomCenter,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: figure),
                  if (_ailment == 'sleep' && !_fainted)
                    Positioned(right: 0, top: 0, child: _Zzz(animation: _idle)),
                  if (_fainted || _ailment == 'confusion')
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height * 0.02,
                      child: _DizzyStars(animation: _idle, size: height * 0.32),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/mascota/karen.png',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }

  Widget _pokemon(double size, Offset towardKaren) {
    final back = widget.shiny ? _p.animatedShinyUrl : _p.animatedUrl;
    final backUrl = back?.replaceFirst('/showdown/', '/showdown/back/');
    // Mientras baja (o si no existe) el sprite de espaldas, el arte oficial
    // mirando hacia Karen.
    final official = Transform.flip(
      flipX: true,
      child: ArtworkImage(
        id: _p.id,
        url: widget.shiny ? _p.formShinyArt : _p.formArt,
        size: size * 0.9,
        shiny: widget.shiny,
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_idle, _lunge, _pokeHit, _enter]),
      builder: (context, child) {
        final bob = math.sin(_idle.value * math.pi * 2 + 1) * 3;
        final l = _lunge.value;
        final lunge = l > 0 && l < 1 ? math.sin(l * math.pi) * 0.38 : 0.0;
        final hit = _pokeHit.value;
        final shake = hit > 0 && hit < 1 ? math.sin(hit * math.pi * 8) * (1 - hit) * 8 : 0.0;
        final enter = Curves.easeOutBack.transform(_enter.value);
        return Transform.translate(
          offset: towardKaren * lunge + Offset(shake - (1 - enter) * size, bob),
          child: child,
        );
      },
      child: backUrl == null
          ? official
          : AnimatedSprite(url: backUrl, size: size, fallback: official),
    );
  }

  Widget _karenCard() {
    final fraction = _hp / _karenMaxHp;
    final badge = kAilmentBadge[_ailment];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Karen', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Color(badge.$2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badge.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: _pickCostume,
                child: FittedBox(child: TypeChip(type: _costume, onColor: false, compact: true)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'PS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFF9A825)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 8,
                    color: const Color(0xFF37474F),
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: fraction),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOut,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        child: Container(
                          color: v > 0.5
                              ? const Color(0xFF43A047)
                              : v > 0.2
                              ? const Color(0xFFFFB300)
                              : const Color(0xFFE53935),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_hp / $_karenMaxHp',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pokemonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              const Text('Nv. 50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [for (final t in _p.types) TypeChip(type: t, onColor: false, compact: true)],
          ),
          if (_pokeStages.values.any((v) => v != 0)) ...[
            const SizedBox(height: 4),
            Text(
              _pokeStages.entries
                  .where((e) => e.value != 0)
                  .map((e) => '${kStatNames[e.key] ?? e.key} ${e.value > 0 ? '+' : ''}${e.value}')
                  .join(' · '),
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bubble() {
    if (_karenLine.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      // El globo viejo se va de golpe: si se funden, los textos se enciman.
      switchOutCurve: const Threshold(0),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(a), child: child),
      ),
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      child: Container(
        key: ValueKey(_lineStamp),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.pokeRed.withValues(alpha: 0.35), width: 1.4),
          boxShadow: kSoftShadow,
        ),
        child: Text(
          _karenLine,
          style: const TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF262838),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchOutCurve: const Threshold(0),
              layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
              child: Text(
                _message,
                key: ValueKey(_message),
                style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_fainted)
            FilledButton.icon(
              onPressed: _rematch,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pokeRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(
                _wins > 1 ? 'Revancha ($_wins victorias)' : 'Revancha',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            )
          else if (_loadingMoves)
            const SizedBox(
              height: 126,
              child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 640 ? 4 : 2;
                final gap = 8.0;
                final width = (box.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final (i, m) in _moves.indexed)
                      SizedBox(
                        width: width,
                        child: _MoveButton(
                          move: m,
                          index: i,
                          effectiveness: m.isDamaging ? _effOf(m) : null,
                          stab: _p.types.contains(m.type),
                          enabled: !_busy,
                          onTap: () => _use(m),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: (_busy && !_fainted) ? null : _pickCostume,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                icon: const Icon(Icons.checkroom_rounded, size: 18),
                label: Text('Disfraz: $_costumeLabel'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy || _loadingMoves || _pool.length <= 4 ? null : () => _loadMoves(reroll: true),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                icon: const Icon(Icons.shuffle_rounded, size: 18),
                label: const Text('Otros movimientos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  final MoveInfo move;
  final int index;
  final double? effectiveness;
  final bool stab;
  final bool enabled;
  final VoidCallback onTap;

  const _MoveButton({
    required this.move,
    required this.index,
    required this.effectiveness,
    required this.stab,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = typeStyle(move.type);
    final eff = effectiveness;
    final (effLabel, effColor) = switch (eff) {
      null => (null, null),
      0 => ('Sin efecto', const Color(0xFF263238)),
      >= 2 => ('Súper eficaz', const Color(0xFFB71C1C)),
      < 1 => ('Poco eficaz', const Color(0xFF37474F)),
      _ => (null, null),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: style.color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        move.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          shadows: [Shadow(color: Color(0x40000000), blurRadius: 3)],
                        ),
                      ),
                    ),
                    if (effLabel != null)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: effColor!.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          effLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(style.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      style.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      move.isDamaging ? 'Pot. ${move.power}${stab ? ' · STAB' : ''}' : 'Estado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Número de daño que sube y se desvanece.
class _PopupText extends StatelessWidget {
  final _Popup popup;
  final Offset at;

  const _PopupText({super.key, required this.popup, required this.at});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      builder: (context, t, _) => Positioned(
        left: at.dx - 60,
        top: at.dy - 50 * Curves.easeOut.transform(t),
        width: 120,
        child: IgnorePointer(
          child: Opacity(
            opacity: (1 - t * t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.7 + Curves.elasticOut.transform(math.min(1, t * 2.5)) * 0.5,
              child: Text(
                popup.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: popup.color,
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Zzz extends StatelessWidget {
  final Animation<double> animation;

  const _Zzz({required this.animation});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value;
      return Transform.translate(
        offset: Offset(math.sin(t * math.pi * 2) * 4, -t * 12),
        child: Opacity(
          opacity: 1 - t * 0.6,
          child: const Text(
            'Zzz',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF5C6BC0)),
          ),
        ),
      );
    },
  );
}

/// Estrellitas girando sobre la cabeza (debilitada o confundida).
class _DizzyStars extends StatelessWidget {
  final Animation<double> animation;
  final double size;

  const _DizzyStars({required this.animation, required this.size});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => SizedBox(
      height: size * 0.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(
                math.cos(animation.value * math.pi * 4 + i * 2.1) * size * 0.4,
                math.sin(animation.value * math.pi * 4 + i * 2.1) * size * 0.1,
              ),
              child: Icon(Icons.star_rounded, size: size * 0.2, color: const Color(0xFFFFD54F)),
            ),
        ],
      ),
    ),
  );
}

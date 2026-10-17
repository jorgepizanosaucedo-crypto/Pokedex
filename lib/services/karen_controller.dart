import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'profile_store.dart';

part 'karen_lines.dart';

/// Ánimo de Karen: decide cómo se mueve el dibujo.
enum KarenMood { idle, happy, cheer, wave, think, point, surprise, worry, sleepy }

/// Reacción estilo manga que aparece junto a ella.
enum KarenEmote { none, sparkle, sweat, exclaim, question, idea, thought, heart, notes, zzz }

/// Las dos guías: la de la lista y la de la ficha de un Pokémon.
enum KarenTour { app, detail }

/// Lo que Karen está diciendo ahora mismo.
class KarenLine {
  final String text;
  final KarenMood mood;
  final KarenEmote emote;

  /// Ids de Pokémon que la acompañan a los costados mientras habla.
  final List<int> companions;

  /// Marca de tiempo: cambiarla reinicia la animación aunque el texto repita.
  final int stamp;

  const KarenLine({
    required this.text,
    required this.stamp,
    this.mood = KarenMood.idle,
    this.emote = KarenEmote.none,
    this.companions = const [],
  });
}

/// Una frase o un paso de la guía.
class KarenStep {
  final String text;
  final KarenMood mood;
  final KarenEmote emote;
  final List<int> companions;

  /// Parte de la pantalla que se ilumina mientras lo explica (ver
  /// `KarenTargets`). `null` = sin foco.
  final String? target;

  const KarenStep(
    this.text, {
    this.mood = KarenMood.idle,
    this.emote = KarenEmote.none,
    this.companions = const [],
    this.target,
  });

  /// La misma frase con los huecos rellenos y, si no traía, acompañantes.
  KarenStep fill({
    String? name,
    int? total,
    int? count,
    String? trainer,
    List<int>? companions,
  }) => KarenStep(
    text
        .replaceAll('{name}', name ?? '')
        .replaceAll('{total}', '${total ?? ''}')
        .replaceAll('{count}', '${count ?? ''}')
        .replaceAll('{trainer}', trainer ?? ''),
    mood: mood,
    emote: emote,
    companions: this.companions.isEmpty ? (companions ?? const []) : this.companions,
    target: target,
  );
}

/// Reparte frases sin repetir ninguna hasta haberlas dicho todas.
class _Bag<T> {
  final List<T> _items;
  final math.Random _random;
  final List<T> _left = [];

  _Bag(this._items, this._random);

  T next() {
    if (_left.isEmpty) _left.addAll(List.of(_items)..shuffle(_random));
    return _left.removeLast();
  }
}

/// Karen, la mascota: decide qué dice, cuándo y con qué cara.
///
/// La parte visual vive en `widgets/karen_overlay.dart`. Aquí sólo está el
/// comportamiento: las reacciones a lo que pasa en la app, el ritmo con el
/// que aparece y las dos guías paso a paso. Las frases están en
/// `karen_lines.dart`.
class KarenController extends ChangeNotifier {
  KarenController._();
  static final KarenController instance = KarenController._();

  static const String name = 'Karen';

  /// Tiempo mínimo entre dos comentarios espontáneos.
  static const Duration _gap = Duration(seconds: 14);

  /// Cuánto hay que estar quieto para que salga un consejo.
  static const Duration _idleAfter = Duration(seconds: 25);

  /// Y cada cuánto, como mucho, puede repetirse eso.
  static const Duration _idleEvery = Duration(seconds: 80);

  final math.Random _random = math.Random();
  final Map<Object, _Bag<Object>> _bags = {};

  KarenLine? _line;
  bool _enabled = true;
  bool _visible = false;
  DateTime _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastIdleTip = DateTime.now();
  DateTime _lastInput = DateTime.now();
  Timer? _autoHide;
  Timer? _idleTimer;
  Timer? _pendingTour;

  /// Lo que ya comentó en esta sesión, para no repetirse.
  final Set<int> _triviaSaid = {};
  final Set<String> _onceSaid = {};
  int _swipes = 0;

  // Guía paso a paso.
  List<KarenStep> _tour = const [];
  KarenTour? _tourKind;
  int _tourIndex = 0;
  VoidCallback? _onTourDone;

  KarenLine? get line => _line;
  bool get enabled => _enabled;
  bool get visible => _visible;
  bool get inTour => _tour.isNotEmpty;
  KarenTour? get tourKind => _tourKind;
  int get tourIndex => _tourIndex;
  int get tourLength => _tour.length;

  T _pick<T extends Object>(Object key, List<T> items) =>
      (_bags[key] ??= _Bag<Object>(items, _random)).next() as T;

  static String get _trainer => ProfileStore.instance.name.split(' ').first;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value && !inTour) hide();
    notifyListeners();
  }

  /// Marca actividad del usuario: reinicia la cuenta para el consejo por inactividad.
  void ping() => _lastInput = DateTime.now();

  void startIdleWatch() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_enabled || _visible || inTour || !ProfileStore.instance.isRegistered) return;
      final now = DateTime.now();
      if (now.difference(_lastInput) < _idleAfter) return;
      if (now.difference(_lastIdleTip) < _idleEvery) return;
      _lastIdleTip = now;
      _say(_pick('tips', _tips));
    });
  }

  void stopIdleWatch() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Calla a Karen y cancela lo pendiente (al cerrar sesión).
  void reset() {
    _autoHide?.cancel();
    _pendingTour?.cancel();
    _tour = const [];
    _tourKind = null;
    _tourIndex = 0;
    _onTourDone = null;
    _visible = false;
    _line = null;
    _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);
    _triviaSaid.clear();
    _onceSaid.clear();
    _swipes = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------- hablar

  /// Dice una frase. Devuelve `false` si tocaba callarse.
  bool _say(KarenStep step, {bool force = false, Duration? hold}) {
    if (!_enabled) return false;
    if (inTour) return false;
    final now = DateTime.now();
    if (!force && now.difference(_lastSpoke) < _gap) return false;
    _lastSpoke = now;

    _line = KarenLine(
      text: step.text,
      mood: step.mood,
      emote: step.emote,
      companions: step.companions,
      stamp: now.microsecondsSinceEpoch,
    );
    _visible = true;
    notifyListeners();

    _autoHide?.cancel();
    // Los textos largos se quedan más rato, con un techo razonable.
    final ms = (3200 + step.text.length * 55).clamp(5000, 12000);
    _autoHide = Timer(hold ?? Duration(milliseconds: ms), hide);
    return true;
  }

  /// Fuerza una frase aunque acabe de hablar (para avisos importantes).
  bool announce(KarenStep step, {Duration? hold}) => _say(step, force: true, hold: hold);

  /// Una frase que sólo se dice una vez por sesión.
  bool _once(String key, KarenStep step) {
    if (_onceSaid.contains(key)) return false;
    final said = _say(step);
    if (said) _onceSaid.add(key);
    return said;
  }

  void hide() {
    _autoHide?.cancel();
    if (!_visible || inTour) return;
    _visible = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ reacciones

  /// Bienvenida tras registrarse o al volver a abrir la app.
  bool greet({required bool firstTime}) {
    final trainer = _trainer;
    if (firstTime) {
      final hello = trainer.isEmpty ? '¡Hola!' : '¡Hola, $trainer!';
      return announce(
        KarenStep(
          '$hello Soy Karen y voy a ser tu guía en la Pokédex. '
          'Déjame enseñarte cómo funciona todo, paso a paso.',
          mood: KarenMood.wave,
          emote: KarenEmote.sparkle,
          companions: const [25, 133],
        ),
        hold: _welcomeHold,
      );
    }
    final hour = DateTime.now().hour;
    final (key, lines) = hour >= 5 && hour < 12
        ? ('morning', _greetMorning)
        : hour >= 12 && hour < 19
        ? ('afternoon', _greetAfternoon)
        : ('night', _greetNight);
    final text = _pick<String>(key, lines).replaceAll('{trainer}', trainer.isEmpty ? 'entrenador' : trainer);
    return announce(
      KarenStep(
        text,
        mood: KarenMood.wave,
        emote: key == 'night' ? KarenEmote.zzz : KarenEmote.heart,
        companions: key == 'night' ? const [94, 143] : const [25, 133],
      ),
    );
  }

  static const Duration _welcomeHold = Duration(milliseconds: 6200);

  /// Saluda y, si es la primera vez, encadena la guía cuando termina de hablar.
  void welcome({required bool firstTime, VoidCallback? onTourDone}) {
    greet(firstTime: firstTime);
    if (!firstTime) return;
    _pendingTour?.cancel();
    _pendingTour = Timer(_welcomeHold + const Duration(milliseconds: 400), () {
      if (_enabled && !inTour && ProfileStore.instance.isRegistered) {
        startTour(onDone: onTourDone);
      }
    });
  }

  /// Al abrir la ficha de un Pokémon: comenta algo con sentido sobre él.
  bool onPokemonOpened({
    required int id,
    required String displayName,
    required String type,
    required int total,
    required bool legendary,
  }) {
    KarenStep fill(KarenStep s) => s.fill(name: displayName, total: total, companions: [id]);

    // Un dato propio de ese Pokémon manda sobre lo demás, una vez por sesión.
    final trivia = _trivia[id];
    if (trivia != null && !_triviaSaid.contains(id)) {
      final said = _say(fill(trivia));
      if (said) _triviaSaid.add(id);
      return said;
    }
    if (legendary) return _say(fill(_pick('legendary', _legendaryLines)));
    if (total >= 540) return _say(fill(_pick('strong', _strongLines)));
    if (total <= 250) return _say(fill(_pick('weak', _weakLines)));

    final lines = _typeLines[type];
    if (lines == null) return false;
    return _say(
      KarenStep(
        _pick('type-$type', lines),
        mood: KarenMood.point,
        emote: KarenEmote.idea,
        companions: [id],
      ),
    );
  }

  /// Al marcar o desmarcar un favorito.
  bool onFavorite(int id, String displayName, {required int teamSize}) => announce(
    _pick('favorite', _favoriteLines).fill(name: displayName, count: teamSize, companions: [id]),
    hold: const Duration(seconds: 5),
  );

  bool onUnfavorite(int id, String displayName) =>
      _say(_pick('unfavorite', _unfavoriteLines).fill(name: displayName, companions: [id]));

  /// Cuando una búsqueda o un filtro no devuelve nada.
  bool onNoResults() => _say(_pick('empty', _noResultsLines));

  /// Cuando la red falla.
  bool onNetworkError() => _say(_pick('network', _networkLines));

  /// Al usar el botón de Pokémon al azar.
  bool onRandom(int id, String displayName) => announce(
    _pick('random', _randomLines).fill(name: displayName, companions: [id]),
    hold: const Duration(seconds: 5),
  );

  /// Al activar la variante shiny.
  bool onShiny(int id, String displayName) => announce(
    _pick('shiny', _shinyLines).fill(name: displayName, companions: [id]),
    hold: const Duration(seconds: 6),
  );

  /// Al pasar al sprite animado.
  bool onAnimated(int id, String displayName) =>
      _say(_pick('animated', _animatedLines).fill(name: displayName));

  /// Al tocar al Pokémon para oír su grito (sólo comenta la primera vez).
  bool onCry(int id, String displayName) =>
      _once('cry', _pick('cry', _cryLines).fill(name: displayName));

  /// Al filtrar por un tipo.
  bool onTypeSelected(String type, List<int> sample) {
    final text = _typeFilterLines[type];
    if (text == null) return false;
    return _once(
      'type-$type',
      KarenStep(text, mood: KarenMood.point, emote: KarenEmote.idea, companions: sample),
    );
  }

  /// Al ver sólo el equipo.
  bool onTeamShown(int count, List<int> sample) => count == 0
      ? _say(_pick('team-empty', _teamEmptyLines))
      : _say(_pick('team', _teamLines).fill(count: count, companions: sample));

  /// Al cambiar de ficha deslizando: cada tanto, un comentario.
  bool onSwipe() {
    _swipes++;
    if (_swipes % 8 != 0) return false;
    return _say(_pick('swipe', _swipeLines));
  }

  /// La primera vez que abre las pestañas de estadísticas o evolución.
  bool onTab(int index) => switch (index) {
    1 => _once('tab-stats', _pick('tab-stats', _statsTabLines)),
    2 => _once('tab-evolution', _pick('tab-evolution', _evolutionTabLines)),
    _ => false,
  };

  // ----------------------------------------------------------------- guía

  /// Arranca una guía. [onDone] se llama al terminarla o saltarla.
  void startTour({KarenTour kind = KarenTour.app, VoidCallback? onDone}) {
    _autoHide?.cancel();
    _pendingTour?.cancel();
    _onTourDone = onDone;
    _tourKind = kind;
    _tour = kind == KarenTour.app ? _appTour : _detailTour;
    _tourIndex = 0;
    _visible = true;
    notifyListeners();
  }

  KarenStep? get currentStep => inTour ? _tour[_tourIndex] : null;

  void nextStep() {
    if (!inTour) return;
    if (_tourIndex >= _tour.length - 1) return endTour();
    _tourIndex++;
    notifyListeners();
  }

  void previousStep() {
    if (!inTour || _tourIndex == 0) return;
    _tourIndex--;
    notifyListeners();
  }

  /// Termina la guía. Con [skipped] se da por vista también la de la ficha:
  /// quien salta la primera no quiere otra al abrir un Pokémon.
  void endTour({bool skipped = false}) {
    if (!inTour) return;
    final kind = _tourKind;
    _tour = const [];
    _tourKind = null;
    _tourIndex = 0;
    _visible = false;
    _lastSpoke = DateTime.now();
    if (kind == KarenTour.app) ProfileStore.instance.markTutorialDone();
    if (kind == KarenTour.detail || skipped) ProfileStore.instance.markDetailTourDone();
    notifyListeners();
    final done = _onTourDone;
    _onTourDone = null;
    done?.call();
  }

  @override
  void dispose() {
    _autoHide?.cancel();
    _idleTimer?.cancel();
    _pendingTour?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- guías

  static const List<KarenStep> _appTour = [
    KarenStep(
      'Esta es la Pokédex nacional entera: 1025 Pokémon, con sus datos reales '
      'traídos en vivo desde la PokeAPI.',
      mood: KarenMood.point,
      emote: KarenEmote.sparkle,
      companions: [1, 4, 7],
    ),
    KarenStep(
      'Cada tarjeta es un Pokémon: su número, su nombre y sus tipos. El color '
      'de la tarjeta es el de su tipo principal.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [1],
      target: 'card',
    ),
    KarenStep(
      'Aquí está el buscador. Funciona con el nombre y también con el número: '
      'escribe 25 y sale Pikachu.',
      mood: KarenMood.think,
      emote: KarenEmote.idea,
      companions: [25],
      target: 'search',
    ),
    KarenStep(
      'Estos son los 18 tipos. Toca uno y la lista se queda sólo con los '
      'Pokémon de ese tipo; tócalo otra vez para quitarlo.',
      mood: KarenMood.point,
      emote: KarenEmote.none,
      companions: [6, 9],
      target: 'types',
    ),
    KarenStep(
      'Este corazón muestra sólo tu equipo. Lo que marques se queda guardado '
      'aunque cierres la app.',
      mood: KarenMood.happy,
      emote: KarenEmote.heart,
      companions: [133],
      target: 'team',
    ),
    KarenStep(
      'La música cambia según el tipo del Pokémon que estés viendo. Aquí la '
      'apagas, y al lado los efectos de sonido.',
      mood: KarenMood.happy,
      emote: KarenEmote.notes,
      companions: [144, 145],
      target: 'sound',
    ),
    KarenStep(
      'Toca tu foto para ver tu perfil: desde ahí repites esta guía, apagas mis '
      'consejos, cierras sesión o borras tus datos.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [25],
      target: 'avatar',
    ),
    KarenStep(
      '¿No sabes a quién ver? Este botón abre un Pokémon al azar. Es mi forma '
      'favorita de descubrir nuevos.',
      mood: KarenMood.cheer,
      emote: KarenEmote.sparkle,
      companions: [132],
      target: 'random',
    ),
    KarenStep(
      '¡Listo! Ahora toca cualquier Pokémon. Cuando abras el primero te enseño '
      'su ficha, que tiene sorpresas.',
      mood: KarenMood.wave,
      emote: KarenEmote.heart,
      companions: [25, 1],
      target: 'card',
    ),
  ];

  static const List<KarenStep> _detailTour = [
    KarenStep(
      '¡Tu primer Pokémon! Esta es su ficha. Toca al Pokémon y oirás su grito '
      'real, sacado de los juegos.',
      mood: KarenMood.cheer,
      emote: KarenEmote.notes,
      target: 'art',
    ),
    KarenStep(
      'Con "Animado" lo ves moverse como en un combate. Vuelve a tocarlo para '
      'regresar al arte oficial.',
      mood: KarenMood.point,
      emote: KarenEmote.sparkle,
      target: 'anim',
    ),
    KarenStep(
      '"Shiny" muestra su variocolor, la versión rara de otro color.',
      mood: KarenMood.surprise,
      emote: KarenEmote.sparkle,
      target: 'shiny',
    ),
    KarenStep(
      'El corazón lo añade a tu equipo. Lo encuentras luego en la lista con el '
      'corazón de arriba.',
      mood: KarenMood.happy,
      emote: KarenEmote.heart,
      target: 'fav',
    ),
    KarenStep(
      'Aquí cambias entre Datos, Stats con su radar, y la cadena de Evolución.',
      mood: KarenMood.think,
      emote: KarenEmote.idea,
      target: 'tabs',
    ),
    KarenStep(
      'Desliza a los lados para pasar al siguiente Pokémon sin volver a la '
      'lista. En la compu, también con las flechas del teclado.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [16, 17],
    ),
    KarenStep(
      'Y la flecha de arriba te regresa a la lista. ¡Eso es todo! Me quedo '
      'cerca por si quieres algún dato.',
      mood: KarenMood.wave,
      emote: KarenEmote.heart,
      target: 'back',
    ),
  ];
}

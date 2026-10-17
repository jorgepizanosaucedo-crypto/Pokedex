import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'profile_store.dart';

/// Ánimo de Karen: decide cómo se mueve el dibujo.
enum KarenMood { idle, happy, cheer, wave, think, point, surprise, worry, sleepy }

/// Reacción estilo manga que aparece junto a ella.
enum KarenEmote { none, sparkle, sweat, exclaim, question, idea, thought, heart, notes, zzz }

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

/// Un paso de la guía de la app.
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
}

/// Karen, la mascota: decide qué dice, cuándo y con qué cara.
///
/// La parte visual vive en `widgets/karen_overlay.dart`. Aquí sólo está el
/// comportamiento: el repertorio de consejos, las reacciones a lo que pasa en
/// la app, el ritmo con el que aparece y la guía paso a paso.
class KarenController extends ChangeNotifier {
  KarenController._();
  static final KarenController instance = KarenController._();

  static const String name = 'Karen';

  /// Tiempo mínimo entre dos consejos espontáneos.
  static const Duration _gap = Duration(seconds: 20);

  /// Cuánto hay que estar quieto para que salga un consejo.
  static const Duration _idleAfter = Duration(seconds: 35);

  /// Y cada cuánto, como mucho, puede repetirse eso.
  static const Duration _idleEvery = Duration(minutes: 4);

  final math.Random _random = math.Random();

  KarenLine? _line;
  bool _enabled = true;
  bool _visible = false;
  DateTime _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastIdleTip = DateTime.now();
  DateTime _lastInput = DateTime.now();
  Timer? _autoHide;
  Timer? _idleTimer;
  Timer? _pendingTour;

  // Guía paso a paso.
  List<KarenStep> _tour = const [];
  int _tourIndex = 0;
  VoidCallback? _onTourDone;

  KarenLine? get line => _line;
  bool get enabled => _enabled;
  bool get visible => _visible;
  bool get inTour => _tour.isNotEmpty;
  int get tourIndex => _tourIndex;
  int get tourLength => _tour.length;

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
      _say(_tips[_random.nextInt(_tips.length)]);
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
    _tourIndex = 0;
    _onTourDone = null;
    _visible = false;
    _line = null;
    _lastSpoke = DateTime.fromMillisecondsSinceEpoch(0);
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

  void hide() {
    _autoHide?.cancel();
    if (!_visible || inTour) return;
    _visible = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ reacciones

  /// Bienvenida tras registrarse o al volver a abrir la app.
  bool greet({required bool firstTime}) {
    final trainer = ProfileStore.instance.name.split(' ').first;
    final hello = trainer.isEmpty ? '¡Hola!' : '¡Hola, $trainer!';
    return announce(
      firstTime
          ? KarenStep(
              '$hello Soy Karen y voy a ser tu asistente de Pokédex. '
              'Déjame enseñarte cómo funciona esto.',
              mood: KarenMood.wave,
              emote: KarenEmote.sparkle,
              companions: const [25, 133],
            )
          : KarenStep(
              '$hello Qué bueno verte otra vez. La Pokédex está lista cuando tú lo estés.',
              mood: KarenMood.wave,
              emote: KarenEmote.heart,
              companions: const [25, 143],
            ),
      hold: firstTime ? _welcomeHold : null,
    );
  }

  static const Duration _welcomeHold = Duration(milliseconds: 5800);

  /// Saluda y, si es la primera vez, encadena la guía cuando termina de hablar.
  void welcome({required bool firstTime, VoidCallback? onTourDone}) {
    greet(firstTime: firstTime);
    if (!firstTime) return;
    _pendingTour?.cancel();
    _pendingTour = Timer(_welcomeHold + const Duration(milliseconds: 500), () {
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
    if (legendary) {
      return _say(
        KarenStep(
          '¡$displayName! Este es de los que casi nadie llega a ver. '
          'Fíjate en sus estadísticas, están muy por encima de lo normal.',
          mood: KarenMood.surprise,
          emote: KarenEmote.exclaim,
          companions: [id],
        ),
      );
    }
    if (total >= 540) {
      return _say(
        KarenStep(
          '$displayName suma $total puntos de estadísticas base. Es un peso pesado.',
          mood: KarenMood.happy,
          emote: KarenEmote.sparkle,
          companions: [id],
        ),
      );
    }
    if (total <= 250) {
      return _say(
        KarenStep(
          '$displayName es pequeñito todavía: $total de total base. '
          'Mira la pestaña de Evolución, seguro tiene futuro.',
          mood: KarenMood.think,
          emote: KarenEmote.idea,
          companions: [id],
        ),
      );
    }
    final line = _typeLines[type];
    if (line == null) return false;
    return _say(KarenStep(line, mood: KarenMood.point, emote: KarenEmote.idea, companions: [id]));
  }

  /// Al marcar un favorito.
  bool onFavorite(int id, String displayName) => announce(
    KarenStep(
      '$displayName ya es parte de tu equipo. Lo encuentras con el corazón de arriba.',
      mood: KarenMood.cheer,
      emote: KarenEmote.heart,
      companions: [id],
    ),
    hold: const Duration(seconds: 5),
  );

  /// Cuando una búsqueda o un filtro no devuelve nada.
  bool onNoResults() => _say(
    const KarenStep(
      'Ahí no hay nada. Prueba quitando el filtro de tipo, o busca por número: '
      'el 025 es Pikachu.',
      mood: KarenMood.worry,
      emote: KarenEmote.sweat,
      companions: [25],
    ),
  );

  /// Cuando la red falla.
  bool onNetworkError() => _say(
    const KarenStep(
      'No consigo hablar con la PokeAPI. Revisa tu conexión y dale a Reintentar.',
      mood: KarenMood.worry,
      emote: KarenEmote.sweat,
    ),
  );

  /// Al usar el botón de Pokémon al azar.
  bool onRandom(int id, String displayName) => announce(
    KarenStep(
      '¡Te tocó $displayName! Así se descubren los que nunca buscarías.',
      mood: KarenMood.cheer,
      emote: KarenEmote.sparkle,
      companions: [id],
    ),
    hold: const Duration(seconds: 5),
  );

  /// Al activar la variante shiny.
  bool onShiny(int id, String displayName) => announce(
    KarenStep(
      '¡Ese es el $displayName variocolor! En los juegos aparece una vez '
      'cada varios miles. Aquí lo tienes con un botón.',
      mood: KarenMood.surprise,
      emote: KarenEmote.sparkle,
      companions: [id],
    ),
    hold: const Duration(seconds: 6),
  );

  // ----------------------------------------------------------------- guía

  /// Arranca la guía de la app. [onDone] se llama al terminarla o saltarla.
  void startTour({VoidCallback? onDone}) {
    _autoHide?.cancel();
    _pendingTour?.cancel();
    _onTourDone = onDone;
    _tour = _tourSteps;
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

  void endTour() {
    if (!inTour) return;
    _tour = const [];
    _tourIndex = 0;
    _visible = false;
    _lastSpoke = DateTime.now();
    ProfileStore.instance.markTutorialDone();
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

  // ------------------------------------------------------------ repertorio

  static const List<KarenStep> _tourSteps = [
    KarenStep(
      'Esto es la Pokédex nacional entera: 1025 Pokémon, con sus datos reales '
      'traídos en vivo desde la PokeAPI.',
      mood: KarenMood.point,
      emote: KarenEmote.sparkle,
      companions: [1, 4, 7],
    ),
    KarenStep(
      'Aquí está el buscador. Funciona con el nombre y también con el '
      'número: escribe 25 y sale Pikachu.',
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
      'Toca cualquier Pokémon y verás su ficha: datos, estadísticas en un radar '
      'y su cadena evolutiva. Dentro, desliza a los lados para pasar al siguiente.',
      mood: KarenMood.think,
      emote: KarenEmote.thought,
      companions: [133, 134],
      target: 'card',
    ),
    KarenStep(
      'Dentro de la ficha, toca el dibujo para oír su grito de verdad, y el '
      'botón Shiny para ver su color raro.',
      mood: KarenMood.surprise,
      emote: KarenEmote.exclaim,
      companions: [94],
    ),
    KarenStep(
      'La música cambia según el tipo del Pokémon que estés viendo. Aquí la '
      'apagas, y al lado los efectos de sonido.',
      mood: KarenMood.happy,
      emote: KarenEmote.notes,
      companions: [144, 145, 146],
      target: 'sound',
    ),
    KarenStep(
      'Toca tu foto para ver tu perfil: desde ahí repites esta guía, cierras '
      'sesión o borras tus datos.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [25],
      target: 'avatar',
    ),
    KarenStep(
      'Y ya está. Si te quedas parado un rato apareceré con algún dato. '
      '¡Que lo disfrutes!',
      mood: KarenMood.cheer,
      emote: KarenEmote.sparkle,
      companions: [25, 1],
    ),
  ];

  static const List<KarenStep> _tips = [
    KarenStep(
      'El botón "Al azar" de abajo abre un Pokémon cualquiera. Es la mejor forma de '
      'encontrar alguno que no conocías.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [132],
    ),
    KarenStep(
      'Dentro de una ficha puedes deslizar a los lados para pasar al siguiente '
      'Pokémon sin volver a la lista.',
      mood: KarenMood.think,
      emote: KarenEmote.idea,
      companions: [16],
    ),
    KarenStep(
      'El radar de estadísticas usa siempre la misma escala, de 0 a 255. Por '
      'eso puedes comparar dos Pokémon de un vistazo.',
      mood: KarenMood.think,
      emote: KarenEmote.thought,
      companions: [65],
    ),
    KarenStep(
      '¿Sabías que el peso sale en hectogramos en la API? Yo ya te lo paso a '
      'kilos para que no tengas que dividir.',
      mood: KarenMood.happy,
      emote: KarenEmote.idea,
      companions: [143],
    ),
    KarenStep(
      'Las habilidades con el ojito tachado son ocultas: en los juegos no '
      'salen normalmente.',
      mood: KarenMood.point,
      emote: KarenEmote.exclaim,
      companions: [448],
    ),
    KarenStep(
      'En la cadena evolutiva puedes tocar cualquier forma para saltar a su '
      'ficha. El que está marcado es el que ya estás viendo.',
      mood: KarenMood.think,
      emote: KarenEmote.idea,
      companions: [133, 196],
    ),
    KarenStep(
      'Si la música te distrae, el botón de la nota la apaga. Los efectos '
      'tienen su propio botón al lado.',
      mood: KarenMood.happy,
      emote: KarenEmote.notes,
      companions: [39],
    ),
    KarenStep(
      'Eevee tiene la cadena evolutiva más ramificada de todas. Búscalo con el '
      'número 133 y mira la pestaña de Evolución.',
      mood: KarenMood.surprise,
      emote: KarenEmote.sparkle,
      companions: [133],
    ),
    KarenStep(
      'Los tipos no son sólo un color: filtran de verdad. Prueba a cruzar el '
      'buscador con un tipo para afinar.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
      companions: [94],
    ),
  ];

  /// Un comentario por tipo, para cuando el Pokémon no destaca por sus números.
  static const Map<String, String> _typeLines = {
    'fire': 'Los de tipo fuego suelen pegar fuerte, pero ojo con su defensa.',
    'water': 'Agua es el tipo más numeroso de toda la Pokédex. Nunca te faltará uno.',
    'grass': 'Los de planta aguantan bien, aunque tienen muchas debilidades.',
    'electric': 'Los eléctricos casi siempre destacan en velocidad. Mira el radar.',
    'psychic': 'Los psíquicos viven del ataque especial. Fíjate en el radar.',
    'dragon': 'Los dragón tardan mucho en evolucionar, pero acaban siendo bestias.',
    'ghost': 'Los fantasma tienen inmunidades que los hacen muy incómodos de enfrentar.',
    'steel': 'Acero es el tipo con más resistencias del juego. Una muralla.',
    'fairy': 'El tipo hada es el más nuevo: se añadió para frenar a los dragones.',
    'rock': 'Los de roca son lentos y duros. Clásico intercambio.',
    'ice': 'Hielo pega muchísimo, pero se defiende fatal. Vidrio de cañón.',
    'bug': 'Los bicho evolucionan muy pronto. Son los primeros que se llenan en la Pokédex.',
    'fighting': 'Los de lucha tienen ataque físico de sobra y poco más. Directos.',
    'poison': 'Veneno era durísimo en la primera generación; hoy está más calmado.',
    'ground': 'Los de tierra son los únicos inmunes a los ataques eléctricos.',
    'flying': 'Casi ningún Pokémon es sólo volador: casi siempre va de segundo tipo.',
    'normal': 'Normal no resiste nada, pero es inmune a los ataques Fantasma.',
    'dark':
        'El tipo siniestro no existía en la primera generación. Llegó para parar a los psíquicos.',
  };
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/karen_controller.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'artwork_image.dart';

/// Proporciones del dibujo original de Karen (420 × 1102 px).
const double _karenAspect = 420 / 1102;

/// Qué parte de ella se ve. En la guía se le ve casi entera, porque es cuando
/// se presenta; en un consejo suelto sólo se asoma, para no tapar la app.
const double _tourVisibleFraction = 0.94;
const double _tipVisibleFraction = 0.6;

/// Lado de la pantalla en el que se coloca Karen.
enum _Side { left, right }

/// Partes de la pantalla que Karen puede iluminar durante la guía.
///
/// Cada pantalla pone `KarenTargets.key('search')` (por ejemplo) en el widget
/// que quiere señalar; la guía lo busca por nombre.
class KarenTargets {
  KarenTargets._();

  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey key(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey(debugLabel: 'karen-$name'));

  /// La clave sólo si [enabled]. En las fichas sólo la que se está mirando
  /// la lleva: el `PageView` construye también las vecinas, y una clave
  /// global no puede estar en dos sitios a la vez.
  static GlobalKey? keyIf(bool enabled, String name) => enabled ? key(name) : null;

  /// Rectángulo en pantalla, o `null` si ahora mismo no se ve.
  static Rect? rectOf(String? name) {
    if (name == null) return null;
    final box = _keys[name]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Espacio que Karen deja libre abajo (el botón "Al azar", por ejemplo).
///
/// Cada pantalla que lo necesite se envuelve en [KarenBottomInset]; manda la
/// última que se montó, que es la que está encima.
class KarenInsets {
  KarenInsets._();

  static final List<_Reserve> _stack = [];

  static double get bottom => _stack.isEmpty ? 0 : _stack.last.value;
}

class _Reserve {
  final double value;
  _Reserve(this.value);
}

class KarenBottomInset extends StatefulWidget {
  final double value;
  final Widget child;

  const KarenBottomInset({super.key, required this.value, required this.child});

  @override
  State<KarenBottomInset> createState() => _KarenBottomInsetState();
}

class _KarenBottomInsetState extends State<KarenBottomInset> {
  late final _Reserve _reserve = _Reserve(widget.value);

  @override
  void initState() {
    super.initState();
    KarenInsets._stack.add(_reserve);
  }

  @override
  void dispose() {
    KarenInsets._stack.remove(_reserve);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Karen sobre toda la app.
///
/// Se monta una sola vez, encima del navegador, para que pueda aparecer en
/// cualquier pantalla sin que cada una tenga que saber de ella.
class KarenOverlay extends StatefulWidget {
  final Widget child;

  const KarenOverlay({super.key, required this.child});

  @override
  State<KarenOverlay> createState() => _KarenOverlayState();
}

class _KarenOverlayState extends State<KarenOverlay> {
  final KarenController _karen = KarenController.instance;

  /// Durante la guía se vuelve a medir lo señalado cada poco: la pantalla de
  /// debajo puede estar todavía entrando, desplazándose o cambiando de tamaño.
  Timer? _measure;
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    _karen.startIdleWatch();
    _karen.addListener(_onKaren);
  }

  @override
  void dispose() {
    _karen.removeListener(_onKaren);
    _karen.stopIdleWatch();
    _measure?.cancel();
    super.dispose();
  }

  void _onKaren() {
    if (_karen.inTour) {
      _measure ??= Timer.periodic(const Duration(milliseconds: 200), (_) => _remeasure());
    } else {
      _measure?.cancel();
      _measure = null;
    }
  }

  void _remeasure() {
    final rect = KarenTargets.rectOf(_karen.currentStep?.target);
    if (rect != _rect && mounted) setState(() => _rect = rect);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _karen,
            builder: (context, _) {
              final step = _karen.currentStep;
              final line = _karen.line;
              final visible = _karen.visible && (step != null || line != null);
              _rect = _karen.inTour ? KarenTargets.rectOf(step?.target) : null;

              // Karen vive encima del navegador, fuera de cualquier Scaffold:
              // sin este Material sus textos salían subrayados en amarillo.
              return Material(
                type: MaterialType.transparency,
                child: _KarenStage(
                  visible: visible,
                  text: step?.text ?? line?.text ?? '',
                  mood: step?.mood ?? line?.mood ?? KarenMood.idle,
                  emote: step?.emote ?? line?.emote ?? KarenEmote.none,
                  companions: step?.companions ?? line?.companions ?? const [],
                  target: _rect,
                  // En la guía el globo no se cierra solo: lleva sus botones.
                  tour: _karen.inTour ? (index: _karen.tourIndex, total: _karen.tourLength) : null,
                  onNext: _karen.nextStep,
                  onBack: _karen.previousStep,
                  onSkip: () => _karen.endTour(skipped: true),
                  onDismiss: _karen.hide,
                  // Cada paso de la guía es un globo nuevo: antes el texto se
                  // quedaba en el primer paso si había una frase previa.
                  stamp: _karen.inTour ? -1 - _karen.tourIndex : (line?.stamp ?? 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Coloca a Karen y su globo según lo que está explicando.
///
/// Reglas, para que nunca tape lo importante:
/// - Karen se pone en el lado contrario a lo que señala y camina de un lado
///   a otro entre pasos.
/// - El globo va pegado a lo señalado (debajo si está arriba, encima si está
///   abajo), con una flechita hacia ello.
/// - Si el globo baja hasta la altura de Karen, se aparta de su columna: ni
///   el globo la tapa a ella ni ella al globo.
/// - Sin nada que señalar, el globo va a su lado, a la altura de su cabeza.
class _KarenStage extends StatelessWidget {
  final bool visible;
  final String text;
  final KarenMood mood;
  final KarenEmote emote;
  final List<int> companions;
  final Rect? target;
  final ({int index, int total})? tour;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;
  final int stamp;

  const _KarenStage({
    required this.visible,
    required this.text,
    required this.mood,
    required this.emote,
    required this.companions,
    required this.target,
    required this.tour,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onDismiss,
    required this.stamp,
  });

  static const double _edge = 8;
  static const double _margin = 12;

  /// Alto aproximado del globo de la guía (texto de tres líneas y botones).
  static const double _bubbleEstimate = 190;

  _Side _side(Size screen) {
    final tour = this.tour;
    if (tour == null) return _Side.left;
    final target = this.target;
    if (target != null) return target.center.dx < screen.width / 2 ? _Side.right : _Side.left;
    // Sin foco, alterna de lado en cada paso: así se nota que avanza.
    return tour.index.isEven ? _Side.right : _Side.left;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom + KarenInsets.bottom;
    final layout = Layout(screen);
    final isTour = tour != null;

    final height = layout.karenHeight(big: isTour);
    final width = height * _karenAspect;
    final visibleFraction = isTour ? _tourVisibleFraction : _tipVisibleFraction;
    final visibleHeight = height * visibleFraction;
    final hidden = height - visibleHeight;
    final mate = width * 0.62;

    final side = _side(screen);
    // Columna que ocupan ella y sus acompañantes.
    final columnWidth = companions.isEmpty ? width : width * 0.92 + mate;
    final columnLeft = side == _Side.left ? _edge : screen.width - _edge - columnWidth;
    final column = Rect.fromLTWH(
      columnLeft,
      screen.height - bottomInset - visibleHeight,
      columnWidth,
      visibleHeight,
    );
    final karenLeft = side == _Side.left ? _edge : screen.width - _edge - width;

    final maxBubble = isTour ? 380.0 : 340.0;
    final minBubble = math.min(220.0, screen.width - _margin * 2);
    double left;
    double bubbleWidth;
    double? top;
    double? bottom;
    ({bool up, double x})? tail;

    final target = this.target;
    if (target != null) {
      final below = target.center.dy < screen.height * 0.55;
      final spanTop = below ? target.bottom + 14 : target.top - 14 - _bubbleEstimate;
      final spanBottom = spanTop + _bubbleEstimate;
      var minX = _margin;
      var maxX = screen.width - _margin;
      // Aquí sólo se esquiva a Karen: si hace falta, el globo puede tapar a
      // sus acompañantes (en un teléfono, con ellos quedaba demasiado estrecho).
      if (spanBottom > column.top - 6) {
        if (side == _Side.left) {
          minX = karenLeft + width + 8;
        } else {
          maxX = karenLeft - 8;
        }
      }
      bubbleWidth = math.max(minBubble, math.min(maxBubble, maxX - minX));
      left = (target.center.dx - bubbleWidth / 2).clamp(minX, math.max(minX, maxX - bubbleWidth));
      left = left.clamp(_margin, math.max(_margin, screen.width - _margin - bubbleWidth));
      if (below) {
        top = target.bottom + 14;
      } else {
        bottom = screen.height - target.top + 14;
      }
      tail = (up: below, x: (target.center.dx - left).clamp(22.0, bubbleWidth - 22.0));
    } else {
      // Junto a ella, a la altura de la cabeza.
      if (side == _Side.left) {
        left = column.right + 10;
        bubbleWidth = math.max(minBubble, math.min(maxBubble, screen.width - left - _margin));
      } else {
        bubbleWidth = math.max(minBubble, math.min(maxBubble, column.left - 10 - _margin));
        left = column.left - 10 - bubbleWidth;
      }
      left = left.clamp(_margin, math.max(_margin, screen.width - _margin - bubbleWidth));
      bottom = bottomInset + visibleHeight * (isTour ? 0.5 : 0.42);
    }

    final bubble = _SpeechBubble(
      key: ValueKey(stamp),
      text: text,
      tour: tour,
      tail: tail,
      onNext: onNext,
      onBack: onBack,
      onSkip: onSkip,
      onDismiss: onDismiss,
    );

    return IgnorePointer(
      ignoring: !visible,
      child: Stack(
        children: [
          // En la guía, un velo con un hueco sobre lo que está explicando.
          // Tocarlo pasa al siguiente paso.
          if (isTour)
            Positioned.fill(
              child: GestureDetector(
                onTap: onNext,
                behavior: HitTestBehavior.opaque,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 420),
                  child: _Spotlight(target: target),
                ),
              ),
            ),
          // Karen camina al otro lado cuando lo señalado cambia de sitio.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            left: karenLeft,
            bottom: bottomInset - hidden,
            width: width,
            height: height,
            child: _SlideUp(
              visible: visible,
              distance: visibleHeight + 40,
              child: _KarenFigure(
                mood: mood,
                emote: emote,
                companions: companions,
                stamp: stamp,
                side: side,
                hiddenFraction: 1 - visibleFraction,
                onTap: isTour ? onNext : onDismiss,
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            left: left,
            width: bubbleWidth,
            top: top,
            bottom: bottom,
            child: _SlideUp(visible: visible, distance: 24, delayed: true, child: bubble),
          ),
        ],
      ),
    );
  }
}

/// Velo oscuro con un hueco redondeado y borde blanco sobre [target].
class _Spotlight extends StatelessWidget {
  final Rect? target;

  static const Color _veil = Color(0x8C14151E);

  const _Spotlight({required this.target});

  @override
  Widget build(BuildContext context) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    // El aro no se sale de la pantalla: lo que ocupa todo el ancho (la barra
    // de tipos, el buscador) se queda con el borde completo a la vista.
    final hole = target?.inflate(6).intersect(screen.deflate(3));
    if (hole == null || hole.isEmpty) return const ColoredBox(color: _veil);
    // El hueco viaja de un elemento al siguiente en vez de saltar.
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: hole),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, rect, _) => CustomPaint(
        size: Size.infinite,
        painter: _SpotlightPainter(hole: rect ?? hole, veil: _veil),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  final Color veil;

  const _SpotlightPainter({required this.hole, required this.veil});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(path, Paint()..color = veil);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole || old.veil != veil;
}

/// Entra deslizándose desde abajo con rebote y sale seca, como en el original.
class _SlideUp extends StatefulWidget {
  final bool visible;
  final double distance;
  final bool delayed;
  final Widget child;

  const _SlideUp({
    required this.visible,
    required this.distance,
    required this.child,
    this.delayed = false,
  });

  @override
  State<_SlideUp> createState() => _SlideUpState();
}

class _SlideUpState extends State<_SlideUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 400),
    value: widget.visible ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    // Cuando termina de esconderse se reconstruye sin el dibujo: así sus
    // animaciones no siguen corriendo (ni repintando) mientras no se ve.
    _c.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _SlideUp old) {
    super.didUpdateWidget(old);
    if (old.visible == widget.visible) return;
    if (widget.visible) {
      Future.delayed(widget.delayed ? const Duration(milliseconds: 260) : Duration.zero, () {
        if (mounted && widget.visible) _c.forward();
      });
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _c.isDismissed) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.status == AnimationStatus.reverse || _c.status == AnimationStatus.dismissed
            ? Curves.easeIn.transform(_c.value)
            : Curves.easeOutBack.transform(_c.value).clamp(0.0, 1.2);
        return Transform.translate(
          offset: Offset(0, (1 - t) * widget.distance),
          child: Opacity(opacity: _c.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// El dibujo de Karen, sin tocar, animado por capas: respira, reacciona según
/// el ánimo, y a su lado la acompañan Pokémon que flotan.
class _KarenFigure extends StatefulWidget {
  final KarenMood mood;
  final KarenEmote emote;
  final List<int> companions;
  final int stamp;
  final _Side side;

  /// Parte de abajo que queda fuera de la pantalla: los acompañantes van
  /// siempre por encima de ella.
  final double hiddenFraction;
  final VoidCallback onTap;

  const _KarenFigure({
    required this.mood,
    required this.emote,
    required this.companions,
    required this.stamp,
    required this.side,
    required this.hiddenFraction,
    required this.onTap,
  });

  @override
  State<_KarenFigure> createState() => _KarenFigureState();
}

class _KarenFigureState extends State<_KarenFigure> with TickerProviderStateMixin {
  /// Respiración continua y flotación de los acompañantes.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  /// El gesto del ánimo: se dispara una vez por frase.
  late final AnimationController _gesture = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// Saltitos mientras camina al otro lado de la pantalla.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(covariant _KarenFigure old) {
    super.didUpdateWidget(old);
    if (old.stamp != widget.stamp || old.mood != widget.mood) _gesture.forward(from: 0);
    if (old.side != widget.side) _walk.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _gesture.dispose();
    _walk.dispose();
    super.dispose();
  }

  /// Traslación, rotación y escala que toca a cada ánimo en este instante.
  ({Offset offset, double angle, double scaleX, double scaleY}) _transform(double g, double b) {
    // La respiración siempre está por debajo de todo lo demás.
    final breathe = (scaleX: 1 + b * 0.006, scaleY: 1 + b * 0.014);

    switch (widget.mood) {
      case KarenMood.happy:
        final hop = math.sin(g.clamp(0.0, 0.6) / 0.6 * math.pi);
        return (
          offset: Offset(0, -26 * hop),
          angle: 0,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.cheer:
        final hop = math.sin((g.clamp(0.0, 0.8) / 0.4) * math.pi).abs();
        return (
          offset: Offset(0, -30 * hop),
          angle: 0,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.wave:
        final w = math.sin(g * math.pi * 4) * (1 - g).clamp(0.0, 1.0);
        return (
          offset: Offset.zero,
          angle: w * 0.055,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.surprise:
        final j = math.sin(g.clamp(0.0, 0.45) / 0.45 * math.pi);
        return (
          offset: Offset(0, -18 * j),
          angle: 0,
          scaleX: breathe.scaleX * (1 + j * 0.03),
          scaleY: breathe.scaleY * (1 + j * 0.03),
        );
      case KarenMood.worry:
        final s = math.sin(g * math.pi * 10) * (1 - g).clamp(0.0, 1.0);
        return (offset: Offset(s * 4, 0), angle: 0, scaleX: breathe.scaleX, scaleY: breathe.scaleY);
      case KarenMood.think:
        return (
          offset: Offset(-4 * g, 0),
          angle: -0.042 * g,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.point:
        // Se inclina hacia el centro de la pantalla, hacia lo que explica.
        final lean = widget.side == _Side.left ? 1 : -1;
        return (
          offset: Offset.zero,
          angle: 0.035 * g * lean,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.sleepy:
        return (
          offset: Offset(0, b * 4),
          angle: 0.026 + b * 0.035,
          scaleX: breathe.scaleX,
          scaleY: breathe.scaleY,
        );
      case KarenMood.idle:
        return (offset: Offset.zero, angle: 0, scaleX: breathe.scaleX, scaleY: breathe.scaleY);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final mate = w * 0.62;
        final onLeft = widget.side == _Side.left;

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _gesture, _walk]),
            builder: (context, _) {
              final t = _transform(
                Curves.easeOut.transform(_gesture.value),
                Curves.easeInOut.transform(_idle.value),
              );
              final bob = math.sin(_idle.value * math.pi * 2) * 5;
              // Tres saltitos mientras cruza.
              final hop = _walk.isAnimating ? math.sin(_walk.value * math.pi * 3).abs() : 0.0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Acompañantes: en columna, del lado de dentro de la
                  // pantalla y fuera de su silueta, flotando a destiempo.
                  for (final (i, id) in widget.companions.take(3).indexed)
                    Positioned(
                      left: onLeft ? w * 0.92 : null,
                      right: onLeft ? null : w * 0.92,
                      bottom: h * (widget.hiddenFraction + 0.03) + i * mate * 0.95,
                      child: Transform.translate(
                        offset: Offset(0, i.isEven ? bob : -bob),
                        child: _Companion(id: id, size: mate, delayIndex: i),
                      ),
                    ),

                  // El dibujo, intacto. Sólo se mueve el contenedor.
                  Positioned.fill(
                    child: Transform.translate(
                      offset: t.offset + Offset(0, -14 * hop),
                      child: Transform.rotate(
                        angle: t.angle,
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scaleX: t.scaleX,
                          scaleY: t.scaleY,
                          alignment: Alignment.bottomCenter,
                          child: Image.asset(
                            'assets/mascota/karen.png',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Reacción manga junto a su cabeza, del lado de dentro: así
                  // no le tapa la cara ni se sale de la pantalla.
                  if (widget.emote != KarenEmote.none)
                    Positioned(
                      left: onLeft ? w * 0.62 : null,
                      right: onLeft ? null : w * 0.62,
                      top: -h * 0.06,
                      width: w * 0.8,
                      height: h * 0.2,
                      child: CustomPaint(painter: _EmotePainter(widget.emote, _idle.value)),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Un Pokémon que acompaña a Karen, con su pequeña entrada.
class _Companion extends StatefulWidget {
  final int id;
  final double size;
  final int delayIndex;

  const _Companion({required this.id, required this.size, required this.delayIndex});

  @override
  State<_Companion> createState() => _CompanionState();
}

class _CompanionState extends State<_Companion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 280 + widget.delayIndex * 160), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(
        scale: Curves.easeOutBack.transform(_c.value).clamp(0.0, 1.3),
        child: Opacity(opacity: _c.value.clamp(0.0, 1.0), child: child),
      ),
      child: ArtworkImage(id: widget.id, size: widget.size, placeholderColor: Colors.transparent),
    );
  }
}

/// Reacciones estilo manga, dibujadas a mano con la paleta del personaje
/// (tinta negra y rojo), para que peguen con su trazo.
class _EmotePainter extends CustomPainter {
  final KarenEmote emote;
  final double t;

  static const Color _ink = Color(0xFF1B1424);
  static const Color _red = Color(0xFFE3141B);

  _EmotePainter(this.emote, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.height;
    final center = Offset(size.width * 0.42, size.height * 0.5);
    switch (emote) {
      case KarenEmote.sparkle:
        _star(
          canvas,
          center + Offset(-unit * 0.22, -unit * 0.1),
          unit * 0.17 * _pulse(0),
          Colors.white,
        );
        _star(canvas, center + Offset(unit * 0.16, -unit * 0.3), unit * 0.22 * _pulse(0.3), _red);
        _star(
          canvas,
          center + Offset(unit * 0.3, unit * 0.12),
          unit * 0.12 * _pulse(0.6),
          Colors.white,
        );
      case KarenEmote.sweat:
        _drop(canvas, center + Offset(0, unit * (0.45 * t - 0.2)), unit * 0.2, 1 - t * 0.5);
      case KarenEmote.exclaim:
        _mark(canvas, center, unit * 0.52, '!');
      case KarenEmote.question:
        _mark(canvas, center, unit * 0.52, '?');
      case KarenEmote.idea:
        _bulb(canvas, center, unit * 0.34);
      case KarenEmote.thought:
        _thought(canvas, center, unit * 0.3);
      case KarenEmote.heart:
        _heart(canvas, center, unit * 0.2 * (1 + math.sin(t * math.pi * 2) * 0.12));
      case KarenEmote.notes:
        _note(canvas, center + Offset(0, -unit * 0.1 * t), unit * 0.16, _ink);
        _note(canvas, center + Offset(unit * 0.26, -unit * 0.3 * t), unit * 0.13, _red);
      case KarenEmote.zzz:
        for (var i = 0; i < 3; i++) {
          _z(
            canvas,
            center + Offset(unit * 0.12 * i, -unit * (0.22 * i + 0.3 * t)),
            unit * (0.1 + i * 0.03),
            (1 - t).clamp(0.3, 1.0),
          );
        }
      case KarenEmote.none:
        break;
    }
  }

  double _pulse(double phase) => 0.6 + 0.4 * math.sin((t + phase) * math.pi * 2).abs();

  Paint get _fill => Paint()..style = PaintingStyle.fill;
  Paint _stroke(double w, [Color c = _ink]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  /// Destello de cuatro puntas.
  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    const waist = 0.26;
    path.moveTo(c.dx, c.dy - r);
    for (final (dx, dy) in [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)]) {
      path.quadraticBezierTo(c.dx, c.dy, c.dx + dx * r * waist, c.dy + dy * r * waist);
      path.quadraticBezierTo(c.dx, c.dy, c.dx + dx * r, c.dy + dy * r);
    }
    path.close();
    canvas.drawPath(path, _fill..color = color);
    canvas.drawPath(path, _stroke(r * 0.16));
  }

  void _drop(Canvas canvas, Offset c, double r, double opacity) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..cubicTo(c.dx - r * 0.85, c.dy + r * 0.3, c.dx - r * 0.7, c.dy + r, c.dx, c.dy + r)
      ..cubicTo(c.dx + r * 0.7, c.dy + r, c.dx + r * 0.85, c.dy + r * 0.3, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, _fill..color = Colors.white.withValues(alpha: opacity));
    canvas.drawPath(path, _stroke(r * 0.18, _ink.withValues(alpha: opacity)));
  }

  /// Signo de admiración o interrogación, con su punto.
  void _mark(Canvas canvas, Offset c, double h, String glyph) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: h,
          height: 1,
          fontWeight: FontWeight.w900,
          color: _red,
          shadows: const [Shadow(color: _ink, blurRadius: 0, offset: Offset(2.5, 2.5))],
        ),
      ),
    )..layout();
    final scale = 0.85 + 0.15 * math.sin(t * math.pi * 2).abs();
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _bulb(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, _fill..color = Colors.white);
    canvas.drawCircle(c, r, _stroke(r * 0.2));
    final base = Rect.fromLTWH(c.dx - r * 0.38, c.dy + r * 0.72, r * 0.76, r * 0.5);
    canvas.drawRect(base, _fill..color = _ink);
    // Rayos que laten.
    final rays = _stroke(r * 0.18, _red.withValues(alpha: _pulse(0)));
    for (var i = 0; i < 5; i++) {
      final a = -math.pi * 0.9 + i * math.pi * 0.45 / 2;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * 1.35,
        c + Offset(math.cos(a), math.sin(a)) * r * 1.75,
        rays,
      );
    }
  }

  void _thought(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, _fill..color = Colors.white);
    canvas.drawCircle(c, r, _stroke(r * 0.16));
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.95), r * 0.32, _fill..color = Colors.white);
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.95), r * 0.32, _stroke(r * 0.12));
    for (var i = 0; i < 3; i++) {
      final up = math.sin((t + i * 0.2) * math.pi * 2) * r * 0.12;
      canvas.drawCircle(
        c + Offset((i - 1) * r * 0.45, up),
        r * 0.13,
        _fill..color = i == 2 ? _red : _ink,
      );
    }
  }

  void _heart(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 2, c.dy - r * 0.6, c.dx - r * 0.8, c.dy - r * 1.8, c.dx, c.dy - r * 0.55)
      ..cubicTo(c.dx + r * 0.8, c.dy - r * 1.8, c.dx + r * 2, c.dy - r * 0.6, c.dx, c.dy + r)
      ..close();
    canvas.drawPath(path, _fill..color = _red);
    canvas.drawPath(path, _stroke(r * 0.22));
  }

  void _note(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 1.5, height: r * 1.1),
      _fill..color = color,
    );
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.5, height: r * 1.1), _stroke(r * 0.2));
    canvas.drawLine(c + Offset(r * 0.7, 0), c + Offset(r * 0.7, -r * 2.2), _stroke(r * 0.26));
  }

  void _z(Canvas canvas, Offset c, double r, double opacity) {
    final p = _stroke(r * 0.26, _ink.withValues(alpha: opacity));
    canvas.drawLine(c, c + Offset(r, 0), p);
    canvas.drawLine(c + Offset(r, 0), c + Offset(0, r), p);
    canvas.drawLine(c + Offset(0, r), c + Offset(r, r), p);
  }

  @override
  bool shouldRepaint(_EmotePainter old) => old.t != t || old.emote != emote;
}

/// Globo de diálogo que escribe letra por letra, con su vocecita.
class _SpeechBubble extends StatefulWidget {
  final String text;
  final ({int index, int total})? tour;

  /// Flechita hacia lo señalado: arriba o abajo, a [x] del borde izquierdo.
  final ({bool up, double x})? tail;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;

  const _SpeechBubble({
    super.key,
    required this.text,
    required this.tour,
    required this.tail,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onDismiss,
  });

  @override
  State<_SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<_SpeechBubble> {
  /// Techo de duración: un texto largo se escribe más rápido en vez de aburrir.
  static const int _maxMs = 2600;

  /// Cuánto "pesa" cada signo: los puntos hacen respirar la frase.
  static const Map<String, int> _pauses = {'.': 4, '!': 4, '?': 4, '…': 4, ',': 3, ':': 3, ';': 3};

  static const Color _ink = Color(0xFF1B1424);
  static const Color _red = Color(0xFFE3141B);

  static final RegExp _voiced = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]');

  int _shown = 0;
  bool _done = false;
  Timer? _timer;
  int _lastBlip = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final chars = widget.text.characters.toList();
    final weight = chars.fold<int>(0, (a, c) => a + (_pauses[c] ?? 1));
    final step = (_maxMs / math.max(1, weight)).clamp(8.0, 34.0);

    void tick() {
      if (!mounted) return;
      if (_shown >= chars.length) return _finish();
      final c = chars[_shown];
      setState(() => _shown++);

      // Una sílaba cada ~70 ms basta para que suene a voz; una por letra
      // era el doble de trabajo para el mismo efecto.
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_voiced.hasMatch(c) && now - _lastBlip > 70) {
        _lastBlip = now;
        SoundService.instance.play(Sfx.voice, volume: 0.22);
      }
      _timer = Timer(Duration(milliseconds: (step * (_pauses[c] ?? 1)).round()), tick);
    }

    tick();
  }

  void _finish() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _shown = widget.text.characters.length;
      _done = true;
    });
  }

  void _onTap() {
    if (!_done) return _finish();
    if (widget.tour != null) {
      widget.onNext();
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final tail = widget.tail;
    final partial = widget.text.characters.take(_shown).toString();

    final body = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ink, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                KarenController.name,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: _red,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (tour != null)
                Text(
                  '${tour.index + 1}/${tour.total}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                )
              else
                const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 4),
          // El texto completo, invisible, reserva el tamaño final del globo:
          // así no crece a saltos mientras se escribe.
          Stack(
            children: [
              Opacity(opacity: 0, child: Text(widget.text, style: _textStyle)),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    partial,
                    style: _textStyle,
                    // Que el lector de pantalla reciba la frase entera.
                    semanticsLabel: widget.text,
                  ),
                ),
              ),
            ],
          ),
          if (tour != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34),
                    foregroundColor: AppColors.muted,
                  ),
                  child: const Text('Saltar', style: TextStyle(fontSize: 12.5)),
                ),
                const Spacer(),
                // Sólo la flecha: con la palabra entera los botones no cabían
                // en el globo de un teléfono.
                if (tour.index > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton.outlined(
                      onPressed: widget.onBack,
                      tooltip: 'Atrás',
                      iconSize: 18,
                      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: AppColors.line),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(
                    tour.index == tour.total - 1 ? '¡Listo!' : 'Siguiente',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: _onTap,
      child: tail == null
          ? body
          : Stack(
              clipBehavior: Clip.none,
              children: [
                body,
                Positioned(
                  left: tail.x - 11,
                  top: tail.up ? -11 : null,
                  bottom: tail.up ? null : -11,
                  width: 22,
                  height: 13,
                  child: CustomPaint(painter: _TailPainter(up: tail.up)),
                ),
              ],
            ),
    );
  }

  static const TextStyle _textStyle = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
    fontWeight: FontWeight.w500,
  );
}

/// Flechita del globo: blanca con el mismo borde de tinta, y la base metida
/// en el globo para tapar su borde en ese tramo.
class _TailPainter extends CustomPainter {
  final bool up;

  const _TailPainter({required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tip = up ? 0.0 : h;
    final base = up ? h : 0.0;
    final inner = up ? h + 2 : -2.0;

    final fill = Path()
      ..moveTo(0, base)
      ..lineTo(w / 2, tip)
      ..lineTo(w, base)
      ..lineTo(w, inner)
      ..lineTo(0, inner)
      ..close();
    canvas.drawPath(fill, Paint()..color = AppColors.surface);

    final edge = Path()
      ..moveTo(0, base)
      ..lineTo(w / 2, tip)
      ..lineTo(w, base);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF1B1424),
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.up != up;
}

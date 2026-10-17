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

/// Partes de la pantalla que Karen puede iluminar durante la guía.
///
/// Cada pantalla pone `KarenTargets.key('search')` (por ejemplo) en el widget
/// que quiere señalar; la guía lo busca por nombre.
class KarenTargets {
  KarenTargets._();

  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey key(String name) =>
      _keys.putIfAbsent(name, () => GlobalKey(debugLabel: 'karen-$name'));

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

  @override
  void initState() {
    super.initState();
    _karen.startIdleWatch();
  }

  @override
  void dispose() {
    _karen.stopIdleWatch();
    super.dispose();
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
                  target: _karen.inTour ? KarenTargets.rectOf(step?.target) : null,
                  // En la guía el globo no se cierra solo: lleva sus botones.
                  tour: _karen.inTour ? (index: _karen.tourIndex, total: _karen.tourLength) : null,
                  onNext: _karen.nextStep,
                  onSkip: _karen.endTour,
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

/// Coloca a Karen y su globo según el espacio disponible.
class _KarenStage extends StatelessWidget {
  final bool visible;
  final String text;
  final KarenMood mood;
  final KarenEmote emote;
  final List<int> companions;
  final Rect? target;
  final ({int index, int total})? tour;
  final VoidCallback onNext;
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
    required this.onSkip,
    required this.onDismiss,
    required this.stamp,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom + KarenInsets.bottom;
    final layout = Layout(media);
    final isTour = tour != null;

    // En la guía se ve entera y centrada; para un consejo suelto se asoma por
    // el costado, más discreta.
    final height = layout.karenHeight(big: isTour);
    final width = height * _karenAspect;
    final visibleFraction = isTour ? _tourVisibleFraction : _tipVisibleFraction;
    final visibleHeight = height * visibleFraction;
    final hidden = height - visibleHeight;

    final bubble = _SpeechBubble(
      key: ValueKey(stamp),
      text: text,
      tour: tour,
      onNext: onNext,
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

          if (isTour) ...[
            // Centrada, con el globo encima: se le ve el dibujo completo.
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset - hidden,
              height: height,
              child: _SlideUp(
                visible: visible,
                distance: visibleHeight + 40,
                child: Center(
                  child: SizedBox(width: width, height: height, child: _figure(centred: true)),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              // El globo va justo encima de su cabeza, sin taparle la cara.
              bottom: bottomInset + visibleHeight * 0.98,
              child: _SlideUp(
                visible: visible,
                distance: 24,
                delayed: true,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: bubble,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Consejo suelto: pegada al borde, sin salirse de la pantalla.
            Positioned(
              left: 4,
              bottom: bottomInset - hidden,
              width: width,
              height: height,
              child: _SlideUp(
                visible: visible,
                distance: visibleHeight + 40,
                child: _figure(centred: false),
              ),
            ),
            Positioned(
              left: width * 1.45,
              right: 12,
              bottom: bottomInset + visibleHeight * 0.42,
              child: _SlideUp(
                visible: visible,
                distance: 24,
                delayed: true,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: bubble,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _figure({required bool centred}) => _KarenFigure(
    mood: mood,
    emote: emote,
    companions: companions,
    stamp: stamp,
    // Pegada al borde izquierdo, los acompañantes van todos a su derecha
    // para que ninguno se salga de la pantalla.
    companionsBothSides: centred,
    onTap: tour != null ? onNext : onDismiss,
  );
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
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(begin: hole, end: hole),
      duration: const Duration(milliseconds: 320),
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
/// el ánimo, y a los costados la acompañan Pokémon que flotan.
class _KarenFigure extends StatefulWidget {
  final KarenMood mood;
  final KarenEmote emote;
  final List<int> companions;
  final int stamp;
  final bool companionsBothSides;
  final VoidCallback onTap;

  const _KarenFigure({
    required this.mood,
    required this.emote,
    required this.companions,
    required this.stamp,
    required this.companionsBothSides,
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

  @override
  void didUpdateWidget(covariant _KarenFigure old) {
    super.didUpdateWidget(old);
    if (old.stamp != widget.stamp || old.mood != widget.mood) _gesture.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _gesture.dispose();
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
        return (
          offset: Offset.zero,
          angle: 0.035 * g,
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

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _gesture]),
            builder: (context, _) {
              final t = _transform(
                Curves.easeOut.transform(_gesture.value),
                Curves.easeInOut.transform(_idle.value),
              );
              final bob = math.sin(_idle.value * math.pi * 2) * 5;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Acompañantes: a sus costados, flotando a destiempo.
                  // Si está pegada al borde, todos van a su derecha para que
                  // ninguno quede fuera de la pantalla.
                  for (final (i, id) in widget.companions.take(3).indexed)
                    Positioned(
                      left: widget.companionsBothSides && i.isEven ? -mate * 0.62 : null,
                      right: widget.companionsBothSides && i.isEven ? null : -mate * 0.62,
                      bottom: h * (0.26 + i * 0.2),
                      child: Transform.translate(
                        offset: Offset(0, i.isEven ? bob : -bob),
                        child: _Companion(id: id, size: mate, delayIndex: i),
                      ),
                    ),

                  // El dibujo, intacto. Sólo se mueve el contenedor.
                  Positioned.fill(
                    child: Transform.translate(
                      offset: t.offset,
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

                  // Reacción manga junto a su cabeza: a la izquierda cuando
                  // está centrada; pegada a la orilla se saldría de la
                  // pantalla, así que ahí va encima y hacia la derecha.
                  if (widget.emote != KarenEmote.none)
                    Positioned(
                      left: widget.companionsBothSides ? -w * 0.34 : w * 0.38,
                      top: widget.companionsBothSides ? h * 0.02 : -h * 0.3,
                      width: w * 0.9,
                      height: h * 0.3,
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
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onDismiss;

  const _SpeechBubble({
    super.key,
    required this.text,
    required this.tour,
    required this.onNext,
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

      final now = DateTime.now().millisecondsSinceEpoch;
      if (RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]').hasMatch(c) && now - _lastBlip > 42) {
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
    final partial = widget.text.characters.take(_shown).toString();

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1B1424), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
          ],
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
                    color: Color(0xFFE3141B),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 34),
                      foregroundColor: AppColors.muted,
                    ),
                    child: const Text('Saltar', style: TextStyle(fontSize: 12.5)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: widget.onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE3141B),
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

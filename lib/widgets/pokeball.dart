import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pokébola vectorial dibujada a mano (se usa como marca de agua y en el splash).
class PokeballPainter extends CustomPainter {
  final Color color;
  final Color? bottomColor;
  final double strokeRatio;

  PokeballPainter({required this.color, this.bottomColor, this.strokeRatio = 0.09});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = r * strokeRatio;
    final rect = Rect.fromCircle(center: c, radius: r);

    final top = Paint()..color = color;
    final bottom = Paint()..color = bottomColor ?? color;

    // Mitades con hueco en la franja central y en el botón.
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(rect)
      ..addOval(Rect.fromCircle(center: c, radius: r * 0.36));
    final band = Rect.fromCenter(center: c, width: size.width * 2, height: stroke * 2);

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left - 1, rect.top - 1, rect.right + 1, band.top));
    canvas.drawPath(ring, top);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left - 1, band.bottom, rect.right + 1, rect.bottom + 1));
    canvas.drawPath(ring, bottom);
    canvas.restore();

    canvas.drawCircle(c, r * 0.22, top);
  }

  @override
  bool shouldRepaint(PokeballPainter old) =>
      old.color != color || old.bottomColor != bottomColor || old.strokeRatio != strokeRatio;
}

class Pokeball extends StatelessWidget {
  final double size;
  final Color color;
  final Color? bottomColor;

  const Pokeball({super.key, required this.size, required this.color, this.bottomColor});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: PokeballPainter(color: color, bottomColor: bottomColor),
    ),
  );
}

/// Pokébola que gira lentamente de forma continua.
class SpinningPokeball extends StatefulWidget {
  final double size;
  final Color color;
  final Duration period;
  final bool animate;

  const SpinningPokeball({
    super.key,
    required this.size,
    required this.color,
    this.period = const Duration(seconds: 18),
    this.animate = true,
  });

  @override
  State<SpinningPokeball> createState() => _SpinningPokeballState();
}

class _SpinningPokeballState extends State<SpinningPokeball> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant SpinningPokeball old) {
    super.didUpdateWidget(old);
    if (widget.animate == old.animate) return;
    widget.animate ? _c.repeat() : _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: Transform.rotate(
      angle: -math.pi / 8,
      child: Pokeball(size: widget.size, color: widget.color),
    ),
  );
}

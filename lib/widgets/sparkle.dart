import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ráfaga de destellos que se dispara al activar la variante shiny.
///
/// Se controla desde fuera incrementando [trigger]: cada valor nuevo
/// reinicia la animación con una semilla distinta.
class SparkleBurst extends StatefulWidget {
  final int trigger;
  final Color color;
  final int particles;

  const SparkleBurst({
    super.key,
    required this.trigger,
    this.color = const Color(0xFFFFE57F),
    this.particles = 26,
  });

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late List<_Spark> _sparks = _Spark.generate(widget.particles, widget.trigger);

  @override
  void didUpdateWidget(covariant SparkleBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _sparks = _Spark.generate(widget.particles, widget.trigger);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => _c.isDismissed
              ? const SizedBox.expand()
              : CustomPaint(
                  painter: _SparkPainter(_sparks, _c.value, widget.color),
                  size: Size.infinite,
                ),
        ),
      ),
    );
  }
}

class _Spark {
  final double angle, distance, size, delay, spin;

  const _Spark(this.angle, this.distance, this.size, this.delay, this.spin);

  static List<_Spark> generate(int count, int seed) {
    final rnd = math.Random(seed * 131 + 17);
    return List.generate(count, (i) {
      return _Spark(
        (i / count) * math.pi * 2 + rnd.nextDouble() * 0.5,
        0.25 + rnd.nextDouble() * 0.6,
        4 + rnd.nextDouble() * 9,
        rnd.nextDouble() * 0.25,
        rnd.nextDouble() * math.pi,
      );
    });
  }
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double t;
  final Color color;

  _SparkPainter(this.sparks, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.shortestSide * 0.75;

    for (final s in sparks) {
      final local = ((t - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final fade = local < 0.55 ? 1.0 : 1 - (local - 0.55) / 0.45;
      final offset =
          center + Offset(math.cos(s.angle), math.sin(s.angle)) * (eased * s.distance * reach);

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(s.spin + eased * 2);
      _drawStar(
        canvas,
        s.size * (1 - eased * 0.35),
        Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0) * 0.95),
      );
      canvas.restore();
    }
  }

  /// Destello de cuatro puntas (estilo "sparkle" de Pokémon).
  void _drawStar(Canvas canvas, double r, Paint paint) {
    final path = Path();
    const waist = 0.26;
    path.moveTo(0, -r);
    path.quadraticBezierTo(0, 0, r * waist, -r * waist);
    path.quadraticBezierTo(0, 0, r, 0);
    path.quadraticBezierTo(0, 0, r * waist, r * waist);
    path.quadraticBezierTo(0, 0, 0, r);
    path.quadraticBezierTo(0, 0, -r * waist, r * waist);
    path.quadraticBezierTo(0, 0, -r, 0);
    path.quadraticBezierTo(0, 0, -r * waist, -r * waist);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.sparks != sparks;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pokeball.dart';

/// Fondo con vida: degradado del color del tipo y orbes luminosos que flotan.
///
/// Un único [AnimationController] alimenta un [CustomPainter] aislado en un
/// [RepaintBoundary], así la animación no repinta el contenido de la pantalla.
class AmbientBackground extends StatefulWidget {
  final Color color;
  final Widget child;
  final int orbCount;

  /// Con `false` el fondo se queda quieto. El `PageView` de las fichas
  /// mantiene vivas las vecinas: si todas animaran, serían tres repintados a
  /// pantalla completa por fotograma justo mientras se desliza.
  final bool animate;

  const AmbientBackground({
    super.key,
    required this.color,
    required this.child,
    this.orbCount = 10,
    this.animate = true,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final List<_Orb> _orbs = _Orb.generate(widget.orbCount);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AmbientBackground old) {
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
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(widget.color, Colors.white, 0.04)!,
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.28)!,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) =>
                CustomPaint(painter: _OrbPainter(_orbs, _c.value), size: Size.infinite),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb {
  final double x, y, radius, speed, phase, drift, opacity;
  final bool isPokeball;

  const _Orb(
    this.x,
    this.y,
    this.radius,
    this.speed,
    this.phase,
    this.drift,
    this.opacity,
    this.isPokeball,
  );

  static List<_Orb> generate(int count) {
    final rnd = math.Random(7);
    return List.generate(count, (i) {
      return _Orb(
        rnd.nextDouble(),
        rnd.nextDouble(),
        0.03 + rnd.nextDouble() * 0.13,
        0.5 + rnd.nextDouble() * 1.6,
        rnd.nextDouble() * math.pi * 2,
        0.04 + rnd.nextDouble() * 0.1,
        0.04 + rnd.nextDouble() * 0.09,
        i % 4 == 0,
      );
    });
  }
}

class _OrbPainter extends CustomPainter {
  final List<_Orb> orbs;
  final double t;

  _OrbPainter(this.orbs, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    for (final orb in orbs) {
      final angle = t * math.pi * 2 * orb.speed + orb.phase;
      final center = Offset(
        (orb.x + math.cos(angle) * orb.drift) * size.width,
        (orb.y + math.sin(angle * 0.8) * orb.drift) * size.height,
      );
      final r = orb.radius * unit;
      final color = Colors.white.withValues(alpha: orb.opacity);

      if (orb.isPokeball) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle * 0.35);
        canvas.translate(-r, -r);
        PokeballPainter(color: color).paint(canvas, Size(r * 2, r * 2));
        canvas.restore();
      } else {
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: center, radius: r)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

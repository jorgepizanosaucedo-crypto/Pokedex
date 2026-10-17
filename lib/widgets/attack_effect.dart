import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Efectos de ataque del combate, uno por tipo, dibujados a mano.
///
/// [t] va de 0 a 1: hasta 0.55 el ataque viaja de [from] a [to] (si es a
/// distancia) y después estalla sobre el objetivo. Los físicos no viajan:
/// el Pokémon embiste y sólo se ve el impacto.
class AttackEffectPainter extends CustomPainter {
  final String type;
  final double t;
  final Offset from;
  final Offset to;
  final bool physical;

  /// Tamaño de referencia del objetivo, para escalar las partículas.
  final double scale;

  AttackEffectPainter({
    required this.type,
    required this.t,
    required this.from,
    required this.to,
    required this.physical,
    required this.scale,
  });

  static const double _travel = 0.55;

  double get _impact => ((t - _travel) / (1 - _travel)).clamp(0.0, 1.0);
  double get _flight => (t / _travel).clamp(0.0, 1.0);

  Offset _along(double k, {double arc = 0}) {
    final p = Offset.lerp(from, to, k)!;
    return p + Offset(0, -math.sin(k * math.pi) * arc);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    switch (type) {
      case 'fire':
        _fire(canvas);
      case 'water':
        _water(canvas);
      case 'electric':
        _electric(canvas, size);
      case 'grass':
        _leaves(canvas, const Color(0xFF43A047), const Color(0xFF9CCC65));
      case 'ice':
        _ice(canvas);
      case 'fighting':
        _punch(canvas, const Color(0xFFFF7043));
      case 'poison':
        _bubbles(canvas, const Color(0xFFAB47BC), const Color(0xFFE1BEE7));
      case 'ground':
        _ground(canvas);
      case 'flying':
        _gust(canvas);
      case 'psychic':
        _psychic(canvas);
      case 'bug':
        _swarm(canvas);
      case 'rock':
        _rocks(canvas);
      case 'ghost':
        _shadowBall(canvas);
      case 'dragon':
        _dragon(canvas);
      case 'dark':
        _slashes(canvas, const Color(0xFF311B92), dark: true);
      case 'steel':
        _slashes(canvas, const Color(0xFFB0BEC5), dark: false);
      case 'fairy':
        _fairy(canvas);
      default:
        _punch(canvas, Colors.white);
    }
  }

  // ------------------------------------------------------------ ayudantes

  void _glow(Canvas canvas, Offset c, double r, Color color, [double alpha = 1]) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _star(Canvas canvas, Offset c, double r, int points, Paint paint, {double rot = 0}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = rot + i * math.pi / points;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  /// Estallido genérico en el objetivo.
  void _burst(Canvas canvas, Color color, {int count = 12, double reach = 1}) {
    final k = _impact;
    if (k <= 0) return;
    _glow(canvas, to, scale * (0.3 + k * 0.5), color, (1 - k) * 0.8);
    final rand = math.Random(type.hashCode);
    for (var i = 0; i < count; i++) {
      final a = i / count * math.pi * 2 + rand.nextDouble() * 0.4;
      final d = scale * reach * (0.15 + 0.55 * Curves.easeOut.transform(k)) * (0.7 + rand.nextDouble() * 0.6);
      canvas.drawCircle(
        to + Offset(math.cos(a), math.sin(a)) * d,
        scale * 0.035 * (1 - k) + 1,
        Paint()..color = color.withValues(alpha: 1 - k),
      );
    }
  }

  // ---------------------------------------------------------------- tipos

  void _fire(Canvas canvas) {
    if (!physical && t < _travel) {
      for (var i = 0; i < 7; i++) {
        final k = (_flight - i * 0.06).clamp(0.0, 1.0);
        final p = _along(Curves.easeIn.transform(k), arc: scale * 0.3);
        _glow(canvas, p, scale * (0.16 - i * 0.015), const Color(0xFFFF6D00));
        _glow(canvas, p, scale * (0.08 - i * 0.008), const Color(0xFFFFEA00));
      }
    }
    final k = _impact;
    if (k <= 0) return;
    final rand = math.Random(3);
    for (var i = 0; i < 16; i++) {
      final x = (rand.nextDouble() - 0.5) * scale * 0.9;
      final rise = Curves.easeOut.transform(k) * scale * (0.3 + rand.nextDouble() * 0.5);
      final p = to + Offset(x * (0.5 + k * 0.6), scale * 0.25 - rise);
      final r = scale * (0.12 + rand.nextDouble() * 0.08) * (1 - k * 0.7);
      _glow(canvas, p, r, const Color(0xFFFF3D00), 1 - k);
      _glow(canvas, p, r * 0.5, const Color(0xFFFFEB3B), 1 - k);
    }
  }

  void _water(Canvas canvas) {
    if (!physical && t < _travel) {
      final paint = Paint()..color = const Color(0xFF29B6F6);
      for (var i = 0; i < 12; i++) {
        final k = (_flight - i * 0.04).clamp(0.0, 1.0);
        if (k <= 0) continue;
        final p = _along(k, arc: scale * 0.15) + Offset(0, math.sin(i * 1.7 + t * 20) * 4);
        canvas.drawCircle(p, scale * 0.06, paint);
        canvas.drawCircle(
          p + Offset(-scale * 0.015, -scale * 0.02),
          scale * 0.018,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      }
    }
    final k = _impact;
    if (k <= 0) return;
    for (var i = 0; i < 3; i++) {
      final kk = (k - i * 0.15).clamp(0.0, 1.0);
      canvas.drawCircle(
        to,
        scale * (0.15 + kk * 0.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * (1 - kk) + 1
          ..color = const Color(0xFF4FC3F7).withValues(alpha: 1 - kk),
      );
    }
    final rand = math.Random(5);
    for (var i = 0; i < 14; i++) {
      final a = -math.pi * (0.1 + rand.nextDouble() * 0.8);
      final v = scale * (0.4 + rand.nextDouble() * 0.5);
      final p = to + Offset(math.cos(a) * v * k, math.sin(a) * v * k + scale * 0.9 * k * k);
      canvas.drawCircle(p, scale * 0.035 * (1 - k) + 1, Paint()..color = const Color(0xFF29B6F6));
    }
  }

  void _electric(Canvas canvas, Size size) {
    final flicker = (t * 24).floor();
    final rand = math.Random(flicker);
    if (t > 0.1 && t < 0.9) {
      for (var b = 0; b < 2; b++) {
        final path = Path();
        var p = Offset(to.dx + (rand.nextDouble() - 0.5) * scale, 0);
        path.moveTo(p.dx, p.dy);
        const steps = 9;
        for (var i = 1; i <= steps; i++) {
          final target = Offset.lerp(Offset(p.dx, 0), to, i / steps)!;
          p = Offset(target.dx + (rand.nextDouble() - 0.5) * scale * 0.5, to.dy * i / steps);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.miter
            ..color = Colors.white,
        );
      }
      if (flicker.isEven) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.18),
        );
      }
    }
    _burst(canvas, const Color(0xFFFFEB3B), count: 10);
  }

  void _leaves(Canvas canvas, Color dark, Color light) {
    final rand = math.Random(9);
    final count = 9;
    for (var i = 0; i < count; i++) {
      final delay = i * 0.04;
      final k = ((t - delay) / 0.75).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final swirl = Offset(math.cos(k * 9 + i), math.sin(k * 9 + i)) * scale * 0.18 * (1 - k);
      final p = (physical ? to + Offset((rand.nextDouble() - 0.5) * scale, -scale * (1 - k)) : _along(k, arc: scale * 0.4)) + swirl;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(k * 12 + i);
      final leaf = Path()
        ..moveTo(0, -scale * 0.08)
        ..quadraticBezierTo(scale * 0.06, 0, 0, scale * 0.08)
        ..quadraticBezierTo(-scale * 0.06, 0, 0, -scale * 0.08);
      canvas.drawPath(leaf, Paint()..color = i.isEven ? dark : light);
      canvas.restore();
    }
    _burst(canvas, light, count: 8);
  }

  void _ice(Canvas canvas) {
    if (!physical && t < _travel) {
      for (var i = 0; i < 6; i++) {
        final k = (_flight - i * 0.07).clamp(0.0, 1.0);
        if (k <= 0) continue;
        final p = _along(k) + Offset(0, (i - 3) * 5.0);
        final dir = (to - from).direction;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(dir);
        final shard = Path()
          ..moveTo(scale * 0.12, 0)
          ..lineTo(-scale * 0.06, scale * 0.04)
          ..lineTo(-scale * 0.06, -scale * 0.04)
          ..close();
        canvas.drawPath(shard, Paint()..color = const Color(0xFFB2EBF2));
        canvas.drawPath(
          shard,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white,
        );
        canvas.restore();
      }
    }
    final k = _impact;
    if (k <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4 * (1 - k) + 1.5
      ..color = Colors.white.withValues(alpha: 1 - k * 0.8);
    final r = scale * (0.2 + 0.4 * Curves.easeOut.transform(k));
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + k;
      final end = to + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(to, end, paint);
      final mid = to + Offset(math.cos(a), math.sin(a)) * r * 0.6;
      canvas.drawLine(mid, mid + Offset(math.cos(a + 0.6), math.sin(a + 0.6)) * r * 0.25, paint);
      canvas.drawLine(mid, mid + Offset(math.cos(a - 0.6), math.sin(a - 0.6)) * r * 0.25, paint);
    }
    _glow(canvas, to, scale * 0.6, const Color(0xFF80DEEA), (1 - k) * 0.6);
  }

  void _punch(Canvas canvas, Color color) {
    final k = _impact;
    if (k <= 0) return;
    // Líneas de velocidad hacia el objetivo.
    final lines = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: (1 - k) * 0.8);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(to + dir * scale * (0.5 + k * 0.3), to + dir * scale * (0.75 + k * 0.4), lines);
    }
    final r = scale * (0.25 + 0.3 * Curves.elasticOut.transform(k.clamp(0.0, 0.6) / 0.6));
    _star(canvas, to, r, 8, Paint()..color = color.withValues(alpha: 1 - k), rot: 0.3);
    _star(
      canvas,
      to,
      r * 0.6,
      8,
      Paint()..color = const Color(0xFFFFF176).withValues(alpha: 1 - k),
      rot: 0.1,
    );
  }

  void _bubbles(Canvas canvas, Color color, Color light) {
    if (!physical && t < _travel) {
      final p = _along(Curves.easeIn.transform(_flight), arc: scale * 0.5);
      _glow(canvas, p, scale * 0.2, color);
      canvas.drawCircle(p, scale * 0.09, Paint()..color = color);
    }
    final k = _impact;
    if (k <= 0) return;
    final rand = math.Random(11);
    for (var i = 0; i < 14; i++) {
      final kk = (k - rand.nextDouble() * 0.3).clamp(0.0, 1.0);
      final p = to + Offset((rand.nextDouble() - 0.5) * scale, scale * 0.3 - kk * scale * 0.9);
      final r = scale * (0.04 + rand.nextDouble() * 0.06) * (kk < 0.85 ? 1 : (1 - kk) / 0.15);
      canvas.drawCircle(p, r, Paint()..color = color.withValues(alpha: 0.85));
      canvas.drawCircle(
        p + Offset(-r * 0.3, -r * 0.3),
        r * 0.3,
        Paint()..color = light.withValues(alpha: 0.9),
      );
    }
  }

  void _ground(Canvas canvas) {
    final k = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
    if (k <= 0) return;
    final rand = math.Random(13);
    _glow(canvas, to + Offset(0, scale * 0.35), scale * 0.8, const Color(0xFF8D6E63), (1 - k) * 0.7);
    for (var i = 0; i < 12; i++) {
      final x = (rand.nextDouble() - 0.5) * scale * 1.2;
      final v = scale * (0.6 + rand.nextDouble() * 0.6);
      final p = to + Offset(x, scale * 0.4 - v * k + scale * 1.4 * k * k);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(k * 6 + i);
      final s = scale * (0.05 + rand.nextDouble() * 0.06);
      canvas.drawPath(
        Path()
          ..moveTo(-s, s)
          ..lineTo(0, -s)
          ..lineTo(s, s * 0.6)
          ..close(),
        Paint()..color = i.isEven ? const Color(0xFF795548) : const Color(0xFFA1887F),
      );
      canvas.restore();
    }
  }

  void _gust(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < 3; i++) {
      final k = ((t - i * 0.1) / 0.7).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final p = physical ? to : _along(k);
      final r = scale * (0.18 + i * 0.05 + (physical ? k * 0.4 : 0));
      paint.color = Colors.white.withValues(alpha: (1 - k) * 0.9);
      canvas.drawArc(Rect.fromCircle(center: p, radius: r), -1.2 + k * 3, 2.2, false, paint);
    }
    _burst(canvas, Colors.white, count: 8);
  }

  void _psychic(Canvas canvas) {
    final colors = [const Color(0xFFF06292), const Color(0xFFBA68C8)];
    for (var i = 0; i < 4; i++) {
      final k = ((t - i * 0.12) / 0.7).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final c = physical ? to : Offset.lerp(from, to, Curves.easeInOut.transform(k))!;
      canvas.drawCircle(
        c,
        scale * (0.15 + k * 0.45),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * (1 - k) + 1
          ..color = colors[i % 2].withValues(alpha: 1 - k),
      );
    }
    final k = _impact;
    if (k > 0) {
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: to,
            width: scale * (0.6 + i * 0.3) * (1 + math.sin(k * math.pi * 4) * 0.1),
            height: scale * (0.3 + i * 0.15),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = colors[i % 2].withValues(alpha: (1 - k) * 0.8),
        );
      }
    }
  }

  void _swarm(Canvas canvas) {
    final rand = math.Random(17);
    for (var i = 0; i < 16; i++) {
      final k = ((t - rand.nextDouble() * 0.25) / 0.75).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final jitter = Offset(math.sin(k * 30 + i), math.cos(k * 26 + i)) * scale * 0.12;
      final p = (physical ? to + Offset((rand.nextDouble() - 0.5) * scale, 0) * (1 - k) : _along(k)) + jitter;
      canvas.drawCircle(p, scale * 0.03, Paint()..color = const Color(0xFF7CB342));
      canvas.drawCircle(p + Offset(scale * 0.025, -scale * 0.02), scale * 0.018,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    _burst(canvas, const Color(0xFFAED581), count: 8);
  }

  void _rocks(Canvas canvas) {
    final rand = math.Random(19);
    for (var i = 0; i < 6; i++) {
      final k = ((t - i * 0.07) / 0.6).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final x = to.dx + (rand.nextDouble() - 0.5) * scale * 0.9;
      final landed = k >= 1;
      final y = landed ? to.dy + scale * 0.1 : -scale + (to.dy + scale) * Curves.easeIn.transform(k);
      final s = scale * (0.09 + rand.nextDouble() * 0.07);
      final alpha = landed ? (1 - _impact).clamp(0.0, 1.0) : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i * 0.8 + k * 2);
      final path = Path();
      for (var j = 0; j < 6; j++) {
        final a = j * math.pi / 3;
        final rr = s * (0.8 + (j.isEven ? 0.25 : 0));
        final p = Offset(math.cos(a), math.sin(a)) * rr;
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = const Color(0xFF8D7B5A).withValues(alpha: alpha));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF5D4E37).withValues(alpha: alpha),
      );
      canvas.restore();
    }
    _burst(canvas, const Color(0xFFBCAAA4), count: 10);
  }

  void _shadowBall(Canvas canvas) {
    if (!physical && t < _travel) {
      final p = _along(Curves.easeInOut.transform(_flight), arc: scale * 0.2);
      final wobble = 1 + math.sin(t * 40) * 0.08;
      _glow(canvas, p, scale * 0.32 * wobble, const Color(0xFF7E57C2));
      canvas.drawCircle(p, scale * 0.14 * wobble, Paint()..color = const Color(0xFF311B92));
    }
    final k = _impact;
    if (k <= 0) return;
    final rand = math.Random(23);
    for (var i = 0; i < 10; i++) {
      final a = rand.nextDouble() * math.pi * 2;
      final d = scale * 0.5 * k * (0.5 + rand.nextDouble());
      _glow(canvas, to + Offset(math.cos(a), math.sin(a)) * d, scale * 0.2 * (1 - k * 0.5),
          const Color(0xFF4527A0), (1 - k) * 0.8);
    }
  }

  void _dragon(Canvas canvas) {
    if (!physical && t < _travel + 0.1) {
      final colors = [const Color(0xFF7C4DFF), const Color(0xFF00B0FF)];
      for (var strand = 0; strand < 2; strand++) {
        for (var i = 0; i < 14; i++) {
          final k = (_flight - i * 0.03).clamp(0.0, 1.0);
          if (k <= 0) continue;
          final base = _along(k);
          final dir = (to - from);
          final normal = Offset(-dir.dy, dir.dx) / (dir.distance == 0 ? 1 : dir.distance);
          final p = base + normal * math.sin(k * 14 + strand * math.pi) * scale * 0.15;
          canvas.drawCircle(p, scale * 0.05 * (1 - i / 14), Paint()..color = colors[strand]);
        }
      }
    }
    _burst(canvas, const Color(0xFF7C4DFF), count: 14, reach: 1.2);
  }

  void _slashes(Canvas canvas, Color color, {required bool dark}) {
    for (var i = 0; i < 3; i++) {
      final k = ((t - 0.2 - i * 0.1) / 0.45).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final fade = (1 - ((t - 0.75) / 0.25).clamp(0.0, 1.0));
      final offset = Offset((i - 1) * scale * 0.22, (i - 1) * scale * 0.08);
      final start = to + offset + Offset(-scale * 0.45, -scale * 0.45);
      final end = to + offset + Offset(scale * 0.45, scale * 0.45);
      final cur = Offset.lerp(start, end, Curves.easeOut.transform(k))!;
      canvas.drawLine(
        start,
        cur,
        Paint()
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: fade),
      );
      canvas.drawLine(
        start,
        cur,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = (dark ? const Color(0xFFB39DDB) : Colors.white).withValues(alpha: fade),
      );
    }
    if (!dark && _impact > 0) {
      _star(canvas, to, scale * 0.3 * (1 - _impact * 0.5), 4,
          Paint()..color = Colors.white.withValues(alpha: 1 - _impact));
    }
  }

  void _fairy(Canvas canvas) {
    final rand = math.Random(29);
    for (var i = 0; i < 12; i++) {
      final k = ((t - rand.nextDouble() * 0.3) / 0.7).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final p = physical
          ? to + Offset(math.cos(i * 0.52 + k * 4), math.sin(i * 0.52 + k * 4)) * scale * 0.5 * (1 - k)
          : _along(k, arc: scale * (0.2 + rand.nextDouble() * 0.4)) +
                Offset(0, (rand.nextDouble() - 0.5) * scale * 0.4);
      final color = i.isEven ? const Color(0xFFF48FB1) : const Color(0xFFFFF59D);
      _star(canvas, p, scale * 0.07, 4, Paint()..color = color, rot: k * 6);
    }
    _burst(canvas, const Color(0xFFF8BBD0), count: 12);
  }

  @override
  bool shouldRepaint(covariant AttackEffectPainter old) =>
      old.t != t || old.type != type || old.from != from || old.to != to;
}

/// Flechas que suben (característica en alza) o bajan (en baja), y
/// chispas verdes para la curación.
class StatEffectPainter extends CustomPainter {
  final double t;
  final Offset center;
  final double scale;

  /// `1` sube, `-1` baja, `0` cura.
  final int direction;

  StatEffectPainter({
    required this.t,
    required this.center,
    required this.scale,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final rand = math.Random(31);
    final color = switch (direction) {
      1 => const Color(0xFFFF7043),
      -1 => const Color(0xFF42A5F5),
      _ => const Color(0xFF66BB6A),
    };
    canvas.drawCircle(
      center,
      scale * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35 * math.sin(t * math.pi)), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: scale * 0.7)),
    );
    for (var i = 0; i < 10; i++) {
      final k = ((t - rand.nextDouble() * 0.4) / 0.6).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final x = center.dx + (rand.nextDouble() - 0.5) * scale;
      final y = direction == -1
          ? center.dy - scale * 0.5 + k * scale
          : center.dy + scale * 0.5 - k * scale;
      final alpha = math.sin(k * math.pi);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: alpha);
      final s = scale * 0.06;
      if (direction == 0) {
        canvas.drawLine(Offset(x - s, y), Offset(x + s, y), paint);
        canvas.drawLine(Offset(x, y - s), Offset(x, y + s), paint);
      } else {
        final d = direction == 1 ? -1.0 : 1.0;
        canvas.drawLine(Offset(x - s, y - d * s * 0.6), Offset(x, y + d * s * 0.4), paint);
        canvas.drawLine(Offset(x, y + d * s * 0.4), Offset(x + s, y - d * s * 0.6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StatEffectPainter old) => old.t != t || old.direction != direction;
}

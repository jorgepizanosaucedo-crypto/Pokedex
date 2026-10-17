import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pokemon.dart';
import '../theme/app_theme.dart';

/// Máximo real de una estadística base en la PokeAPI (Blissey tiene 255 de PS).
/// Se usa como escala fija: así ningún valor se recorta ni se exageran los bajos.
const double kStatMax = 255;

const Map<String, String> _shortLabels = {
  'hp': 'PS',
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'At. Esp.',
  'special-defense': 'Def. Esp.',
  'speed': 'Vel',
};

/// Anima de 0 al valor dado, con retardo opcional (para escalonar las barras).
class AnimatedValue extends StatefulWidget {
  final double value;
  final Duration delay;
  final Duration duration;
  final Widget Function(double t) builder;

  const AnimatedValue({
    super.key,
    required this.value,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 750),
  });

  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, _) => widget.builder(widget.value * _anim.value),
  );
}

/// Barras horizontales animadas. Una sola serie (este Pokémon), con nombre y
/// valor siempre visibles: la lectura nunca depende sólo del color.
class StatBars extends StatelessWidget {
  final List<PokemonStat> stats;
  final Color color;

  const StatBars({super.key, required this.stats, required this.color});

  @override
  Widget build(BuildContext context) {
    final fill = readableOn(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, stat) in stats.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    kStatLabels[stat.name] ?? capitalize(stat.name),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${stat.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _Track(
                    value: stat.value / kStatMax,
                    color: fill,
                    delay: Duration(milliseconds: 55 * i),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Escala 0 – ${kStatMax.toInt()}, el máximo posible de una estadística base.',
          style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}

/// Carril recesivo + relleno con extremos redondeados anclado al origen.
class _Track extends StatelessWidget {
  final double value;
  final Color color;
  final Duration delay;

  const _Track({required this.value, required this.color, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: AnimatedValue(
        value: value,
        delay: delay,
        builder: (t) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: t.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Radar hexagonal de las seis estadísticas base: polígono del color del tipo
/// sobre una rejilla recesiva, con cada eje etiquetado y su valor a la vista.
class StatRadar extends StatefulWidget {
  final List<PokemonStat> stats;
  final Color color;

  const StatRadar({super.key, required this.stats, required this.color});

  @override
  State<StatRadar> createState() => _StatRadarState();
}

class _StatRadarState extends State<StatRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void didUpdateWidget(covariant StatRadar old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.12,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _RadarPainter(
              stats: widget.stats,
              color: readableOn(widget.color),
              progress: Curves.easeOutCubic.transform(_c.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<PokemonStat> stats;
  final Color color;
  final double progress;

  _RadarPainter({required this.stats, required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (stats.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    // Margen fijo para las etiquetas: antes iban a un 25 % más del radio y,
    // con el radar grande, la de arriba quedaba cortada por las pestañas.
    const labelGap = 22.0;
    final radius = math.min(size.width, size.height) / 2 - 40;
    if (radius <= 0) return;
    final n = stats.length;

    Offset vertex(int i, double factor) {
      final angle = -math.pi / 2 + (i / n) * math.pi * 2;
      return center + Offset(math.cos(angle), math.sin(angle)) * (radius * factor);
    }

    // Rejilla recesiva: anillos de referencia y radios.
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.ink.withValues(alpha: 0.08);
    for (final ring in const [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = vertex(i, ring);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, vertex(i, 1), grid);
    }

    // Polígono de datos.
    final dataPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final factor = (stats[i].value / kStatMax).clamp(0.0, 1.0) * progress;
      final p = vertex(i, factor);
      points.add(p);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawPath(
      dataPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Vértices con aro del color de la superficie, para separarlos de la rejilla.
    for (final p in points) {
      canvas.drawCircle(p, 3.6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 2.6, Paint()..color = color);
    }

    // Etiquetas directas: nombre corto + valor, en tinta neutra.
    for (var i = 0; i < n; i++) {
      final edge = vertex(i, 1.0);
      final labelPos = edge + (edge - center) / radius * labelGap;
      final painter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          children: [
            TextSpan(
              text: '${_shortLabels[stats[i].name] ?? stats[i].name}\n',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.25,
              ),
            ),
            TextSpan(
              text: '${stats[i].value}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      )..layout();
      painter.paint(canvas, labelPos - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.stats != stats || old.color != color;
}

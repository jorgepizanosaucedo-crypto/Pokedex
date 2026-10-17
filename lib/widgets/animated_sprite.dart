import 'package:flutter/material.dart';

/// Sprite animado de Pokémon Showdown (un GIF en movimiento) sobre el arte
/// oficial.
///
/// Mientras el GIF baja se ve [fallback] —el arte oficial, que llega volando
/// desde la tarjeta—, y en cuanto hay primer fotograma el sprite aparece
/// encima con un fundido y el arte se desvanece. Si el GIF no existe o falla,
/// se queda el arte y no pasa nada.
///
/// Los sprites vienen a escala de combate (Pikachu mide 60 px y Charizard
/// 133): se amplían todos por el mismo factor, así conservan su tamaño
/// relativo, y se encogen sólo si no caben. El factor crece con el espacio:
/// en la computadora el hueco del arte es casi el doble que en un teléfono.
class AnimatedSprite extends StatefulWidget {
  final String? url;
  final double size;
  final Widget fallback;

  const AnimatedSprite({super.key, required this.url, required this.size, required this.fallback});

  @override
  State<AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<AnimatedSprite> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_onFrame, onError: _onError);
  Size? _natural;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AnimatedSprite old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _natural = null;
      _resolve();
    }
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = null;
    final url = widget.url;
    if (url == null) return;
    _stream = NetworkImage(url).resolve(createLocalImageConfiguration(context))
      ..addListener(_listener);
  }

  void _onFrame(ImageInfo info, bool sync) {
    final natural = Size(info.image.width.toDouble(), info.image.height.toDouble());
    info.dispose();
    // Sólo hace falta el tamaño del primer fotograma; los siguientes los pinta
    // el propio `Image` de abajo.
    _stream?.removeListener(_listener);
    if (mounted && _natural == null) setState(() => _natural = natural);
  }

  void _onError(Object error, StackTrace? stack) => _stream?.removeListener(_listener);

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final natural = _natural;
    final url = widget.url;
    final ready = natural != null && url != null;
    final box = widget.size;

    var w = 0.0;
    var h = 0.0;
    if (ready) {
      final scale = (box / 70).clamp(2.5, 4.5);
      w = natural.width * scale;
      h = natural.height * scale;
      final fit = [1.0, box / w, box / h].reduce((a, b) => a < b ? a : b);
      w *= fit;
      h *= fit;
    }

    return SizedBox.square(
      dimension: box,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedOpacity(
            opacity: ready ? 0 : 1,
            duration: const Duration(milliseconds: 260),
            child: widget.fallback,
          ),
          if (ready)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * t,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
              child: Padding(
                // Los pies del sprite se apoyan un poco por encima del borde.
                padding: EdgeInsets.only(bottom: box * 0.08),
                child: Image.network(
                  url,
                  width: w,
                  height: h,
                  fit: BoxFit.contain,
                  // Píxeles nítidos al ampliar, como en Showdown.
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

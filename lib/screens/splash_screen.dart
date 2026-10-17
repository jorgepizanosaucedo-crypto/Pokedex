import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/favorites_store.dart';
import '../services/pokeapi_service.dart';
import '../services/profile_store.dart';
import '../services/sound_service.dart';
import '../services/type_index.dart';
import '../theme/app_theme.dart';
import '../widgets/pokeball.dart';
import 'login_screen.dart';
import 'pokedex_screen.dart';

/// Apertura de la app: la pokébola cae, rebota, tiembla y se abre en un
/// destello blanco que da paso a la Pokédex.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _left = false;

  /// Carga de datos guardados, en paralelo a la animación de apertura.
  late final Future<void> _ready;

  // Caída con rebote.
  late final Animation<double> _drop = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.34, curve: Curves.bounceOut),
  );
  // Temblor previo a la apertura.
  late final Animation<double> _shake = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.36, 0.68, curve: Curves.easeInOut),
  );
  // Destello que cubre la pantalla.
  late final Animation<double> _flash = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.72, 1, curve: Curves.easeInCubic),
  );
  late final Animation<double> _title = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.38, 0.62, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    // Mientras corre la animación se cargan los datos guardados; para cuando
    // termina ya sabemos si hay que registrar al entrenador o no.
    _ready = Future.wait([FavoritesStore.instance.load(), ProfileStore.instance.load()]);
    // Se adelanta la red: la lista y los tipos empiezan a llegar mientras
    // corre la animación, así la Pokédex aparece ya cargada.
    PokeApiService.instance.getPokemonList(limit: 1025).then((_) {}, onError: (Object _) {});
    TypeIndex.instance.load();
    SoundService.instance.play(Sfx.start, volume: 0.7);
    _c.forward().then((_) => _leave());
  }

  /// Sale del splash (al terminar la animación o al tocar la pantalla).
  Future<void> _leave() async {
    if (_left) return;
    _left = true;
    await _ready;
    if (!mounted) return;
    final registered = ProfileStore.instance.isRegistered;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 620),
        pageBuilder: (_, _, _) => registered ? const PokedexScreen() : const LoginScreen(),
        // La Pokédex aparece desde el blanco del destello.
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(
              begin: 1.06,
              end: 1.0,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ballSize = math.min(size.width * 0.42, 190.0);

    return Scaffold(
      backgroundColor: AppColors.night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tocar la pantalla salta la animación.
        onTap: () {
          _c.stop();
          _leave();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Un temblor que se va apagando: tres sacudidas cada vez más suaves.
            final wobble = math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 0.12;

            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [Color(0xFF2A2030), Color(0xFF14151E)],
                    ),
                  ),
                ),
                // Resplandor que crece bajo la bola mientras tiembla.
                Center(
                  child: Container(
                    width: ballSize * (1.6 + _shake.value * 1.4),
                    height: ballSize * (1.6 + _shake.value * 1.4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.pokeRed.withValues(alpha: 0.38 * _shake.value + 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, (1 - _drop.value) * -size.height * 0.55),
                    child: Transform.rotate(
                      angle: wobble,
                      child: Transform.scale(
                        scale: 1 + _flash.value * 0.35,
                        child: Pokeball(
                          size: ballSize,
                          color: AppColors.pokeRed,
                          bottomColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.62),
                  child: Opacity(
                    opacity: _title.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _title.value) * 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'POKÉDEX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              shadows: [
                                Shadow(
                                  color: AppColors.pokeRed.withValues(alpha: 0.7),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Datos en vivo desde la PokeAPI',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // El destello final: se abre desde el centro y lo cubre todo.
                IgnorePointer(
                  child: Opacity(
                    opacity: _flash.value,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

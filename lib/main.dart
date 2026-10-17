import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'services/karen_controller.dart';
import 'services/music_service.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';
import 'widgets/karen_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // Las miniaturas de la lista se decodifican a 256 px (unos 260 KB cada
  // una): con este margen caben varias pantallas sin volver a decodificar.
  PaintingBinding.instance.imageCache
    ..maximumSize = 600
    ..maximumSizeBytes = 200 << 20;

  MusicService.instance.init();
  // Música, efectos y Karen se guardan; se aplican antes del primer cuadro.
  await SettingsStore.instance.load();
  runApp(const PokedexApp());
}

class PokedexApp extends StatelessWidget {
  const PokedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokédex',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Karen se monta una vez encima de todo: así puede aparecer en cualquier
      // pantalla. Y como los navegadores bloquean el audio hasta que hay un
      // gesto, cada toque sirve también para arrancar la música.
      builder: (context, child) => Listener(
        onPointerDown: (_) {
          MusicService.instance.ensureStarted();
          KarenController.instance.ping();
        },
        child: KarenOverlay(child: child ?? const SizedBox.shrink()),
      ),
      home: const SplashScreen(),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/karen_controller.dart';
import 'services/music_service.dart';
import 'services/settings_store.dart';
import 'services/sound_service.dart';
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
  SoundService.instance.init();
  // En web los efectos se bajan y decodifican ya, para que el primero suene
  // a tiempo (el de la apertura incluido).
  SoundService.instance.preload();
  // Firebase arranca a la par que los ajustes, así no suma espera a la
  // apertura.
  final firebase = _initFirebase();
  // Música, efectos y Karen se guardan; se aplican antes del primer cuadro.
  await SettingsStore.instance.load();
  await firebase;
  runApp(const PokedexApp());
}

/// Conecta con el proyecto de Firebase (cuentas y datos en la nube). Si falla,
/// por ejemplo sin red, la Pokédex abre igual con lo guardado en el
/// dispositivo.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase no se pudo iniciar: $e');
  }
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
          SoundService.instance.unlock();
          MusicService.instance.ensureStarted();
          KarenController.instance.ping();
        },
        child: KarenOverlay(child: child ?? const SizedBox.shrink()),
      ),
      home: const SplashScreen(),
    );
  }
}

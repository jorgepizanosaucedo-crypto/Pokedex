// Configuración de Firebase (proyecto pokedex-jorge) para cada plataforma.
//
// Es el mismo archivo que genera `flutterfire configure`; si algún día lo
// vuelves a correr, lo reemplaza sin problema. Estos valores no son secretos:
// identifican al proyecto, y lo que protege los datos son las reglas de
// Firestore (ver firestore.rules), donde cada entrenador sólo lee y escribe
// lo suyo.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'Firebase no está configurado para ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5BsZiLGM_90iYVP2RkxryVq0So6eLaUw',
    appId: '1:725219152289:web:a0d6b6cfbfcdf7d99b3be0',
    messagingSenderId: '725219152289',
    projectId: 'pokedex-jorge',
    authDomain: 'pokedex-jorge.firebaseapp.com',
    storageBucket: 'pokedex-jorge.firebasestorage.app',
    measurementId: 'G-NB1BKX8D5N',
  );

  // Usa la misma clave que la web: las dos claves que crea Firebase tienen las
  // mismas restricciones (sólo las APIs de Firebase).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5BsZiLGM_90iYVP2RkxryVq0So6eLaUw',
    appId: '1:725219152289:android:a643b1320704c7f19b3be0',
    messagingSenderId: '725219152289',
    projectId: 'pokedex-jorge',
    storageBucket: 'pokedex-jorge.firebasestorage.app',
  );

  // En Windows, Firebase usa la configuración de la app web (Google sólo lo
  // soporta para desarrollo, no para publicar).
  static const FirebaseOptions windows = web;
}

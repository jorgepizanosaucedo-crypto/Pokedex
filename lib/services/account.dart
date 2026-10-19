import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Cuenta del entrenador en Firebase Authentication, con correo y contraseña
/// (proyecto pokedex-jorge).
///
/// Si Firebase no pudo arrancar (sin red al abrir la app, o en las pruebas),
/// todo responde como "sin cuenta" y la Pokédex sigue funcionando con lo
/// guardado en el dispositivo.
class Account {
  Account._();

  /// Firebase arrancó y se puede usar.
  static bool get available => Firebase.apps.isNotEmpty;

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get user => available ? _auth.currentUser : null;
  static bool get signedIn => user != null;
  static String? get email => user?.email;

  /// Espera a que Firebase diga si había una sesión abierta. En el navegador
  /// tarda un momento en leerla; con [timeout] no se queda esperando de más.
  static Future<User?> restore({Duration timeout = const Duration(seconds: 5)}) async {
    if (!available) return null;
    try {
      return await _auth.authStateChanges().first.timeout(timeout);
    } catch (_) {
      return _auth.currentUser;
    }
  }

  static Future<User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    try {
      await user.updateDisplayName(name.trim());
    } catch (_) {
      // El nombre también va en Firestore; esto es sólo un extra.
    }
    return user;
  }

  static Future<User> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!;
  }

  /// Manda el correo para cambiar la contraseña.
  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> signOut() async {
    if (!available) return;
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Un correo con forma de correo (lo demás lo revisa Firebase).
  static bool looksLikeEmail(String text) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim());

  /// Mensaje en español para un error de Firebase Authentication.
  static String messageFor(Object error) =>
      messageForCode(error is FirebaseAuthException ? error.code : '');

  /// Código del error (`email-already-in-use`…), o vacío si no es de Firebase.
  static String codeOf(Object error) => error is FirebaseAuthException ? error.code : '';

  static String messageForCode(String code) => switch (code) {
        'invalid-email' => 'Ese correo no parece válido. Revísalo.',
        'missing-email' => 'Escribe tu correo.',
        'user-disabled' => 'Esta cuenta está desactivada.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ya hay una cuenta con ese correo. Inicia sesión con ella.',
        'weak-password' => 'La contraseña es muy débil: usa al menos 6 caracteres.',
        'missing-password' => 'Escribe tu contraseña.',
        'too-many-requests' => 'Demasiados intentos seguidos. Espera un momento y vuelve a probar.',
        'network-request-failed' => 'No hay conexión. Revisa tu internet y vuelve a intentar.',
        'operation-not-allowed' => 'El registro con correo no está activado en el servidor.',
        _ => 'No se pudo completar. Inténtalo de nuevo.',
      };
}

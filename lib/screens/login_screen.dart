import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account.dart';
import '../services/cloud_sync.dart';
import '../services/music_service.dart';
import '../services/profile_store.dart';
import '../services/session.dart';
import '../services/settings_store.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/karen_overlay.dart';
import '../widgets/pokeball.dart';
import '../widgets/trainer_avatar.dart';
import 'pokedex_screen.dart';

/// Crear cuenta o iniciar sesión (Firebase Authentication, con correo y
/// contraseña). El perfil y el equipo se guardan en la cuenta y en el
/// dispositivo, así que se recuperan desde cualquier teléfono o computadora.
///
/// Si no hay conexión con Firebase, o si se prefiere, se puede entrar sin
/// cuenta: entonces todo se queda sólo en este dispositivo, como antes.
class LoginScreen extends StatefulWidget {
  /// Aviso que se muestra arriba del formulario (por ejemplo, al volver aquí
  /// después de cerrar sesión).
  final String? notice;

  /// Empieza en "Iniciar sesión" en vez de "Crear cuenta".
  final bool signIn;

  const LoginScreen({super.key, this.notice, this.signIn = false});

  /// Ruta con fundido, para volver aquí desde cualquier pantalla.
  static Route<void> route({String? notice, bool signIn = false}) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, _, _) => LoginScreen(notice: notice, signIn: signIn),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  late bool _signIn = widget.signIn;
  String? _type;
  Uint8List? _photo;
  bool _busy = false;
  bool _showPassword = false;
  String? _photoError;
  String? _error;
  String? _info;

  bool get _online => Account.available;

  @override
  void initState() {
    super.initState();
    // Quien ya tenía perfil en este dispositivo (sin cuenta) no lo vuelve a
    // escribir: sólo le falta el correo y la contraseña.
    final profile = ProfileStore.instance;
    if (profile.isRegistered) {
      _name.text = profile.name;
      _type = profile.favoriteType;
      _photo = profile.photo;
    }
    for (final c in [_name, _email, _password]) {
      c.addListener(_onEdit);
    }
  }

  void _onEdit() => setState(() {
    _error = null;
  });

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_busy) return false;
    if (!_online) return _name.text.trim().isNotEmpty;
    final emailOk = _email.text.trim().isNotEmpty;
    final passwordOk = _password.text.isNotEmpty;
    return _signIn ? emailOk && passwordOk : _name.text.trim().isNotEmpty && emailOk && passwordOk;
  }

  void _switchMode(bool signIn) {
    if (_signIn == signIn || _busy) return;
    SoundService.instance.play(Sfx.tab, volume: 0.4);
    setState(() {
      _signIn = signIn;
      _error = null;
      _info = null;
    });
  }

  Future<void> _pickPhoto() async {
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    setState(() => _photoError = null);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final prepared = await ProfileStore.preparePhoto(bytes);
      if (!mounted) return;
      if (prepared == null) {
        setState(() => _photoError = 'No pude leer esa imagen. Prueba con otra.');
        return;
      }
      setState(() => _photo = prepared);
      SoundService.instance.play(Sfx.shiny, volume: 0.4);
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = 'No se pudo abrir la galería en este dispositivo.');
      }
    }
  }

  void _fail(String message) {
    SoundService.instance.play(Sfx.error, volume: 0.45);
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (!_online) {
      await _enterWithoutAccount();
      return;
    }
    if (!Account.looksLikeEmail(_email.text)) {
      _fail('Ese correo no parece válido. Revísalo.');
      return;
    }
    if (!_signIn && _password.text.length < 6) {
      _fail('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    HapticFeedback.mediumImpact();
    try {
      if (_signIn) {
        final user = await Account.signIn(email: _email.text, password: _password.text);
        // Baja el perfil y el equipo guardados en la cuenta.
        await CloudSync.instance.start(user.uid);
        final profile = ProfileStore.instance;
        if (!profile.isRegistered) {
          await profile.save(
            name: user.displayName ?? _email.text.trim().split('@').first,
            favoriteType: profile.favoriteType,
            updatePhoto: false,
          );
        }
      } else {
        final user = await Account.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        await ProfileStore.instance.save(name: _name.text, favoriteType: _type, photo: _photo);
        await CloudSync.instance.start(user.uid, upload: true);
      }
      if (!mounted) return;
      SoundService.instance.play(Sfx.success, volume: 0.55);
      _enter();
    } catch (e) {
      if (!mounted) return;
      _fail(Account.messageFor(e));
      // Si el correo ya tiene cuenta, lo lógico es iniciar sesión con ella.
      if (Account.codeOf(e) == 'email-already-in-use') setState(() => _signIn = true);
    }
  }

  Future<void> _enterWithoutAccount() async {
    if (_name.text.trim().isEmpty) {
      _fail('Escribe tu nombre de entrenador para entrar sin cuenta.');
      return;
    }
    setState(() => _busy = true);
    await ProfileStore.instance.save(name: _name.text, favoriteType: _type, photo: _photo);
    if (!mounted) return;
    SoundService.instance.play(Sfx.success, volume: 0.5);
    _enter();
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!Account.looksLikeEmail(email)) {
      _fail('Escribe arriba el correo de tu cuenta y vuelve a tocar aquí.');
      return;
    }
    SoundService.instance.play(Sfx.tap, volume: 0.35);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Account.sendPasswordReset(email);
      if (!mounted) return;
      SoundService.instance.play(Sfx.chip, volume: 0.45);
      setState(() {
        _busy = false;
        _info = 'Listo: si hay una cuenta con $email, te llegó un correo para cambiar '
            'la contraseña. Revisa también la carpeta de spam.';
      });
    } catch (e) {
      if (mounted) _fail(Account.messageFor(e));
    }
  }

  void _enter() {
    // Antes se navegaba con el contexto del splash, que ya no existía: el
    // botón se quedaba gris y no pasaba nada.
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, _, _) => const PokedexScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
      (_) => false,
    );
  }

  InputDecoration _field(String hint, IconData icon, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: AppColors.background,
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final types = kTypeStyles.keys.toList();
    final layout = Layout.of(context);
    final creating = !_signIn || !_online;

    final String title;
    final String subtitle;
    final String button;
    if (!_online) {
      title = 'Bienvenido';
      subtitle = 'Entra para empezar tu Pokédex';
      button = 'Entrar sin cuenta';
    } else if (_signIn) {
      title = '¡Hola de nuevo!';
      subtitle = 'Inicia sesión y recupera tu equipo';
      button = 'Entrar';
    } else {
      title = 'Bienvenido';
      subtitle = 'Crea tu cuenta de entrenador';
      button = 'Crear cuenta y entrar';
    }

    return KarenBottomInset(
      value: 0,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Cabecera con la misma identidad roja del resto de la app.
            SizedBox(
              height: layout.isShort ? 150.0 : 230.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF04E2A), AppColors.pokeRed, Color(0xFFA81F05)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -46,
                    right: -54,
                    child: SpinningPokeball(size: 220, color: Colors.white.withValues(alpha: 0.12)),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: ContentWidth(
                maxWidth: kFormMaxWidth,
                child: AutofillGroup(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, layout.isShort ? 18 : 30, 20, 28),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey(title),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.12),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_online) ...[
                                _ModeSwitch(signIn: _signIn, onChanged: _switchMode),
                                const SizedBox(height: 18),
                              ],
                              if (widget.notice != null) ...[
                                _Notice(widget.notice!),
                                const SizedBox(height: 16),
                              ],
                              if (!_online) ...[
                                const _Notice(
                                  'No me pude conectar con el servidor de cuentas. Puedes entrar sin '
                                  'cuenta y crearla después desde tu perfil.',
                                  warning: true,
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (creating) ...[
                                Center(
                                  child: Column(
                                    children: [
                                      TrainerAvatar(
                                        photo: _photo,
                                        initials: _name.text.trim().isEmpty
                                            ? '?'
                                            : _name.text.trim()[0].toUpperCase(),
                                        size: layout.isShort ? 68 : 86,
                                        onTap: _pickPhoto,
                                        showEditBadge: true,
                                      ),
                                      const SizedBox(height: 10),
                                      TextButton.icon(
                                        onPressed: _pickPhoto,
                                        style: TextButton.styleFrom(foregroundColor: AppColors.pokeRed),
                                        icon: const Icon(Icons.add_a_photo_rounded, size: 17),
                                        label: Text(
                                          _photo == null ? 'Elegir foto de perfil' : 'Cambiar foto',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (_photo != null)
                                        TextButton(
                                          onPressed: () {
                                            SoundService.instance.play(Sfx.chipOff, volume: 0.35);
                                            setState(() => _photo = null);
                                          },
                                          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                                          child: const Text(
                                            'Quitar foto',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      if (_photoError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _photoError!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.pokeRed,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const _Label('¿Cómo te llamas?'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _name,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  autofillHints: const [AutofillHints.nickname],
                                  maxLength: 24,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  decoration: _field('Tu nombre de entrenador', Icons.badge_rounded),
                                ),
                                const SizedBox(height: 14),
                              ],
                              if (_online) ...[
                                const _Label('Correo'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  decoration: _field('tucorreo@ejemplo.com', Icons.alternate_email_rounded),
                                ),
                                const SizedBox(height: 14),
                                const _Label('Contraseña'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  obscureText: !_showPassword,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: [
                                    _signIn ? AutofillHints.password : AutofillHints.newPassword,
                                  ],
                                  onSubmitted: (_) => _submit(),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  decoration: _field(
                                    _signIn ? 'Tu contraseña' : 'Mínimo 6 caracteres',
                                    Icons.lock_rounded,
                                    suffix: IconButton(
                                      tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                      onPressed: () {
                                        SoundService.instance.play(Sfx.toggle, volume: 0.35);
                                        setState(() => _showPassword = !_showPassword);
                                      },
                                      icon: Icon(
                                        _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: AppColors.muted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_signIn)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _busy ? null : _forgotPassword,
                                      style: TextButton.styleFrom(foregroundColor: AppColors.pokeRed),
                                      child: const Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 14),
                              ],
                              if (creating) ...[
                                const _Label('Tu tipo favorito (opcional)'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: types.map((type) {
                                    final style = typeStyle(type);
                                    final active = _type == type;
                                    return GestureDetector(
                                      onTap: () {
                                        // Al elegirlo suena el tipo mismo.
                                        if (active) {
                                          SoundService.instance.play(Sfx.chipOff, volume: 0.35);
                                        } else {
                                          SoundService.instance.playType(type, volume: 0.4);
                                        }
                                        setState(() => _type = active ? null : type);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: active ? style.color : AppColors.background,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: active ? style.color : AppColors.line,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              style.icon,
                                              size: 13,
                                              color: active ? Colors.white : style.color,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              style.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: active ? Colors.white : AppColors.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (_error != null) ...[
                                _Notice(_error!, warning: true),
                                const SizedBox(height: 12),
                              ],
                              if (_info != null) ...[
                                _Notice(_info!),
                                const SizedBox(height: 12),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _canSubmit ? _submit : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.pokeRed,
                                    // Desactivado sigue siendo rojo, sólo más tenue.
                                    disabledBackgroundColor: AppColors.pokeRed.withValues(alpha: 0.45),
                                    disabledForegroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: _busy
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.catching_pokemon_rounded),
                                  label: Text(
                                    button,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_online && !_signIn)
                                Center(
                                  child: TextButton(
                                    onPressed: _busy || _name.text.trim().isEmpty ? null : _enterWithoutAccount,
                                    style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                                    child: const Text(
                                      'Prefiero entrar sin cuenta',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              Center(
                                child: Text(
                                  _online
                                      ? 'Con tu cuenta, tu perfil y tu equipo te siguen a cualquier dispositivo.'
                                      : 'Tus datos se quedan en este dispositivo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las dos pestañas de arriba de la tarjeta: crear cuenta o iniciar sesión.
class _ModeSwitch extends StatelessWidget {
  final bool signIn;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.signIn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final active = signIn == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? AppColors.pokeRed : AppColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(children: [option('Crear cuenta', false), option('Iniciar sesión', true)]),
    );
  }
}

/// Aviso arriba del formulario: verde (todo bien) o rojo (algo falló).
class _Notice extends StatelessWidget {
  final String text;
  final bool warning;

  const _Notice(this.text, {this.warning = false});

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.pokeRedInk : const Color(0xFF23855A);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.error_rounded : Icons.check_circle_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      color: AppColors.muted,
      letterSpacing: 1.2,
    ),
  );
}

/// Hoja del perfil, desde el avatar de la cabecera: foto, guía, ajustes y el
/// control de los datos (cerrar sesión, borrar lo descargado, borrar todo).
Future<void> showTrainerSheet(BuildContext context) async {
  final profile = ProfileStore.instance;
  final settings = SettingsStore.instance;
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final signedIn = Account.signedIn;
  SoundService.instance.play(Sfx.sheetUp, volume: 0.45);

  Future<void> backToLogin(String notice) =>
      navigator.pushAndRemoveUntil(LoginScreen.route(notice: notice), (_) => false);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => ListenableBuilder(
      listenable: Listenable.merge([profile, settings]),
      builder: (context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              TrainerAvatar(
                photo: profile.photo,
                initials: profile.initials,
                size: 84,
                showEditBadge: true,
                tooltip: 'Cambiar foto',
                onTap: () async {
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 90,
                    );
                    if (picked == null) return;
                    final prepared = await ProfileStore.preparePhoto(await picked.readAsBytes());
                    if (prepared != null) await profile.setPhoto(prepared);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 12),
              Text(
                profile.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (profile.favoriteType != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Entrenador de tipo ${typeStyle(profile.favoriteType).label}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      signedIn ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                      size: 15,
                      color: signedIn ? const Color(0xFF23855A) : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        signedIn
                            ? '${Account.email ?? 'Tu cuenta'} · tu equipo se guarda en la nube'
                            : 'Sin cuenta: tu perfil se guarda sólo en este dispositivo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!signedIn && Account.available)
                _SheetTile(
                  icon: Icons.cloud_upload_rounded,
                  iconColor: AppColors.pokeRed,
                  title: 'Crear cuenta o iniciar sesión',
                  subtitle: 'Guarda tu perfil y tu equipo en la nube y úsalos en otro dispositivo',
                  onTap: () {
                    SoundService.instance.play(Sfx.card, volume: 0.45);
                    Navigator.of(sheetContext).pop();
                    navigator.push(LoginScreen.route());
                  },
                ),
              _SheetTile(
                icon: Icons.school_rounded,
                iconColor: AppColors.pokeRed,
                title: 'Ver la guía otra vez',
                subtitle: 'Karen te explica la app paso a paso',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  MusicService.instance.ensureStarted();
                  KarenTourLauncher.request();
                },
              ),
              _SheetTile(
                icon: Icons.chat_bubble_rounded,
                iconColor: AppColors.pokeRed,
                title: 'Consejos de Karen',
                subtitle: 'Comentarios, datos y memes mientras navegas',
                trailing: Switch(
                  value: settings.karen,
                  activeTrackColor: AppColors.pokeRed,
                  onChanged: (value) {
                    SoundService.instance.play(value ? Sfx.toggle : Sfx.chipOff, volume: 0.4);
                    settings.setKaren(value);
                  },
                ),
                onTap: () {
                  SoundService.instance.play(settings.karen ? Sfx.chipOff : Sfx.toggle, volume: 0.4);
                  settings.setKaren(!settings.karen);
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.line),
              ),
              _ConfirmTile(
                icon: Icons.logout_rounded,
                title: 'Cerrar sesión',
                subtitle: signedIn
                    ? 'Sales de tu cuenta en este dispositivo. En la nube no se borra nada.'
                    : 'Borra tu perfil y tu equipo de este dispositivo',
                question: signedIn
                    ? '¿Cerrar sesión? Tu perfil y tu equipo siguen guardados en tu cuenta.'
                    : '¿Cerrar sesión? Se borran tu perfil y tu equipo.',
                confirmLabel: 'Sí, cerrar sesión',
                onConfirm: () async {
                  await Session.signOut();
                  SoundService.instance.play(Sfx.back, volume: 0.45);
                  if (signedIn) {
                    await navigator.pushAndRemoveUntil(
                      LoginScreen.route(
                        notice: 'Cerraste sesión. Tu perfil y tu equipo siguen en tu cuenta: '
                            'entra cuando quieras.',
                        signIn: true,
                      ),
                      (_) => false,
                    );
                  } else {
                    await backToLogin(
                      'Cerraste sesión. Tu perfil y tu equipo se borraron de este dispositivo.',
                    );
                  }
                },
              ),
              _SheetTile(
                icon: Icons.cleaning_services_rounded,
                title: 'Borrar lo descargado',
                subtitle: 'Imágenes y datos guardados de la PokeAPI. No cierra tu sesión.',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Session.clearDownloads();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Listo: se borró lo descargado. Se vuelve a bajar al usarlo.'),
                    ),
                  );
                },
              ),
              _ConfirmTile(
                icon: Icons.delete_forever_rounded,
                title: 'Borrar todos mis datos',
                subtitle: signedIn
                    ? 'De este dispositivo: perfil, equipo, ajustes y lo descargado. Tu cuenta no se borra.'
                    : 'Perfil, equipo, ajustes y lo descargado',
                question: '¿Borrar todo? No se puede deshacer.',
                confirmLabel: 'Sí, borrar todo',
                danger: true,
                onConfirm: () async {
                  await Session.wipeEverything();
                  await backToLogin('Se borraron todos tus datos de este dispositivo.');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opción de la hoja de perfil.
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final Color titleColor;

  const _SheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = AppColors.muted,
    this.titleColor = AppColors.ink,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: titleColor),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Opción que pide confirmación en el mismo sitio, sin diálogo encima.
class _ConfirmTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String question;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final bool danger;

  const _ConfirmTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.question,
    required this.confirmLabel,
    required this.onConfirm,
    this.danger = false,
  });

  @override
  State<_ConfirmTile> createState() => _ConfirmTileState();
}

class _ConfirmTileState extends State<_ConfirmTile> {
  bool _asking = false;
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.pokeRedInk : AppColors.ink;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !_asking
          ? _SheetTile(
              icon: widget.icon,
              iconColor: widget.danger ? AppColors.pokeRedInk : AppColors.muted,
              titleColor: widget.danger ? AppColors.pokeRedInk : AppColors.ink,
              title: widget.title,
              subtitle: widget.subtitle,
              onTap: () {
                SoundService.instance.play(Sfx.tap, volume: 0.3);
                setState(() => _asking = true);
              },
            )
          : Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              decoration: BoxDecoration(
                color: (widget.danger ? AppColors.pokeRed : AppColors.ink).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (widget.danger ? AppColors.pokeRed : AppColors.ink).withValues(
                    alpha: 0.18,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.icon, size: 20, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.question,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Los botones van a la derecha, donde el pulgar los busca.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _asking = false),
                          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: widget.danger ? AppColors.pokeRed : AppColors.ink,
                            disabledBackgroundColor:
                                (widget.danger ? AppColors.pokeRed : AppColors.ink).withValues(
                                  alpha: 0.4,
                                ),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.confirmLabel,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Pequeño puente para pedir la guía desde cualquier sitio sin acoplar
/// pantallas entre sí.
class KarenTourLauncher {
  KarenTourLauncher._();
  static VoidCallback? handler;
  static void request() => handler?.call();
}

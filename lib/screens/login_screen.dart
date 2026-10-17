import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

/// Alta del entrenador: nombre, foto y tipo favorito.
///
/// No hay servidor ni contraseña: los datos se guardan en el dispositivo y
/// sirven para la bienvenida y para que Karen te llame por tu nombre.
class LoginScreen extends StatefulWidget {
  /// Aviso que se muestra arriba del formulario (por ejemplo, al volver aquí
  /// después de cerrar sesión).
  final String? notice;

  const LoginScreen({super.key, this.notice});

  /// Ruta con fundido, para volver aquí desde cualquier pantalla.
  static Route<void> route({String? notice}) => PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, _, _) => LoginScreen(notice: notice),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  String? _type;
  Uint8List? _photo;
  bool _busy = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty && !_busy;

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

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    SoundService.instance.play(Sfx.open, volume: 0.5);
    await ProfileStore.instance.save(name: _name.text, favoriteType: _type, photo: _photo);
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final types = kTypeStyles.keys.toList();
    final layout = Layout.of(context);

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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, layout.isShort ? 18 : 30, 20, 28),
                  children: [
                    const Text(
                      'Bienvenido',
                      style: TextStyle(
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
                      'Regístrate para empezar tu Pokédex',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.notice != null) ...[
                            _Notice(widget.notice!),
                            const SizedBox(height: 18),
                          ],
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
                                    onPressed: () => setState(() => _photo = null),
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
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 24,
                            onSubmitted: (_) => _submit(),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Tu nombre de entrenador',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.background,
                              prefixIcon: const Icon(
                                Icons.badge_rounded,
                                color: AppColors.muted,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                                  SoundService.instance.play(Sfx.tap, volume: 0.3);
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
                          const SizedBox(height: 22),
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
                              icon: const Icon(Icons.catching_pokemon_rounded),
                              label: const Text(
                                'Entrar a la Pokédex',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'Tus datos se quedan en este dispositivo.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.muted.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso verde arriba del formulario.
class _Notice extends StatelessWidget {
  final String text;

  const _Notice(this.text);

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF23855A);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: green),
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
  SoundService.instance.play(Sfx.tap, volume: 0.35);

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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  profile.favoriteType == null
                      ? 'Tu perfil se guarda sólo en este dispositivo'
                      : 'Entrenador de tipo ${typeStyle(profile.favoriteType).label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
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
                subtitle: 'Comentarios y datos mientras navegas',
                trailing: Switch(
                  value: settings.karen,
                  activeTrackColor: AppColors.pokeRed,
                  onChanged: settings.setKaren,
                ),
                onTap: () => settings.setKaren(!settings.karen),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.line),
              ),
              _ConfirmTile(
                icon: Icons.logout_rounded,
                title: 'Cerrar sesión',
                subtitle: 'Borra tu perfil y tu equipo de este dispositivo',
                question: '¿Cerrar sesión? Se borran tu perfil y tu equipo.',
                confirmLabel: 'Sí, cerrar sesión',
                onConfirm: () async {
                  await Session.signOut();
                  await backToLogin(
                    'Cerraste sesión. Tu perfil y tu equipo se borraron de este dispositivo.',
                  );
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
                subtitle: 'Perfil, equipo, ajustes y lo descargado',
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

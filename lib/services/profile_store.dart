import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'prefs.dart';

/// Datos del entrenador: nombre, foto y tipo favorito, guardados en el
/// dispositivo. No hay servidor ni cuenta remota: el registro es local.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  static const _key = 'trainer_profile';
  static const _photoKey = 'trainer_photo';

  /// Lado al que se reduce la foto antes de guardarla. Una imagen de cámara
  /// ocuparía megabytes en las preferencias; así son unas decenas de KB.
  static const int photoSize = 256;

  bool _loaded = false;
  String _name = '';
  String? _favoriteType;
  bool _tutorialDone = false;
  Uint8List? _photo;

  bool get loaded => _loaded;
  String get name => _name;
  String? get favoriteType => _favoriteType;
  bool get tutorialDone => _tutorialDone;
  Uint8List? get photo => _photo;

  /// Hay sesión cuando el entrenador ya puso su nombre.
  bool get isRegistered => _name.trim().isNotEmpty;

  /// Iniciales para el avatar cuando no hay foto.
  String get initials => initialsOf(_name);

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => String.fromCharCode(s.runes.first);
    if (parts.length == 1) return first(parts.first).toUpperCase();
    return (first(parts.first) + first(parts.last)).toUpperCase();
  }

  Future<void> load() async {
    final prefs = await Prefs.load();
    try {
      final raw = prefs?.getString(_key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _name = json['name'] as String? ?? '';
        _favoriteType = json['favoriteType'] as String?;
        _tutorialDone = json['tutorialDone'] as bool? ?? false;
      }
      final photo = prefs?.getString(_photoKey);
      if (photo != null) _photo = base64Decode(photo);
    } catch (_) {
      // Datos dañados: se empieza de cero.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Crea o actualiza el perfil. [photo] sólo cambia si se pasa
  /// [updatePhoto]; así editar el nombre no borra la foto.
  Future<void> save({
    required String name,
    String? favoriteType,
    Uint8List? photo,
    bool updatePhoto = true,
  }) async {
    _name = name.trim();
    _favoriteType = favoriteType;
    if (updatePhoto) _photo = photo;
    notifyListeners();
    await _persist();
  }

  Future<void> setPhoto(Uint8List? photo) async {
    _photo = photo;
    notifyListeners();
    await _persist();
  }

  Future<void> markTutorialDone() async {
    if (_tutorialDone) return;
    _tutorialDone = true;
    await _persist();
  }

  /// Borra el perfil del dispositivo (cerrar sesión).
  Future<void> clear() async {
    _name = '';
    _favoriteType = null;
    _tutorialDone = false;
    _photo = null;
    notifyListeners();
    final prefs = await Prefs.load();
    try {
      await prefs?.remove(_key);
      await prefs?.remove(_photoKey);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await Prefs.load();
    try {
      await prefs?.setString(
        _key,
        jsonEncode({'name': _name, 'favoriteType': _favoriteType, 'tutorialDone': _tutorialDone}),
      );
      final photo = _photo;
      if (photo == null) {
        await prefs?.remove(_photoKey);
      } else {
        await prefs?.setString(_photoKey, base64Encode(photo));
      }
    } catch (_) {}
  }

  /// Reduce una foto elegida a un cuadrado de [photoSize] píxeles.
  ///
  /// Se recorta al centro para que un retrato vertical no salga deformado, y
  /// se vuelve a codificar en PNG: así cabe de sobra en las preferencias.
  static Future<Uint8List?> preparePhoto(Uint8List original) async {
    try {
      final codec = await ui.instantiateImageCodec(original);
      final frame = await codec.getNextFrame();
      final src = frame.image;

      final side = src.width < src.height ? src.width : src.height;
      final srcRect = ui.Rect.fromLTWH(
        (src.width - side) / 2,
        (src.height - side) / 2,
        side.toDouble(),
        side.toDouble(),
      );
      const dstRect = ui.Rect.fromLTWH(0, 0, photoSize * 1.0, photoSize * 1.0);

      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawImageRect(src, srcRect, dstRect, ui.Paint()..filterQuality = ui.FilterQuality.medium);
      final out = await recorder.endRecording().toImage(photoSize, photoSize);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);

      src.dispose();
      out.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

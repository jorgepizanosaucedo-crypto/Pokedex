import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'favorites_store.dart';
import 'profile_store.dart';

/// Copia en la nube (Cloud Firestore) del perfil y el equipo del entrenador.
///
/// El dispositivo sigue siendo de donde se pinta todo: los almacenes locales
/// se guardan como siempre y, con la sesión iniciada, cada cambio se sube a
/// `entrenadores/{uid}`. Si cambia en otro dispositivo, llega aquí solo.
/// Las reglas de Firestore (firestore.rules) sólo dejan leer y escribir ese
/// documento a su dueño.
class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  static const String collection = 'entrenadores';

  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _debounce;
  bool _applying = false;

  /// La foto que ya está en la nube: así no se vuelve a subir en cada
  /// favorito (pesa más que todo lo demás junto).
  Uint8List? _uploadedPhoto;

  bool get active => _uid != null;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection(collection).doc(uid);

  /// Empieza a sincronizar la cuenta [uid].
  ///
  /// Con [upload] (al crear la cuenta) se sube lo del dispositivo. Si no, se
  /// baja lo guardado en la cuenta; el equipo se junta con el de este
  /// dispositivo para no perder los favoritos marcados sin sesión.
  Future<void> start(String uid, {bool upload = false}) async {
    await stop();
    _uid = uid;
    if (upload) {
      await _push(created: true);
    } else {
      try {
        final snap = await _doc(uid).get().timeout(const Duration(seconds: 8));
        if (_uid != uid) return;
        final data = snap.data();
        if (data == null) {
          await _push(created: true);
        } else {
          final local = FavoritesStore.instance.sorted.toSet();
          _apply(data);
          final merged = FavoritesStore.instance.sorted.toSet();
          if (local.difference(merged).isNotEmpty) {
            FavoritesStore.instance.replaceAll(merged.union(local));
            await _push();
          }
        }
      } catch (e) {
        // Sin red: se sigue con lo local y se sube con el próximo cambio.
        debugPrint('No se pudo leer la cuenta: $e');
      }
    }
    if (_uid != uid) return;
    ProfileStore.instance.addListener(_schedule);
    FavoritesStore.instance.addListener(_schedule);
    _sub = _doc(uid).snapshots().listen(
      (snap) {
        // Los cambios propios que aún no confirma el servidor no se aplican,
        // ni nada mientras hay cambios locales esperando a subir: si no, una
        // confirmación vieja borraría el favorito recién marcado.
        final data = snap.data();
        if (data == null || snap.metadata.hasPendingWrites) return;
        if (_debounce?.isActive ?? false) return;
        _apply(data);
      },
      onError: (Object e) => debugPrint('Sincronización detenida: $e'),
    );
  }

  /// Deja de sincronizar (al cerrar sesión). No borra nada.
  Future<void> stop() async {
    ProfileStore.instance.removeListener(_schedule);
    FavoritesStore.instance.removeListener(_schedule);
    _debounce?.cancel();
    _debounce = null;
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    _uploadedPhoto = null;
  }

  /// Sube enseguida lo que estaba esperando (antes de cerrar sesión).
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await _push();
    }
  }

  void _schedule() {
    if (_applying || _uid == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _push);
  }

  Future<void> _push({bool created = false}) async {
    final uid = _uid;
    if (uid == null) return;
    final profile = ProfileStore.instance;
    final photo = profile.photo;
    final sendPhoto = created || !identical(photo, _uploadedPhoto);
    try {
      await _doc(uid).set({
        'nombre': profile.name,
        'tipoFavorito': profile.favoriteType,
        if (sendPhoto) 'foto': photo == null ? null : base64Encode(photo),
        'favoritos': FavoritesStore.instance.sorted,
        'guiaVista': profile.tutorialDone,
        'guiaFichaVista': profile.detailTourDone,
        'actualizado': FieldValue.serverTimestamp(),
        if (created) 'creado': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (sendPhoto) _uploadedPhoto = photo;
    } catch (e) {
      debugPrint('No se pudo guardar en la nube: $e');
    }
  }

  void _apply(Map<String, dynamic> data) {
    _applying = true;
    try {
      final photo = data['foto'];
      ProfileStore.instance.applyRemote(
        name: data['nombre'] as String? ?? '',
        favoriteType: data['tipoFavorito'] as String?,
        // Si la cuenta nunca guardó foto, se queda la del dispositivo.
        updatePhoto: data.containsKey('foto'),
        photo: photo is String && photo.isNotEmpty ? base64Decode(photo) : null,
        tutorialDone: data['guiaVista'] as bool?,
        detailTourDone: data['guiaFichaVista'] as bool?,
      );
      _uploadedPhoto = ProfileStore.instance.photo;
      final favorites = data['favoritos'];
      if (favorites is List) {
        FavoritesStore.instance.replaceAll(favorites.whereType<num>().map((n) => n.toInt()));
      }
    } catch (e) {
      debugPrint('Datos de la nube con otro formato: $e');
    } finally {
      _applying = false;
    }
  }
}

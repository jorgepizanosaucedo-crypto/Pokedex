import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Foto del entrenador, o sus iniciales mientras no haya foto.
class TrainerAvatar extends StatelessWidget {
  final Uint8List? photo;
  final String initials;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final Color ring;

  /// Fondo detrás de las iniciales. En la cabecera roja va translúcido para
  /// que las iniciales blancas se lean (antes salía blanco sobre blanco).
  final Color fill;
  final String? tooltip;

  const TrainerAvatar({
    super.key,
    required this.photo,
    required this.initials,
    required this.size,
    this.onTap,
    this.showEditBadge = false,
    this.ring = AppColors.pokeRed,
    this.fill = AppColors.background,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final border = size * 0.035 + 1.5;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: ring, width: border),
        boxShadow: size < 48
            ? null
            : [
                BoxShadow(
                  color: ring.withValues(alpha: 0.22),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.05),
                ),
              ],
      ),
      // La foto se recorta al círculo de dentro del aro. Antes se recortaba al
      // de fuera: la foto, cuadrada, tapaba el aro rojo por las esquinas.
      child: photo != null
          ? ClipOval(
              child: SizedBox.expand(
                child: Image.memory(
                  photo!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            )
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: ring,
                  height: 1,
                ),
              ),
            ),
    );

    final avatarWithBadge = MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: showEditBadge
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  avatar,
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: EdgeInsets.all(size * 0.06),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ring,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: size * 0.17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : avatar,
      ),
    );
    return tooltip == null ? avatarWithBadge : Tooltip(message: tooltip!, child: avatarWithBadge);
  }
}

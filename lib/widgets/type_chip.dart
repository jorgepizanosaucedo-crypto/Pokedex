import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta de tipo. `onColor` = translúcida sobre fondo de color; si no, sólida.
///
/// Sobre color va con un velo oscuro y no claro: así el texto blanco gana
/// contraste en lugar de perderlo.
class TypeChip extends StatelessWidget {
  final String type;
  final bool onColor;
  final bool compact;

  const TypeChip({super.key, required this.type, this.onColor = true, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = typeStyle(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4.5),
      decoration: BoxDecoration(
        color: onColor ? Colors.black.withValues(alpha: 0.14) : style.color,
        borderRadius: BorderRadius.circular(30),
        border: onColor ? Border.all(color: Colors.white.withValues(alpha: 0.26)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 11 : 13, color: Colors.white),
          SizedBox(width: compact ? 4 : 5),
          Text(
            style.label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

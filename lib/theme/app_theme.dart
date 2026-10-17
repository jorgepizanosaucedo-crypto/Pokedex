import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF4F5FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF1B1D2A);
  static const muted = Color(0xFF6E7387);

  /// Línea fina para separar superficies blancas sin sombras pesadas.
  static const line = Color(0xFFE3E6EF);
  static const pokeRed = Color(0xFFE3350D);

  /// Rojo un poco más profundo para texto y bordes sobre blanco.
  static const pokeRedInk = Color(0xFFC42B08);

  /// Fondo del splash y de la pantalla de arranque de Android.
  static const night = Color(0xFF14151E);
}

/// Sombra neutra y suave. Las sombras de color se reservan para lo que está
/// activo o presionado.
const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x0F1B1D2A), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x141B1D2A), blurRadius: 16, offset: Offset(0, 6)),
];

class TypeStyle {
  final String label;
  final Color color;
  final IconData icon;
  const TypeStyle(this.label, this.color, this.icon);
}

/// Los colores de tipo de siempre, vivos, sólo un poco más profundos donde
/// hacía falta para que el nombre en blanco se lea (contraste de 3:1 o más,
/// el mínimo para texto en negrita). Antes el eléctrico, el hada o el roca
/// dejaban el nombre casi invisible.
const Map<String, TypeStyle> kTypeStyles = {
  'normal': TypeStyle('Normal', Color(0xFF8C8E88), Icons.circle_outlined),
  'fire': TypeStyle('Fuego', Color(0xFFE8692A), Icons.local_fire_department_rounded),
  'water': TypeStyle('Agua', Color(0xFF4A8FD9), Icons.water_drop_rounded),
  'electric': TypeStyle('Eléctrico', Color(0xFFBD8C0B), Icons.bolt_rounded),
  'grass': TypeStyle('Planta', Color(0xFF43A34A), Icons.eco_rounded),
  'ice': TypeStyle('Hielo', Color(0xFF31A1AA), Icons.ac_unit_rounded),
  'fighting': TypeStyle('Lucha', Color(0xFFD3425F), Icons.sports_mma_rounded),
  'poison': TypeStyle('Veneno', Color(0xFFA864C7), Icons.science_rounded),
  'ground': TypeStyle('Tierra', Color(0xFFD0703C), Icons.terrain_rounded),
  'flying': TypeStyle('Volador', Color(0xFF7290D4), Icons.air_rounded),
  'psychic': TypeStyle('Psíquico', Color(0xFFEB5A6B), Icons.psychology_rounded),
  'bug': TypeStyle('Bicho', Color(0xFF78A01E), Icons.bug_report_rounded),
  'rock': TypeStyle('Roca', Color(0xFFA48F55), Icons.landscape_rounded),
  'ghost': TypeStyle('Fantasma', Color(0xFF6F6AC1), Icons.blur_on_rounded),
  'dragon': TypeStyle('Dragón', Color(0xFF0B6DC3), Icons.whatshot_rounded),
  'dark': TypeStyle('Siniestro', Color(0xFF5A5366), Icons.dark_mode_rounded),
  'steel': TypeStyle('Acero', Color(0xFF5A8EA1), Icons.shield_rounded),
  'fairy': TypeStyle('Hada', Color(0xFFD867C6), Icons.auto_awesome_rounded),
};

/// Gris neutro mientras todavía no se sabe el tipo.
const TypeStyle kUnknownType = TypeStyle('', Color(0xFF8A8FA3), Icons.help_outline_rounded);

TypeStyle typeStyle(String? type) => kTypeStyles[type] ?? kUnknownType;

const Map<String, String> kStatLabels = {
  'hp': 'PS',
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'At. Esp.',
  'special-defense': 'Def. Esp.',
  'speed': 'Velocidad',
};

/// La PokeAPI sólo da el hábitat en inglés.
const Map<String, String> kHabitats = {
  'cave': 'Cueva',
  'forest': 'Bosque',
  'grassland': 'Pradera',
  'mountain': 'Montaña',
  'rare': 'Raro',
  'rough-terrain': 'Terreno agreste',
  'sea': 'Mar',
  'urban': 'Ciudad',
  'waters-edge': 'Orilla del agua',
};

/// Anchos máximos de contenido.
///
/// La app se diseñó con proporciones de teléfono. Sin un tope, en una tableta
/// o en un navegador maximizado los formularios, las pestañas y el radar se
/// estiran hasta quedar irreconocibles. Estos topes no hacen nada en un
/// teléfono —la pantalla ya es más estrecha— y recortan donde sobra espacio.
const double kFormMaxWidth = 460;
const double kSheetMaxWidth = 680;
const double kGridMaxWidth = 1080;

/// Ancho total de la ficha en pantallas anchas (arte e información lado a lado).
const double kDetailWideMaxWidth = 1040;

/// Medidas de la pantalla, para decidir disposición.
class Layout {
  final Size size;

  const Layout(this.size);

  factory Layout.of(BuildContext context) => Layout(MediaQuery.sizeOf(context));

  /// Teléfono en vertical.
  bool get isCompact => size.width < 600;

  /// Poca altura: teléfono en horizontal, o ventana aplastada.
  bool get isShort => size.height < 560;

  /// Hay sitio para poner la cadena evolutiva en fila.
  bool get fitsEvolutionRow => size.width >= 560;

  /// Computadora o tableta en horizontal: la ficha pone el arte a la
  /// izquierda y la información a la derecha, en vez de apilarlos.
  bool get isWide => size.width >= 900 && size.height >= 520;

  /// Ancho máximo de cada tarjeta de la lista. En la computadora un poco más
  /// pequeñas: las de teléfono se veían enormes en un monitor.
  double get cardMaxExtent => isCompact ? 200 : 178;

  /// Alto del arte en la ficha, limitado también por el ancho para que en
  /// horizontal no se coma la pantalla entera.
  double get artworkHeight => [
    size.height * (isShort ? 0.34 : 0.30),
    size.width * 0.6,
    260.0,
  ].reduce((a, b) => a < b ? a : b);

  /// Alto de la mascota: cabe entera tanto en un teléfono en horizontal como
  /// en una pantalla grande, y en la computadora no pasa de un tamaño
  /// razonable (antes llegaba a 400 px y tapaba media pantalla).
  double karenHeight({required bool big}) {
    final byHeight = size.height * (big ? 0.40 : 0.30);
    final byWidth = size.width * (big ? 0.62 : 0.40);
    return (byHeight < byWidth ? byHeight : byWidth).clamp(140.0, big ? 300.0 : 220.0);
  }
}

/// Centra a [child] y le pone un ancho máximo.
class ContentWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ContentWidth({super.key, required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

String capitalize(String s) =>
    s.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// La lista de la PokeAPI nombra a algunos Pokémon por su forma por defecto
/// ("giratina-altered", "maushold-family-of-four"). En la Pokédex se muestra
/// el nombre de la especie, como en los juegos.
const Map<String, String> _defaultForms = {
  'deoxys-normal': 'deoxys',
  'wormadam-plant': 'wormadam',
  'giratina-altered': 'giratina',
  'shaymin-land': 'shaymin',
  'basculin-red-striped': 'basculin',
  'darmanitan-standard': 'darmanitan',
  'frillish-male': 'frillish',
  'jellicent-male': 'jellicent',
  'tornadus-incarnate': 'tornadus',
  'thundurus-incarnate': 'thundurus',
  'landorus-incarnate': 'landorus',
  'keldeo-ordinary': 'keldeo',
  'meloetta-aria': 'meloetta',
  'pyroar-male': 'pyroar',
  'meowstic-male': 'meowstic',
  'aegislash-shield': 'aegislash',
  'pumpkaboo-average': 'pumpkaboo',
  'gourgeist-average': 'gourgeist',
  'zygarde-50': 'zygarde',
  'oricorio-baile': 'oricorio',
  'lycanroc-midday': 'lycanroc',
  'wishiwashi-solo': 'wishiwashi',
  'minior-red-meteor': 'minior',
  'mimikyu-disguised': 'mimikyu',
  'toxtricity-amped': 'toxtricity',
  'eiscue-ice': 'eiscue',
  'indeedee-male': 'indeedee',
  'morpeko-full-belly': 'morpeko',
  'urshifu-single-strike': 'urshifu',
  'basculegion-male': 'basculegion',
  'enamorus-incarnate': 'enamorus',
  'oinkologne-male': 'oinkologne',
  'maushold-family-of-four': 'maushold',
  'squawkabilly-green-plumage': 'squawkabilly',
  'palafin-zero': 'palafin',
  'tatsugiri-curly': 'tatsugiri',
  'dudunsparce-two-segment': 'dudunsparce',
};

/// Nombre para mostrar. Unos pocos nombres de la API llevan el género o un
/// signo pegado con guion; esos se arreglan a mano.
String displayName(String apiName) => switch (_defaultForms[apiName] ?? apiName) {
  'nidoran-f' => 'Nidoran ♀',
  'nidoran-m' => 'Nidoran ♂',
  'mr-mime' => 'Mr. Mime',
  'mime-jr' => 'Mime Jr.',
  'mr-rime' => 'Mr. Rime',
  'farfetchd' => "Farfetch'd",
  'sirfetchd' => "Sirfetch'd",
  'type-null' => 'Código Cero',
  'ho-oh' => 'Ho-Oh',
  'porygon-z' => 'Porygon-Z',
  'jangmo-o' => 'Jangmo-o',
  'hakamo-o' => 'Hakamo-o',
  'kommo-o' => 'Kommo-o',
  'flabebe' => 'Flabébé',
  final name => capitalize(name),
};

/// Oscurece los colores muy claros lo justo para que una marca mantenga
/// contraste sobre una superficie blanca.
Color readableOn(Color color, {Color surface = Colors.white}) {
  final needed = surface.computeLuminance() > 0.5 ? 0.34 : 0.0;
  final excess = color.computeLuminance() - needed;
  if (excess <= 0) return color;
  return Color.lerp(color, Colors.black, (excess * 0.95).clamp(0.0, 0.34))!;
}

String dexNumber(int id) => '#${id.toString().padLeft(4, '0')}';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.pokeRed, surface: AppColors.background),
    scaffoldBackgroundColor: AppColors.background,
    // Poppins va empaquetada en assets/fonts: antes se descargaba de Google
    // Fonts al abrir y en web el texto tardaba en aparecer.
    fontFamily: 'Poppins',
  );

  final text = base.textTheme.apply(
    fontFamily: 'Poppins',
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  // Material reparte espaciado entre letras pensando en Roboto; Poppins ya
  // es ancha y con ese extra los textos se veían deshilachados.
  TextStyle? tight(TextStyle? s) => s?.copyWith(letterSpacing: 0);

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: tight(text.displayLarge),
      displayMedium: tight(text.displayMedium),
      displaySmall: tight(text.displaySmall),
      headlineLarge: tight(text.headlineLarge),
      headlineMedium: tight(text.headlineMedium),
      headlineSmall: tight(text.headlineSmall),
      titleLarge: tight(text.titleLarge),
      titleMedium: tight(text.titleMedium),
      titleSmall: tight(text.titleSmall),
      bodyLarge: tight(text.bodyLarge),
      bodyMedium: tight(text.bodyMedium),
      bodySmall: tight(text.bodySmall),
      labelLarge: tight(text.labelLarge),
      labelMedium: tight(text.labelMedium),
      labelSmall: tight(text.labelSmall),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.pokeRed,
      selectionColor: Color(0x40E3350D),
      selectionHandleColor: AppColors.pokeRed,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

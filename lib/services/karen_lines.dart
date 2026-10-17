part of 'karen_controller.dart';

// Repertorio de Karen. Cada categoría tiene varias frases y se reparten con
// `_Bag`, que no repite ninguna hasta haber dicho todas.
//
// En las frases, {name} es el nombre del Pokémon, {total} su total base,
// {count} un número y {trainer} el nombre del entrenador.

// ---------------------------------------------------------------- saludos

const List<String> _greetMorning = [
  '¡Buenos días, {trainer}! Hoy es buen día para descubrir un Pokémon nuevo.',
  '¡Buenos días, {trainer}! ¿Café y Pokédex? Yo ya estoy lista.',
  '¡Arriba, {trainer}! Los Pokémon madrugadores te estaban esperando.',
];

const List<String> _greetAfternoon = [
  '¡Buenas tardes, {trainer}! ¿Seguimos donde lo dejamos?',
  '¡Hola, {trainer}! Qué bueno verte otra vez. La Pokédex está lista.',
  '¡Buenas tardes, {trainer}! Tengo datos nuevos que contarte.',
];

const List<String> _greetNight = [
  '¡Buenas noches, {trainer}! A esta hora salen los Pokémon fantasma…',
  '¡Hola, {trainer}! Una vuelta nocturna por la Pokédex nunca sobra.',
  'Buenas noches, {trainer}. Si te da sueño, Snorlax te entiende perfectamente.',
];

// ------------------------------------------------------------- reacciones

const List<KarenStep> _legendaryLines = [
  KarenStep(
    '¡{name}! Es de los que casi nadie llega a ver. Mira sus estadísticas, '
    'están muy por encima de lo normal.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  KarenStep(
    'Ojo: {name} es legendario. ¿Notaste que cambió la música? Los '
    'legendarios tienen su propio tema.',
    mood: KarenMood.surprise,
    emote: KarenEmote.notes,
  ),
  KarenStep(
    '{name} suma {total} puntos base. En los juegos sólo hay uno así en todo '
    'el mundo.',
    mood: KarenMood.point,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Estás ante {name}, una leyenda. Abre la pestaña Stats y compáralo '
    'con cualquier otro.',
    mood: KarenMood.cheer,
    emote: KarenEmote.exclaim,
  ),
];

const List<KarenStep> _strongLines = [
  KarenStep(
    '{name} suma {total} puntos de estadísticas base. Es un peso pesado.',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    '¡Uf! {total} de total base. {name} juega en otra liga.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  KarenStep(
    '{name} está entre los más fuertes de la Pokédex. Mira lo grande que '
    'sale su radar.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
];

const List<KarenStep> _weakLines = [
  KarenStep(
    '{name} es pequeñito todavía: {total} de total base. Mira la pestaña '
    'Evolución, seguro tiene futuro.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'No subestimes a {name}. Todos los grandes empezaron así.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  KarenStep(
    '{name} tiene {total} de total base. Poco, pero qué tierno.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
];

const List<KarenStep> _favoriteLines = [
  KarenStep(
    '{name} ya es parte de tu equipo. Lo encuentras con el corazón de arriba.',
    mood: KarenMood.cheer,
    emote: KarenEmote.heart,
  ),
  KarenStep(
    '¡Buena elección! {name} se queda contigo aunque cierres la app.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  KarenStep(
    '{name} al equipo. Ya van {count}. ¿Armamos uno completo de seis?',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Anotado: {name} es de tus favoritos. Tienes buen ojo.',
    mood: KarenMood.wave,
    emote: KarenEmote.heart,
  ),
];

const List<KarenStep> _unfavoriteLines = [
  KarenStep(
    '{name} sale del equipo. Siempre puedes volver a marcarlo.',
    mood: KarenMood.think,
    emote: KarenEmote.sweat,
  ),
  KarenStep(
    'Adiós, {name}… bueno, sigue en la Pokédex. Sólo deja de ser favorito.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
];

const List<KarenStep> _randomLines = [
  KarenStep(
    '¡Te tocó {name}! Así se descubren los que nunca buscarías.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'La ruleta dice… ¡{name}! ¿Lo conocías?',
    mood: KarenMood.surprise,
    emote: KarenEmote.question,
  ),
  KarenStep(
    '¡{name} salvaje apareció! Bueno, más o menos.',
    mood: KarenMood.happy,
    emote: KarenEmote.exclaim,
  ),
  KarenStep(
    'Al azar: {name}. Si no te convence, dale otra vez al dado.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
];

const List<KarenStep> _shinyLines = [
  KarenStep(
    '¡Ese es el {name} variocolor! En los juegos aparece una vez cada varios '
    'miles. Aquí lo tienes con un botón.',
    mood: KarenMood.surprise,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    '¡Brilla! Los shiny no son más fuertes, sólo más raros… y más bonitos.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Mira bien a {name}: en su versión shiny cambia de color, no de '
    'estadísticas.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
];

const List<KarenStep> _animatedLines = [
  KarenStep(
    '¡Ahora se mueve! Es su sprite animado de combate.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Así se ve {name} en batalla. Tócalo y verás cómo ataca.',
    mood: KarenMood.point,
    emote: KarenEmote.exclaim,
  ),
];

const List<KarenStep> _cryLines = [
  KarenStep(
    'Ese es el grito real de {name}, sacado de los juegos.',
    mood: KarenMood.surprise,
    emote: KarenEmote.notes,
  ),
  KarenStep(
    '¿Lo oíste? Cada Pokémon tiene su propio grito. ¡Prueba con otros!',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
  ),
  KarenStep(
    'Ja, ja. {name} tiene carácter. Cada tanto vuelve a gritar solo.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
  ),
];

const List<KarenStep> _noResultsLines = [
  KarenStep(
    'Ahí no hay nada. Prueba quitando el filtro de tipo, o busca por número: '
    'el 025 es Pikachu.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
    companions: [25],
  ),
  KarenStep(
    'Mmm, nada por aquí. ¿Seguro que se escribe así? Prueba con menos letras.',
    mood: KarenMood.think,
    emote: KarenEmote.question,
  ),
  KarenStep(
    'Sin resultados. A veces el nombre en inglés y en español es distinto: '
    'busca por número y sales de dudas.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
];

const List<KarenStep> _networkLines = [
  KarenStep(
    'No consigo hablar con la PokeAPI. Revisa tu conexión y dale a Reintentar.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
  KarenStep(
    'Uy, se cortó la conexión. Lo que ya viste sigue guardado; lo nuevo '
    'llegará cuando vuelva el internet.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
];

const List<KarenStep> _teamEmptyLines = [
  KarenStep(
    'Tu equipo está vacío. Abre un Pokémon y toca el corazón para sumarlo.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Todavía no tienes favoritos. ¿Empezamos con tu inicial preferido?',
    mood: KarenMood.think,
    emote: KarenEmote.question,
    companions: [1, 4, 7],
  ),
];

const List<KarenStep> _teamLines = [
  KarenStep(
    'Este es tu equipo: {count} Pokémon. Se guardan en este dispositivo.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  KarenStep(
    '{count} en tu equipo. Vuelve a tocar el corazón para ver la Pokédex entera.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
];

const List<KarenStep> _swipeLines = [
  KarenStep(
    '¡Vas rapidísimo! Cada vez que deslizas cambia el ambiente según el tipo.',
    mood: KarenMood.cheer,
    emote: KarenEmote.notes,
  ),
  KarenStep(
    'Así me gusta, a recorrer la Pokédex. ¿Ya viste a todos los de esta '
    'generación?',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Si vas buscando uno en concreto, el buscador te lleva directo.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
  ),
];

const List<KarenStep> _statsTabLines = [
  KarenStep(
    'El radar usa siempre la misma escala, de 0 a 255. Así puedes comparar '
    'Pokémon de un vistazo.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Fíjate en qué punta del radar sobresale: ese es su punto fuerte.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
];

const List<KarenStep> _evolutionTabLines = [
  KarenStep(
    'Toca cualquier forma de la cadena para saltar a su ficha.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Debajo de cada flecha está lo que necesita para evolucionar: nivel, '
    'piedra, amistad…',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
];

// ------------------------------------------------------------ por tipo

/// Comentarios por tipo, para cuando el Pokémon no destaca por sus números.
const Map<String, List<String>> _typeLines = {
  'fire': [
    'Los de tipo fuego suelen pegar fuerte, pero ojo con su defensa.',
    'Fuego le gana a Planta, Hielo, Bicho y Acero. Contra Agua, mejor ni '
        'intentarlo.',
    'Los Pokémon de fuego no pueden quemarse. Práctico, ¿no?',
  ],
  'water': [
    'Agua es el tipo más numeroso de toda la Pokédex. Nunca te faltará uno.',
    'Agua es súper eficaz contra Fuego, Tierra y Roca.',
    'Los de agua sólo temen a Planta y a Eléctrico.',
  ],
  'grass': [
    'Los de planta aguantan bien, aunque tienen cinco debilidades.',
    'Los de planta son inmunes a los polvos y esporas, como Somnífero.',
    'Planta le gana a Agua, Tierra y Roca. Un buen comodín.',
  ],
  'electric': [
    'Los eléctricos casi siempre destacan en velocidad. Mira el radar.',
    'Los de tipo eléctrico no pueden quedar paralizados.',
    'Su gran pesadilla es Tierra: es inmune a la electricidad.',
  ],
  'psychic': [
    'Los psíquicos viven del ataque especial. Fíjate en el radar.',
    'Siniestro es inmune a los ataques psíquicos. Su archienemigo.',
    'En la primera generación los psíquicos dominaban: casi nada los frenaba.',
  ],
  'dragon': [
    'Los dragón tardan mucho en evolucionar, pero acaban siendo bestias.',
    'Dragón es súper eficaz contra… Dragón. Gana quien pegue primero.',
    'El tipo Hada es inmune a los ataques de tipo Dragón.',
  ],
  'ghost': [
    'Los fantasma tienen inmunidades que los hacen muy incómodos de enfrentar.',
    'Normal y Lucha no le hacen nada a un fantasma.',
    'A los fantasma no se les puede impedir huir de un combate.',
  ],
  'steel': [
    'Acero es el tipo con más resistencias del juego. Una muralla.',
    'Los de acero no se pueden envenenar.',
    'Acero llegó en la segunda generación, junto con Siniestro.',
  ],
  'fairy': [
    'El tipo hada es el más nuevo: llegó en la sexta generación para frenar '
        'a los dragones.',
    'Hada es inmune a Dragón y fuerte contra Lucha y Siniestro.',
    'Clefairy era de tipo Normal hasta que llegó el tipo Hada.',
  ],
  'rock': [
    'Los de roca son lentos y duros. Clásico intercambio.',
    'En una tormenta de arena, los de roca suben su Defensa Especial.',
    'Roca es fuerte contra Volador, Fuego, Hielo y Bicho.',
  ],
  'ice': [
    'Hielo pega muchísimo, pero se defiende fatal. Vidrio de cañón.',
    'Hielo es súper eficaz contra Dragón: el mejor antídoto.',
    'Los de hielo no se congelan, y con nieve suben su Defensa.',
  ],
  'bug': [
    'Los bicho evolucionan muy pronto. Son los primeros que llenan la Pokédex.',
    'Bicho es súper eficaz contra Planta, Psíquico y Siniestro.',
    'Caterpie ya es Butterfree en el nivel 10. Nadie evoluciona tan rápido.',
  ],
  'fighting': [
    'Los de lucha tienen ataque físico de sobra y poco más. Directos.',
    'Lucha es súper eficaz contra Normal, Roca, Acero, Hielo y Siniestro.',
    'Un consejo: los golpes de Lucha no le hacen nada a los fantasma.',
  ],
  'poison': [
    'Veneno era durísimo en la primera generación; hoy está más calmado.',
    'Veneno es uno de los dos tipos fuertes contra Hada.',
    'Los de tipo veneno no pueden envenenarse.',
  ],
  'ground': [
    'Los de tierra son inmunes a los ataques eléctricos.',
    'Tierra es súper eficaz contra cinco tipos: Fuego, Eléctrico, Veneno, '
        'Roca y Acero.',
    'Pero ojo: los voladores esquivan los ataques de tierra.',
  ],
  'flying': [
    'Casi ningún Pokémon es sólo volador: casi siempre va de segundo tipo.',
    'Los voladores son inmunes a los ataques de tipo Tierra.',
    'Volador es fuerte contra Planta, Bicho y Lucha.',
  ],
  'normal': [
    'Normal no resiste nada, pero es inmune a los ataques Fantasma.',
    'Los de tipo normal sólo tienen una debilidad: Lucha.',
    'Normal es el tipo de los Pokémon de las primeras rutas, como Rattata o '
        'Pidgey.',
  ],
  'dark': [
    'El tipo siniestro no existía en la primera generación. Llegó para parar '
        'a los psíquicos.',
    'Siniestro es inmune a los ataques psíquicos.',
    'Siniestro es débil a Lucha, Bicho y Hada.',
  ],
};

/// Al filtrar por un tipo.
const Map<String, String> _typeFilterLines = {
  'fire': '¡Fuego! Ojo, que aquí hace calor. Estos son todos los de tipo fuego.',
  'water': 'Agua es el tipo con más Pokémon. Prepárate para bajar un buen rato.',
  'grass': 'Los de planta. Fíjate cuántos son también de tipo veneno.',
  'electric': '¡Eléctricos! Pikachu no es el único, ya verás.',
  'psychic': 'Los psíquicos. Muchos legendarios están aquí.',
  'dragon': 'Dragones: pocos, pero casi todos muy fuertes.',
  'ghost': 'Los fantasma… ¿se te erizó la piel? A mí sí.',
  'steel': 'Acero: los más duros de toda la Pokédex.',
  'fairy': 'Tipo hada. Varios Pokémon antiguos se cambiaron a este tipo.',
  'rock': 'Los de roca. Muchos fósiles están aquí.',
  'ice': 'Hielo: de los tipos con menos Pokémon.',
  'bug': 'Los bicho. Muchos evolucionan antes del nivel 10.',
  'fighting': 'Lucha: puro músculo.',
  'poison': 'Veneno. Aquí están Gengar y compañía.',
  'ground': 'Tierra: los únicos inmunes a la electricidad.',
  'flying': 'Voladores. Casi todos tienen otro tipo además de este.',
  'normal': 'Normal: aquí están Snorlax, Eevee y muchos clásicos.',
  'dark': 'Siniestro. Los rebeldes de la Pokédex.',
};

// ---------------------------------------------------- datos de Pokémon

/// Datos curiosos de Pokémon concretos: se dicen la primera vez que se abre
/// su ficha en la sesión, por encima de los comentarios genéricos.
const Map<int, KarenStep> _trivia = {
  1: KarenStep(
    'Bulbasaur es el número 001. La semilla de su lomo crece con él gracias '
    'a la luz del sol.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  4: KarenStep(
    'La llama de la cola de Charmander dice cómo se siente: arde más fuerte '
    'cuando está emocionado.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  6: KarenStep(
    'Charizard parece dragón, pero es Fuego y Volador. Sólo su megaevolución X '
    'se vuelve tipo Dragón.',
    mood: KarenMood.think,
    emote: KarenEmote.exclaim,
  ),
  7: KarenStep(
    'Squirtle se mete en su caparazón para defenderse y desde ahí lanza agua '
    'a presión.',
    mood: KarenMood.happy,
    emote: KarenEmote.idea,
  ),
  25: KarenStep(
    '¡Pikachu! Guarda electricidad en las bolsitas rojas de sus mejillas.',
    mood: KarenMood.cheer,
    emote: KarenEmote.heart,
  ),
  26: KarenStep(
    'Raichu tiene una forma de Alola que es Eléctrico y Psíquico, y surfea '
    'sobre su cola.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  39: KarenStep(
    'Jigglypuff canta una nana que duerme a cualquiera. Y se enoja si su '
    'público se duerme.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
  ),
  52: KarenStep(
    'A Meowth le encantan las cosas que brillan, sobre todo las monedas.',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
  ),
  54: KarenStep(
    'Psyduck vive con dolor de cabeza. Cuando empeora, desata poderes '
    'psíquicos que ni él controla.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
  63: KarenStep(
    'Abra duerme unas 18 horas al día, y se teletransporta aunque esté dormido.',
    mood: KarenMood.sleepy,
    emote: KarenEmote.zzz,
  ),
  94: KarenStep(
    'Dicen que si de pronto sientes frío, puede haber un Gengar escondido en '
    'tu sombra…',
    mood: KarenMood.surprise,
    emote: KarenEmote.sweat,
  ),
  104: KarenStep(
    'Cubone lleva puesto el cráneo de su madre. Es de las entradas más tristes '
    'de la Pokédex.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
  129: KarenStep(
    'Magikarp es famoso por ser débil, pero en el nivel 20 se convierte en '
    'Gyarados.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
  ),
  130: KarenStep(
    'Gyarados es la prueba de que entrenar a Magikarp valía la pena.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  131: KarenStep(
    'Lapras lleva personas sobre su caparazón para cruzar el mar.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  132: KarenStep(
    'Ditto puede transformarse en cualquier Pokémon. Por eso en los juegos '
    'puede criar con casi todos.',
    mood: KarenMood.happy,
    emote: KarenEmote.question,
  ),
  133: KarenStep(
    'Eevee tiene ocho evoluciones distintas, más que ningún otro Pokémon. '
    'Míralas en la pestaña Evolución.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  143: KarenStep(
    'Snorlax come unos 400 kilos de comida al día y después se echa a dormir. '
    'Mi ídolo.',
    mood: KarenMood.sleepy,
    emote: KarenEmote.zzz,
  ),
  144: KarenStep(
    'Articuno es una de las tres aves legendarias de Kanto, la del hielo.',
    mood: KarenMood.surprise,
    emote: KarenEmote.sparkle,
  ),
  145: KarenStep(
    'Zapdos, el ave legendaria del trueno. Dicen que aparece entre nubes de '
    'tormenta.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  146: KarenStep(
    'Moltres, el ave legendaria del fuego. Cada aleteo suyo suelta llamas.',
    mood: KarenMood.surprise,
    emote: KarenEmote.sparkle,
  ),
  147: KarenStep(
    'Durante mucho tiempo se creyó que Dratini era un mito, hasta que '
    'encontraron una colonia bajo el agua.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
  149: KarenStep(
    'Dicen que Dragonite puede dar la vuelta al mundo en unas 16 horas.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  150: KarenStep(
    'Mewtwo fue creado por científicos a partir del ADN de Mew.',
    mood: KarenMood.worry,
    emote: KarenEmote.exclaim,
  ),
  151: KarenStep(
    'Se dice que Mew lleva el código genético de todos los Pokémon.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  172: KarenStep(
    'Pichu todavía no controla su electricidad: a veces se da toques a sí '
    'mismo.',
    mood: KarenMood.happy,
    emote: KarenEmote.sweat,
  ),
  196: KarenStep(
    'Eevee evoluciona en Espeon si tiene mucha amistad de día. De noche, sale '
    'Umbreon.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  197: KarenStep(
    'Umbreon es la evolución nocturna de Eevee. Sus anillos brillan en la '
    'oscuridad.',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
  ),
  201: KarenStep(
    'Hay 28 formas de Unown: las 26 letras, más los signos ! y ?.',
    mood: KarenMood.think,
    emote: KarenEmote.question,
  ),
  249: KarenStep(
    'Lugia vive en lo más profundo del mar. Dicen que un aleteo suyo provoca '
    'tormentas.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  250: KarenStep(
    'Cuenta la leyenda que quien ve a Ho-Oh alcanza la felicidad eterna.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  251: KarenStep(
    'Celebi puede viajar en el tiempo. Dicen que sólo aparece en épocas de paz.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  282: KarenStep(
    'Gardevoir protege a su entrenador con todo. Puede crear pequeños agujeros '
    'negros.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  349: KarenStep(
    'Feebas parece poca cosa, pero evoluciona en Milotic, uno de los Pokémon '
    'más bellos.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
  ),
  350: KarenStep(
    'Milotic tiene fama de ser el Pokémon más bello de todos.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  359: KarenStep(
    'La gente creía que Absol traía desastres. En realidad aparece para '
    'avisar de ellos.',
    mood: KarenMood.worry,
    emote: KarenEmote.exclaim,
  ),
  384: KarenStep(
    'Rayquaza vive en la capa de ozono y casi nunca baja a tierra.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  445: KarenStep(
    'Garchomp vuela tan rápido como un avión de combate.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  448: KarenStep(
    'Lucario percibe el aura, la energía que emiten todos los seres vivos.',
    mood: KarenMood.point,
    emote: KarenEmote.sparkle,
  ),
  493: KarenStep(
    'Según la mitología Pokémon, Arceus creó el universo.',
    mood: KarenMood.surprise,
    emote: KarenEmote.sparkle,
  ),
  570: KarenStep(
    'Zorua se disfraza con ilusiones: puede hacerse pasar por otro Pokémon o '
    'por una persona.',
    mood: KarenMood.think,
    emote: KarenEmote.question,
  ),
  658: KarenStep(
    'Greninja lanza estrellas ninja hechas de agua comprimida.',
    mood: KarenMood.point,
    emote: KarenEmote.exclaim,
  ),
  700: KarenStep(
    'Sylveon envuelve con sus lazos a quien quiere calmar. Es la evolución '
    'Hada de Eevee.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  722: KarenStep(
    'Rowlet puede girar la cabeza casi media vuelta para mirar atrás.',
    mood: KarenMood.happy,
    emote: KarenEmote.question,
  ),
  778: KarenStep(
    'Mimikyu se disfraza de Pikachu porque quiere hacer amigos. No mires '
    'debajo del disfraz…',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
  887: KarenStep(
    'Dragapult lanza a sus Dreepy como si fueran misiles. Ellos se divierten.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
  906: KarenStep(
    'Sprigatito huele dulce, y se pasa el día acicalándose. Igual que yo.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
  ),
  1025: KarenStep(
    'Pecharunt es el 1025: el último de esta Pokédex. ¡Llegaste al final!',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
};

// ------------------------------------------------------------- consejos

const List<KarenStep> _tips = [
  KarenStep(
    'El botón "Al azar" de abajo abre un Pokémon cualquiera. Es la mejor forma '
    'de encontrar alguno que no conocías.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [132],
  ),
  KarenStep(
    'Dentro de una ficha puedes deslizar a los lados para pasar al siguiente '
    'Pokémon sin volver a la lista.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
    companions: [16],
  ),
  KarenStep(
    'En la computadora también funcionan las flechas del teclado para pasar '
    'de ficha, y Esc para volver.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [137],
  ),
  KarenStep(
    'El radar de estadísticas usa siempre la misma escala, de 0 a 255. Por eso '
    'puedes comparar dos Pokémon de un vistazo.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [65],
  ),
  KarenStep(
    '¿Sabías que el peso sale en hectogramos en la API? Yo ya te lo paso a '
    'kilos para que no tengas que dividir.',
    mood: KarenMood.happy,
    emote: KarenEmote.idea,
    companions: [143],
  ),
  KarenStep(
    'Las habilidades con el ojito tachado son ocultas: en los juegos no salen '
    'normalmente.',
    mood: KarenMood.point,
    emote: KarenEmote.exclaim,
    companions: [448],
  ),
  KarenStep(
    'En la cadena evolutiva puedes tocar cualquier forma para saltar a su '
    'ficha.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
    companions: [133, 196],
  ),
  KarenStep(
    'Si la música te distrae, el botón de la nota la apaga. Los efectos tienen '
    'su propio botón al lado.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
    companions: [39],
  ),
  KarenStep(
    'Eevee tiene la cadena evolutiva más ramificada de todas. Búscalo con el '
    'número 133.',
    mood: KarenMood.surprise,
    emote: KarenEmote.sparkle,
    companions: [133],
  ),
  KarenStep(
    'Los tipos no son sólo un color: filtran de verdad. Prueba a cruzar el '
    'buscador con un tipo.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [94],
  ),
  KarenStep(
    'En la ficha, el botón "Animado" muestra a cada Pokémon moviéndose como '
    'en un combate.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
    companions: [6],
  ),
  KarenStep(
    'Toca al Pokémon en su ficha para oír su grito. Cada uno suena distinto.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
    companions: [25],
  ),
  KarenStep(
    'La música cambia según el tipo del Pokémon que abres. Los legendarios '
    'tienen su propio tema.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
    companions: [150],
  ),
  KarenStep(
    'Un equipo clásico tiene seis Pokémon. ¿Ya armaste el tuyo con el corazón?',
    mood: KarenMood.point,
    emote: KarenEmote.heart,
    companions: [25, 6],
  ),
  KarenStep(
    'Si buscas "#150" o "150" llegas directo a Mewtwo. El número también '
    'cuenta.',
    mood: KarenMood.think,
    emote: KarenEmote.idea,
    companions: [150],
  ),
  KarenStep(
    'La Pokédex nacional tiene nueve generaciones. La primera llega hasta el '
    '151, Mew.',
    mood: KarenMood.point,
    emote: KarenEmote.thought,
    companions: [151],
  ),
  KarenStep(
    'Los iniciales de Kanto son Bulbasaur, Charmander y Squirtle: 001, 004 y '
    '007.',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
    companions: [1, 4, 7],
  ),
  KarenStep(
    'Pikachu no siempre iba a ser la mascota: al principio el anime iba a '
    'girar en torno a Clefairy.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [35, 25],
  ),
  KarenStep(
    'Algunos Pokémon sólo evolucionan por intercambio, como Machoke o Haunter.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [67, 93],
  ),
  KarenStep(
    'El porcentaje de "Captura" de la ficha dice qué tan fácil es atraparlo. '
    'Los legendarios suelen tenerlo bajísimo.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [144],
  ),
  KarenStep(
    'Ser shiny no cambia las estadísticas. Sólo el color… y lo presumible.',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
    companions: [130],
  ),
  KarenStep(
    'Toca tu foto, arriba a la derecha, para repetir mi guía o apagar mis '
    'consejos.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Lo que ya viste se guarda: la próxima vez la Pokédex abre al instante, '
    'aunque vayas sin conexión.',
    mood: KarenMood.happy,
    emote: KarenEmote.idea,
    companions: [137],
  ),
  KarenStep(
    'Los tipos se combinan: un Pokémon puede tener hasta dos. Mira las '
    'etiquetas de cada tarjeta.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [6],
  ),
  KarenStep(
    'Hay Pokémon con la misma forma y distinto tipo según la región, como el '
    'Vulpix de Alola, que es de hielo.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [37],
  ),
  KarenStep(
    'Wobbuffet no ataca: sólo devuelve los golpes. Raro, pero efectivo.',
    mood: KarenMood.happy,
    emote: KarenEmote.question,
    companions: [202],
  ),
  KarenStep(
    'Shedinja tiene un solo punto de vida. Pero es inmune a casi todo.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
    companions: [292],
  ),
  KarenStep(
    'Blissey tiene 255 de PS base, de los más altos de toda la Pokédex.',
    mood: KarenMood.point,
    emote: KarenEmote.heart,
    companions: [242],
  ),
  KarenStep(
    'Ninjask es de los Pokémon más rápidos. Mira su barra de velocidad.',
    mood: KarenMood.point,
    emote: KarenEmote.exclaim,
    companions: [291],
  ),
  KarenStep(
    'Shuckle tiene una de las defensas más altas de todas, pero es lentísimo.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [213],
  ),
  KarenStep(
    '¿Te aburriste? Prueba a abrir tres al azar seguidos y quédate con tu '
    'favorito.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Sigo aquí. Si quieres silencio, apaga mis consejos desde tu perfil. '
    'No me ofendo… mucho.',
    mood: KarenMood.sleepy,
    emote: KarenEmote.zzz,
  ),
];

// ------------------------------------------------------- filtros nuevos

/// Al filtrar por generación.
const Map<int, KarenStep> _generationLines = {
  1: KarenStep(
    'Kanto, donde empezó todo: 151 Pokémon y una Pokédex en la que cabía el '
    'mundo entero.',
    mood: KarenMood.happy,
    emote: KarenEmote.heart,
    companions: [1, 4, 7],
  ),
  2: KarenStep(
    'Johto trajo el día y la noche, los bebés y los primeros shiny. Y a Togepi, '
    'que nunca se sabe qué va a hacer.',
    mood: KarenMood.point,
    emote: KarenEmote.sparkle,
    companions: [152, 155, 158],
  ),
  3: KarenStep(
    'Hoenn: mucha agua, habilidades por primera vez y la pelea de Kyogre '
    'contra Groudon.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [252, 255, 258],
  ),
  4: KarenStep(
    'Sinnoh, la región de los mitos: Dialga, Palkia, Giratina… y Arceus, que '
    'según la leyenda creó todo.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
    companions: [387, 390, 393],
  ),
  5: KarenStep(
    'Teselia arrancó con 156 Pokémon nuevos y ninguno antiguo en la historia. '
    'Valiente, ¿no?',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [495, 498, 501],
  ),
  6: KarenStep(
    'Kalos estrenó el tipo Hada y las megaevoluciones. Mira la categoría '
    '"Megaevoluciones" en los filtros.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
    companions: [650, 653, 656],
  ),
  7: KarenStep(
    'Alola: formas regionales, ultraentes de otra dimensión y Pokémon que '
    'cambian con el clima de las islas.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
    companions: [722, 725, 728],
  ),
  8: KarenStep(
    'Galar, la región del Dinamax: Pokémon gigantes en estadios llenos. Busca '
    'la categoría "Gigamax".',
    mood: KarenMood.cheer,
    emote: KarenEmote.exclaim,
    companions: [810, 813, 816],
  ),
  9: KarenStep(
    'Paldea, mundo abierto y Pokémon paradoja: parientes del pasado y del '
    'futuro de Pokémon que ya conoces.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [906, 909, 912],
  ),
};

/// Al filtrar por categoría (clave = nombre del `DexCategory`).
const Map<String, String> _categoryLines = {
  'starter': 'Los iniciales: el primer amigo de cada entrenador. ¿Cuál escogiste tú?',
  'legendary': 'Los legendarios. Cada uno tiene su propia leyenda y casi siempre '
      'su propia canción.',
  'mythical': 'Los singulares: antes sólo se conseguían en eventos especiales. '
      'Mew fue el primero, escondido en el juego sin que nadie lo supiera.',
  'pseudo': 'Pseudolegendarios: tres etapas, 600 puntos de base y mucha '
      'paciencia para criarlos. Casi todos son dragones.',
  'ultraBeast': 'Ultraentes: llegaron por agujeros en el cielo de Alola. Ni '
      'siquiera se sabe si son Pokémon como los demás.',
  'paradox': 'Pokémon paradoja: versiones del pasado y del futuro. Electrofuria es '
      'el Raikou prehistórico, por ejemplo. ¡Ábrelos y mira de quién son pariente!',
  'baby': 'Los bebés: nacen de un huevo y suelen evolucionar con amistad. '
      'Cuidado, que son adorables.',
  'fossil': 'Revividos de un fósil. Algunos de Galar se armaron con dos mitades '
      'de fósiles distintos… y se nota.',
  'regional': 'Formas regionales: el mismo Pokémon adaptado a otra región. Vulpix '
      'en Alola se volvió de hielo por el frío de la montaña.',
  'mega': 'Megaevoluciones: con su megapiedra cambian de aspecto y se vuelven '
      'mucho más fuertes, pero sólo durante el combate.',
  'gmax': 'Gigamax: en Galar algunos Pokémon crecen hasta ser enormes y cambian '
      'de forma. Snorlax gigamax tiene un bosque en la panza.',
  'otherForms': 'Otras formas: Giratina Origen, Kyogre Primigenio, Deoxys y sus '
      'formas… cada una con sus propias estadísticas.',
};

const List<KarenStep> _monoTypeLines = [
  KarenStep(
    'Monotipo: Pokémon de un solo tipo. Combínalo con un tipo de la barra y '
    'te quedan los puros, como los de fuego puro.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Los de un solo tipo tienen menos debilidades que combinar… pero también '
    'menos resistencias.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
];

const List<KarenStep> _dualTypeLines = [
  KarenStep(
    'Doble tipo: dos tipos a la vez. Hay combinaciones que se anulan '
    'debilidades. Míralo en Stats, en "Debilidades".',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'Con dos tipos, un ataque puede hacer cuatro veces el daño. Ojo con los '
    'que tienen un ×4 en la tabla.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
  ),
];

// ---------------------------------------------------------------- formas

/// Al cambiar de forma en la ficha (clave = `FormKind.name`).
const Map<String, List<KarenStep>> _formLines = {
  'mega': [
    KarenStep(
      '¡Megaevolución! {name} ahora tiene otras estadísticas y a veces hasta otro '
      'tipo. Mira la pestaña Stats.',
      mood: KarenMood.cheer,
      emote: KarenEmote.exclaim,
    ),
    KarenStep(
      '{name}. En los juegos sólo un Pokémon por combate puede megaevolucionar. '
      'Elige bien.',
      mood: KarenMood.surprise,
      emote: KarenEmote.sparkle,
    ),
    KarenStep(
      '¡Qué brillo! {name}. La megapiedra y el Megaaro tienen que estar en '
      'sintonía.',
      mood: KarenMood.happy,
      emote: KarenEmote.sparkle,
    ),
  ],
  'gmax': [
    KarenStep(
      '{name}. ¡Mira qué tamaño! Gigamax sólo dura tres turnos, pero qué tres '
      'turnos.',
      mood: KarenMood.surprise,
      emote: KarenEmote.exclaim,
    ),
    KarenStep(
      '{name}: los gigamax tienen su propio movimiento Max, más fuerte que el '
      'de un Dinamax normal.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
    ),
  ],
  'primal': [
    KarenStep(
      '{name}. La regresión primigenia lo devuelve a su forma ancestral: así era '
      'cuando moldeaba los océanos y los continentes.',
      mood: KarenMood.surprise,
      emote: KarenEmote.exclaim,
    ),
  ],
  'regional': [
    KarenStep(
      '{name}. Mismo Pokémon, otra región: el clima y la comida lo cambiaron '
      'por completo.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
    ),
    KarenStep(
      '{name}. Fíjate en los tipos: las formas regionales a veces cambian hasta '
      'de tipo.',
      mood: KarenMood.think,
      emote: KarenEmote.thought,
    ),
    KarenStep(
      '¡{name}! Me encantan las formas regionales. Es como ver a un amigo que '
      'volvió de vacaciones muy cambiado.',
      mood: KarenMood.happy,
      emote: KarenEmote.heart,
    ),
  ],
  'other': [
    KarenStep(
      '{name}. Algunas formas cambian sólo el aspecto; otras, también las '
      'estadísticas y el tipo.',
      mood: KarenMood.point,
      emote: KarenEmote.idea,
    ),
    KarenStep(
      'Forma nueva: {name}. Compara las estadísticas con la forma normal, a veces '
      'cambian muchísimo.',
      mood: KarenMood.think,
      emote: KarenEmote.thought,
    ),
  ],
};

const List<KarenStep> _movesTabLines = [
  KarenStep(
    'Estos son sus movimientos, por nivel, por MT, por huevo y por tutor. Toca '
    'uno para leer qué hace.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
  ),
  KarenStep(
    'El número de la izquierda es el nivel al que lo aprende. "Evo." es al '
    'evolucionar.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
];

/// Al ver una evolución que no es sólo subir de nivel. {how} es la frase
/// completa ("Eevee evoluciona en Vaporeon al usarle una Piedra agua").
const List<String> _specialEvolutionLines = [
  'Ojo con esta: {how}. No basta con subir de nivel.',
  'Dato: {how}. ¡Más de un entrenador se quedó esperando sin saberlo!',
  'Esta evolución tiene truco: {how}.',
];

const List<KarenStep> _battleTabHint = [
  KarenStep(
    '¿Quieres probar sus ataques? El botón "Combate" de arriba te deja '
    'atacarme. Prometo no quejarme… mucho.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
];

const List<KarenStep> _newFeatureTips = [
  KarenStep(
    'En "Filtros", junto al buscador, puedes ver sólo una generación, los '
    'legendarios, los paradoja o las megaevoluciones.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [6, 150],
  ),
  KarenStep(
    'Si un Pokémon tiene formas, salen debajo de su nombre en la ficha: megas, '
    'regionales, gigamax, los 18 tipos de Arceus…',
    mood: KarenMood.point,
    emote: KarenEmote.sparkle,
    companions: [493],
  ),
  KarenStep(
    'En la ficha, el botón "Combate" te deja atacarme con sus movimientos de '
    'verdad. Me duele en el alma, pero aprenderás de tipos.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
    companions: [25],
  ),
  KarenStep(
    'En Stats, abajo del todo, está la tabla de debilidades: qué le hace el '
    'doble de daño y qué no le hace nada.',
    mood: KarenMood.point,
    emote: KarenEmote.idea,
    companions: [130],
  ),
  KarenStep(
    'Busca "paradoja" en los filtros: Electrofuria es el Raikou prehistórico, y '
    'Ferropaladín el Gardevoir del futuro.',
    mood: KarenMood.surprise,
    emote: KarenEmote.exclaim,
    companions: [1021, 1006],
  ),
  KarenStep(
    'Toca una habilidad en la ficha y te digo qué hace. Algunas cambian el '
    'combate por completo.',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
    companions: [149],
  ),
];

const List<KarenStep> _battleWonLines = [
  KarenStep(
    '¡Me ganaste con {name}! Voy a necesitar un día libre. Mejor una semana.',
    mood: KarenMood.worry,
    emote: KarenEmote.sweat,
  ),
  KarenStep(
    'Ese {name} pega fuerte. Mi espalda lo confirma. ¡Buen combate!',
    mood: KarenMood.happy,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Perdí, pero aprendiste de tipos. Eso cuenta como victoria para las dos. ¿No?',
    mood: KarenMood.think,
    emote: KarenEmote.thought,
  ),
  KarenStep(
    'Ya me curé en el Centro Pokémon. La próxima vez me disfrazo de algo más resistente.',
    mood: KarenMood.cheer,
    emote: KarenEmote.heart,
  ),
];

const List<KarenStep> _battleFledLines = [
  KarenStep(
    '¿Ya te vas? Justo cuando le estaba agarrando el gusto… a esquivar.',
    mood: KarenMood.happy,
    emote: KarenEmote.notes,
  ),
  KarenStep(
    'Empate técnico. Yo digo que gané porque sigo de pie.',
    mood: KarenMood.cheer,
    emote: KarenEmote.sparkle,
  ),
  KarenStep(
    'Huir también es estrategia. Te espero cuando quieras la revancha.',
    mood: KarenMood.wave,
    emote: KarenEmote.heart,
  ),
];

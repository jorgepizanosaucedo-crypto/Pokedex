/// Lo que dice Karen durante el combate. Todo en tono de comedia: ella
/// recibe los golpes y se queja con dignidad (o sin ella).
///
/// {name} = Pokémon, {move} = movimiento, {type} = tipo del disfraz de Karen.
library;

const List<String> kBattleStart = [
  '¿Combate? ¿Contra mí? Bueno… me puse mi disfraz de tipo {type}. Sé gentil, {name}.',
  'Hoy voy de tipo {type}. Lo elegí porque combina con mis zapatos, no por estrategia.',
  'Muy bien, {name}. Tipo {type} activado. Si lloro, es por la emoción.',
  'Me pongo el disfraz de tipo {type} y… ¿por qué me miras así, {name}?',
  'Reglas: tú atacas, yo me quejo. Disfraz de tipo {type} listo. ¡Adelante!',
  'Tipo {type}, de pies a cabeza. Leí en un blog que era muy resistente. Ojalá.',
];

const List<String> kHitNormal = [
  '¡Auch! Eso dolió… pero con elegancia.',
  '¡Oye! Me despeinaste.',
  'Estoy bien, estoy bien. Sólo se me cayó la dignidad.',
  '¡Uf! Un golpe honesto. Respeto.',
  'Eso me va a dejar marca. Y una historia para contar.',
  '¿{move}? Ya veo por qué lo aprende.',
  '¡Ay! Anoto: {name} no se anda con rodeos.',
  'Duele, pero sigo de pie. Más o menos de pie.',
  'Ese {move} fue directo a mi autoestima.',
  '¡Ahí va mi peinado de una hora!',
];

const List<String> kHitSuper = [
  '¡¿SÚPER EFICAZ?! ¡Nadie me dijo que el tipo {type} era débil a eso!',
  '¡AAAH! Ok, ok, el disfraz de tipo {type} fue mala idea.',
  'Eso fue el doble de daño. Lo sé porque me duele el doble.',
  '¡Mi disfraz! ¡Mi pobre disfraz de tipo {type}!',
  '¡Súper eficaz! Toma nota: así se aprovechan las debilidades. Yo tomo una curita.',
  '¿Quién me mandó vestirme de tipo {type} contra {name}? Ah, sí, yo.',
  '¡Eso me mandó a la siguiente región!',
  '¡Ay, ay, ay! Tabla de tipos uno, Karen cero.',
];

const List<String> kHitWeak = [
  'Je. ¿Eso fue un ataque o un masaje? No es muy eficaz contra el tipo {type}.',
  'Mi disfraz de tipo {type} lo aguanta todo. Bueno, eso al menos.',
  'Cosquillas. Puras cosquillas.',
  '¡Ja! El tipo {type} resiste eso. Estudié… un poco.',
  'Eso no fue muy eficaz. Te recomiendo revisar la tabla de debilidades.',
  '¿Ya empezaste? Ni lo sentí.',
];

const List<String> kHitImmune = [
  '¡No me hizo nada! El tipo {type} es inmune. Soy intocable. Soy leyenda.',
  'Nada. Cero. Ni un rasguño. ¿Ves? Por eso hay que estudiar los tipos.',
  '¡Ja! {move} no afecta al tipo {type}. Me voy a tomar un selfie.',
  'Puedes seguir intentándolo, pero el tipo {type} dice que no.',
];

const List<String> kHitCrit = [
  '¡GOLPE CRÍTICO! ¡Justo en el orgullo!',
  '¡Eso fue crítico! Literalmente y emocionalmente.',
  '¡Crítico! ¿Practicaste ese golpe frente al espejo, {name}?',
  '¡Ay! Le diste justo donde duele. ¿Cómo sabías?',
];

const List<String> kMiss = [
  '¡Fallaste! Mis años de esquivar responsabilidades por fin sirvieron.',
  '¡Ja! Ni me tocaste. Agilidad de entrenadora.',
  'Uy, casi. Muy casi. Pero no.',
  'Me agaché a amarrarme el zapato justo a tiempo. Suerte pura.',
  '¡Fallado! Esa precisión necesita entrenamiento, {name}.',
];

const List<String> kLowHp = [
  'Me queda poca vida… alguien llame a la enfermera Joy.',
  'Estoy en rojo. Así se siente un Pokémon con la barra parpadeando.',
  'Un golpe más y me desmayo con estilo, te lo advierto.',
  'Veo una luz blanca… ah, no, es el Centro Pokémon.',
];

const List<String> kFaint = [
  'Me… rindo… ¡{name} gana! Dile a mis Pokémon que los quiero.',
  '¡Karen se debilitó! Bueno, era cuestión de tiempo. Muy buen combate.',
  'Me voy a acostar aquí un ratito. Tú gana, {name}, tú gana.',
  'K.O. Lo acepto. Lo superaré… algún día. Tal vez mañana.',
  '¡Ganaste! Ahora entiendes por qué los entrenadores llevan pociones.',
];

const List<String> kRematch = [
  '¡Ya me recuperé! Revancha. Esta vez con disfraz de tipo {type}.',
  'Me tomé una poción. Tipo {type} esta vez. Veamos qué pasa.',
  'Nuevo combate, nuevo disfraz de tipo {type}. Nueva yo. Misma suerte, seguramente.',
];

const List<String> kCostume = [
  'Cambio de disfraz: ahora soy tipo {type}. ¿Me queda?',
  'Tipo {type}. Me lo probé en el vestidor y me sentí invencible.',
  'Listo, tipo {type}. A ver qué te parece ahora, {name}.',
];

const List<String> kStatDown = [
  '¿Bajó mi {stat}? Ahora sí estoy en problemas.',
  'Siento mi {stat} más baja. Como mi ánimo los lunes.',
  'Eso bajó mi {stat}. Muy astuto, {name}. Muy astuto.',
];

const List<String> kStatUp = [
  '¿Subió el {stat} de {name}? Eso no me gusta nada.',
  '¡Se está preparando! ¡Esto va a doler!',
  'Uy. {name} se puso serio. Muy serio.',
];

const List<String> kHealed = [
  '¡Eso es trampa! ¿Te curas mientras yo sufro?',
  'Qué bonito, {name} se curó. Yo sigo despeinada.',
];

const List<String> kNothing = [
  '¿Y eso qué fue? No pasó nada. Absolutamente nada.',
  '¡Ja! Un movimiento muy bonito… que no hace nada.',
  'Mmm… ¿era un baile? Lindo, pero no me hizo nada.',
];

/// Al cambiar los movimientos desde la hoja.
const List<String> kNewMoves = [
  '¿Movimientos nuevos? Todos aprendidos legalmente, ¿verdad? …Verdad.',
  'Uy, cambiaste de estrategia. Ya me dio miedo.',
  'Bien elegidos. A ver si sabes usarlos.',
];

/// Bromas para movimientos famosos que en el combate no hacen nada.
const Map<String, List<String>> kMoveQuips = {
  'splash': [
    '¡{name} usó Salpicadura! …Pero no pasó nada. El clásico de los clásicos.',
    'Salpicadura. El movimiento más honesto del juego: promete nada y cumple.',
  ],
  'transform': [
    '¿Te ibas a transformar en mí? Hay una sola Karen, gracias.',
  ],
  'sketch': [
    'Esquema necesita copiar el movimiento que yo usé… y yo no usé nada. Jaque mate.',
  ],
  'celebrate': [
    '¡Feliz cumpleaños a ti también! …Espera, ¿estamos peleando o no?',
  ],
  'hold-hands': [
    '¿Tomarnos de la mano en pleno combate? Qué tierno. Y qué inútil.',
  ],
  'teleport': [
    '¿Teletransportarte? Aquí no hay a dónde ir, {name}.',
  ],
  'happy-hour': [
    'Hora Feliz duplica el dinero que ganas. Aquí sólo te ganas mi respeto.',
  ],
};

/// Estados alterados: lo que dice al recibirlos.
const Map<String, List<String>> kAilment = {
  'burn': [
    '¡Me quemé! ¡Agua, agua! ¿Por qué nadie trae agua?',
    'Quemada. Ahora huelo a malvavisco tostado.',
  ],
  'paralysis': [
    'Me… paralicé… no… puedo… mover… ni… las… cejas.',
    '¡Parálisis! Ahora mismo tengo el pelo de punta. Literal.',
  ],
  'poison': [
    'Envenenada… me siento como después de comer en la feria.',
    '¡Veneno! Me estoy poniendo morada. Combina con mi disfraz, al menos.',
  ],
  'sleep': [
    'Zzz… cinco minutitos más… zzz…',
    'Me dio sueño… ¿esto cuenta como siesta?',
  ],
  'freeze': [
    '¡Con… ge… lada! ¡Pásenme una chamarra!',
    'Soy una paleta helada sabor Karen.',
  ],
  'confusion': [
    '¿Dónde estoy? ¿Quién soy? ¿Por qué hay tres {name}?',
    'Todo da vueltas… ¿alguien más ve pajaritos?',
  ],
  'infatuation': [
    '¡Ay, {name}, qué lindo eres! Digo… ¡concéntrate, Karen!',
    'Me enamoré. No puedo atacar algo tan adorable.',
  ],
  'trap': [
    '¡Quedé atrapada! ¡Esto no estaba en el contrato!',
  ],
  'leech-seed': [
    '¡Me plantaron una semilla! Ahora soy un jardín.',
  ],
};

/// Daño de cada turno por estado.
const Map<String, String> kAilmentTick = {
  'burn': 'Karen sufre por la quemadura…',
  'poison': 'El veneno le resta PS a Karen…',
  'trap': 'Karen sigue atrapada…',
  'leech-seed': 'La semilla le chupa energía a Karen…',
};

/// Los "movimientos" de Karen: no le hacen daño real al Pokémon.
/// (mensaje, frase de Karen, efecto)
enum KarenAction { nothing, heal, lowerAttack, miss }

const List<(String, String, KarenAction)> kKarenMoves = [
  ('Karen usó Chancla voladora.', '¡Toma eso! …¿No le dolió? Era mi chancla favorita.', KarenAction.miss),
  ('Karen usó Sermón de media hora.', 'Y otra cosa: hay que comer verduras. ¡Te bajó el ánimo de pelear!', KarenAction.lowerAttack),
  ('Karen usó Pedir un café.', 'Ahh, cafeína. Ya me siento mejor.', KarenAction.heal),
  ('Karen usó Mirada de desaprobación.', 'Te estoy mirando muy feo. Muy, muy feo.', KarenAction.nothing),
  ('Karen usó Tarea sorpresa.', '¡Para mañana, la tabla de tipos completa! …No le afectó.', KarenAction.nothing),
  ('Karen usó Selfie con flash.', '¡Sonríe! …Creo que lo cegué un poquito.', KarenAction.lowerAttack),
  ('Karen usó Tirar la toalla… pero se arrepintió.', 'No, no, ¡todavía puedo!', KarenAction.nothing),
  ('Karen usó Poción de supermercado.', 'Sabe a fresa artificial, pero funciona.', KarenAction.heal),
  ('Karen usó Abrazo sorpresa.', '¡Ven aquí! …Se escapó. Mal día para los abrazos.', KarenAction.miss),
  ('Karen usó Contar un chiste malo.', '¿Por qué Snorlax no juega? Porque se duerme. …¿Nada?', KarenAction.lowerAttack),
];

const List<String> kKarenAsleep = [
  'Karen está dormida… zzz… murmura algo sobre Snorlax.',
  'Karen sigue dormida. Ronca bajito.',
];

const List<String> kKarenWakes = ['¡Karen se despertó! "¿Me perdí de algo?"'];

const List<String> kKarenParalyzed = ['¡Karen está paralizada! No se puede mover.'];

const List<String> kKarenFrozen = ['Karen está congelada… tirita en silencio.'];

const List<String> kKarenThaws = ['¡Karen se descongeló! "¡Por fin siento los dedos!"'];

const List<String> kKarenHurtsSelf = ['¡Está tan confundida que se golpeó a sí misma!'];

/// Nombres en español de las características, para los mensajes.
const Map<String, String> kStatNames = {
  'attack': 'Ataque',
  'defense': 'Defensa',
  'special-attack': 'Ataque Especial',
  'special-defense': 'Defensa Especial',
  'speed': 'Velocidad',
  'accuracy': 'Precisión',
  'evasion': 'Evasión',
};

/// Nombres de estado para la etiqueta de la barra de PS.
const Map<String, (String, int)> kAilmentBadge = {
  'burn': ('QUE', 0xFFE64A19),
  'paralysis': ('PAR', 0xFFF9A825),
  'poison': ('ENV', 0xFF8E24AA),
  'sleep': ('DOR', 0xFF78909C),
  'freeze': ('CON', 0xFF29B6F6),
  'confusion': ('CNF', 0xFFEC407A),
  'infatuation': ('ENA', 0xFFE91E63),
  'trap': ('ATR', 0xFF6D4C41),
  'leech-seed': ('DRE', 0xFF43A047),
};

/// Frase de estado para el mensaje del combate.
const Map<String, String> kAilmentMessage = {
  'burn': '¡Karen se ha quemado!',
  'paralysis': '¡Karen está paralizada! Quizá no pueda moverse.',
  'poison': '¡Karen ha sido envenenada!',
  'sleep': '¡Karen se ha dormido!',
  'freeze': '¡Karen se ha congelado!',
  'confusion': '¡Karen está confundida!',
  'infatuation': '¡Karen se ha enamorado!',
  'trap': '¡Karen ha quedado atrapada!',
  'leech-seed': '¡Karen ha sido infectada por las drenadoras!',
};

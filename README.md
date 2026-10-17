# Pokédex — consumo de API con Flutter y Dio

Pokédex nacional completa (1025 Pokémon) construida sobre la
[PokeAPI](https://pokeapi.co/api/v2/pokemon/1/), con registro de entrenador,
buscador, filtro por tipo, fichas detalladas, variante shiny, gritos reales,
música que cambia según el tipo del Pokémon y Karen, una mascota que guía y
comenta.

Corresponde a la actividad de consumo de APIs: añadir Dio, hacer la petición de
red, convertir la respuesta en objetos Dart y mostrarlos con Flutter.

## Los cuatro pasos de la práctica

| Paso | Dónde está |
|---|---|
| 1. Dio en las dependencias | [`pubspec.yaml`](pubspec.yaml) → `dio: ^5.11.1` |
| 2. Petición de red (`Future`, `Dio.get`) | [`lib/services/pokeapi_service.dart`](lib/services/pokeapi_service.dart) |
| 3. Respuesta → clase personalizada | [`lib/models/pokemon.dart`](lib/models/pokemon.dart) (`Pokemon.fromJson`) |
| 4. Obtener y mostrar los datos | [`lib/screens/`](lib/screens/) con `FutureBuilder` |

## Cómo ejecutarla

```bash
flutter pub get
flutter run -d chrome     # también: -d windows, -d android
```

### Probarla en el teléfono con GitHub Pages

El repositorio trae [`.github/workflows/pages.yml`](.github/workflows/pages.yml):
en cada push a `main`, GitHub compila la versión web y la publica en
`https://<usuario>.github.io/<repositorio>/`. Sólo hay que activarlo una vez en
**Settings → Pages → Source: GitHub Actions**. Después basta abrir ese enlace en
el teléfono (y, si se quiere, "Agregar a la pantalla de inicio").

En Windows de escritorio, Flutter necesita el **Modo de desarrollador** activado
para los plugins (`start ms-settings:developers`). En Chrome funciona sin eso.

```bash
flutter test       # pruebas del parseo de la PokeAPI
flutter analyze    # análisis estático
```

## Endpoints usados

| Endpoint | Para qué |
|---|---|
| `/pokemon?limit=1025` | lista completa de nombres e ids |
| `/pokemon/{id}/` | tipos, estadísticas, habilidades, arte, grito |
| `/pokemon-species/{id}/` | descripción (en español si existe), categoría, hábitat, si es legendario |
| `/evolution-chain/{id}/` | cadena evolutiva con sus condiciones |
| `/type/{nombre}/` | filtro por tipo con una sola petición |

Las respuestas se guardan en una caché en memoria dentro del servicio, y la
lista y el índice de tipos además se guardan en el dispositivo: a partir de la
segunda apertura la Pokédex aparece al instante, sin esperar a la red.

## Estructura

```
lib/
├── main.dart                     punto de entrada, tema y montaje de Karen
├── models/pokemon.dart           Pokemon, PokemonSpecies, EvolutionStep…
├── services/
│   ├── pokeapi_service.dart      cliente Dio + caché + errores legibles
│   ├── sound_service.dart        efectos de interfaz y gritos
│   ├── music_service.dart        temas por tipo, fundidos y ciclo de vida
│   ├── karen_controller.dart     qué dice la mascota, cuándo y con qué cara
│   ├── profile_store.dart        entrenador: nombre, foto y tipo favorito
│   ├── favorites_store.dart      favoritos persistidos
│   ├── settings_store.dart       música, sonidos y Karen encendidos o no
│   ├── session.dart              cerrar sesión y borrar datos
│   ├── artwork.dart              URLs del arte, tamaños y precarga
│   └── type_index.dart           tipos de los 1025 sin pedir uno por uno
├── theme/app_theme.dart          colores, tipos y tipografía
├── screens/
│   ├── splash_screen.dart        apertura con la pokébola
│   ├── login_screen.dart         registro, hoja de perfil, sesión y datos
│   ├── pokedex_screen.dart       cuadrícula, buscador y filtros
│   └── detail_screen.dart        ficha con pestañas y swipe
└── widgets/
    ├── karen_overlay.dart        la mascota: dibujo, acompañantes y globo
    ├── artwork_image.dart        arte oficial sin parpadeos ni esperas
    ├── stats_view.dart           radar hexagonal y barras
    └── …                         tarjetas, destellos, fondo, avatar
```

## Karen, la mascota

Personaje original cedido por su autor para este proyecto (ver
[`assets/mascota/LICENSE.txt`](assets/mascota/LICENSE.txt)). El dibujo se usa sin
modificar; **no** está bajo la licencia del código.

Con un solo PNG se consigue que parezca viva, animando por capas:

- **El cuerpo** respira siempre, y según el ánimo salta, se inclina, tiembla,
  saluda o se mece. Son transformaciones del contenedor; el dibujo no se toca.
- **A sus costados** la acompañan sprites de Pokémon que entran con un rebote y
  flotan a destiempo. Cambian según de qué esté hablando.
- **Reacciones manga** dibujadas con `CustomPainter` en su misma paleta (tinta
  y rojo): destellos, gota de sudor, `!`, `?`, bombilla, nube de pensamiento,
  corazón, notas y zzz.
- **El globo** se escribe letra por letra con una vocecita por carácter. Dura
  como mucho 2.6 s —los textos largos van más rápido—, el texto completo va
  invisible detrás para que el globo no crezca a saltos, y tocarlo lo completa.
- **Cuándo aparece**: bienvenida, guía paso a paso de la app, al abrir un
  Pokémon, al marcar un favorito, al activar shiny, cuando una búsqueda no da
  resultados, cuando falla la red, y con consejos si te quedas parado.

## Tu sesión y tus datos

Tocar tu foto, arriba a la derecha, abre tu perfil. Desde ahí:

| Opción | Qué hace |
|---|---|
| **Cerrar sesión** | vuelve al registro y olvida tu nombre, foto y equipo |
| **Borrar lo descargado** | vacía la caché de la PokeAPI y de las imágenes; tu perfil se queda |
| **Borrar todos mis datos** | todo lo anterior y además los ajustes: la app queda como recién instalada |

Las dos acciones que no se pueden deshacer piden confirmación con un segundo toque.
También puedes repetir la guía de Karen o apagar sus consejos.

## Detalles de la interfaz

- **Registro de entrenador**: nombre, tipo favorito y foto de perfil libre
  (recortada y reducida a 256 px antes de guardarla). Todo queda en el
  dispositivo; no hay servidor.
- **Apertura animada**: la pokébola cae, rebota, tiembla y se abre en un destello.
- **Fondo vivo**: degradado del color del tipo con orbes y pokébolas flotando,
  pintado en un `CustomPainter` aislado para no repintar el contenido.
- **Música por ambiente**: siete temas chiptune originales sintetizados por
  [`tools/generate_music.py`](tools/generate_music.py). El del mapa suena en la
  lista; al abrir una ficha cambia con fundido cruzado al ambiente de su tipo
  (fuego, agua, planta, eléctrico, siniestro) y los legendarios y singulares
  tienen el suyo, más solemne. Se aparta cuando suena un grito y se calla al
  pasar la app a segundo plano.
- **Presentación del Pokémon**: al abrir una ficha, el arte entra desde el
  costado girando y frenando, y cada 14 segundos se sacude soltando su grito.
- **Shiny**: cambia el arte oficial con una ráfaga de destellos y su sonido.
- **Radar de estadísticas**: hexágono dibujado a mano, escala fija 0–255 para no
  recortar ni exagerar ningún valor; cada eje con su nombre y su número, así la
  lectura nunca depende sólo del color.
- **Swipe entre fichas**: la ficha es un `PageView` sobre la lista filtrada.
- **Estados cubiertos**: carga con marcadores animados, vacío, y error de red con
  mensaje legible y botón de reintento.

### Imágenes sin esperas

El arte oficial son PNG de 475×475: casi 900 KB **ya decodificados** cada uno.
Mostrándolos tal cual, bajar deprisa por los más de mil de la lista desborda el
`ImageCache`, que empieza a expulsar y volver a decodificar, y se ven huecos.

[`artwork.dart`](lib/services/artwork.dart) y
[`artwork_image.dart`](lib/widgets/artwork_image.dart) lo resuelven así:

- **Dos tamaños**: la cuadrícula decodifica a 256 px; la ficha usa el original.
- **Caché en disco** con `cached_network_image` (en web, la del navegador).
- **Precarga**: la cuadrícula construye 1000 px por delante del scroll; al tocar
  una tarjeta se pide el arte grande antes de navegar, y en la ficha se precargan
  los vecinos del swipe y la versión shiny.
- **Sin pantallazo gris**: la ficha muestra al instante la miniatura que ya
  estaba en la tarjeta (el `Hero` la lleva volando) y encima aparece el arte
  grande cuando llega.
- [`main.dart`](lib/main.dart) le da a la caché de imágenes espacio para 600
  imágenes / 200 MB.

La tipografía Poppins va dentro de la app (`assets/fonts`), así que tampoco hay
un parpadeo de texto mientras se descarga.

## Dependencias

| Paquete | Uso |
|---|---|
| `dio` | cliente HTTP |
| `cached_network_image` | arte oficial con caché en disco |
| `audioplayers` | música, efectos de sonido y gritos |
| `flutter_cache_manager` | vaciar la caché de imágenes al borrar datos |
| `shared_preferences` | perfil y favoritos entre sesiones |
| `image_picker` | foto de perfil |

Los sonidos y la música de `assets/` no son de terceros: están sintetizados para este
proyecto con los scripts de [`tools/`](tools/), y se regeneran con
`python tools/generate_music.py` y `python tools/generate_voice.py`.

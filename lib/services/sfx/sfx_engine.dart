/// Motor de efectos cortos. En web usa Web Audio; en el resto de
/// plataformas no hace nada y `SoundService` usa `audioplayers`.
library;

export 'sfx_engine_io.dart' if (dart.library.js_interop) 'sfx_engine_web.dart';

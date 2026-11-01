import 'dart:typed_data';
import 'poster_saver_stub.dart'
    if (dart.library.html) 'poster_saver_web.dart'
    if (dart.library.io) 'poster_saver_io.dart';

class PosterSaver {
  /// Guarda el archivo PNG en el dispositivo (Web, Desktop o Móvil) y devuelve la ruta o nombre
  static Future<String?> save({
    required Uint8List bytes,
    required String fileName,
  }) {
    return savePosterFile(bytes: bytes, fileName: fileName);
  }
}

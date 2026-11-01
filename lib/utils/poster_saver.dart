import 'dart:typed_data';
import 'poster_saver_stub.dart'
    if (dart.library.html) 'poster_saver_web.dart'
    if (dart.library.io) 'poster_saver_io.dart';

class PosterSaver {
  /// Guarda el archivo PNG en el dispositivo (Galería en Móvil, Descargas en PC/Web)
  static Future<String?> save({
    required Uint8List bytes,
    required String fileName,
  }) {
    return savePosterFile(bytes: bytes, fileName: fileName);
  }

  /// Comparte el archivo PNG a través de la hoja nativa del sistema (WhatsApp, Drive, etc.)
  static Future<bool> share({
    required Uint8List bytes,
    required String fileName,
  }) {
    return sharePosterFile(bytes: bytes, fileName: fileName);
  }
}

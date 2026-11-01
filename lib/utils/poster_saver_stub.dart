import 'dart:typed_data';

Future<String?> savePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  throw UnsupportedError('Platform not supported');
}

Future<bool> sharePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  return false;
}

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

Future<String?> savePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    final base64Data = base64Encode(bytes);
    final anchor = html.AnchorElement(href: 'data:image/png;base64,$base64Data')
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    return fileName;
  } catch (e) {
    return null;
  }
}

Future<bool> sharePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  return false;
}

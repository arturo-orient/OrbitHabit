import 'dart:io';
import 'dart:typed_data';

Future<String?> savePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    String? downloadsDir;

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final winDownloads = '$userProfile\\Downloads';
        if (Directory(winDownloads).existsSync()) {
          downloadsDir = winDownloads;
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final unixDownloads = '$home/Downloads';
        if (Directory(unixDownloads).existsSync()) {
          downloadsDir = unixDownloads;
        }
      }
    } else if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (androidDownloads.existsSync()) {
        downloadsDir = androidDownloads.path;
      }
    }

    Directory targetDir;
    if (downloadsDir != null) {
      targetDir = Directory(downloadsDir);
    } else {
      targetDir = Directory.systemTemp;
    }

    final sep = Platform.pathSeparator;
    final filePath = '${targetDir.path}$sep$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (e) {
    try {
      final fallbackPath = '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
      final fallbackFile = File(fallbackPath);
      await fallbackFile.writeAsBytes(bytes, flush: true);
      return fallbackFile.path;
    } catch (_) {
      return null;
    }
  }
}

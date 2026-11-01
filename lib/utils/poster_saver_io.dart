import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

const _mediaChannel = MethodChannel('com.example.orbithabit/media_saver');

Future<String?> savePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid) {
    try {
      final String? result = await _mediaChannel.invokeMethod<String>(
        'saveImageToGallery',
        {
          'bytes': bytes,
          'fileName': fileName,
        },
      );
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } catch (_) {
      // Fallback a escritura tradicional si el canal no respondiera
    }
  }

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

Future<bool> sharePosterFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (Platform.isAndroid) {
    try {
      final bool? result = await _mediaChannel.invokeMethod<bool>(
        'shareImage',
        {
          'bytes': bytes,
          'fileName': fileName,
        },
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
  return false;
}

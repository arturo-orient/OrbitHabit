import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Crea un Shader de gradiente barrido (SweepGradient) perfectamente alineado con un arco
/// con extremos redondeados (`StrokeCap.round`), evitando cualquier corte brusco en las puntas.
Shader _buildArcSweepShader({
  required Offset center,
  required double radius,
  required double strokeWidth,
  required double startAngleRad,
  required double sweepAngleRad,
  required Color startColor,
  required Color endColor,
}) {
  final double capAngle = (strokeWidth * 0.55) / radius;
  final double baseRotation = startAngleRad - capAngle;
  final double totalArcFraction =
      ((sweepAngleRad + (capAngle * 2.0)) / (2.0 * math.pi)).clamp(0.05, 0.95);

  return SweepGradient(
    center: Alignment.center,
    colors: [startColor, startColor, endColor, endColor],
    stops: [
      0.0,
      (capAngle / (2.0 * math.pi)).clamp(0.0, totalArcFraction * 0.2),
      totalArcFraction,
      1.0,
    ],
    transform: GradientRotation(baseRotation),
  ).createShader(Rect.fromCircle(center: center, radius: radius));
}

void _drawArcWithShadow({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required double strokeWidth,
  required double startAngleRad,
  required double sweepAngleRad,
  required Color startColor,
  required Color endColor,
  required double scale,
}) {
  final Rect rect = Rect.fromCircle(center: center, radius: radius);

  // Sombra cálida sutil debajo del anillo para relieve táctil sobre fondo claro
  final Paint shadowPaint = Paint()
    ..color = startColor.withValues(alpha: 0.20)
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 * scale)
    ..isAntiAlias = true;

  canvas.save();
  canvas.translate(0, 7.0 * scale);
  canvas.drawArc(rect, startAngleRad, sweepAngleRad, false, shadowPaint);
  canvas.restore();

  final Paint arcPaint = Paint()
    ..shader = _buildArcSweepShader(
      center: center,
      radius: radius,
      strokeWidth: strokeWidth,
      startAngleRad: startAngleRad,
      sweepAngleRad: sweepAngleRad,
      startColor: startColor,
      endColor: endColor,
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  canvas.drawArc(rect, startAngleRad, sweepAngleRad, false, arcPaint);
}

/// Renderiza vectorialmente el icono "Nordic Sage & Dual-Ring Minimal" a cualquier resolución [size],
/// escalando proporcionalmente desde el lienzo maestro de 1024x1024 px.
///
/// Cumple estrictamente la Safe Zone de Android Adaptive Icons y Web Maskable Icons.
Future<Uint8List> renderNordicSageOrbitalIcon({
  required int size,
  required bool includeBackground,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );

  final double scale = size / 1024.0;
  final Offset center = Offset(512.0 * scale, 512.0 * scale);
  const double degToRad = math.pi / 180.0;

  // 1. Fondo Bruma Salvia Nórdica (#F7FCFA -> #DCECE6)
  if (includeBackground) {
    final bgRect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        540.0 * scale,
        const [Color(0xFFF7FCFA), Color(0xFFDCECE6)],
        const [0.0, 1.0],
      );
    canvas.drawRect(bgRect, bgPaint);
  }

  // Geometrías de los 2 anillos concéntricos gruesos
  final double r1 = 232.0 * scale;
  final double w1 = 60.0 * scale;

  final double r2 = 144.0 * scale;
  final double w2 = 52.0 * scale;

  // 2. Carriles Guía Orbitales (Tracks de fondo completos al 8% de opacidad)
  final Paint trackPaint = Paint()
    ..color = const Color(0x14193832)
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  canvas.drawCircle(center, r1, trackPaint..strokeWidth = w1);
  canvas.drawCircle(center, r2, trackPaint..strokeWidth = w2);

  // 3. Anillo Exterior (Radio 232px, grosor 60px):
  // Esmeralda Bosque (#1B665C) -> Turquesa Salvia (#43A899)
  _drawArcWithShadow(
    canvas: canvas,
    center: center,
    radius: r1,
    strokeWidth: w1,
    startAngleRad: -15.0 * degToRad,
    sweepAngleRad: 250.0 * degToRad,
    startColor: const Color(0xFF1B665C),
    endColor: const Color(0xFF43A899),
    scale: scale,
  );

  // 4. Anillo Interior (Radio 144px, grosor 52px):
  // Coral Terracota (#DF5C57) -> Melocotón Suave (#FA9878)
  _drawArcWithShadow(
    canvas: canvas,
    center: center,
    radius: r2,
    strokeWidth: w2,
    startAngleRad: 25.0 * degToRad,
    sweepAngleRad: 195.0 * degToRad,
    startColor: const Color(0xFFDF5C57),
    endColor: const Color(0xFFFA9878),
    scale: scale,
  );

  // 5. Núcleo Central Generoso: Sol Ámbar Dorado (Radio 31px, #F2A43A)
  canvas.drawCircle(
    center + Offset(0, 6.0 * scale),
    32.0 * scale,
    Paint()
      ..color = const Color(0x38E8962E)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 * scale)
      ..isAntiAlias = true,
  );
  canvas.drawCircle(
    center,
    31.0 * scale,
    Paint()
      ..color = const Color(0xFFF2A43A)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  // 6. Satélite Orbital Sólido (Radio 24px, #1B665C Esmeralda Profundo sin punto blanco interior)
  const double satAngle = -70.0 * degToRad;
  final Offset satCenter = Offset(
    center.dx + r1 * math.cos(satAngle),
    center.dy + r1 * math.sin(satAngle),
  );
  canvas.drawCircle(
    satCenter + Offset(0, 6.0 * scale),
    24.0 * scale,
    Paint()
      ..color = const Color(0x331B665C)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9.0 * scale)
      ..isAntiAlias = true,
  );
  canvas.drawCircle(
    satCenter,
    24.0 * scale,
    Paint()
      ..color = const Color(0xFF1B665C)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('No se pudo codificar el icono PNG de tamaño $size');
  }
  return byteData.buffer.asUint8List();
}

Future<void> _writePng(String relativePath, Uint8List bytes) async {
  final file = File(relativePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

void main() {
  test('Genera todos los iconos vectoriales Nordic Sage Orbital (Android + Web + Master)', () async {
    // 1. Master Icons (1024x1024)
    final masterFull = await renderNordicSageOrbitalIcon(
      size: 1024,
      includeBackground: true,
    );
    final masterForeground = await renderNordicSageOrbitalIcon(
      size: 1024,
      includeBackground: false,
    );

    await _writePng('assets/icon/app_icon.png', masterFull);
    await _writePng('assets/icon/app_icon_foreground.png', masterForeground);

    // 2. Densidades Android Legacy/Standard (ic_launcher.png y launcher_icon.png)
    const Map<String, int> androidLegacySizes = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };

    for (final entry in androidLegacySizes.entries) {
      final bytes = await renderNordicSageOrbitalIcon(
        size: entry.value,
        includeBackground: true,
      );
      await _writePng('android/app/src/main/res/${entry.key}/ic_launcher.png', bytes);
      await _writePng('android/app/src/main/res/${entry.key}/launcher_icon.png', bytes);
    }

    // 3. Densidades Android Adaptive Icon Foreground (108dp: 108..432px)
    const Map<String, int> androidForegroundSizes = {
      'mipmap-mdpi': 108,
      'mipmap-hdpi': 162,
      'mipmap-xhdpi': 216,
      'mipmap-xxhdpi': 324,
      'mipmap-xxxhdpi': 432,
    };

    for (final entry in androidForegroundSizes.entries) {
      final fgBytes = await renderNordicSageOrbitalIcon(
        size: entry.value,
        includeBackground: false,
      );
      await _writePng(
        'android/app/src/main/res/${entry.key}/ic_launcher_foreground.png',
        fgBytes,
      );
      final densitySuffix = entry.key.replaceFirst('mipmap-', '');
      await _writePng(
        'android/app/src/main/res/drawable-$densitySuffix/splash.png',
        fgBytes,
      );
      await _writePng(
        'android/app/src/main/res/drawable-$densitySuffix/android12splash.png',
        fgBytes,
      );
      await _writePng(
        'android/app/src/main/res/drawable-night-$densitySuffix/android12splash.png',
        fgBytes,
      );
    }

    // 4. Iconos Web PWA & Favicon
    final faviconBytes = await renderNordicSageOrbitalIcon(
      size: 64,
      includeBackground: true,
    );
    final web192Bytes = await renderNordicSageOrbitalIcon(
      size: 192,
      includeBackground: true,
    );
    final web512Bytes = await renderNordicSageOrbitalIcon(
      size: 512,
      includeBackground: true,
    );

    await _writePng('web/favicon.png', faviconBytes);
    await _writePng('web/icons/Icon-192.png', web192Bytes);
    await _writePng('web/icons/Icon-512.png', web512Bytes);
    await _writePng('web/icons/Icon-maskable-192.png', web192Bytes);
    await _writePng('web/icons/Icon-maskable-512.png', web512Bytes);

    // Verificaciones de integridad PNG
    expect(masterFull.length, greaterThan(1000));
    expect(masterForeground.length, greaterThan(1000));
    expect(masterFull.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
    expect(File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png').existsSync(), isTrue);
    expect(File('web/icons/Icon-512.png').existsSync(), isTrue);
  });
}

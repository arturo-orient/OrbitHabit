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
  // Margen angular que ocupa la gorra redondeada (StrokeCap.round) en cada extremo
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

/// Renderiza vectorialmente el icono "Warm Lo-Fi Orbital" a cualquier resolución [size],
/// escalando proporcionalmente desde el lienzo maestro de 1024x1024 px.
///
/// Cumple estrictamente la Safe Zone de Android Adaptive Icons y Web Maskable Icons.
Future<Uint8List> renderWarmLofiOrbitalIcon({
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

  // Paleta "Warm Lo-Fi Orbital"
  const Color obsidianDeep = Color(0xFF0D0E12);
  const Color obsidianWarmCenter = Color(0xFF1E1B24);
  const Color trackGuideColor = Color(0x14FFF8EB); // 8% opacidad blanco cálido

  // Anillo 1 (Exterior): Salvia Esmeralda -> Turquesa Menta Luminoso
  const Color ring1Start = Color(0xFF52968C);
  const Color ring1End = Color(0xFF84DCC6);

  // Anillo 2 (Medio): Rosa Coral -> Melocotón Luminoso
  const Color ring2Start = Color(0xFFE57A77);
  const Color ring2End = Color(0xFFFFAD87);

  // Anillo 3 (Interior): Ámbar Dorado -> Arena Solar
  const Color ring3Start = Color(0xFFE8993E);
  const Color ring3End = Color(0xFFFFD166);

  // Núcleo Solar Vivo y Satélite Orbital Brillante
  const Color coreHaloColor = Color(0x44FFD166);
  const Color coreSolidColor = Color(0xFFFFF8E7);
  const Color satelliteHaloColor = Color(0x6684DCC6);
  const Color satelliteSolidColor = Color(0xFFFFFDF9);

  // 1. Fondo Obsidiana Profundo (#0D0E12) con resplandor radial central cálido (#1E1B24 -> #0D0E12)
  if (includeBackground) {
    final bgRect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        512.0 * scale,
        const [obsidianWarmCenter, obsidianDeep],
        const [0.0, 1.0],
      );
    canvas.drawRect(bgRect, bgPaint);
  }

  // Geometrías de los 3 anillos concéntricos
  final double r1 = 245.0 * scale;
  final double w1 = 46.0 * scale;

  final double r2 = 172.0 * scale;
  final double w2 = 42.0 * scale;

  final double r3 = 102.0 * scale;
  final double w3 = 38.0 * scale;

  // 2. Carriles Guía Orbitales (Tracks de fondo completos al 8% de opacidad)
  final Paint trackPaint = Paint()
    ..color = trackGuideColor
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  canvas.drawCircle(center, r1, trackPaint..strokeWidth = w1);
  canvas.drawCircle(center, r2, trackPaint..strokeWidth = w2);
  canvas.drawCircle(center, r3, trackPaint..strokeWidth = w3);

  // 3. Anillo 1 (Exterior - Radio 245px, grosor 46px):
  // Arco de 250° dejando el hueco de 110° entre -125° y -15° (centrado en -70° para el satélite).
  // El arco recorre desde -15° (+250° en sentido horario) hasta +235° (-125°).
  const double r1StartRad = -15.0 * degToRad;
  const double r1SweepRad = 250.0 * degToRad;
  final Rect rect1 = Rect.fromCircle(center: center, radius: r1);
  final Paint paint1 = Paint()
    ..shader = _buildArcSweepShader(
      center: center,
      radius: r1,
      strokeWidth: w1,
      startAngleRad: r1StartRad,
      sweepAngleRad: r1SweepRad,
      startColor: ring1Start,
      endColor: ring1End,
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = w1
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  canvas.drawArc(rect1, r1StartRad, r1SweepRad, false, paint1);

  // 4. Anillo 2 (Medio - Radio 172px, grosor 42px):
  // Desde 20° con barrido de 195°. Gradiente cálido de Rosa Coral (#E57A77) a Melocotón Luminoso (#FFAD87).
  const double r2StartRad = 20.0 * degToRad;
  const double r2SweepRad = 195.0 * degToRad;
  final Rect rect2 = Rect.fromCircle(center: center, radius: r2);
  final Paint paint2 = Paint()
    ..shader = _buildArcSweepShader(
      center: center,
      radius: r2,
      strokeWidth: w2,
      startAngleRad: r2StartRad,
      sweepAngleRad: r2SweepRad,
      startColor: ring2Start,
      endColor: ring2End,
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = w2
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  canvas.drawArc(rect2, r2StartRad, r2SweepRad, false, paint2);

  // 5. Anillo 3 (Interior - Radio 102px, grosor 38px):
  // Desde -60° con barrido de 140°. Gradiente de Ámbar Dorado (#E8993E) a Arena Solar (#FFD166).
  const double r3StartRad = -60.0 * degToRad;
  const double r3SweepRad = 140.0 * degToRad;
  final Rect rect3 = Rect.fromCircle(center: center, radius: r3);
  final Paint paint3 = Paint()
    ..shader = _buildArcSweepShader(
      center: center,
      radius: r3,
      strokeWidth: w3,
      startAngleRad: r3StartRad,
      sweepAngleRad: r3SweepRad,
      startColor: ring3Start,
      endColor: ring3End,
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = w3
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  canvas.drawArc(rect3, r3StartRad, r3SweepRad, false, paint3);

  // 6. Núcleo Solar Vivo (Centro 512, 512):
  // Halo suave difuminado (blur 18, #44FFD166, radio 36px) + núcleo sólido luminoso (radio 20px, #FFF8E7).
  final Paint coreHaloPaint = Paint()
    ..color = coreHaloColor
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 * scale)
    ..isAntiAlias = true;
  canvas.drawCircle(center, 36.0 * scale, coreHaloPaint);

  final Paint coreSolidPaint = Paint()
    ..color = coreSolidColor
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  canvas.drawCircle(center, 20.0 * scale, coreSolidPaint);

  // 7. Satélite Orbital Brillante:
  // En el hueco del anillo exterior (ángulo -70°, radio 245px):
  // Halo suave (blur 12, #6684DCC6, radio 26px) + satélite sólido (radio 19px, #FFFDF9).
  const double satelliteAngleRad = -70.0 * degToRad;
  final Offset satelliteCenter = Offset(
    center.dx + r1 * math.cos(satelliteAngleRad),
    center.dy + r1 * math.sin(satelliteAngleRad),
  );

  final Paint satelliteHaloPaint = Paint()
    ..color = satelliteHaloColor
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 * scale)
    ..isAntiAlias = true;
  canvas.drawCircle(satelliteCenter, 26.0 * scale, satelliteHaloPaint);

  final Paint satelliteSolidPaint = Paint()
    ..color = satelliteSolidColor
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  canvas.drawCircle(satelliteCenter, 19.0 * scale, satelliteSolidPaint);

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
  test('Genera todos los iconos vectoriales Warm Lo-Fi Orbital (Android + Web + Master)', () async {
    // 1. Master Icons (1024x1024)
    final masterFull = await renderWarmLofiOrbitalIcon(
      size: 1024,
      includeBackground: true,
    );
    final masterForeground = await renderWarmLofiOrbitalIcon(
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
      final bytes = await renderWarmLofiOrbitalIcon(
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
      final fgBytes = await renderWarmLofiOrbitalIcon(
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
    final faviconBytes = await renderWarmLofiOrbitalIcon(
      size: 64,
      includeBackground: true,
    );
    final web192Bytes = await renderWarmLofiOrbitalIcon(
      size: 192,
      includeBackground: true,
    );
    final web512Bytes = await renderWarmLofiOrbitalIcon(
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

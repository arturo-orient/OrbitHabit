import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/schedule_block.dart';
import '../utils/poster_saver.dart';

/// Servicio de Renderizado de Póster PNG de Alta Resolución para el Cuadrante Mensual.
/// Dibuja directamente en un `ui.Canvas` de 1080x1440 con rigor técnico suizo (Neo-Bento).
class SchedulePosterService {
  static const _monthNames = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
  ];

  static const _weekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  /// Guarda el PNG del póster en el dispositivo y devuelve la ruta guardada o nombre de archivo
  static Future<String?> savePosterPng({
    required Uint8List bytes,
    required DateTime month,
  }) async {
    final monthName = _monthNames[month.month - 1].toLowerCase();
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);
    final fileName = 'OrbitHabit_Cuadrante_${capitalizedMonth}_${month.year}.png';
    return await PosterSaver.save(bytes: bytes, fileName: fileName);
  }

  /// Comparte el PNG del póster directamente a través de apps externas (WhatsApp, Telegram, Drive)
  static Future<bool> sharePosterPng({
    required Uint8List bytes,
    required DateTime month,
  }) async {
    final monthName = _monthNames[month.month - 1].toLowerCase();
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);
    final fileName = 'OrbitHabit_Cuadrante_${capitalizedMonth}_${month.year}.png';
    return await PosterSaver.share(bytes: bytes, fileName: fileName);
  }

  /// Genera un PNG de alta resolución con el cuadrante mensual, turnos y telemetría de horas adaptable.
  /// Calcula dinámicamente la altura del Canvas según el número de semanas (4, 5 o 6) y si se muestra el pie.
  static Future<Uint8List> renderMonthlyPosterPng({
    required DateTime month,
    required List<ScheduleBlock> blocks,
    required String userName,
    required bool isDark,
    Set<String>? includedBlockIds,
    bool showTelemetryFooter = true,
    String? customSubtitle,
  }) async {
    const width = 1080.0;
    const margin = 40.0;
    const cellHeight = 148.0;
    const cellGap = 6.0;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1 = Lunes
    final numRows = ((firstWeekday - 1 + daysInMonth) / 7.0).ceil(); // 4, 5 o 6 semanas
    final monthPrefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    // 1. Cabecera editorial y dimensiones dinámicas
    final headerLeft = margin + 28.0;
    final gridLeft = headerLeft;
    final gridWidth = width - margin * 2 - 56.0;
    final colWidth = gridWidth / 7.0;

    final gridTopY = margin + 145.0;
    final gridHeight = numRows * cellHeight + (numRows - 1) * cellGap;
    final gridBottomY = gridTopY + gridHeight;

    const footerHeight = 210.0;
    final double height = showTelemetryFooter
        ? (gridBottomY + 36.0 + footerHeight + margin)
        : (gridBottomY + margin + 28.0);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 2. Paleta Cromática Suiza
    final bgColor = isDark ? const Color(0xFF09090B) : const Color(0xFFF7F7F8);
    final surfaceColor = isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0x28FFFFFF) : const Color(0xFFCBD0D6);
    final borderSubtle = isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E4E8);
    final textPrimary = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF09090B);
    final textSecondary = isDark ? const Color(0xFF71717A) : const Color(0xFF4B5563);
    final textMuted = isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);
    final accentColor = isDark ? const Color(0xFFD4FF00) : const Color(0xFF0052FF);

    // Fondo completo dinámico
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 3. Marco Exterior de Precisión Suiza
    final frameRect = Rect.fromLTWH(margin, margin, width - margin * 2, height - margin * 2);
    final framePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(20)), framePaint);

    // Retícula Técnica: Cruces de Registro Suizo en las 4 esquinas dinámicas
    _drawCrosshair(canvas, margin, margin, accentColor);
    _drawCrosshair(canvas, width - margin, margin, accentColor);
    _drawCrosshair(canvas, margin, height - margin, accentColor);
    _drawCrosshair(canvas, width - margin, height - margin, accentColor);

    // 4. Cabecera Editorial
    var currentY = margin + 30.0;

    // Etiqueta Técnica Superior
    _drawText(
      canvas: canvas,
      text: customSubtitle ?? 'ORBITHABIT // CUADRANTE MENSUAL DE TURNOS',
      offset: Offset(headerLeft, currentY),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: accentColor,
        letterSpacing: 2.0,
      ),
    );
    currentY += 26.0;

    // Título Principal (Mes y Año)
    final monthName = _monthNames[month.month - 1];
    _drawText(
      canvas: canvas,
      text: '$monthName ${month.year}',
      offset: Offset(headerLeft, currentY),
      style: TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: 1.5,
      ),
    );

    // Cápsula de Operador / Usuario (Alineado a la derecha en cabecera)
    final operatorText = 'OPERADOR: ${userName.toUpperCase()}';
    final opPainter = _buildTextPainter(
      operatorText,
      TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.black : Colors.white,
        letterSpacing: 1.0,
      ),
    );
    final opWidth = opPainter.width + 24.0;
    final opHeight = opPainter.height + 12.0;
    final opRect = Rect.fromLTWH(width - margin - 28.0 - opWidth, currentY + 14.0, opWidth, opHeight);

    final opBgPaint = Paint()..color = accentColor;
    canvas.drawRRect(RRect.fromRectAndRadius(opRect, const Radius.circular(8)), opBgPaint);
    opPainter.paint(canvas, Offset(opRect.left + 12.0, opRect.top + 6.0));

    currentY += 65.0;

    // Separador sutil
    final linePaint = Paint()
      ..color = borderSubtle
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(headerLeft, currentY), Offset(width - margin - 28.0, currentY), linePaint);
    currentY += 20.0;

    // 5. Cabecera de Días de la Semana (7 Columnas: LUN - DOM)
    for (int i = 0; i < 7; i++) {
      final isWeekend = i >= 5;
      final x = gridLeft + i * colWidth;
      _drawText(
        canvas: canvas,
        text: _weekdaysShort[i],
        offset: Offset(x + (colWidth - 36) / 2, currentY),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isWeekend ? accentColor : textSecondary,
          letterSpacing: 1.2,
        ),
      );
    }

    // 6. Filtrar bloques incluidos según personalización
    final effectiveBlocks = includedBlockIds != null
        ? blocks.where((b) => includedBlockIds.contains(b.id)).toList()
        : blocks;

    // Mapa de fechas asignadas a turnos (soporta múltiples turnos por día)
    final Map<String, List<ScheduleBlock>> dateShiftsMap = {};
    for (final b in effectiveBlocks) {
      for (final d in b.assignedDates) {
        if (d.startsWith(monthPrefix)) {
          dateShiftsMap.putIfAbsent(d, () => []).add(b);
        }
      }
    }

    // 7. Cuadrícula de Celdas de Alta Precisión
    int dayCounter = 1;

    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < 7; col++) {
        final cellX = gridLeft + col * colWidth;
        final cellY = gridTopY + row * (cellHeight + cellGap);
        final cellRect = Rect.fromLTWH(cellX + cellGap * 0.5, cellY, colWidth - cellGap, cellHeight);

        // Celdas vacías antes del primer día o después del último
        if (row == 0 && col < (firstWeekday - 1)) {
          continue;
        } else if (dayCounter > daysInMonth) {
          continue;
        }

        final dateIso = '$monthPrefix-${dayCounter.toString().padLeft(2, '0')}';
        final dayShifts = dateShiftsMap[dateIso] ?? const [];

        if (dayShifts.isEmpty) {
          // Celda de descanso / sin turno asignado
          final emptyBgPaint = Paint()
            ..color = surfaceColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), emptyBgPaint);

          final emptyBorderPaint = Paint()
            ..color = borderSubtle
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), emptyBorderPaint);

          // Número de día
          _drawText(
            canvas: canvas,
            text: dayCounter.toString().padLeft(2, '0'),
            offset: Offset(cellRect.left + 8, cellRect.top + 7),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          );

          // Punto sutil de descanso
          final restDotPaint = Paint()..color = borderSubtle;
          canvas.drawCircle(Offset(cellRect.center.dx, cellRect.center.dy + 16), 2.5, restDotPaint);
        } else if (dayShifts.length == 1) {
          // Celda con 1 solo turno
          final shift = dayShifts.first;
          final shiftColor = shift.color;

          // Fondo tintado
          final cellBgPaint = Paint()
            ..color = shiftColor.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), cellBgPaint);

          // Borde
          final cellBorderPaint = Paint()
            ..color = shiftColor.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), cellBorderPaint);

          // Número de día
          _drawText(
            canvas: canvas,
            text: dayCounter.toString().padLeft(2, '0'),
            offset: Offset(cellRect.left + 8, cellRect.top + 7),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          );

          // Punto indicador cromático
          final dotPaint = Paint()..color = shiftColor;
          canvas.drawCircle(Offset(cellRect.right - 12, cellRect.top + 14), 4.5, dotPaint);

          // Título del turno (Truncado si es largo)
          final cleanTitle = shift.title.toUpperCase();
          _drawText(
            canvas: canvas,
            text: cleanTitle.length > 12 ? '${cleanTitle.substring(0, 10)}..' : cleanTitle,
            offset: Offset(cellRect.left + 8, cellRect.top + 38),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: shiftColor,
            ),
          );

          // Horario
          _drawText(
            canvas: canvas,
            text: shift.formattedTimeRange,
            offset: Offset(cellRect.left + 8, cellRect.top + 60),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          );

          // Duración
          _drawText(
            canvas: canvas,
            text: shift.formattedDuration,
            offset: Offset(cellRect.left + 8, cellRect.top + 80),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          );
        } else {
          // Celda Multi-tarea (2 o más tareas en el día)
          final primaryColor = dayShifts.first.color;

          final cellBgPaint = Paint()
            ..color = primaryColor.withValues(alpha: 0.10)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), cellBgPaint);

          final cellBorderPaint = Paint()
            ..color = primaryColor.withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), cellBorderPaint);

          // Número de día
          _drawText(
            canvas: canvas,
            text: dayCounter.toString().padLeft(2, '0'),
            offset: Offset(cellRect.left + 8, cellRect.top + 7),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          );

          // Puntos cromáticos en la esquina superior derecha (hasta 3 puntos)
          for (int i = 0; i < dayShifts.length && i < 3; i++) {
            final dotColor = dayShifts[i].color;
            final dotPaint = Paint()..color = dotColor;
            final dotX = cellRect.right - 10 - i * 11;
            canvas.drawCircle(Offset(dotX, cellRect.top + 14), 3.5, dotPaint);
          }

          // Bloques apilados en el cuerpo (hasta 2 visibles)
          for (int i = 0; i < dayShifts.length && i < 2; i++) {
            final shift = dayShifts[i];
            final shiftColor = shift.color;
            final itemY = cellRect.top + 32.0 + i * 50.0;
            final itemRect = Rect.fromLTWH(cellRect.left + 5.0, itemY, cellRect.width - 10.0, 44.0);

            final itemBgPaint = Paint()
              ..color = shiftColor.withValues(alpha: 0.18)
              ..style = PaintingStyle.fill;
            canvas.drawRRect(RRect.fromRectAndRadius(itemRect, const Radius.circular(5)), itemBgPaint);

            // Barra lateral izquierda sólida
            final barPaint = Paint()..color = shiftColor;
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                Rect.fromLTWH(itemRect.left, itemRect.top, 3.0, itemRect.height),
                topLeft: const Radius.circular(5),
                bottomLeft: const Radius.circular(5),
              ),
              barPaint,
            );

            // Título truncado
            final cleanTitle = shift.title.toUpperCase();
            _drawText(
              canvas: canvas,
              text: cleanTitle.length > 9 ? '${cleanTitle.substring(0, 8)}..' : cleanTitle,
              offset: Offset(itemRect.left + 6.0, itemRect.top + 5.0),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: shiftColor,
              ),
            );

            // Horario
            _drawText(
              canvas: canvas,
              text: shift.formattedTimeRange,
              offset: Offset(itemRect.left + 6.0, itemRect.top + 22.0),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: textSecondary,
              ),
            );
          }

          // Indicador si hay más de 2 tareas
          if (dayShifts.length > 2) {
            _drawText(
              canvas: canvas,
              text: '+${dayShifts.length - 2}',
              offset: Offset(cellRect.right - 24, cellRect.bottom - 16),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            );
          }
        }

        dayCounter++;
      }
    }

    // 8. Pie de Telemetría y Resumen Bento (Opcional, colocado inmediatamente bajo la rejilla)
    if (showTelemetryFooter) {
      final footerY = gridBottomY + 36.0;
      final footerRect = Rect.fromLTWH(gridLeft, footerY, gridWidth, footerHeight);

      final footerBgPaint = Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(footerRect, const Radius.circular(16)), footerBgPaint);

      final footerBorderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(footerRect, const Radius.circular(16)), footerBorderPaint);

      // Cabecera del pie
      _drawText(
        canvas: canvas,
        text: 'TELEMETRÍA MENSUAL // DESGLOSE DE TURNOS',
        offset: Offset(footerRect.left + 20, footerRect.top + 16),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: accentColor,
          letterSpacing: 1.2,
        ),
      );

      // Calcular estadísticas con base en effectiveBlocks
      final List<Map<String, dynamic>> shiftStats = [];
      int grandTotalShifts = 0;
      double grandTotalHours = 0.0;

      for (final b in effectiveBlocks) {
        final count = b.assignedDates.where((d) => d.startsWith(monthPrefix)).length;
        if (count > 0) {
          final hours = count * (b.durationInMinutes / 60.0);
          grandTotalShifts += count;
          grandTotalHours += hours;
          shiftStats.add({
            'title': b.title,
            'count': count,
            'hours': hours,
            'color': b.color,
            'time': b.formattedTimeRange,
          });
        }
      }

      // Dibujar estadísticas por turno en fila
      var statX = footerRect.left + 20.0;
      final statY = footerRect.top + 46.0;

      if (shiftStats.isEmpty) {
        _drawText(
          canvas: canvas,
          text: 'No hay turnos visibles seleccionados en este mes.',
          offset: Offset(statX, statY + 15),
          style: TextStyle(fontSize: 13, color: textSecondary),
        );
      } else {
        for (int i = 0; i < shiftStats.length && i < 4; i++) {
          final item = shiftStats[i];
          final shiftColor = item['color'] as Color;
          final title = item['title'] as String;
          final count = item['count'] as int;
          final hours = item['hours'] as double;

          // Indicador cuadrado
          final badgePaint = Paint()..color = shiftColor;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(statX, statY, 12, 12), const Radius.circular(3)),
            badgePaint,
          );

          _drawText(
            canvas: canvas,
            text: '$title: $count turnos · ${hours.toStringAsFixed(1)}h',
            offset: Offset(statX + 18, statY - 2),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          );

          statX += 230.0;
          if (statX > footerRect.right - 200) {
            statX = footerRect.left + 20.0;
          }
        }
      }

      // Línea de Total General al fondo del contenedor
      final totalY = footerRect.bottom - 45.0;
      canvas.drawLine(
        Offset(footerRect.left + 20, totalY - 12),
        Offset(footerRect.right - 20, totalY - 12),
        linePaint,
      );

      _drawText(
        canvas: canvas,
        text: 'TOTAL PLANIFICADO: $grandTotalShifts TURNOS · ${grandTotalHours.toStringAsFixed(1)} HORAS',
        offset: Offset(footerRect.left + 20, totalY),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: accentColor,
          letterSpacing: 1.0,
        ),
      );

      _drawText(
        canvas: canvas,
        text: 'ORBITHABIT PRECISION SYSTEM',
        offset: Offset(footerRect.right - 200, totalY + 2),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 1.0,
        ),
      );
    }

    // 9. Renderizar a imagen y convertir a PNG
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static void _drawCrosshair(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    const s = 7.0;
    canvas.drawLine(Offset(x - s, y), Offset(x + s, y), paint);
    canvas.drawLine(Offset(x, y - s), Offset(x, y + s), paint);
  }

  static TextPainter _buildTextPainter(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  static void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final painter = _buildTextPainter(text, style);
    painter.paint(canvas, offset);
  }
}

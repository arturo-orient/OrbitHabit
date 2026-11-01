import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../domain/models/schedule_block.dart';

/// Servicio de Renderizado de Póster PNG de Alta Resolución para el Cuadrante Mensual.
/// Dibuja directamente en un `ui.Canvas` de 1080x1440 con rigor técnico suizo (Neo-Bento).
class SchedulePosterService {
  static const _monthNames = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
  ];

  static const _weekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  /// Genera un PNG de 1080x1440 px con el cuadrante mensual, turnos y telemetría de horas
  static Future<Uint8List> renderMonthlyPosterPng({
    required DateTime month,
    required List<ScheduleBlock> blocks,
    required String userName,
    required bool isDark,
  }) async {
    const width = 1080.0;
    const height = 1440.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

    // 1. Paleta Cromática Suiza
    final bgColor = isDark ? const Color(0xFF09090B) : const Color(0xFFF7F7F8);
    final surfaceColor = isDark ? const Color(0xFF121215) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0x28FFFFFF) : const Color(0xFFCBD0D6);
    final borderSubtle = isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E4E8);
    final textPrimary = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF09090B);
    final textSecondary = isDark ? const Color(0xFF71717A) : const Color(0xFF4B5563);
    final textMuted = isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);
    final accentColor = isDark ? const Color(0xFFD4FF00) : const Color(0xFF0052FF);

    // Fondo completo
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Marco Exterior de Precisión Suiza (Inset 40px)
    const margin = 40.0;
    final frameRect = Rect.fromLTWH(margin, margin, width - margin * 2, height - margin * 2);
    final framePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(20)), framePaint);

    // Retícula Técnica: Cruces de Registro Suizo en las 4 esquinas
    _drawCrosshair(canvas, margin, margin, accentColor);
    _drawCrosshair(canvas, width - margin, margin, accentColor);
    _drawCrosshair(canvas, margin, height - margin, accentColor);
    _drawCrosshair(canvas, width - margin, height - margin, accentColor);

    // 3. Cabecera Editorial
    final headerLeft = margin + 28.0;
    var currentY = margin + 30.0;

    // Etiqueta Técnica Superior
    _drawText(
      canvas: canvas,
      text: 'ORBITHABIT // CUADRANTE MENSUAL DE TURNOS',
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

    // 4. Cabecera de Días de la Semana (7 Columnas: LUN - DOM)
    final gridLeft = headerLeft;
    final gridWidth = width - margin * 2 - 56.0;
    final colWidth = gridWidth / 7.0;

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
    currentY += 28.0;

    // 5. Cuadrícula de Días del Mes
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1 = Lunes
    final monthPrefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    final cellHeight = 114.0;
    final cellGap = 6.0;

    // Mapa de fechas asignadas a turnos
    final Map<String, ScheduleBlock> dateShiftMap = {};
    for (final b in blocks) {
      for (final d in b.assignedDates) {
        if (d.startsWith(monthPrefix)) {
          dateShiftMap[d] = b;
        }
      }
    }

    int dayCounter = 1;
    int row = 0;

    while (dayCounter <= daysInMonth) {
      for (int col = 0; col < 7; col++) {
        final cellX = gridLeft + col * colWidth;
        final cellY = currentY + row * (cellHeight + cellGap);
        final cellRect = Rect.fromLTWH(cellX + cellGap * 0.5, cellY, colWidth - cellGap, cellHeight);

        // Si antes del primer día del mes o después del último día
        if (row == 0 && col < (firstWeekday - 1)) {
          // Celda vacía previa
          continue;
        } else if (dayCounter > daysInMonth) {
          // Celda vacía posterior
          continue;
        }

        final dateIso = '$monthPrefix-${dayCounter.toString().padLeft(2, '0')}';
        final assignedShift = dateShiftMap[dateIso];

        if (assignedShift != null) {
          // Celda con turno asignado
          final shiftColor = assignedShift.color;

          // Fondo tintado
          final cellBgPaint = Paint()
            ..color = shiftColor.withOpacity(0.16)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(RRect.fromRectAndRadius(cellRect, const Radius.circular(10)), cellBgPaint);

          // Borde
          final cellBorderPaint = Paint()
            ..color = shiftColor.withOpacity(0.75)
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
          final cleanTitle = assignedShift.title.toUpperCase();
          _drawText(
            canvas: canvas,
            text: cleanTitle.length > 10 ? '${cleanTitle.substring(0, 8)}..' : cleanTitle,
            offset: Offset(cellRect.left + 8, cellRect.top + 38),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: shiftColor,
            ),
          );

          // Horario (ej. 07:00-15:00)
          final timeStr = '${assignedShift.startHour.toString().padLeft(2, '0')}:${assignedShift.startMinute.toString().padLeft(2, '0')}\n${assignedShift.endHour.toString().padLeft(2, '0')}:${assignedShift.endMinute.toString().padLeft(2, '0')}';
          _drawText(
            canvas: canvas,
            text: timeStr,
            offset: Offset(cellRect.left + 8, cellRect.top + 60),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              height: 1.25,
            ),
          );
        } else {
          // Celda de descanso / sin turno asignado
          final emptyBgPaint = Paint()
            ..color = surfaceColor.withOpacity(0.5)
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
          canvas.drawCircle(Offset(cellRect.center.dx, cellRect.center.dy + 12), 2.5, restDotPaint);
        }

        dayCounter++;
      }
      row++;
    }

    // 6. Pie de Telemetría y Resumen Bento (Parte Inferior)
    final footerY = height - margin - 235.0;
    final footerRect = Rect.fromLTWH(gridLeft, footerY, gridWidth, 205.0);

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

    // Calcular estadísticas
    final List<Map<String, dynamic>> shiftStats = [];
    int grandTotalShifts = 0;
    double grandTotalHours = 0.0;

    for (final b in blocks) {
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
        text: 'No hay turnos planificados en este mes todavía.',
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

    // 7. Renderizar a imagen y convertir a PNG
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static void _drawCrosshair(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
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

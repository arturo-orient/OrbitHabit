import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../utils/date_utils.dart';
import '../theme/app_theme.dart';

class OrbitTracker extends StatefulWidget {
  final List<Habit> habits;
  final List<ScheduleBlock> scheduleBlocks;
  final DateTime currentMonth;
  final Function(DateTime date) onDayColumnTapped;

  const OrbitTracker({
    Key? key,
    required this.habits,
    this.scheduleBlocks = const [],
    required this.currentMonth,
    required this.onDayColumnTapped,
  }) : super(key: key);

  @override
  State<OrbitTracker> createState() => _OrbitTrackerState();
}

class _OrbitTrackerState extends State<OrbitTracker> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int? _hoveredDay;
  DateTime? _lastTappedDate;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    );

    // Iniciar el barrido en cuanto el lienzo se haya dibujado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _animationController.forward(from: 0.0);
        }
      });
    });
  }

  void replayAnimation() {
    if (mounted) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(OrbitTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMonth != widget.currentMonth ||
        oldWidget.habits.length != widget.habits.length) {
      replayAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int? _getDayFromOffset(Offset localPosition, Size size) {
    if (widget.habits.isEmpty) return null;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    var angle = math.atan2(dy, dx);
    
    if (angle < 0) angle += 2 * math.pi;

    final startOffsetAngle = math.pi; // Empieza a las 9 en punto (izquierda)
    var rotatedAngle = angle - startOffsetAngle;
    if (rotatedAngle < 0) rotatedAngle += 2 * math.pi;

    final maxRadius = math.min(size.width, size.height) * 0.37;
    final minRadius = maxRadius * 0.3; 
    
    if (distance < minRadius || distance > maxRadius) return null;

    final daysInMonth = OrbitDateUtils.getDaysInMonth(widget.currentMonth.year, widget.currentMonth.month);
    final totalSweep = math.pi * 1.6; // 288 degrees horseshoe
    final anglePerDay = totalSweep / daysInMonth;

    if (rotatedAngle > totalSweep) return null;

    final dayIndex = (rotatedAngle / anglePerDay).floor();
    final day = dayIndex + 1;
    
    if (day < 1 || day > daysInMonth) return null;
    return day;
  }

  void _handlePanUpdate(Offset localPosition, Size size) {
    final day = _getDayFromOffset(localPosition, size);
    if (day != _hoveredDay) {
      setState(() {
        _hoveredDay = day;
      });
      if (day != null) {
        // Advanced premium haptic tick simulating a physical rotary dial gear!
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final day = _getDayFromOffset(details.localPosition, size);
    if (day != null) {
      final tappedDate = DateTime(widget.currentMonth.year, widget.currentMonth.month, day);
      if (!OrbitDateUtils.isFutureDate(tappedDate)) {
        widget.onDayColumnTapped(tappedDate);
      }
    }
  }

  void _handlePanEnd() {
    if (_hoveredDay == null) return;
    
    final tappedDate = DateTime(widget.currentMonth.year, widget.currentMonth.month, _hoveredDay!);
    
    // Future date block
    if (OrbitDateUtils.isFutureDate(tappedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes predecir el futuro 🔮')),
      );
      setState(() => _hoveredDay = null);
      return;
    }

    setState(() {
      _lastTappedDate = tappedDate;
      _hoveredDay = null; // reset hover
    });

    widget.onDayColumnTapped(tappedDate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridTextColor = isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onTapUp: (details) => _handleTapUp(details, size),
          onPanStart: (details) => _handlePanUpdate(details.localPosition, size),
          onPanUpdate: (details) => _handlePanUpdate(details.localPosition, size),
          onPanEnd: (details) => _handlePanEnd(),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: OrbitPainter(
                  habits: widget.habits,
                  scheduleBlocks: widget.scheduleBlocks,
                  currentMonth: widget.currentMonth,
                  hoveredDay: _hoveredDay,
                  animatingDate: _lastTappedDate,
                  animationValue: _scaleAnimation.value,
                  gridTextColor: gridTextColor,
                  isDark: isDark,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class OrbitPainter extends CustomPainter {
  final List<Habit> habits;
  final List<ScheduleBlock> scheduleBlocks;
  final DateTime currentMonth;
  final int? hoveredDay;
  final DateTime? animatingDate;
  final double animationValue;
  final Color gridTextColor;
  final bool isDark;

  OrbitPainter({
    required this.habits,
    this.scheduleBlocks = const [],
    required this.currentMonth,
    this.hoveredDay,
    this.animatingDate,
    this.animationValue = 1.0,
    required this.gridTextColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (habits.isEmpty) return;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = math.min(size.width, size.height) * 0.37; // Reduced from 0.45 to add breathing room and avoid overlap
    final minRadius = maxRadius * 0.3;
    final availableRadius = maxRadius - minRadius;
    final ringWidth = availableRadius / (habits.length > 0 ? habits.length : 1);
    final ringPadding = ringWidth * 0.08; // Slightly reduced padding for a cleaner visual grid

    final daysInMonth = OrbitDateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
    final totalSweep = math.pi * 1.6; // 288 degrees horseshoe
    final anglePerDay = totalSweep / daysInMonth;
    final startOffsetAngle = math.pi; // Left side

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Rejilla de alta precisión adaptativa al tema
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;
    final today = now.day;

    // 1. Barrido de rejilla circular progresiva
    final sweepProgress = animationValue.clamp(0.0, 1.0);
    final animatedSweep = totalSweep * sweepProgress;

    for (int h = 0; h <= habits.length; h++) {
      final r = minRadius + (h * ringWidth);
      final path = Path();
      if (animatedSweep > 0.001) {
        path.arcTo(Rect.fromCircle(center: center, radius: r), startOffsetAngle, animatedSweep, true);
        canvas.drawPath(path, gridPaint);
      }
    }

    // 2. Números exteriores y líneas radiales iluminándose en secuencia
    for (int d = 1; d <= daysInMonth; d++) {
      final dayProgress = (d - 1) / (daysInMonth > 0 ? daysInMonth : 1);
      final numThreshold = (dayProgress * 0.78);
      
      // Si la onda aún no llega a este día, omitir
      if (animationValue < numThreshold) continue;

      final numOpacity = ((animationValue - numThreshold) / 0.18).clamp(0.0, 1.0);

      final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
      final centerAngle = startAngle + (anglePerDay / 2);
      
      final textRadius = maxRadius + 14.0;
      final tx = center.dx + textRadius * math.cos(centerAngle);
      final ty = center.dy + textRadius * math.sin(centerAngle);

      double rotationAngle = centerAngle + math.pi / 2;
      double normalizedRotation = rotationAngle;
      while (normalizedRotation > math.pi) normalizedRotation -= 2 * math.pi;
      while (normalizedRotation < -math.pi) normalizedRotation += 2 * math.pi;

      if (normalizedRotation.abs() > math.pi / 2) {
        rotationAngle += math.pi;
      }

      final isToday = isCurrentMonth && d == today;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(rotationAngle);

      if (isToday) {
        final highlightPaint = Paint()
          ..color = AppTheme.dynamicAccent(isDark).withValues(alpha: numOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 20.0, height: 16.0),
            const Radius.circular(3.5),
          ),
          highlightPaint,
        );
      }

      textPainter.text = TextSpan(
        text: d.toString().padLeft(2, '0'),
        style: AppTheme.monoStyle(
          color: isToday
              ? (isDark ? AppTheme.obsidianCanvas : Colors.white)
              : (isDark
                  ? gridTextColor.withValues(alpha: 0.75 * numOpacity)
                  : AppTheme.boneTextPrimary.withValues(alpha: 0.85 * numOpacity)),
          fontSize: isToday ? 10.0 : 9.0,
          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.0,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
      
      // Draw radial grid lines
      final innerTx = center.dx + minRadius * math.cos(startAngle);
      final innerTy = center.dy + minRadius * math.sin(startAngle);
      final outerTx = center.dx + maxRadius * math.cos(startAngle);
      final outerTy = center.dy + maxRadius * math.sin(startAngle);
      final radialLinePaint = Paint()
        ..color = gridTextColor.withValues(alpha: 0.06 * numOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset(innerTx, innerTy), Offset(outerTx, outerTy), radialLinePaint);
    }
    
    // Línea radial de cierre si el barrido está completo
    if (animationValue >= 0.95) {
      final endAngle = startOffsetAngle + totalSweep;
      final innerTx = center.dx + minRadius * math.cos(endAngle);
      final innerTy = center.dy + minRadius * math.sin(endAngle);
      final outerTx = center.dx + maxRadius * math.cos(endAngle);
      final outerTy = center.dy + maxRadius * math.sin(endAngle);
      canvas.drawLine(Offset(innerTx, innerTy), Offset(outerTx, outerTy), gridPaint);
    }

    // 3. Casillas de hábitos: apertura de acordeón/fuelle circular casilla por casilla
    for (int h = 0; h < habits.length; h++) {
      final habitIndex = habits.length - 1 - h;
      final habit = habits[habitIndex];
      final innerRadius = minRadius + (h * ringWidth) + ringPadding;
      final outerRadius = minRadius + ((h + 1) * ringWidth) - ringPadding;
      
      // Desfase concéntrico entre anillos (el anillo exterior sigue al interior)
      final ringLag = (h / math.max(habits.length, 1)) * 0.10;

      // Buscar bloques de horario vinculados a este hábito
      final relatedBlocks = scheduleBlocks.where((b) =>
          (b.habitId != null && b.habitId == habit.id) ||
          b.title.trim().toLowerCase() == habit.name.trim().toLowerCase() ||
          (habit.name.toLowerCase().contains('trabaj') && b.title.toLowerCase().contains('trabaj')) ||
          (habit.name.toLowerCase().contains('turno') && b.title.toLowerCase().contains('turno'))).toList();
      final monthPrefix = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
      final hasAssignedCalendarDates = relatedBlocks.any((b) => b.assignedDates.any((d) => d.startsWith(monthPrefix)));

      for (int d = 1; d <= daysInMonth; d++) {
        final dayFraction = (d - 1) / (daysInMonth > 0 ? daysInMonth : 1);
        final cellStart = (dayFraction * 0.72 + ringLag).clamp(0.0, 0.88);
        final cellEnd = (cellStart + 0.12).clamp(0.0, 1.0);

        if (animationValue < cellStart) continue;

        double cellProgress = 1.0;
        if (animationValue < cellEnd) {
          cellProgress = (animationValue - cellStart) / (cellEnd - cellStart);
          cellProgress = const Cubic(0.16, 1.0, 0.3, 1.0).transform(cellProgress);
        }

        final date = DateTime(currentMonth.year, currentMonth.month, d);
        final dateIso = date.toIso8601String().split('T').first;
        final isFutureDay = date.isAfter(DateTime(now.year, now.month, now.day));
        final isCompleted = !isFutureDay && habit.completedDates.contains(dateIso);

        // Determinamos si el hábito está programado para este día
        bool isScheduled = true;
        if (relatedBlocks.isNotEmpty) {
          if (hasAssignedCalendarDates) {
            isScheduled = relatedBlocks.any((b) => b.assignedDates.contains(dateIso));
          } else {
            isScheduled = relatedBlocks.any((b) => b.daysOfWeek.contains(date.weekday));
          }
        } else if (habit.frequencyType == 0) {
          isScheduled = habit.activeWeekdays.contains(date.weekday);
        }

        // Si NO está programado para este día y NO está completado, dejamos el hueco limpio (espacio negativo puro)
        if (!isScheduled && !isCompleted) {
          continue;
        }
        
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        // Cada casilla se abre como un fuelle de acordeón a lo largo del arco
        final fullSweep = anglePerDay - 0.04;
        final animatedSweep = fullSweep * cellProgress;

        if (animatedSweep <= 0.0001) continue;

        final path = Path();
        path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, animatedSweep, true);
        path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + animatedSweep, -animatedSweep, false);
        path.close();

        final paint = Paint()..style = PaintingStyle.fill;

        if (isCompleted) {
          paint.color = habit.color.withValues(alpha: cellProgress);
        } else {
          paint.color = habit.color.withValues(alpha: 0.08 * cellProgress);
        }

        canvas.drawPath(path, paint);
      }
    }

    // 3. Hover indicator (Scrubbing feedback)
    if (hoveredDay != null && hoveredDay! >= 1 && hoveredDay! <= daysInMonth) {
      final d = hoveredDay!;
      final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
      final sweepAngle = anglePerDay - 0.04;
      final outerRadius = minRadius + (habits.length * ringWidth) - ringPadding;
      final innerRadius = minRadius + ringPadding;

      final path = Path();
      path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweepAngle, true);
      path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + sweepAngle, -sweepAngle, false);
      path.close();

      final hoverPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withOpacity(0.9);

      canvas.drawPath(path, hoverPaint);
    }

    // 4. Glow effect (Apple Watch style) for perfectly completed days
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(currentMonth.year, currentMonth.month, d);
      final dateIso = date.toIso8601String().split('T').first;
      
      bool allCompleted = true;
      bool hasAnyDue = false;
      
      for (var habit in habits) {
        bool isDueToday = false;
        
        if (habit.frequencyType == 0) {
          isDueToday = habit.activeWeekdays.contains(date.weekday);
        } else {
          // Si es flexible, no es "obligatorio" un día en concreto, 
          // salvo que decidamos que rompa el día perfecto. Lo más justo es que
          // no lo rompa (no era obligatorio *hoy*). Si lo haces, genial, sale pintado.
          isDueToday = false; 
        }

        if (isDueToday) {
          hasAnyDue = true;
          if (!habit.completedDates.contains(dateIso)) {
            allCompleted = false;
            break;
          }
        } else {
           // If it wasn't due, but we completed it anyway (e.g. flexible habit, or done on off-day),
           // it still counts as something positive, so we can mark hasAnyDue = true to allow the glow
           if (habit.completedDates.contains(dateIso)) {
             hasAnyDue = true;
           }
        }
      }

      if (hasAnyDue && allCompleted && habits.isNotEmpty) {
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        final sweepAngle = anglePerDay - 0.04;
        final outerRadius = minRadius + (habits.length * ringWidth) - ringPadding;
        final innerRadius = minRadius + ringPadding;

        // Draw a glowing border around the whole day column
        final path = Path();
        path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweepAngle, true);
        path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + sweepAngle, -sweepAngle, false);
        path.close();

        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withOpacity(0.8 * animationValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4.0);

        canvas.drawPath(path, glowPaint);
      }
    }

    // 5. NÚCLEO CENTRAL TÉCNICO (The Dial Core)
    final coreRadius = minRadius * 0.88;
    final corePaint = Paint()
      ..color = gridTextColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, coreRadius, corePaint);

    // Crosshairs sutiles de precisión
    final tickLen = coreRadius * 0.14;
    canvas.drawLine(Offset(center.dx - coreRadius, center.dy), Offset(center.dx - coreRadius + tickLen, center.dy), corePaint);
    canvas.drawLine(Offset(center.dx + coreRadius, center.dy), Offset(center.dx + coreRadius - tickLen, center.dy), corePaint);
    canvas.drawLine(Offset(center.dx, center.dy - coreRadius), Offset(center.dx, center.dy - coreRadius + tickLen), corePaint);
    canvas.drawLine(Offset(center.dx, center.dy + coreRadius), Offset(center.dx, center.dy + coreRadius - tickLen), corePaint);

    // Métricas del núcleo (Hábitos de hoy completados)
    int completedToday = 0;
    int totalToday = 0;
    final todayIsoStr = DateTime.now().toIso8601String().split('T').first;
    for (final h in habits) {
      if (h.frequencyType == 0) {
        if (h.activeWeekdays.contains(DateTime.now().weekday)) {
          totalToday++;
          if (h.completedDates.contains(todayIsoStr)) completedToday++;
        }
      } else {
        totalToday++;
        if (h.completedDates.contains(todayIsoStr)) completedToday++;
      }
    }

    final percentToday = totalToday > 0 ? ((completedToday / totalToday) * 100).toInt() : 100;

    // Indicador numérico central
    final coreNumPainter = TextPainter(
      text: TextSpan(
        text: '$completedToday/$totalToday',
        style: AppTheme.monoStyle(
          fontSize: (coreRadius * 0.44).clamp(14.0, 22.0),
          fontWeight: FontWeight.w800,
          color: (completedToday == totalToday && totalToday > 0)
              ? AppTheme.dynamicAccent(isDark)
              : (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    coreNumPainter.paint(
      canvas,
      Offset(center.dx - coreNumPainter.width / 2, center.dy - coreNumPainter.height / 2 - 5),
    );

    // Subtítulo central
    final coreSubPainter = TextPainter(
      text: TextSpan(
        text: 'HOY · $percentToday%',
        style: AppTheme.monoStyle(
          fontSize: (coreRadius * 0.20).clamp(8.5, 10.5),
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    coreSubPainter.paint(
      canvas,
      Offset(center.dx - coreSubPainter.width / 2, center.dy + coreNumPainter.height / 2 - 3),
    );
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) {
    return oldDelegate.habits != habits ||
           oldDelegate.currentMonth != currentMonth ||
           oldDelegate.hoveredDay != hoveredDay ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isDark != isDark;
  }
}

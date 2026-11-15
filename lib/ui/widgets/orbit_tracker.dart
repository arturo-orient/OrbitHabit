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
          child: RepaintBoundary(
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

  List<ScheduleBlock> _getRelatedBlocks(Habit habit) {
    return scheduleBlocks.where((b) =>
        (b.habitId != null && b.habitId == habit.id) ||
        b.title.trim().toLowerCase() == habit.name.trim().toLowerCase() ||
        (habit.name.toLowerCase().contains('trabaj') && b.title.toLowerCase().contains('trabaj')) ||
        (habit.name.toLowerCase().contains('turno') && b.title.toLowerCase().contains('turno'))).toList();
  }

  bool _hasAssignedCalendarDates(List<ScheduleBlock> relatedBlocks, DateTime month) {
    final monthPrefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return relatedBlocks.any((b) => b.assignedDates.any((d) => d.startsWith(monthPrefix)));
  }

  /// Determina si un hábito debe pintarse en opaco (día activo) en [date].
  @visibleForTesting
  static bool isHabitScheduledForDate(
    Habit habit,
    DateTime date,
    String dateIso,
    List<ScheduleBlock> relatedBlocks,
    bool hasAssignedCalendarDates,
  ) {
    if (relatedBlocks.isNotEmpty) {
      if (hasAssignedCalendarDates) {
        return relatedBlocks.any((b) => b.assignedDates.contains(dateIso));
      } else {
        return relatedBlocks.any(
          (b) => b.daysOfWeek.isEmpty || b.daysOfWeek.contains(date.weekday),
        );
      }
    }
    return habit.activeWeekdays.isEmpty ||
        habit.activeWeekdays.contains(date.weekday);
  }

  bool _isHabitScheduledOnDate(
    Habit habit,
    DateTime date,
    String dateIso,
    List<ScheduleBlock> relatedBlocks,
    bool hasAssignedCalendarDates,
  ) =>
      isHabitScheduledForDate(
        habit,
        date,
        dateIso,
        relatedBlocks,
        hasAssignedCalendarDates,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = math.min(size.width, size.height) * 0.37;
    final minRadius = maxRadius * 0.3;

    // Rejilla de alta precisión adaptativa al tema
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final startOffsetAngle = math.pi;
    final totalSweep = math.pi * 1.6;

    if (habits.isEmpty) {
      // Modo Blueprint en Espera: 3 anillos concéntricos sutiles
      for (int i = 0; i < 3; i++) {
        final r = minRadius + (i * ((maxRadius - minRadius) / 2));
        final path = Path()
          ..arcTo(Rect.fromCircle(center: center, radius: r), startOffsetAngle, totalSweep, true);
        canvas.drawPath(path, gridPaint);
      }

      // Núcleo central técnico con crosshairs
      final coreRadius = minRadius * 0.88;
      final corePaint = Paint()
        ..color = gridTextColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, coreRadius, corePaint);

      final tickLen = coreRadius * 0.14;
      canvas.drawLine(Offset(center.dx - coreRadius, center.dy), Offset(center.dx - coreRadius + tickLen, center.dy), corePaint);
      canvas.drawLine(Offset(center.dx + coreRadius, center.dy), Offset(center.dx + coreRadius - tickLen, center.dy), corePaint);
      canvas.drawLine(Offset(center.dx, center.dy - coreRadius), Offset(center.dx, center.dy - coreRadius + tickLen), corePaint);
      canvas.drawLine(Offset(center.dx, center.dy + coreRadius), Offset(center.dx, center.dy + coreRadius - tickLen), corePaint);

      // Texto '0/0' y 'EN ESPERA'
      final numPainter = TextPainter(
        text: TextSpan(
          text: '0/0',
          style: AppTheme.monoStyle(
            fontSize: (coreRadius * 0.44).clamp(14.0, 22.0),
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numPainter.paint(canvas, Offset(center.dx - numPainter.width / 2, center.dy - numPainter.height / 2 - 5));

      final subPainter = TextPainter(
        text: TextSpan(
          text: 'EN ESPERA',
          style: AppTheme.monoStyle(
            fontSize: (coreRadius * 0.18).clamp(8.0, 10.0),
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subPainter.paint(canvas, Offset(center.dx - subPainter.width / 2, center.dy + numPainter.height / 2 - 3));

      return;
    }

    final availableRadius = maxRadius - minRadius;
    final ringWidth = availableRadius / (habits.length > 0 ? habits.length : 1);
    final ringPadding = ringWidth * 0.08; // Slightly reduced padding for a cleaner visual grid

    final daysInMonth = OrbitDateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
    final anglePerDay = totalSweep / daysInMonth;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;
    final today = now.day;
    final todayDate = DateTime(now.year, now.month, now.day);
    final accentColor = AppTheme.dynamicAccent(isDark);

    // Precalcular bloques relacionados por hábito y qué días tienen TODAS las tareas completadas
    final relatedBlocksByHabitId = <String, List<ScheduleBlock>>{
      for (final habit in habits) habit.id: _getRelatedBlocks(habit),
    };
    final fullCompletedDays = <int>{};
    if (habits.isNotEmpty) {
      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(currentMonth.year, currentMonth.month, d);
        if (date.isAfter(todayDate)) continue;
        final dateIso = date.toIso8601String().split('T').first;
        final allDone = habits.every((habit) {
          final rel = relatedBlocksByHabitId[habit.id] ?? const <ScheduleBlock>[];
          return habit.completedDates.contains(dateIso) ||
              rel.any((b) => b.completedDates.contains(dateIso));
        });
        if (allDone) {
          fullCompletedDays.add(d);
        }
      }
    }

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
    final radialLinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

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
      final isFullDay = fullCompletedDays.contains(d);

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(rotationAngle);

      if (isToday) {
        final highlightPaint = Paint()
          ..color = accentColor.withValues(alpha: numOpacity)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 20.0, height: 16.0),
            const Radius.circular(3.5),
          ),
          highlightPaint,
        );
      } else if (isFullDay) {
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 20.0, height: 15.5),
          const Radius.circular(3.5),
        );
        final fillPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.18 * numOpacity)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = accentColor.withValues(alpha: 0.80 * numOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawRRect(badgeRect, fillPaint);
        canvas.drawRRect(badgeRect, strokePaint);
      }

      textPainter.text = TextSpan(
        text: d.toString().padLeft(2, '0'),
        style: AppTheme.monoStyle(
          color: isToday
              ? (isDark ? AppTheme.obsidianCanvas : Colors.white)
              : isFullDay
                  ? accentColor.withValues(alpha: numOpacity)
                  : (isDark
                      ? gridTextColor.withValues(alpha: 0.75 * numOpacity)
                      : AppTheme.boneTextPrimary.withValues(alpha: 0.85 * numOpacity)),
          fontSize: (isToday || isFullDay) ? 10.0 : 9.0,
          fontWeight: (isToday || isFullDay) ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.0,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
      
      // Draw radial grid lines reutilizando instancia de Paint
      final innerTx = center.dx + minRadius * math.cos(startAngle);
      final innerTy = center.dy + minRadius * math.sin(startAngle);
      final outerTx = center.dx + maxRadius * math.cos(startAngle);
      final outerTy = center.dy + maxRadius * math.sin(startAngle);
      radialLinePaint.color = gridTextColor.withValues(alpha: 0.06 * numOpacity);
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

    // Rectángulos orbitales compartidos para indicadores de columna completa
    final outerRingRadius = minRadius + (habits.length * ringWidth) - ringPadding;
    final innerRingRadius = minRadius + ringPadding;
    final ringRectInner = Rect.fromCircle(center: center, radius: innerRingRadius);
    final ringRectOuter = Rect.fromCircle(center: center, radius: outerRingRadius);

    // 3. Casillas de hábitos: apertura de acordeón/fuelle circular (acelerada por hardware vía drawArc)
    for (int h = 0; h < habits.length; h++) {
      final habitIndex = habits.length - 1 - h;
      final habit = habits[habitIndex];
      final innerRadius = minRadius + (h * ringWidth) + ringPadding;
      final outerRadius = minRadius + ((h + 1) * ringWidth) - ringPadding;

      final midRadius = (innerRadius + outerRadius) * 0.5;
      final ringThickness = (outerRadius - innerRadius).clamp(1.0, 200.0);
      final cellPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..strokeCap = StrokeCap.butt;
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85;
      final midRect = Rect.fromCircle(center: center, radius: midRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      
      // Desfase concéntrico entre anillos (el anillo exterior sigue al interior)
      final ringLag = (h / math.max(habits.length, 1)) * 0.10;

      // Buscar bloques de horario vinculados a este hábito
      final relatedBlocks = _getRelatedBlocks(habit);
      final hasAssignedCalendarDates = _hasAssignedCalendarDates(relatedBlocks, currentMonth);

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
        final isCompleted = !isFutureDay &&
            (habit.completedDates.contains(dateIso) ||
                relatedBlocks.any((b) => b.completedDates.contains(dateIso)));

        // Determinamos si el hábito está programado para este día
        final isScheduled = _isHabitScheduledOnDate(
          habit,
          date,
          dateIso,
          relatedBlocks,
          hasAssignedCalendarDates,
        );

        // Si NO está programado para este día y NO está completado, dejamos el hueco limpio (espacio negativo puro)
        if (!isScheduled && !isCompleted) {
          continue;
        }
        
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        final fullSweep = anglePerDay - 0.04;
        final animatedSweep = fullSweep * cellProgress;

        if (animatedSweep <= 0.0001) continue;

        if (isCompleted) {
          cellPaint.color = habit.color.withValues(alpha: cellProgress);
          canvas.drawArc(midRect, startAngle, animatedSweep, false, cellPaint);
        } else {
          cellPaint.color = habit.color.withValues(
            alpha: (isDark ? 0.16 : 0.18) * cellProgress,
          );
          canvas.drawArc(midRect, startAngle, animatedSweep, false, cellPaint);

          // Borde sutil para que la pauta de días activos (ej. L-V) destaque en opaco
          borderPaint.color = habit.color.withValues(alpha: 0.28 * cellProgress);
          final cellBorderPath = Path()
            ..arcTo(innerRect, startAngle, animatedSweep, true)
            ..arcTo(outerRect, startAngle + animatedSweep, -animatedSweep, false)
            ..close();
          canvas.drawPath(cellBorderPath, borderPaint);
        }
      }
    }

    // 3. Hover indicator (Scrubbing feedback con rectángulos cacheados)
    if (hoveredDay != null && hoveredDay! >= 1 && hoveredDay! <= daysInMonth) {
      final d = hoveredDay!;
      final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
      final sweepAngle = anglePerDay - 0.04;

      final path = Path()
        ..arcTo(ringRectInner, startAngle, sweepAngle, true)
        ..arcTo(ringRectOuter, startAngle + sweepAngle, -sweepAngle, false)
        ..close();

      final hoverPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withValues(alpha: 0.9);

      canvas.drawPath(path, hoverPaint);
    }

    // 3b. Remarcado visual de días con TODAS las tareas completadas
    if (fullCompletedDays.isNotEmpty) {
      final fullDayGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = accentColor.withValues(alpha: 0.55 * animationValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3.5);
      final fullDayBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = (isDark ? Colors.white : accentColor)
            .withValues(alpha: 0.90 * animationValue);

      for (final d in fullCompletedDays) {
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        final sweepAngle = (anglePerDay - 0.04) * animationValue.clamp(0.0, 1.0);
        if (sweepAngle <= 0.0001) continue;

        final path = Path()
          ..arcTo(ringRectInner, startAngle, sweepAngle, true)
          ..arcTo(ringRectOuter, startAngle + sweepAngle, -sweepAngle, false)
          ..close();

        canvas.drawPath(path, fullDayGlowPaint);
        canvas.drawPath(path, fullDayBorderPaint);
      }
    }

    // 4. NÚCLEO CENTRAL TÉCNICO (The Dial Core)
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
    final todayIsoStr = todayDate.toIso8601String().split('T').first;
    for (final h in habits) {
      final relatedBlocks = _getRelatedBlocks(h);
      final hasAssigned = _hasAssignedCalendarDates(relatedBlocks, todayDate);
      final isScheduledToday = _isHabitScheduledOnDate(h, todayDate, todayIsoStr, relatedBlocks, hasAssigned);
      final isDoneToday = h.completedDates.contains(todayIsoStr) ||
          relatedBlocks.any((b) => b.completedDates.contains(todayIsoStr));

      if (relatedBlocks.isNotEmpty) {
        // En días libres según el cuadrante de turnos, no computa como pendiente (0/1 HOY)
        if (isScheduledToday) {
          totalToday++;
          if (isDoneToday) completedToday++;
        } else if (isDoneToday) {
          totalToday++;
          completedToday++;
        }
      } else if (h.frequencyType == 0) {
        if (h.activeWeekdays.contains(todayDate.weekday)) {
          totalToday++;
          if (isDoneToday) completedToday++;
        }
      } else {
        totalToday++;
        if (isDoneToday) completedToday++;
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
           oldDelegate.scheduleBlocks != scheduleBlocks ||
           oldDelegate.currentMonth != currentMonth ||
           oldDelegate.hoveredDay != hoveredDay ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isDark != isDark;
  }
}

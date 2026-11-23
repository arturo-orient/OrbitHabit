import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/sound_service.dart';
import '../theme/app_theme.dart';

class OrbitClock24 extends ConsumerStatefulWidget {
  final List<ScheduleBlock> blocks;
  final Function(ScheduleBlock block)? onBlockTapped;

  const OrbitClock24({
    Key? key,
    required this.blocks,
    this.onBlockTapped,
  }) : super(key: key);

  /// Descompone los turnos en los arcos estrictos que deben ser visualizados en el día `now` (00:00 - 24:00).
  /// Para turnos nocturnos (ej. 23:00 -> 07:00):
  /// - Tramo matutino (00:00 -> 07:00): Solo se pinta si el turno se inició ayer noche (`appliesToDate(yesterday)`).
  /// - Tramo nocturno (23:00 -> 24:00): Solo se pinta si el turno inicia hoy noche (`appliesToDate(now)`).
  static List<ClockArcSegment> getSegmentsForDay(List<ScheduleBlock> blocks, DateTime now) {
    return _OrbitClockPainter.getSegmentsForDay(blocks, now);
  }

  /// Devuelve los arcos continuos para dibujar e interactuar en el reloj 24H.
  /// Los turnos nocturnos que inician hoy (ej. 23:00 -> 07:00) se devuelven como
  /// un único arco continuo (`sweepMinutes = durationInMinutes`) que cruza las 00:00.
  static List<ClockArcSegment> getContinuousArcsForDay(List<ScheduleBlock> blocks, DateTime now) {
    return _OrbitClockPainter.getContinuousArcsForDay(blocks, now);
  }

  @override
  ConsumerState<OrbitClock24> createState() => _OrbitClock24State();
}

class _OrbitClock24State extends ConsumerState<OrbitClock24>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Timer _tickerTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Pulse animation for the live satellite indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Update time every 10 seconds for smooth live display
    _tickerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pulseController.stop();
    }
  }

  ScheduleBlock? _findActiveBlock(List<ScheduleBlock> blocks, DateTime now) {
    for (final block in blocks) {
      if (block.isActiveAt(now)) {
        return block;
      }
    }
    return null;
  }

  /// Calcula la fecha efectiva del turno considerando si es nocturno cruzando la medianoche
  String _getEffectiveDateIso(ScheduleBlock? block, DateTime now) {
    if (block != null && block.isOvernight) {
      final currentMinutes = now.hour * 60 + now.minute;
      final endMinutes = block.endHour * 60 + block.endMinute;
      final yesterday = now.subtract(const Duration(days: 1));
      if (currentMinutes < endMinutes && block.appliesToDate(yesterday)) {
        return yesterday.toIso8601String().split('T').first;
      }
    }
    return now.toIso8601String().split('T').first;
  }

  /// Hit-testing polar en los arcos del reloj horario
  ScheduleBlock? _getBlockAtPosition(Offset localPosition, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final maxRadius = math.min(size.width, size.height) * 0.44;
    final trackWidth = maxRadius * 0.18;

    // Comprueba si distance está dentro de la corona circular del anillo
    if (distance < (maxRadius - trackWidth - 8) || distance > (maxRadius + 8)) {
      return null;
    }

    // Ángulo polar desde las 00:00 (arriba, -math.pi / 2)
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    // Convierte el ángulo a minutos del día (0..1439)
    final tappedMinutes = ((angle / (2 * math.pi)) * 1440).floor() % 1440;

    final segments = _OrbitClockPainter.getContinuousArcsForDay(widget.blocks, _now);
    for (final seg in segments) {
      if (_OrbitClockPainter.minuteInSegment(tappedMinutes, seg)) {
        return seg.block;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final activeBlock = _findActiveBlock(widget.blocks, _now);

    Habit? linkedHabit;
    if (activeBlock != null) {
      if (activeBlock.habitId != null) {
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == activeBlock.habitId,
              orElse: () => null,
            );
      }
      if (linkedHabit == null) {
        final bTitle = activeBlock.title.trim().toLowerCase();
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) =>
                  h != null &&
                  (h.name.trim().toLowerCase() == bTitle ||
                      (h.name.toLowerCase().contains('trabaj') && bTitle.contains('trabaj')) ||
                      (h.name.toLowerCase().contains('turno') && bTitle.contains('turno'))),
              orElse: () => null,
            );
      }
    }

    final effectiveDateIso = _getEffectiveDateIso(activeBlock, _now);
    final isHabitDoneToday = (linkedHabit?.completedDates.contains(effectiveDateIso) ?? false) ||
        (activeBlock?.completedDates.contains(effectiveDateIso) ?? false);

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Hand-crafted 24-hour Canvas Dial aislado en RepaintBoundary con Hit-Testing Polar
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final tappedBlock = _getBlockAtPosition(details.localPosition, size);
                if (tappedBlock != null && widget.onBlockTapped != null) {
                  HapticFeedback.selectionClick();
                  widget.onBlockTapped!(tappedBlock);
                }
              },
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: size,
                      painter: _OrbitClockPainter(
                        blocks: widget.blocks,
                        habits: habits,
                        now: _now,
                        pulseValue: _pulseAnimation.value,
                        textColor: textColor,
                        activeBlock: activeBlock,
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Center Zen Core (Digital Time + Active Block Card + Quick Habit Toggle)
            SizedBox(
              width: size.width * 0.54,
              height: size.height * 0.54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Digital Live Clock
                  Text(
                    '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.outfit(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1.2,
                    ),
                  ),

                  if (activeBlock != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${activeBlock.title} · ${activeBlock.formattedTimeRange.replaceAll(' - ', ' ➔ ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTheme.monoStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: (linkedHabit?.color ?? activeBlock.color),
                        ),
                      ),
                    ),
                    // Quick Habit Toggle Action Button if linked to a Habit!
                    if (linkedHabit != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (!isHabitDoneToday) {
                            SoundService().playCheck();
                          }
                          ref
                              .read(scheduleProvider.notifier)
                              .toggleDateForBlock(activeBlock.id, effectiveDateIso);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isHabitDoneToday
                                ? linkedHabit.color.withOpacity(0.2)
                                : linkedHabit.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: linkedHabit.color,
                              width: 1.5,
                            ),
                            boxShadow: isHabitDoneToday
                                ? []
                                : [
                                    BoxShadow(
                                      color:
                                          linkedHabit.color.withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHabitDoneToday
                                    ? Icons.check_circle
                                    : Icons.check,
                                size: 14,
                                color: isHabitDoneToday
                                    ? linkedHabit.color
                                    : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isHabitDoneToday
                                    ? 'Completado'
                                    : 'Marcar Hecho',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isHabitDoneToday
                                      ? linkedHabit.color
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Quick Block/Shift Completion Button when not linked to a Habit
                    if (linkedHabit == null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isShiftDoneToday = activeBlock.completedDates.contains(effectiveDateIso);
                          final shiftColor = activeBlock.color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              if (!isShiftDoneToday) {
                                SoundService().playCheck();
                              }
                              ref.read(scheduleProvider.notifier).toggleDateForBlock(activeBlock.id, effectiveDateIso);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isShiftDoneToday
                                    ? shiftColor.withOpacity(0.2)
                                    : shiftColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: shiftColor, width: 1.5),
                                boxShadow: isShiftDoneToday
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: shiftColor.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isShiftDoneToday
                                        ? Icons.check_circle
                                        : (activeBlock.hasMonthlyHourTarget ? Icons.work_outline : Icons.check),
                                    size: 14,
                                    color: isShiftDoneToday ? shiftColor : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isShiftDoneToday
                                        ? (activeBlock.hasMonthlyHourTarget ? 'Turno Registrado' : 'Completado')
                                        : (activeBlock.hasMonthlyHourTarget ? 'Registrar Turno' : 'Marcar Hecho'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isShiftDoneToday ? shiftColor : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbitClockPainter extends CustomPainter {
  final List<ScheduleBlock> blocks;
  final List<Habit> habits;
  final DateTime now;
  final double pulseValue;
  final Color textColor;
  final ScheduleBlock? activeBlock;

  _OrbitClockPainter({
    required this.blocks,
    required this.habits,
    required this.now,
    required this.pulseValue,
    required this.textColor,
    this.activeBlock,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = math.min(size.width, size.height) * 0.44;
    final trackWidth = maxRadius * 0.18;
    final trackRadius = maxRadius - trackWidth * 0.5;

    // 1. Background Orbital Track (Circle Ring)
    final trackBgPaint = Paint()
      ..color = textColor.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth;
    canvas.drawCircle(center, trackRadius, trackBgPaint);

    final trackBorderPaint = Paint()
      ..color = textColor.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius, trackBorderPaint);
    canvas.drawCircle(center, maxRadius - trackWidth, trackBorderPaint);

    // 2. 24-Hour Markers and Subtle Radial Ticks
    final tickPaint = Paint()
      ..color = textColor.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int h = 0; h < 24; h++) {
      // 00:00 starts at the very top (-pi/2)
      final angle = -math.pi / 2 + (h / 24.0) * 2 * math.pi;

      final isMajor = h % 6 == 0; // 00, 06, 12, 18
      final isSubMajor = h % 3 == 0; // 03, 09, 15, 21

      final tickInner = maxRadius - trackWidth - (isMajor ? 6.0 : (isSubMajor ? 4.0 : 2.0));
      final tickOuter = maxRadius - trackWidth;

      final p1 = Offset(
        center.dx + tickInner * math.cos(angle),
        center.dy + tickInner * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + tickOuter * math.cos(angle),
        center.dy + tickOuter * math.sin(angle),
      );

      tickPaint.strokeWidth = isMajor ? 1.5 : 0.8;
      tickPaint.color = textColor.withOpacity(isMajor ? 0.35 : 0.15);
      canvas.drawLine(p1, p2, tickPaint);

      // Print Hour Labels at major intervals (00, 06, 12, 18 or 3-hour steps)
      if (isSubMajor) {
        final labelRadius = maxRadius + 12.0;
        final tx = center.dx + labelRadius * math.cos(angle);
        final ty = center.dy + labelRadius * math.sin(angle);

        final label = h.toString().padLeft(2, '0');
        textPainter.text = TextSpan(
          text: label,
          style: GoogleFonts.outfit(
            fontSize: isMajor ? 11 : 9.5,
            fontWeight: isMajor ? FontWeight.bold : FontWeight.w500,
            color: textColor.withOpacity(isMajor ? 0.7 : 0.4),
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(tx - textPainter.width / 2, ty - textPainter.height / 2),
        );
      }
    }

    // 3. Draw Scheduled Time Blocks as Continuous Coloured Arc Segments (with Concentric Lanes for Overlaps)
    final segments = getContinuousArcsForDay(blocks, now);

    // Calculamos carriles concéntricos (soportando arcos que cruzan las 24:00)
    final Map<ClockArcSegment, int> segmentLanes = {};
    final Map<ClockArcSegment, int> segmentMaxLanes = {};

    for (int i = 0; i < segments.length; i++) {
      final current = segments[i];
      final usedLanes = <int>{};

      for (int j = 0; j < segments.length; j++) {
        if (i == j) continue;
        final other = segments[j];
        if (_segmentsOverlap(current, other)) {
          if (segmentLanes.containsKey(other)) {
            usedLanes.add(segmentLanes[other]!);
          }
        }
      }

      int lane = 0;
      while (usedLanes.contains(lane)) {
        lane++;
      }
      segmentLanes[current] = lane;
    }

    for (final current in segments) {
      int localMaxLane = segmentLanes[current]!;
      for (final other in segments) {
        if (current == other) continue;
        if (_segmentsOverlap(current, other)) {
          localMaxLane = math.max(localMaxLane, segmentLanes[other]!);
        }
      }
      segmentMaxLanes[current] = localMaxLane + 1;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    final todayIso = _isoDate(now);
    final isDarkTheme = textColor.computeLuminance() > 0.5;
    final List<Offset> placedLabelCenters = [];

    for (final seg in segments) {
      final block = seg.block;
      // Check if linked to a habit to inherit its official color and completion status
      Habit? linked;
      if (block.habitId != null) {
        linked = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == block.habitId,
              orElse: () => null,
            );
      }
      final blockColor = linked?.color ?? block.color;
      final isLightBlockColor = blockColor.computeLuminance() > 0.55;
      final contrastFg = isLightBlockColor ? const Color(0xFF141414) : Colors.white;
      final effectiveIso = seg.effectiveDateIso ?? todayIso;
      final isSegmentCompleted = block.completedDates.contains(effectiveIso) ||
          (linked?.completedDates.contains(effectiveIso) ?? false);

      final startAngle = -math.pi / 2 + (seg.startMinutes / 1440.0) * 2 * math.pi;
      final sweepAngle = (seg.sweepMinutes / 1440.0) * 2 * math.pi;

      final isSegmentActive = (block == activeBlock) &&
          minuteInSegment(currentMinutes, seg);

      final numLanes = segmentMaxLanes[seg] ?? 1;
      final laneIndex = segmentLanes[seg] ?? 0;

      double currentTrackRadius;
      double currentStrokeWidth;

      if (numLanes == 1) {
        currentTrackRadius = trackRadius;
        currentStrokeWidth = isSegmentActive ? trackWidth * 0.95 : trackWidth * 0.82;
      } else {
        // Distribución en carriles concéntricos paralelos
        const laneGap = 2.5;
        final totalAvailableWidth = trackWidth * 0.92;
        final singleLaneWidth = (totalAvailableWidth - (numLanes - 1) * laneGap) / numLanes;
        currentStrokeWidth = singleLaneWidth;

        final outerOffset = (totalAvailableWidth * 0.5) - (singleLaneWidth * 0.5);
        final offset = outerOffset - laneIndex * (singleLaneWidth + laneGap);
        currentTrackRadius = trackRadius + offset;
      }

      final arcStartAngle = startAngle + 0.015;
      final safeSweep = (sweepAngle - 0.03).clamp(0.01, math.pi * 2);
      final arcEndAngle = arcStartAngle + safeSweep;
      final arcRect = Rect.fromCircle(center: center, radius: currentTrackRadius);

      if (isSegmentCompleted) {
        // Completado: halo sutil + arco sólido 100% + marcadores de dirección + insignia de check
        final glowPaint = Paint()
          ..color = blockColor.withValues(alpha: isSegmentActive ? 0.45 * pulseValue : 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth * 1.45
          ..strokeCap = StrokeCap.butt
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
        canvas.drawArc(arcRect, arcStartAngle, safeSweep, false, glowPaint);

        final completedPaint = Paint()
          ..color = blockColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(arcRect, arcStartAngle, safeSweep, false, completedPaint);
      } else {
        // Pendiente: cuerpo translúcido legible + guía central definida (sin redondeo simétrico)
        if (isSegmentActive) {
          final glowPaint = Paint()
            ..color = blockColor.withValues(alpha: 0.28 * pulseValue)
            ..style = PaintingStyle.stroke
            ..strokeWidth = currentStrokeWidth * 1.35
            ..strokeCap = StrokeCap.butt
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
          canvas.drawArc(arcRect, arcStartAngle, safeSweep, false, glowPaint);
        }

        final pendingPaint = Paint()
          ..color = blockColor.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(arcRect, arcStartAngle, safeSweep, false, pendingPaint);

        final guidePaint = Paint()
          ..color = blockColor.withValues(alpha: 0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (currentStrokeWidth * 0.18).clamp(1.8, 3.2)
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(arcRect, arcStartAngle, safeSweep, false, guidePaint);
      }

      // Chevrons direccionales horarios (›) indicando flujo Inicio ➔ Fin
      final chevronFractions = isSegmentCompleted
          ? (safeSweep >= 0.65 ? const [0.22, 0.78] : const <double>[])
          : (safeSweep >= 0.55
              ? const [0.24, 0.50, 0.76]
              : (safeSweep >= 0.22 ? const [0.50] : const <double>[]));
      final chevronArm = (currentStrokeWidth * 0.23).clamp(2.8, 4.6);
      final chevronPaint = Paint()
        ..color = isSegmentCompleted
            ? contrastFg.withValues(alpha: 0.78)
            : contrastFg.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (chevronArm * 0.40).clamp(1.3, 2.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final f in chevronFractions) {
        final theta = arcStartAngle + safeSweep * f;
        final ur = Offset(math.cos(theta), math.sin(theta));
        final ut = Offset(-math.sin(theta), math.cos(theta));
        final pt = Offset(
          center.dx + currentTrackRadius * ur.dx,
          center.dy + currentTrackRadius * ur.dy,
        );
        final path = Path()
          ..moveTo(
            pt.dx - ut.dx * chevronArm * 0.45 + ur.dx * chevronArm * 0.65,
            pt.dy - ut.dy * chevronArm * 0.45 + ur.dy * chevronArm * 0.65,
          )
          ..lineTo(
            pt.dx + ut.dx * chevronArm * 0.55,
            pt.dy + ut.dy * chevronArm * 0.55,
          )
          ..lineTo(
            pt.dx - ut.dx * chevronArm * 0.45 - ur.dx * chevronArm * 0.65,
            pt.dy - ut.dy * chevronArm * 0.45 - ur.dy * chevronArm * 0.65,
          );
        canvas.drawPath(path, chevronPaint);
      }

      // Nodo de INICIO (●) en arcStartAngle para distinguir inequívocamente dónde arranca
      if (safeSweep >= 0.08) {
        final startUr = Offset(math.cos(arcStartAngle), math.sin(arcStartAngle));
        final startPt = Offset(
          center.dx + currentTrackRadius * startUr.dx,
          center.dy + currentTrackRadius * startUr.dy,
        );
        final startRadius = (currentStrokeWidth * 0.38).clamp(4.0, 7.0);
        canvas.drawCircle(
          startPt,
          startRadius,
          Paint()
            ..color = blockColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          startPt,
          startRadius * 0.55,
          Paint()
            ..color = contrastFg
            ..style = PaintingStyle.fill,
        );
      }

      // Punta de flecha + barra terminal de FIN (▸|) en arcEndAngle
      if (safeSweep >= 0.08) {
        final endUr = Offset(math.cos(arcEndAngle), math.sin(arcEndAngle));
        final endUt = Offset(-math.sin(arcEndAngle), math.cos(arcEndAngle));
        final endPt = Offset(
          center.dx + currentTrackRadius * endUr.dx,
          center.dy + currentTrackRadius * endUr.dy,
        );
        final barHalf = (currentStrokeWidth * 0.46).clamp(5.0, 9.2);
        final tipSize = (currentStrokeWidth * 0.30).clamp(3.2, 5.6);

        // Barra radial de cierre perpendicular al anillo
        canvas.drawLine(
          endPt - endUr * barHalf,
          endPt + endUr * barHalf,
          Paint()
            ..color = isSegmentCompleted ? contrastFg : blockColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );

        // Punta de flecha apuntando en sentido horario hacia la barra final
        final arrowPath = Path()
          ..moveTo(
            endPt.dx - endUt.dx * (tipSize * 1.15) + endUr.dx * (tipSize * 0.72),
            endPt.dy - endUt.dy * (tipSize * 1.15) + endUr.dy * (tipSize * 0.72),
          )
          ..lineTo(
            endPt.dx - endUt.dx * 1.4,
            endPt.dy - endUt.dy * 1.4,
          )
          ..lineTo(
            endPt.dx - endUt.dx * (tipSize * 1.15) - endUr.dx * (tipSize * 0.72),
            endPt.dy - endUt.dy * (tipSize * 1.15) - endUr.dy * (tipSize * 0.72),
          )
          ..close();
        canvas.drawPath(
          arrowPath,
          Paint()
            ..color = isSegmentCompleted ? contrastFg : blockColor
            ..style = PaintingStyle.fill,
        );
      }

      // Insignia circular de check (✓) en el punto medio para tramos completados
      if (isSegmentCompleted && safeSweep >= 0.14) {
        final midAngle = arcStartAngle + safeSweep * 0.5;
        final badgeCenter = Offset(
          center.dx + currentTrackRadius * math.cos(midAngle),
          center.dy + currentTrackRadius * math.sin(midAngle),
        );
        final badgeRadius = (currentStrokeWidth * 0.46).clamp(5.2, 8.8);

        canvas.drawCircle(
          badgeCenter,
          badgeRadius + 1.1,
          Paint()
            ..color = blockColor
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          badgeCenter,
          badgeRadius,
          Paint()
            ..color = contrastFg
            ..style = PaintingStyle.fill,
        );

        final checkPath = Path()
          ..moveTo(
            badgeCenter.dx - badgeRadius * 0.42,
            badgeCenter.dy + badgeRadius * 0.02,
          )
          ..lineTo(
            badgeCenter.dx - badgeRadius * 0.10,
            badgeCenter.dy + badgeRadius * 0.36,
          )
          ..lineTo(
            badgeCenter.dx + badgeRadius * 0.45,
            badgeCenter.dy - badgeRadius * 0.32,
          );
        canvas.drawPath(
          checkPath,
          Paint()
            ..color = blockColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = (badgeRadius * 0.30).clamp(1.4, 2.2)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      // Etiquetas interiores con la hora exacta de inicio (ej. 23:00) y fin (ej. 07:00)
      if (sweepAngle >= 0.35) {
        final startLabel = seg.isFromYesterday
            ? '00:00'
            : '${block.startHour.toString().padLeft(2, '0')}:${block.startMinute.toString().padLeft(2, '0')}';
        final endLabel =
            '${block.endHour.toString().padLeft(2, '0')}:${block.endMinute.toString().padLeft(2, '0')}';

        _drawEdgeTimeLabel(
          canvas: canvas,
          textPainter: textPainter,
          center: center,
          angle: startAngle + 0.09,
          ringInnerRadius: maxRadius - trackWidth,
          labelRadius: (maxRadius - trackWidth - 15.0).clamp(24.0, maxRadius),
          text: startLabel,
          accentColor: blockColor,
          isStart: true,
          isDarkTheme: isDarkTheme,
          textColor: textColor,
          placedCenters: placedLabelCenters,
        );

        _drawEdgeTimeLabel(
          canvas: canvas,
          textPainter: textPainter,
          center: center,
          angle: startAngle + sweepAngle - 0.09,
          ringInnerRadius: maxRadius - trackWidth,
          labelRadius: (maxRadius - trackWidth - 15.0).clamp(24.0, maxRadius),
          text: endLabel,
          accentColor: blockColor,
          isStart: false,
          isDarkTheme: isDarkTheme,
          textColor: textColor,
          placedCenters: placedLabelCenters,
        );
      }
    }

    // 4. Current Time Satellite Node (High-Contrast Needle + Double-Contour Marker + Outer Pointer)
    final currentAngle = -math.pi / 2 + (currentMinutes / 1440.0) * 2 * math.pi;
    final ur = Offset(math.cos(currentAngle), math.sin(currentAngle));
    final ut = Offset(-math.sin(currentAngle), math.cos(currentAngle));

    final needleInner = Offset(
      center.dx + (maxRadius - trackWidth - 5.0) * ur.dx,
      center.dy + (maxRadius - trackWidth - 5.0) * ur.dy,
    );
    final needleOuter = Offset(
      center.dx + (maxRadius + 4.5) * ur.dx,
      center.dy + (maxRadius + 4.5) * ur.dy,
    );

    // Aguja radial con contorno oscuro de contraste para destacar sobre cualquier color de bloque
    canvas.drawLine(
      needleInner,
      needleOuter,
      Paint()
        ..color = const Color(0xFF0A0A0A).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      needleInner,
      needleOuter,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    final satelliteCenter = Offset(
      center.dx + trackRadius * ur.dx,
      center.dy + trackRadius * ur.dy,
    );

    // Halo exterior luminoso
    final satelliteHaloPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * pulseValue)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(satelliteCenter, 10.5 * pulseValue, satelliteHaloPaint);

    // Anillo contorno oscuro (#0A0A0A, grosor 2.5px alrededor del núcleo de 5.5px -> radio 8.0px)
    final darkContourPaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 8.0, darkContourPaint);

    // Núcleo blanco puro (radio 5.5px)
    final satelliteCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 5.5, satelliteCorePaint);

    // Punto central de precisión
    final satelliteInnerDot = Paint()
      ..color = const Color(0xFFFF5A36)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 2.2, satelliteInnerDot);

    // Pequeño triángulo/puntero exterior apuntando radialmente hacia el dial
    final pointerTip = Offset(
      center.dx + (maxRadius + 1.8) * ur.dx,
      center.dy + (maxRadius + 1.8) * ur.dy,
    );
    final pointerBaseCenter = Offset(
      center.dx + (maxRadius + 8.8) * ur.dx,
      center.dy + (maxRadius + 8.8) * ur.dy,
    );
    const pointerHalfWidth = 4.6;
    final pointerPath = Path()
      ..moveTo(pointerTip.dx, pointerTip.dy)
      ..lineTo(
        pointerBaseCenter.dx + ut.dx * pointerHalfWidth,
        pointerBaseCenter.dy + ut.dy * pointerHalfWidth,
      )
      ..lineTo(
        pointerBaseCenter.dx - ut.dx * pointerHalfWidth,
        pointerBaseCenter.dy - ut.dy * pointerHalfWidth,
      )
      ..close();

    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = const Color(0xFF0A0A0A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  void _drawEdgeTimeLabel({
    required Canvas canvas,
    required TextPainter textPainter,
    required Offset center,
    required double angle,
    required double ringInnerRadius,
    required double labelRadius,
    required String text,
    required Color accentColor,
    required bool isStart,
    required bool isDarkTheme,
    required Color textColor,
    required List<Offset> placedCenters,
  }) {
    final pos = Offset(
      center.dx + labelRadius * math.cos(angle),
      center.dy + labelRadius * math.sin(angle),
    );
    for (final prev in placedCenters) {
      if ((pos - prev).distance < 26.0) return;
    }
    placedCenters.add(pos);

    textPainter.text = TextSpan(
      text: isStart ? '▶$text' : '$text■',
      style: AppTheme.monoStyle(
        fontSize: 8.5,
        fontWeight: isStart ? FontWeight.w800 : FontWeight.w700,
        color: isStart ? accentColor : textColor.withValues(alpha: 0.78),
      ),
    );
    textPainter.layout();

    final pillRect = Rect.fromCenter(
      center: pos,
      width: textPainter.width + 7,
      height: textPainter.height + 4,
    );
    final pillRRect = RRect.fromRectAndRadius(pillRect, const Radius.circular(4));

    final tickOuter = Offset(
      center.dx + (ringInnerRadius - 1.5) * math.cos(angle),
      center.dy + (ringInnerRadius - 1.5) * math.sin(angle),
    );
    final tickInner = Offset(
      center.dx + (ringInnerRadius - 5.5) * math.cos(angle),
      center.dy + (ringInnerRadius - 5.5) * math.sin(angle),
    );
    canvas.drawLine(
      tickOuter,
      tickInner,
      Paint()
        ..color = accentColor.withValues(alpha: isStart ? 0.70 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = (isDarkTheme ? const Color(0xEB141414) : const Color(0xF2F6F5F2))
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = accentColor.withValues(alpha: isStart ? 0.55 : 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  static String _isoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static List<(int, int)> _normalizedDayRanges(ClockArcSegment seg) {
    if (seg.sweepMinutes <= 0) return const [];
    final end = seg.startMinutes + seg.sweepMinutes;
    if (end <= 1440) {
      return [(seg.startMinutes, end)];
    }
    return [
      (seg.startMinutes, 1440),
      (0, (end - 1440).clamp(1, 1440)),
    ];
  }

  static bool _segmentsOverlap(ClockArcSegment a, ClockArcSegment b) {
    for (final ra in _normalizedDayRanges(a)) {
      for (final rb in _normalizedDayRanges(b)) {
        if (math.max(ra.$1, rb.$1) < math.min(ra.$2, rb.$2)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool minuteInSegment(int minuteOfDay, ClockArcSegment seg) {
    for (final r in _normalizedDayRanges(seg)) {
      if (minuteOfDay >= r.$1 && minuteOfDay < r.$2) {
        return true;
      }
    }
    return false;
  }

  /// Devuelve los arcos continuos para dibujar e interactuar en el reloj 24H.
  /// Solo incluye los bloques que aplican explícitamente al día `now` (sin arrastrar
  /// turnos nocturnos del día anterior si hoy no está marcado en el calendario).
  static List<ClockArcSegment> getContinuousArcsForDay(
    List<ScheduleBlock> blocks,
    DateTime now,
  ) {
    final todayIso = _isoDate(now);
    final segments = <ClockArcSegment>[];

    for (final block in blocks) {
      if (block.appliesToDate(now)) {
        segments.add(
          ClockArcSegment(
            block: block,
            startMinutes: block.startInMinutes,
            sweepMinutes: block.durationInMinutes,
            isForTonight: block.isOvernight,
            effectiveDateIso: todayIso,
          ),
        );
      }
    }
    return segments;
  }

  /// Descompone los turnos en los arcos estrictos que deben ser visualizados en el día `now` (00:00 - 24:00).
  /// Para turnos nocturnos (ej. 23:00 -> 07:00):
  /// - Tramo matutino (00:00 -> 07:00): Solo se pinta si el turno se inició ayer noche (`appliesToDate(yesterday)`).
  /// - Tramo nocturno (23:00 -> 24:00): Solo se pinta si el turno inicia hoy noche (`appliesToDate(now)`).
  static List<ClockArcSegment> getSegmentsForDay(List<ScheduleBlock> blocks, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    final segments = <ClockArcSegment>[];

    for (final block in blocks) {
      if (!block.isOvernight) {
        if (block.appliesToDate(now)) {
          segments.add(ClockArcSegment(
            block: block,
            startMinutes: block.startInMinutes,
            sweepMinutes: block.durationInMinutes,
          ));
        }
      } else {
        // Tramo matutino (00:00 -> endInMinutes) de turno iniciado anoche
        if (block.appliesToDate(yesterday)) {
          segments.add(ClockArcSegment(
            block: block,
            startMinutes: 0,
            sweepMinutes: block.endInMinutes,
            isFromYesterday: true,
          ));
        }
        // Tramo nocturno (startInMinutes -> 24:00) de turno que inicia esta noche
        if (block.appliesToDate(now)) {
          segments.add(ClockArcSegment(
            block: block,
            startMinutes: block.startInMinutes,
            sweepMinutes: 1440 - block.startInMinutes,
            isForTonight: true,
          ));
        }
      }
    }
    return segments;
  }

  @override
  bool shouldRepaint(covariant _OrbitClockPainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.blocks != blocks ||
        oldDelegate.habits != habits ||
        oldDelegate.textColor != textColor ||
        oldDelegate.activeBlock != activeBlock;
  }
}

class ClockArcSegment {
  final ScheduleBlock block;
  final int startMinutes;
  final int sweepMinutes;
  final bool isFromYesterday;
  final bool isForTonight;
  final String? effectiveDateIso;

  const ClockArcSegment({
    required this.block,
    required this.startMinutes,
    required this.sweepMinutes,
    this.isFromYesterday = false,
    this.isForTonight = false,
    this.effectiveDateIso,
  });

  int get endMinutes => startMinutes + sweepMinutes;
}

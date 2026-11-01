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

    final segments = _OrbitClockPainter.getSegmentsForDay(widget.blocks, _now);
    for (final seg in segments) {
      if (tappedMinutes >= seg.startMinutes && tappedMinutes < seg.endMinutes) {
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
    if (activeBlock?.habitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == activeBlock!.habitId,
            orElse: () => null,
          );
    }

    final effectiveDateIso = _getEffectiveDateIso(activeBlock, _now);
    final isHabitDoneToday = linkedHabit?.completedDates.contains(effectiveDateIso) ?? false;

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
                    // Quick Habit Toggle Action Button if linked to a Habit!
                    if (linkedHabit != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          SoundService().playCheck();
                          ref
                              .read(habitsProvider.notifier)
                              .toggleDay(linkedHabit!.id, effectiveDateIso);
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

                    // Quick Shift Completion Button if it has a monthly hour target (like night shift work!)
                    if (linkedHabit == null && activeBlock.hasMonthlyHourTarget) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final isShiftDoneToday = activeBlock.completedDates.contains(effectiveDateIso);
                          final shiftColor = activeBlock.color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              SoundService().playCheck();
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
                                    isShiftDoneToday ? Icons.check_circle : Icons.work_outline,
                                    size: 14,
                                    color: isShiftDoneToday ? shiftColor : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isShiftDoneToday ? 'Turno Registrado' : 'Registrar Turno',
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

    // 3. Draw Scheduled Time Blocks as Coloured Arc Segments (with Concentric Lanes for Overlaps)
    final segments = getSegmentsForDay(blocks, now);

    // Calculamos carriles concéntricos para evitar que tareas o tramos solapados se pisen
    final Map<ClockArcSegment, int> segmentLanes = {};
    final Map<ClockArcSegment, int> segmentMaxLanes = {};

    for (int i = 0; i < segments.length; i++) {
      final current = segments[i];
      final usedLanes = <int>{};

      for (int j = 0; j < segments.length; j++) {
        if (i == j) continue;
        final other = segments[j];
        final startMax = math.max(current.startMinutes, other.startMinutes);
        final endMin = math.min(current.endMinutes, other.endMinutes);
        if (startMax < endMin) {
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
        final startMax = math.max(current.startMinutes, other.startMinutes);
        final endMin = math.min(current.endMinutes, other.endMinutes);
        if (startMax < endMin) {
          localMaxLane = math.max(localMaxLane, segmentLanes[other]!);
        }
      }
      segmentMaxLanes[current] = localMaxLane + 1;
    }

    final currentMinutes = now.hour * 60 + now.minute;

    for (final seg in segments) {
      final block = seg.block;
      // Check if linked to a habit to inherit its official color
      Color blockColor = block.color;
      if (block.habitId != null) {
        final linked = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == block.habitId,
              orElse: () => null,
            );
        if (linked != null) {
          blockColor = linked.color;
        }
      }

      final startAngle = -math.pi / 2 + (seg.startMinutes / 1440.0) * 2 * math.pi;
      final sweepAngle = (seg.sweepMinutes / 1440.0) * 2 * math.pi;

      final isSegmentActive = (block == activeBlock) &&
          (currentMinutes >= seg.startMinutes && currentMinutes < seg.endMinutes);

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

      final blockPaint = Paint()
        ..color = isSegmentActive ? blockColor : blockColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round;

      final safeSweep = (sweepAngle - 0.04).clamp(0.01, math.pi * 2);

      // Glow effect if this segment is active right now!
      if (isSegmentActive) {
        final glowPaint = Paint()
          ..color = blockColor.withOpacity(0.40 * pulseValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth * 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: currentTrackRadius),
          startAngle + 0.02,
          safeSweep,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: currentTrackRadius),
        startAngle + 0.02,
        safeSweep,
        false,
        blockPaint,
      );
    }

    // 4. Current Time Satellite Node (Orbiting Indicator)
    final currentAngle = -math.pi / 2 + (currentMinutes / 1440.0) * 2 * math.pi;

    final satelliteCenter = Offset(
      center.dx + trackRadius * math.cos(currentAngle),
      center.dy + trackRadius * math.sin(currentAngle),
    );

    // Glowing halo around the satellite
    final satelliteHaloPaint = Paint()
      ..color = const Color(0xFFE6A590).withOpacity(0.4 * pulseValue)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(satelliteCenter, 8.0 * pulseValue, satelliteHaloPaint);

    // Solid core of the satellite
    final satellitePaint = Paint()
      ..color = const Color(0xFFE6A590) // Coral Zen accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 4.5, satellitePaint);

    final satelliteInnerDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(satelliteCenter, 2.0, satelliteInnerDot);
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

  const ClockArcSegment({
    required this.block,
    required this.startMinutes,
    required this.sweepMinutes,
    this.isFromYesterday = false,
    this.isForTonight = false,
  });

  int get endMinutes => startMinutes + sweepMinutes;
}

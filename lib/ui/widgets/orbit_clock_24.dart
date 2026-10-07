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

  @override
  ConsumerState<OrbitClock24> createState() => _OrbitClock24State();
}

class _OrbitClock24State extends ConsumerState<OrbitClock24>
    with SingleTickerProviderStateMixin {
  late Timer _tickerTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
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
    _tickerTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  ScheduleBlock? _findActiveBlock(List<ScheduleBlock> blocks, DateTime now) {
    for (final block in blocks) {
      if (block.isActiveAt(now)) {
        return block;
      }
    }
    return null;
  }

  ScheduleBlock? _findNextBlock(List<ScheduleBlock> blocks, DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    ScheduleBlock? nextBlock;
    int minDiff = 999999;

    for (final block in blocks) {
      if (!block.appliesToWeekday(now.weekday)) continue;
      int diff = block.startInMinutes - currentMinutes;
      if (diff < 0) {
        diff += 1440; // Tomorrow's occurrence
      }
      if (diff > 0 && diff < minDiff) {
        minDiff = diff;
        nextBlock = block;
      }
    }
    return nextBlock;
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final activeBlock = _findActiveBlock(widget.blocks, _now);
    final nextBlock = activeBlock == null ? _findNextBlock(widget.blocks, _now) : null;

    Habit? linkedHabit;
    if (activeBlock?.habitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == activeBlock!.habitId,
            orElse: () => null,
          );
    }

    final todayIso = _now.toIso8601String().split('T').first;
    final isHabitDoneToday = linkedHabit?.completedDates.contains(todayIso) ?? false;

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Hand-crafted 24-hour Canvas Dial
            AnimatedBuilder(
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
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Active block info or free time
                  if (activeBlock != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: linkedHabit != null
                                ? linkedHabit.color
                                : activeBlock.color,
                            boxShadow: [
                              BoxShadow(
                                color: (linkedHabit?.color ?? activeBlock.color)
                                    .withOpacity(0.6),
                                blurRadius: 6,
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            activeBlock.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quedan ${_formatRemaining(activeBlock.minutesRemainingAt(_now) ?? 0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: textColor.withOpacity(0.55),
                      ),
                    ),

                    // Quick Habit Toggle Action Button if linked to a Habit!
                    if (linkedHabit != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          SoundService().playCheck();
                          ref
                              .read(habitsProvider.notifier)
                              .toggleDay(linkedHabit!.id, todayIso);
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
                          final isShiftDoneToday = activeBlock.completedDates.contains(todayIso);
                          final shiftColor = activeBlock.color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              SoundService().playCheck();
                              ref.read(scheduleProvider.notifier).toggleDateForBlock(activeBlock.id, todayIso);
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
                  ] else ...[
                    // Free time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'Tiempo Libre',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    if (nextBlock != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Próximo: ${nextBlock.title} (${nextBlock.startHour.toString().padLeft(2, '0')}:${nextBlock.startMinute.toString().padLeft(2, '0')})',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: textColor.withOpacity(0.45),
                        ),
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

  String _formatRemaining(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
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

    // 3. Draw Scheduled Time Blocks as Coloured Arc Segments
    for (final block in blocks) {
      if (!block.appliesToWeekday(now.weekday) &&
          !(block.isOvernight &&
              block.appliesToWeekday(now.weekday == 1 ? 7 : now.weekday - 1))) {
        continue;
      }

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

      final startAngle = -math.pi / 2 + (block.startInMinutes / 1440.0) * 2 * math.pi;
      final sweepAngle = (block.durationInMinutes / 1440.0) * 2 * math.pi;

      final isCurrent = block == activeBlock;

      final blockPaint = Paint()
        ..color = isCurrent ? blockColor : blockColor.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCurrent ? trackWidth * 0.95 : trackWidth * 0.82
        ..strokeCap = StrokeCap.round;

      // Glow effect if this block is active right now!
      if (isCurrent) {
        final glowPaint = Paint()
          ..color = blockColor.withOpacity(0.35 * pulseValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackWidth * 1.35
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: trackRadius),
          startAngle + 0.02,
          sweepAngle - 0.04,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: trackRadius),
        startAngle + 0.02,
        sweepAngle - 0.04,
        false,
        blockPaint,
      );
    }

    // 4. Current Time Satellite Node (Orbiting Indicator)
    final currentMinutes = now.hour * 60 + now.minute;
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

  @override
  bool shouldRepaint(covariant _OrbitClockPainter oldDelegate) {
    return oldDelegate.now != now ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.blocks != blocks ||
        oldDelegate.activeBlock != activeBlock;
  }
}

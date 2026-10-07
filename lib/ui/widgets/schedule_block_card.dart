import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/sound_service.dart';

class ScheduleBlockCard extends ConsumerWidget {
  final ScheduleBlock block;
  final VoidCallback onTap;

  const ScheduleBlockCard({
    Key? key,
    required this.block,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final now = DateTime.now();
    final isActive = block.isActiveAt(now);

    Habit? linkedHabit;
    if (block.habitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == block.habitId,
            orElse: () => null,
          );
    }

    final cardColor = linkedHabit?.color ?? block.color;
    final todayIso = now.toIso8601String().split('T').first;
    final isHabitDone = linkedHabit?.completedDates.contains(todayIso) ?? false;

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? cardColor.withOpacity(0.6)
                : Colors.grey.withOpacity(0.12),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? cardColor.withOpacity(0.08)
                  : Colors.black.withOpacity(0.02),
              blurRadius: isActive ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left color accent bar / dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: cardColor.withOpacity(0.6),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Title + Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          block.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor?.withOpacity(0.9),
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'AHORA',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: cardColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Linked habit chip or duration info
                  Row(
                    children: [
                      if (block.isOvernight) ...[
                        Icon(Icons.nights_stay,
                            size: 13, color: textColor?.withOpacity(0.4)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        block.formattedDuration,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor?.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (linkedHabit != null) ...[
                        Text(' · ',
                            style:
                                TextStyle(color: textColor?.withOpacity(0.3))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isHabitDone
                                ? cardColor.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: cardColor.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHabitDone
                                    ? Icons.check
                                    : Icons.radio_button_unchecked,
                                size: 10,
                                color: cardColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isHabitDone ? 'Hecho' : linkedHabit.name,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: cardColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Monthly hour target progress if enabled!
                  if (block.hasMonthlyHourTarget) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final workedHours = block.getMonthlyWorkedHours(now);
                        final target = block.monthlyTargetHours;
                        final progress = target > 0 ? (workedHours / target).clamp(0.0, 1.0) : 0.0;
                        final isCompleted = workedHours >= target;
                        final overtime = block.getOvertimeHours(now);
                        final isShiftDoneToday = block.completedDates.contains(todayIso);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCompleted
                                      ? 'Meta cumplida ✨ ${overtime > 0 ? "(+${overtime.toStringAsFixed(0)}h extras)" : ""}'
                                      : 'Meta: ${workedHours.toStringAsFixed(0)} / ${target}h al mes',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted
                                        ? const Color(0xFFFFB74D)
                                        : textColor?.withOpacity(0.65),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    SoundService().playCheck();
                                    ref.read(scheduleProvider.notifier).toggleDateForBlock(block.id, todayIso);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isShiftDoneToday
                                          ? cardColor.withOpacity(0.2)
                                          : cardColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isShiftDoneToday ? cardColor : cardColor.withOpacity(0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isShiftDoneToday ? Icons.check_circle : Icons.check,
                                          size: 11,
                                          color: cardColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isShiftDoneToday ? 'Turno Hecho' : 'Completar Turno',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: cardColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                backgroundColor: Colors.grey.withOpacity(0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted ? const Color(0xFFFFB74D) : cardColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Right: Time range (e.g. "23:00 - 07:00")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                block.formattedTimeRange,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor?.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

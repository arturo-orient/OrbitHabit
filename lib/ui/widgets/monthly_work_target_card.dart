import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/sound_service.dart';

class MonthlyWorkTargetCard extends ConsumerWidget {
  final ScheduleBlock block;
  final DateTime currentMonth;
  final VoidCallback onTap;

  const MonthlyWorkTargetCard({
    Key? key,
    required this.block,
    required this.currentMonth,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    Habit? linkedHabit;
    if (block.habitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == block.habitId,
            orElse: () => null,
          );
    } else {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h != null && h.name.trim().toLowerCase() == block.title.trim().toLowerCase(),
            orElse: () => null,
          );
    }

    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final blockColor = block.color;

    final workedHours = block.getMonthlyWorkedHours(currentMonth, linkedHabit);
    final target = block.monthlyTargetHours;
    final progress = target > 0 ? (workedHours / target).clamp(0.0, 1.0) : 0.0;
    final isCompleted = block.isTargetReached(currentMonth, linkedHabit);
    final overtime = block.getOvertimeHours(currentMonth, linkedHabit);

    final now = DateTime.now();
    final todayIso = now.toIso8601String().split('T').first;
    final isCurrentMonthSelected =
        now.year == currentMonth.year && now.month == currentMonth.month;
    final effectiveDates = block.getEffectiveCompletedDates(linkedHabit);
    final isTodayDone = effectiveDates.contains(todayIso);

    final prefix = '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}';
    final completedShiftsInMonth =
        effectiveDates.where((d) => d.startsWith(prefix)).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFFFFB74D).withOpacity(0.5)
                : blockColor.withOpacity(0.2),
            width: isCompleted ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isCompleted
                  ? const Color(0xFFFFB74D).withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Icono / Título + Badge de Horas
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: blockColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '💼',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
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
                                fontWeight: FontWeight.bold,
                                color: textColor?.withOpacity(0.9),
                              ),
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB74D).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                overtime > 0
                                    ? '+${overtime.toStringAsFixed(0)}h extra 🔥'
                                    : '¡Meta 100%! ✨',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB74D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$completedShiftsInMonth turnos · ${block.formattedDuration}/turno',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor?.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${workedHours.toStringAsFixed(0)} / ${target}h',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? const Color(0xFFFFB74D)
                            : blockColor,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% del mes',
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor?.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barra de Progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.grey.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? const Color(0xFFFFB74D) : blockColor,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Pie: Botón rápido de turno de hoy o detalle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toca para ver o editar días',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor?.withOpacity(0.4),
                  ),
                ),
                if (isCurrentMonthSelected)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      SoundService().playCheck();
                      ref
                          .read(scheduleProvider.notifier)
                          .toggleDateForBlock(block.id, todayIso);
                      if (block.habitId != null) {
                        ref
                            .read(habitsProvider.notifier)
                            .toggleDay(block.habitId!, todayIso);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTodayDone
                            ? blockColor.withOpacity(0.18)
                            : blockColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isTodayDone
                              ? blockColor
                              : blockColor.withOpacity(0.25),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTodayDone
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            size: 13,
                            color: blockColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTodayDone ? 'Turno Hoy Hecho' : 'Completar Hoy',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: blockColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

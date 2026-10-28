import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/sound_service.dart';
import '../theme/app_theme.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);
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
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.bentoCard(
          isLight: !isDark,
          borderRadius: AppTheme.radiusMd,
          borderColor: isCompleted
              ? accent.withValues(alpha: 0.4)
              : null,
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
                    color: blockColor.withValues(alpha: 0.12),
                    borderRadius: AppTheme.radiusXs,
                    border: Border.all(
                      color: blockColor.withValues(alpha: 0.3),
                      width: AppTheme.borderPrecision,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: blockColor,
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
                              style: AppTheme.displayStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.obsidianTextPrimary
                                    : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: AppTheme.radiusXs,
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: AppTheme.borderPrecision,
                                ),
                              ),
                              child: Text(
                                overtime > 0
                                    ? '+${overtime.toStringAsFixed(0)}H EXTRA'
                                    : 'OBJETIVO 100%',
                                style: AppTheme.monoStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$completedShiftsInMonth turnos · ${block.formattedDuration}/turno',
                        style: AppTheme.monoStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.obsidianTextMuted
                              : AppTheme.boneTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${workedHours.toStringAsFixed(0)} / ${target}H',
                      style: AppTheme.monoStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? accent
                            : (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% REGISTRADO',
                      style: AppTheme.monoStyle(
                        fontSize: 9,
                        color: isDark
                            ? AppTheme.obsidianTextMuted
                            : AppTheme.boneTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Barra de Progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3.5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? accent : blockColor,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Pie: Botón rápido de turno de hoy o detalle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '// TOQUE PARA CONFIGURAR',
                  style: AppTheme.monoStyle(
                    fontSize: 9,
                    color: isDark
                        ? AppTheme.obsidianTextMuted
                        : AppTheme.boneTextMuted,
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
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTodayDone
                            ? blockColor.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: AppTheme.radiusXs,
                        border: Border.all(
                          color: isTodayDone
                              ? blockColor
                              : (isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder),
                          width: AppTheme.borderPrecision,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTodayDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 11,
                            color: isTodayDone ? blockColor : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTodayDone ? 'TURNO HECHO' : 'REGISTRAR HOY',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isTodayDone ? blockColor : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
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

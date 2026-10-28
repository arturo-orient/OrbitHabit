import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/sound_service.dart';
import '../theme/app_theme.dart';

/// Modal interactivo de Detalle del Día con diseño Neo-Bento editorial.
/// Permite visualizar y conmutar el estado de hábitos y turnos para una fecha concreta.
class DayDetailsSheet extends ConsumerStatefulWidget {
  final DateTime date;

  const DayDetailsSheet({Key? key, required this.date}) : super(key: key);

  @override
  ConsumerState<DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends ConsumerState<DayDetailsSheet> {
  static const _weekdaysEs = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  static const _monthsEs = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre'
  ];

  String _formatDateHeader(DateTime date) {
    final weekday = _weekdaysEs[date.weekday - 1];
    final day = date.day;
    final month = _monthsEs[date.month - 1];
    final year = date.year;
    return '$weekday, $day de $month de $year';
  }

  String _getRelativeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'HOY';
    if (diff == -1) return 'AYER';
    if (diff == 1) return 'MAÑANA';
    if (diff < -1) return 'HACE ${diff.abs()} DÍAS';
    return 'EN $diff DÍAS';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);
    final allHabits = ref.watch(habitsProvider);
    final allBlocks = ref.watch(scheduleProvider);
    final dateIso = widget.date.toIso8601String().split('T').first;

    // Hábitos activos para este día
    final activeHabits = allHabits.where((h) {
      if (h.frequencyType == 0) {
        return h.activeWeekdays.contains(widget.date.weekday);
      }
      return true;
    }).toList();

    // Bloques/turnos que aplican a este día concreto del calendario
    final activeBlocks = allBlocks.where((b) {
      return b.appliesToDate(widget.date);
    }).toList();

    final completedHabitsCount = activeHabits
        .where((h) => h.completedDates.contains(dateIso))
        .length;
    final totalHabits = activeHabits.length;
    final habitProgress = totalHabits > 0 ? (completedHabitsCount / totalHabits) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tirador superior ergonómico
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Cabecera: Fecha y Badge relativo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateHeader(widget.date),
                      style: AppTheme.displayStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.obsidianTextPrimary
                            : AppTheme.boneTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      totalHabits > 0
                          ? '$completedHabitsCount de $totalHabits hábitos completados'
                          : 'Sin hábitos asignados',
                      style: AppTheme.monoStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppTheme.obsidianTextSecondary
                            : AppTheme.boneTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppTheme.radiusXs,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                    width: AppTheme.borderPrecision,
                  ),
                ),
                child: Text(
                  _getRelativeLabel(widget.date),
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),

          if (totalHabits > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: habitProgress,
                minHeight: 4,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  habitProgress == 1.0 ? accent : (isDark ? Colors.white70 : AppTheme.boneTextPrimary),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Lista de Hábitos
          if (activeHabits.isEmpty && activeBlocks.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: AppTheme.bentoCard(
                isLight: !isDark,
                borderRadius: AppTheme.radiusMd,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 32,
                    color: isDark
                        ? AppTheme.obsidianTextMuted
                        : AppTheme.boneTextMuted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Día libre de hábitos',
                    style: AppTheme.displayStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.obsidianTextPrimary
                          : AppTheme.boneTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No hay tareas ni turnos programados para esta fecha.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.obsidianTextMuted
                          : AppTheme.boneTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  if (activeHabits.isNotEmpty) ...[
                    ...activeHabits.map((habit) {
                      final isCompleted = habit.completedDates.contains(dateIso);
                      return _buildHabitItem(
                        context: context,
                        habit: habit,
                        isCompleted: isCompleted,
                        isDark: isDark,
                        dateIso: dateIso,
                      );
                    }),
                  ],

                  if (activeBlocks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Turnos de Trabajo',
                      style: AppTheme.displayStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppTheme.obsidianTextSecondary
                            : AppTheme.boneTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...activeBlocks.map((block) {
                      Habit? linkedHabit;
                      if (block.habitId != null) {
                        linkedHabit = allHabits.cast<Habit?>().firstWhere(
                              (h) => h?.id == block.habitId,
                              orElse: () => null,
                            );
                      }
                      final isCompleted = block
                          .getEffectiveCompletedDates(linkedHabit)
                          .contains(dateIso);

                      return _buildBlockItem(
                        context: context,
                        block: block,
                        isCompleted: isCompleted,
                        isDark: isDark,
                        dateIso: dateIso,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitItem({
    required BuildContext context,
    required Habit habit,
    required bool isCompleted,
    required bool isDark,
    required String dateIso,
  }) {
    final habitColor = habit.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          if (!isCompleted) {
            HapticFeedback.mediumImpact();
            SoundService().playCheck();
          } else {
            HapticFeedback.lightImpact();
          }
          ref.read(habitsProvider.notifier).toggleDay(habit.id, dateIso);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.bentoCard(
            isLight: !isDark,
            borderRadius: AppTheme.radiusMd,
            borderColor: isCompleted ? habitColor.withValues(alpha: 0.35) : null,
          ),
          child: Row(
            children: [
              // Indicador visual con color del hábito
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: habitColor,
                  borderRadius: BorderRadius.circular(2.5),
                  boxShadow: [
                    BoxShadow(
                      color: habitColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Nombre del hábito
              Expanded(
                child: Text(
                  habit.name,
                  style: AppTheme.displayStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? (isCompleted
                            ? AppTheme.obsidianTextPrimary.withValues(alpha: 0.65)
                            : AppTheme.obsidianTextPrimary)
                        : (isCompleted
                            ? AppTheme.boneTextPrimary.withValues(alpha: 0.65)
                            : AppTheme.boneTextPrimary),
                  ),
                ),
              ),

              // Interruptor de Checkbox Táctil
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? habitColor.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted
                        ? habitColor
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.20)),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: habitColor,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockItem({
    required BuildContext context,
    required ScheduleBlock block,
    required bool isCompleted,
    required bool isDark,
    required String dateIso,
  }) {
    final blockColor = block.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          if (!isCompleted) {
            HapticFeedback.mediumImpact();
            SoundService().playCheck();
          } else {
            HapticFeedback.lightImpact();
          }
          ref.read(scheduleProvider.notifier).toggleDateForBlock(block.id, dateIso);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.bentoCard(
            isLight: !isDark,
            borderRadius: AppTheme.radiusMd,
            borderColor: isCompleted ? blockColor.withValues(alpha: 0.35) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
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
                  size: 14,
                  color: blockColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title,
                      style: AppTheme.displayStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.obsidianTextPrimary
                            : AppTheme.boneTextPrimary,
                      ),
                    ),
                    Text(
                      '${block.formattedDuration} · ${block.isOvernight ? 'Turno nocturno' : 'Turno diurno'}',
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? blockColor.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCompleted
                        ? blockColor
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.20)),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: blockColor,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

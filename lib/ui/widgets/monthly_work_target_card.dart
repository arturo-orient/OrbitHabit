import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/sound_service.dart';
import '../theme/app_theme.dart';

class MonthlyWorkTargetCard extends ConsumerStatefulWidget {
  final WorkShiftGroup? group;
  final ScheduleBlock? block;
  final DateTime currentMonth;
  final VoidCallback onTap;
  final Function(ScheduleBlock shift)? onEditShift;

  const MonthlyWorkTargetCard({
    Key? key,
    this.group,
    this.block,
    required this.currentMonth,
    required this.onTap,
    this.onEditShift,
  })  : assert(group != null || block != null),
        super(key: key);

  @override
  ConsumerState<MonthlyWorkTargetCard> createState() => _MonthlyWorkTargetCardState();
}

class _MonthlyWorkTargetCardState extends ConsumerState<MonthlyWorkTargetCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);

    // Resolver grupo efectivo
    Habit? linkedHabit;
    if (widget.group?.habit != null) {
      linkedHabit = widget.group!.habit;
    } else if (widget.group?.habitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == widget.group!.habitId,
            orElse: () => null,
          );
    } else if (widget.block != null) {
      if (widget.block!.habitId != null) {
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == widget.block!.habitId,
              orElse: () => null,
            );
      } else {
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) => h != null && h.name.trim().toLowerCase() == widget.block!.title.trim().toLowerCase(),
              orElse: () => null,
            );
      }
    }

    final effectiveGroup = widget.group ??
        WorkShiftGroup(
          title: widget.block!.title,
          habitId: widget.block!.habitId,
          habit: linkedHabit,
          shifts: [widget.block!],
          monthlyTargetHours: widget.block!.monthlyTargetHours,
        );

    final title = effectiveGroup.title;
    final color = effectiveGroup.color;
    final target = effectiveGroup.monthlyTargetHours;
    final workedHours = effectiveGroup.getMonthlyWorkedHours(widget.currentMonth);
    final progress = target > 0 ? (workedHours / target).clamp(0.0, 1.0) : 0.0;
    final isCompleted = effectiveGroup.isTargetReached(widget.currentMonth);
    final overtime = effectiveGroup.getOvertimeHours(widget.currentMonth);
    final totalShifts = effectiveGroup.getMonthlyShiftsCount(widget.currentMonth);
    final breakdown = effectiveGroup.getBreakdown(widget.currentMonth);
    final shifts = effectiveGroup.shifts;

    final now = DateTime.now();
    final todayIso = now.toIso8601String().split('T').first;
    final isCurrentMonthSelected =
        now.year == widget.currentMonth.year && now.month == widget.currentMonth.month;
    final isFutureMonth = widget.currentMonth.year > now.year ||
        (widget.currentMonth.year == now.year && widget.currentMonth.month > now.month);

    final plannedHours = effectiveGroup.getMonthlyPlannedHours(widget.currentMonth);
    final plannedShifts = effectiveGroup.getMonthlyPlannedShiftsCount(widget.currentMonth);
    final displayHours = isFutureMonth ? plannedHours : workedHours;
    final displayProgress = target > 0 ? (displayHours / target).clamp(0.0, 1.0) : 0.0;

    // Determinar si hoy está marcado
    final isTodayDone = shifts.any((s) =>
        s.completedDates.contains(todayIso) ||
        (linkedHabit != null && linkedHabit.completedDates.contains(todayIso)));

    // Turno programado para hoy (si lo hay)
    final todayShift = shifts.cast<ScheduleBlock?>().firstWhere(
          (s) => s != null && s.appliesToDate(now),
          orElse: () => shifts.isNotEmpty ? shifts.first : null,
        );

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.bentoCard(
          isLight: !isDark,
          borderRadius: AppTheme.radiusMd,
          borderColor: (!isFutureMonth && isCompleted) ? accent.withValues(alpha: 0.45) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Cabecera Principal: Icono + Título + Badge + Horas
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppTheme.radiusXs,
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: AppTheme.borderPrecision,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 17,
                    color: color,
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
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.displayStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.obsidianTextPrimary
                                    : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ),
                          if (!isFutureMonth && isCompleted) ...[
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
                          ] else if (isFutureMonth && plannedHours > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: AppTheme.radiusXs,
                                border: Border.all(
                                  color: color.withValues(alpha: 0.4),
                                  width: AppTheme.borderPrecision,
                                ),
                              ),
                              child: Text(
                                'PLANIFICADO',
                                style: AppTheme.monoStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isFutureMonth
                            ? '$plannedShifts turnos planificados · ${shifts.length} horarios'
                            : (shifts.length > 1
                                ? '$totalShifts turnos · ${shifts.length} horarios configurados'
                                : '$totalShifts turnos · ${shifts.isNotEmpty ? shifts.first.formattedDuration : ""}/turno'),
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
                      isFutureMonth
                          ? '~${plannedHours.toStringAsFixed(0)} / ${target}H'
                          : '${workedHours.toStringAsFixed(0)} / ${target}H',
                      style: AppTheme.monoStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: (!isFutureMonth && isCompleted)
                            ? accent
                            : (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
                      ),
                    ),
                    Text(
                      isFutureMonth
                          ? 'PLANIFICADO'
                          : '${(progress * 100).toInt()}% REGISTRADO',
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

            // 2. Barra de Progreso Quirúrgica
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: displayProgress,
                minHeight: 3.5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  (!isFutureMonth && isCompleted)
                      ? accent
                      : (isFutureMonth ? color.withValues(alpha: 0.6) : color),
                ),
              ),
            ),

            // 3. Botón de Desglose por Horario (si hay múltiples turnos)
            if (shifts.length > 1) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: AppTheme.radiusXs,
                    border: Border.all(
                      color: isDark
                          ? AppTheme.obsidianBorder
                          : AppTheme.boneBorder,
                      width: AppTheme.borderPrecision,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 13,
                            color: isDark
                                ? AppTheme.obsidianTextSecondary
                                : AppTheme.boneTextSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'DESGLOSE DE TURNOS (${shifts.length})',
                            style: AppTheme.monoStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.obsidianTextSecondary
                                  : AppTheme.boneTextSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _isExpanded ? 'Ocultar' : 'Ver horas',
                            style: AppTheme.monoStyle(
                              fontSize: 9.5,
                              color: isDark
                                  ? AppTheme.obsidianTextMuted
                                  : AppTheme.boneTextMuted,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: isDark
                                ? AppTheme.obsidianTextMuted
                                : AppTheme.boneTextMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Contenido del Desglose Desplegable
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white,
                    borderRadius: AppTheme.radiusSm,
                    border: Border.all(
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      width: AppTheme.borderPrecision,
                    ),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < breakdown.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 12,
                            thickness: 0.5,
                            color: isDark
                                ? AppTheme.obsidianBorder
                                : AppTheme.boneBorder,
                          ),
                        _buildShiftRow(breakdown[i], isDark, accent),
                      ],
                    ],
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],

            const SizedBox(height: 8),

            // 5. Pie: Botón rápido de turno de hoy o configurar
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
                if (isCurrentMonthSelected && todayShift != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      SoundService().playCheck();
                      ref
                          .read(scheduleProvider.notifier)
                          .toggleDateForBlock(todayShift.id, todayIso);
                      if (todayShift.habitId != null) {
                        ref
                            .read(habitsProvider.notifier)
                            .toggleDay(todayShift.habitId!, todayIso);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isTodayDone
                            ? color.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: AppTheme.radiusXs,
                        border: Border.all(
                          color: isTodayDone
                              ? color
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
                            color: isTodayDone ? color : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTodayDone ? 'TURNO HECHO' : 'REGISTRAR HOY',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isTodayDone ? color : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
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

  Widget _buildShiftRow(ShiftBreakdownItem item, bool isDark, Color accent) {
    final s = item.shift;
    final isNight = s.isOvernight || s.title.toLowerCase().contains('noche') || s.title.toLowerCase().contains('nocturno');
    final shiftColor = s.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
            size: 13,
            color: isNight ? const Color(0xFF9EA1D4) : shiftColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: AppTheme.displayStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.obsidianTextPrimary
                        : AppTheme.boneTextPrimary,
                  ),
                ),
                Text(
                  '${s.formattedTimeRange} · ${s.formattedDuration}/turno',
                  style: AppTheme.monoStyle(
                    fontSize: 9.5,
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
                '${item.totalHours.toStringAsFixed(0)}h',
                style: AppTheme.monoStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: item.totalHours > 0
                      ? (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary)
                      : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                ),
              ),
              Text(
                '${item.shiftsCount} turnos',
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
    );
  }
}

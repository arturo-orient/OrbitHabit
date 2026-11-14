import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/streak_utils.dart';
import '../theme/app_theme.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  static const double _evolutionLeftPad = 34.0;
  static const double _evolutionRightPad = 8.0;

  late DateTime _selectedMonth;
  bool _showFullMonth = false;
  int? _selectedBarIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _selectedBarIndex = null;
    });
  }

  void _updateSelectedBarFromDx(double dx, double chartWidth, int count) {
    if (count <= 0) return;
    final plotWidth = math.max(1.0, chartWidth - _evolutionLeftPad - _evolutionRightPad);
    final slotWidth = plotWidth / count;
    final idx = ((dx - _evolutionLeftPad) / slotWidth).floor().clamp(0, count - 1);
    if (_selectedBarIndex != idx) {
      HapticFeedback.selectionClick();
      setState(() => _selectedBarIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final settings = ref.watch(settingsProvider);
    final scheduleBlocks = ref.watch(scheduleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);

    final heavyDutyShield = StreakUtils.computeHeavyDutyShieldDates(scheduleBlocks);
    final vacationSet = settings.vacationDates.toSet();
    final effectiveVacationDates = {...vacationSet, ...heavyDutyShield}.toList();

    int globalMaxStreak = 0;
    for (final habit in habits) {
      final maxStreak = StreakUtils.calculateMaxStreak(habit, effectiveVacationDates);
      if (maxStreak > globalMaxStreak) globalMaxStreak = maxStreak;
    }

    final perfectDays = _calculatePerfectDays(habits, effectiveVacationDates);
    final evolutionPoints = _buildDailyEvolution(
      habits: habits,
      month: _selectedMonth,
      fullMonth: _showFullMonth,
      vacationSet: vacationSet,
      heavyDutySet: heavyDutyShield,
    );
    final avgCompliance = _computeAverageCompliance(evolutionPoints);
    final selectedPoint = (_selectedBarIndex != null &&
            _selectedBarIndex! >= 0 &&
            _selectedBarIndex! < evolutionPoints.length)
        ? evolutionPoints[_selectedBarIndex!]
        : null;

    final weekdayRates = _buildWeekdayRates(
      habits: habits,
      month: _selectedMonth,
      effectivePausedDates: effectiveVacationDates.toSet(),
    );
    final bestWeekdayIndex = _findBestWeekdayIndex(weekdayRates);

    final workTelemetry = _buildWorkTelemetry(
      habits: habits,
      blocks: scheduleBlocks,
      month: _selectedMonth,
      isDark: isDark,
    );

    final habitRankings = _buildHabitRankings(
      habits: habits,
      month: _selectedMonth,
      vacationSet: vacationSet,
      heavyDutySet: heavyDutyShield,
      effectivePausedDates: effectiveVacationDates,
    );

    final surfaceColor = isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface;
    final borderColor = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
    final textPrimary = isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary;
    final textMuted = isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 20, color: textPrimary),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'MÉTRICAS & TELEMETRÍA',
          style: AppTheme.monoStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: borderColor, height: 1.0),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: borderColor, width: AppTheme.borderPrecision),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de Mes
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(color: borderColor, width: AppTheme.borderPrecision),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MonthArrowButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _changeMonth(-1),
                        isDark: isDark,
                      ),
                      Column(
                        children: [
                          Text(
                            'PERIODO ANALIZADO',
                            style: AppTheme.monoStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_monthNameEs(_selectedMonth.month)} ${_selectedMonth.year}',
                            style: AppTheme.monoStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      _MonthArrowButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _changeMonth(1),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1. RESUMEN GLOBAL
                _SectionHeaderRow(
                  title: 'RESUMEN // RENDIMIENTO GLOBAL',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatBentoCard(
                        title: 'RACHA MÁXIMA',
                        value: '${globalMaxStreak}d',
                        subtitle: 'Récord consecutivo',
                        icon: Icons.bolt_rounded,
                        accentColor: accent,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBentoCard(
                        title: 'DÍAS PERFECTOS',
                        value: '$perfectDays',
                        subtitle: '100% de hábitos',
                        icon: Icons.auto_awesome_rounded,
                        accentColor: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. GRÁFICA 1: EVOLUCIÓN DE CUMPLIMIENTO
                _SectionHeaderRow(
                  title: 'GRÁFICA 01 // EVOLUCIÓN DIARIA',
                  trailing: 'MEDIA // ${(avgCompliance * 100).round()}%',
                  trailingColor: accent,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              'EVOLUCIÓN DE CUMPLIMIENTO',
                              style: AppTheme.monoStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: textPrimary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RangePill(
                                  label: '[ 14 DÍAS ]',
                                  isSelected: !_showFullMonth,
                                  accentColor: accent,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _showFullMonth = false;
                                      _selectedBarIndex = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                _RangePill(
                                  label: '[ MES COMPLETO ]',
                                  isSelected: _showFullMonth,
                                  accentColor: accent,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _showFullMonth = true;
                                      _selectedBarIndex = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.obsidianSurfaceElevated
                              : AppTheme.boneSurfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedPoint != null ? accent.withValues(alpha: 0.45) : borderColor,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          selectedPoint != null
                              ? _formatSelectedPointReadout(selectedPoint)
                              : 'TOCA O DESLIZA UNA BARRA PARA INSPECCIONAR EL DÍA',
                          style: AppTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: selectedPoint != null ? textPrimary : textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (habits.isEmpty)
                        _EmptyTelemetryBox(
                          message: '// Crea al menos un hábito para trazar la evolución.',
                          isDark: isDark,
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              key: const ValueKey('evolution_chart_touch_area'),
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => _updateSelectedBarFromDx(
                                d.localPosition.dx,
                                constraints.maxWidth,
                                evolutionPoints.length,
                              ),
                              onHorizontalDragStart: (d) => _updateSelectedBarFromDx(
                                d.localPosition.dx,
                                constraints.maxWidth,
                                evolutionPoints.length,
                              ),
                              onHorizontalDragUpdate: (d) => _updateSelectedBarFromDx(
                                d.localPosition.dx,
                                constraints.maxWidth,
                                evolutionPoints.length,
                              ),
                              child: SizedBox(
                                height: 176,
                                width: double.infinity,
                                child: CustomPaint(
                                  painter: _EvolutionChartPainter(
                                    points: evolutionPoints,
                                    avgRatio: avgCompliance,
                                    selectedIndex: _selectedBarIndex,
                                    accentColor: accent,
                                    isDark: isDark,
                                    leftPad: _evolutionLeftPad,
                                    rightPad: _evolutionRightPad,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      if (habits.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _LegendDot(color: accent, label: 'CUMPLIMIENTO'),
                            _LegendDot(
                              color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7),
                              label: 'TENDENCIA',
                            ),
                            const _LegendDot(
                              color: Color(0xFFD97706),
                              label: 'ESCUDO / VAC.',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. GRÁFICA 2: RENDIMIENTO POR DÍA DE LA SEMANA
                _SectionHeaderRow(
                  title: 'GRÁFICA 02 // RENDIMIENTO SEMANAL',
                  trailing: bestWeekdayIndex >= 0
                      ? 'MEJOR DÍA // ${_weekdayFullEs(bestWeekdayIndex + 1).toUpperCase()}'
                      : null,
                  trailingColor: accent,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PATRÓN L - D',
                            style: AppTheme.monoStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: textPrimary,
                            ),
                          ),
                          if (bestWeekdayIndex >= 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.4),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                '${(weekdayRates[bestWeekdayIndex] * 100).round()}% TOP',
                                style: AppTheme.monoStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (habits.isEmpty)
                        _EmptyTelemetryBox(
                          message: '// Sin datos semanales disponibles todavía.',
                          isDark: isDark,
                        )
                      else
                        SizedBox(
                          height: 152,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _WeekdayChartPainter(
                              rates: weekdayRates,
                              bestIndex: bestWeekdayIndex,
                              accentColor: accent,
                              isDark: isDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 4. GRÁFICA 3: TELEMETRÍA DE HORAS DE TRABAJO
                _SectionHeaderRow(
                  title: 'GRÁFICA 03 // TELEMETRÍA DE HORAS',
                  trailing: workTelemetry != null
                      ? 'META // ${workTelemetry.targetHours}H'
                      : null,
                  trailingColor: accent,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: workTelemetry == null
                      ? _EmptyTelemetryBox(
                          message:
                              '// Configura un horario con Meta Mensual de Horas para visualizar Mañana, Tarde y Noche.',
                          isDark: isDark,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'HORAS REALES VS. META MENSUAL',
                                  style: AppTheme.monoStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  '${workTelemetry.progressPercent}%',
                                  style: AppTheme.monoStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 82,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _WorkTelemetryChartPainter(
                                  summary: workTelemetry,
                                  accentColor: accent,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _MiniStat(
                                  label: 'REALES',
                                  value: _formatHours(workTelemetry.totalWorkedHours),
                                  isDark: isDark,
                                  valueColor: accent,
                                ),
                                _MiniStat(
                                  label: 'PLANIFICADAS',
                                  value: _formatHours(workTelemetry.totalPlannedHours),
                                  isDark: isDark,
                                ),
                                _MiniStat(
                                  label: 'EXTRAS',
                                  value: _formatSignedHours(workTelemetry.totalExtraHours),
                                  isDark: isDark,
                                  valueColor: workTelemetry.totalExtraHours > 0
                                      ? const Color(0xFFD97706)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(height: 1, thickness: 1, color: borderColor),
                            const SizedBox(height: 12),
                            ...workTelemetry.categories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: cat.color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cat.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.bodyStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${cat.workedShifts} turnos · ${_formatHours(cat.workedHours)} real / ${_formatHours(cat.plannedHours)} plan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: AppTheme.monoStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                ),
                const SizedBox(height: 24),

                // 5. DESGLOSE POR HÁBITO (RANKING DE CONSTANCIA)
                _SectionHeaderRow(
                  title: 'DESGLOSE // RANKING DE CONSTANCIA',
                  trailing: '[${habits.length.toString().padLeft(2, '0')}]',
                  trailingColor: accent,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                if (habits.isEmpty)
                  _EmptyTelemetryBox(
                    message: '// No hay datos de hábitos registrados todavía.',
                    isDark: isDark,
                  )
                else
                  ...habitRankings.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    final habit = item.habit;
                    final totalProtected = item.vacationProtectedDays + item.heavyDutyProtectedDays;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.bentoCard(
                        isLight: !isDark,
                        borderRadius: AppTheme.radiusMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: habit.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: habit.color.withValues(alpha: 0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  '#${rank.toString().padLeft(2, '0')}',
                                  style: AppTheme.monoStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: habit.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  habit.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.displayStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${item.ratePercent}%',
                                style: AppTheme.monoStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: habit.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (item.ratePercent / 100).clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(habit.color),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _MiniStat(
                                label: 'RACHA',
                                value: '${item.currentStreak}d',
                                isDark: isDark,
                              ),
                              _MiniStat(
                                label: 'RÉCORD',
                                value: '${item.maxStreak}d',
                                isDark: isDark,
                              ),
                              _MiniStat(
                                label: 'MES ACTIVO',
                                value: '${item.completedInRange} / ${item.expectedInRange}',
                                isDark: isDark,
                              ),
                              _MiniStat(
                                label: 'PROTEGIDOS',
                                value: '${totalProtected}d',
                                isDark: isDark,
                                valueColor: totalProtected > 0 ? const Color(0xFFD97706) : null,
                              ),
                            ],
                          ),
                          if (totalProtected > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                'ESCUDO RACHA // ${item.vacationProtectedDays}d Vacaciones · ${item.heavyDutyProtectedDays}d Turno +12h',
                                style: AppTheme.monoStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CÁLCULO DE TELEMETRÍA Y SERIES ---

  int _calculatePerfectDays(List<Habit> habits, List<String> pausedDates) {
    if (habits.isEmpty) return 0;
    final Set<String> allDates = {};
    for (final h in habits) {
      allDates.addAll(h.completedDates);
    }

    int perfectDays = 0;
    for (final dateStr in allDates) {
      if (pausedDates.contains(dateStr)) continue;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final expectedHabits = habits.where((h) => h.activeWeekdays.contains(date.weekday)).toList();
      if (expectedHabits.isEmpty) continue;
      if (expectedHabits.every((h) => h.completedDates.contains(dateStr))) {
        perfectDays++;
      }
    }
    return perfectDays;
  }

  List<_DailyCompliancePoint> _buildDailyEvolution({
    required List<Habit> habits,
    required DateTime month,
    required bool fullMonth,
    required Set<String> vacationSet,
    required Set<String> heavyDutySet,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = month.year == today.year && month.month == today.month;

    int startDay = 1;
    int endDay = daysInMonth;
    if (!fullMonth) {
      endDay = isCurrentMonth ? today.day : daysInMonth;
      startDay = math.max(1, endDay - 13);
    }

    final List<_DailyCompliancePoint> points = [];
    for (int d = startDay; d <= endDay; d++) {
      final date = DateTime(month.year, month.month, d);
      final iso = _formatIsoDate(date);
      final isVac = vacationSet.contains(iso);
      final isHeavy = heavyDutySet.contains(iso);

      final expected = habits.where((h) => h.activeWeekdays.contains(date.weekday)).toList();
      final completed = expected.where((h) => h.completedDates.contains(iso)).length;
      final extraDone = habits
          .where((h) => !h.activeWeekdays.contains(date.weekday) && h.completedDates.contains(iso))
          .length;

      final totalCompleted = completed + extraDone;
      final totalExpected = expected.length;
      double ratio = 0.0;
      if (date.isAfter(today)) {
        ratio = 0.0;
      } else if (totalExpected > 0) {
        ratio = (completed / totalExpected).clamp(0.0, 1.0);
      } else if (extraDone > 0) {
        ratio = 1.0;
      }

      points.add(
        _DailyCompliancePoint(
          date: date,
          iso: iso,
          completedCount: totalCompleted,
          expectedCount: totalExpected,
          ratio: ratio,
          isVacation: isVac,
          isHeavyDuty: isHeavy,
        ),
      );
    }
    return points;
  }

  double _computeAverageCompliance(List<_DailyCompliancePoint> points) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = points
        .where((p) => !p.date.isAfter(today) && p.expectedCount > 0 && !p.isVacation && !p.isHeavyDuty)
        .toList();
    if (active.isEmpty) return 0.0;
    final sum = active.fold<double>(0.0, (acc, p) => acc + p.ratio);
    return (sum / active.length).clamp(0.0, 1.0);
  }

  List<double> _buildWeekdayRates({
    required List<Habit> habits,
    required DateTime month,
    required Set<String> effectivePausedDates,
  }) {
    final completedByWeekday = List<int>.filled(7, 0);
    final expectedByWeekday = List<int>.filled(7, 0);
    if (habits.isEmpty) return List<double>.filled(7, 0.0);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      if (date.isAfter(today)) continue;
      final iso = _formatIsoDate(date);
      if (effectivePausedDates.contains(iso)) continue;

      final idx = date.weekday - 1;
      for (final h in habits) {
        if (h.activeWeekdays.contains(date.weekday)) {
          expectedByWeekday[idx]++;
          if (h.completedDates.contains(iso)) {
            completedByWeekday[idx]++;
          }
        }
      }
    }

    return List<double>.generate(7, (i) {
      if (expectedByWeekday[i] == 0) return 0.0;
      return (completedByWeekday[i] / expectedByWeekday[i]).clamp(0.0, 1.0);
    });
  }

  int _findBestWeekdayIndex(List<double> rates) {
    int bestIdx = -1;
    double bestVal = 0.0;
    for (int i = 0; i < rates.length; i++) {
      if (rates[i] > bestVal) {
        bestVal = rates[i];
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  _WorkTelemetrySummary? _buildWorkTelemetry({
    required List<Habit> habits,
    required List<ScheduleBlock> blocks,
    required DateTime month,
    required bool isDark,
  }) {
    final workBlocks = blocks.where((b) => b.hasMonthlyHourTarget).toList();
    if (workBlocks.isEmpty) return null;

    final groups = <WorkShiftGroup>[];
    final processedIds = <String>{};

    for (final b in workBlocks) {
      if (processedIds.contains(b.id)) continue;
      Habit? linkedHabit;
      if (b.habitId != null) {
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == b.habitId,
              orElse: () => null,
            );
      }
      linkedHabit ??= habits.cast<Habit?>().firstWhere(
            (h) =>
                h != null &&
                (h.name.trim().toLowerCase() == b.title.trim().toLowerCase() ||
                    (h.name.toLowerCase().contains('trabaj') &&
                        b.title.toLowerCase().contains('trabaj')) ||
                    (h.name.toLowerCase().contains('turno') &&
                        b.title.toLowerCase().contains('turno'))),
            orElse: () => null,
          );

      final groupBlocks = <ScheduleBlock>[];
      for (final other in workBlocks) {
        if (processedIds.contains(other.id)) continue;
        bool belongs = other.id == b.id;
        if (linkedHabit != null) {
          if (other.habitId == linkedHabit.id ||
              other.title.trim().toLowerCase() == linkedHabit.name.trim().toLowerCase() ||
              (linkedHabit.name.toLowerCase().contains('trabaj') &&
                  other.title.toLowerCase().contains('trabaj')) ||
              (linkedHabit.name.toLowerCase().contains('turno') &&
                  other.title.toLowerCase().contains('turno'))) {
            belongs = true;
          }
        }
        if (belongs) {
          groupBlocks.add(other);
          processedIds.add(other.id);
        }
      }

      groups.add(
        WorkShiftGroup(
          title: linkedHabit?.name ?? b.title,
          habitId: linkedHabit?.id,
          habit: linkedHabit,
          shifts: groupBlocks,
          monthlyTargetHours: b.monthlyTargetHours,
        ),
      );
    }

    double morningWorked = 0, morningPlanned = 0, morningExtra = 0;
    int morningShifts = 0, morningPlannedCount = 0;
    double afternoonWorked = 0, afternoonPlanned = 0, afternoonExtra = 0;
    int afternoonShifts = 0, afternoonPlannedCount = 0;
    double nightWorked = 0, nightPlanned = 0, nightExtra = 0;
    int nightShifts = 0, nightPlannedCount = 0;

    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    int targetHours = 0;

    for (final g in groups) {
      targetHours += g.monthlyTargetHours;
      for (final s in g.shifts) {
        final shiftDurHours = s.durationInMinutes / 60.0;
        final workedDates = g.getEffectiveWorkedDatesForShift(s, month);
        final plannedCount = s.assignedDates.where((d) => d.startsWith(prefix)).length;
        final extra = s.getExtraHoursForMonth(month);
        final workedH = (workedDates.length * shiftDurHours) + extra;
        final plannedH = plannedCount * shiftDurHours;

        final bucket = _classifyShiftBucket(s);
        if (bucket == 'Mañana') {
          morningWorked += workedH;
          morningPlanned += plannedH;
          morningExtra += extra;
          morningShifts += workedDates.length;
          morningPlannedCount += plannedCount;
        } else if (bucket == 'Tarde') {
          afternoonWorked += workedH;
          afternoonPlanned += plannedH;
          afternoonExtra += extra;
          afternoonShifts += workedDates.length;
          afternoonPlannedCount += plannedCount;
        } else {
          nightWorked += workedH;
          nightPlanned += plannedH;
          nightExtra += extra;
          nightShifts += workedDates.length;
          nightPlannedCount += plannedCount;
        }
      }
    }

    final categories = <_ShiftCategoryStats>[
      if (morningWorked > 0 || morningPlanned > 0 || morningShifts > 0)
        _ShiftCategoryStats(
          label: 'Mañana',
          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
          workedHours: morningWorked,
          plannedHours: morningPlanned,
          extraHours: morningExtra,
          workedShifts: morningShifts,
          plannedShifts: morningPlannedCount,
        ),
      if (afternoonWorked > 0 || afternoonPlanned > 0 || afternoonShifts > 0)
        _ShiftCategoryStats(
          label: 'Tarde',
          color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7),
          workedHours: afternoonWorked,
          plannedHours: afternoonPlanned,
          extraHours: afternoonExtra,
          workedShifts: afternoonShifts,
          plannedShifts: afternoonPlannedCount,
        ),
      if (nightWorked > 0 || nightPlanned > 0 || nightShifts > 0)
        _ShiftCategoryStats(
          label: 'Noche',
          color: AppTheme.dynamicAccent(isDark),
          workedHours: nightWorked,
          plannedHours: nightPlanned,
          extraHours: nightExtra,
          workedShifts: nightShifts,
          plannedShifts: nightPlannedCount,
        ),
    ];

    final totalWorked = morningWorked + afternoonWorked + nightWorked;
    final totalPlanned = morningPlanned + afternoonPlanned + nightPlanned;
    final totalExtra = morningExtra + afternoonExtra + nightExtra;
    final effectiveTarget = targetHours > 0 ? targetHours : 120;

    return _WorkTelemetrySummary(
      targetHours: effectiveTarget,
      totalWorkedHours: totalWorked,
      totalPlannedHours: totalPlanned,
      totalExtraHours: totalExtra,
      categories: categories,
    );
  }

  String _classifyShiftBucket(ScheduleBlock s) {
    final lower = s.title.toLowerCase();
    if (lower.contains('nocturn') || lower.contains('noche') || s.isOvernight) {
      return 'Noche';
    }
    if (lower.contains('tarde')) return 'Tarde';
    if (lower.contains('mañana')) return 'Mañana';
    if (s.startHour >= 6 && s.startHour < 14) return 'Mañana';
    if (s.startHour >= 14 && s.startHour < 21) return 'Tarde';
    return 'Noche';
  }

  List<_HabitRankingEntry> _buildHabitRankings({
    required List<Habit> habits,
    required DateTime month,
    required Set<String> vacationSet,
    required Set<String> heavyDutySet,
    required List<String> effectivePausedDates,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final isCurrentMonth = month.year == today.year && month.month == today.month;
    final endDay = month.isAfter(today)
        ? 0
        : (isCurrentMonth ? today.day : daysInMonth);

    final list = habits.map((habit) {
      int completed = 0;
      int expected = 0;
      int vacProtected = 0;
      int heavyProtected = 0;

      for (int d = 1; d <= endDay; d++) {
        final date = DateTime(month.year, month.month, d);
        if (!habit.activeWeekdays.contains(date.weekday)) continue;
        final iso = _formatIsoDate(date);
        final done = habit.completedDates.contains(iso);

        if (!done && vacationSet.contains(iso)) {
          vacProtected++;
          continue;
        }
        if (!done && heavyDutySet.contains(iso)) {
          heavyProtected++;
          continue;
        }
        expected++;
        if (done) completed++;
      }

      final rate = expected == 0 ? 0 : ((completed / expected) * 100).round().clamp(0, 100);
      return _HabitRankingEntry(
        habit: habit,
        ratePercent: rate,
        currentStreak: StreakUtils.calculateCurrentStreak(habit, effectivePausedDates),
        maxStreak: StreakUtils.calculateMaxStreak(habit, effectivePausedDates),
        completedInRange: completed,
        expectedInRange: expected,
        vacationProtectedDays: vacProtected,
        heavyDutyProtectedDays: heavyProtected,
      );
    }).toList();

    list.sort((a, b) {
      final byRate = b.ratePercent.compareTo(a.ratePercent);
      if (byRate != 0) return byRate;
      final byStreak = b.currentStreak.compareTo(a.currentStreak);
      if (byStreak != 0) return byStreak;
      return b.maxStreak.compareTo(a.maxStreak);
    });
    return list;
  }

  String _formatSelectedPointReadout(_DailyCompliancePoint p) {
    final pct = (p.ratio * 100).round();
    final dayLabel = '${p.date.day.toString().padLeft(2, '0')} ${_monthNameEs(p.date.month).substring(0, 3)}';
    final shieldTag = p.isVacation
        ? ' · VACACIONES'
        : (p.isHeavyDuty ? ' · ESCUDO +12H' : '');
    return '$dayLabel // ${p.completedCount}/${p.expectedCount} HÁBITOS · $pct%$shieldTag';
  }

  String _formatIsoDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatHours(double h) {
    if ((h - h.roundToDouble()).abs() < 0.05) return '${h.round()}h';
    return '${h.toStringAsFixed(1)}h';
  }

  String _formatSignedHours(double h) {
    final absStr = _formatHours(h.abs());
    if (h > 0.05) return '+$absStr';
    if (h < -0.05) return '-$absStr';
    return '0h';
  }

  String _monthNameEs(int m) {
    const names = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  String _weekdayFullEs(int weekday) {
    const names = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return names[(weekday - 1).clamp(0, 6)];
  }
}

// --- DATA MODELS ---

class _DailyCompliancePoint {
  final DateTime date;
  final String iso;
  final int completedCount;
  final int expectedCount;
  final double ratio;
  final bool isVacation;
  final bool isHeavyDuty;

  const _DailyCompliancePoint({
    required this.date,
    required this.iso,
    required this.completedCount,
    required this.expectedCount,
    required this.ratio,
    required this.isVacation,
    required this.isHeavyDuty,
  });
}

class _ShiftCategoryStats {
  final String label;
  final Color color;
  final double workedHours;
  final double plannedHours;
  final double extraHours;
  final int workedShifts;
  final int plannedShifts;

  const _ShiftCategoryStats({
    required this.label,
    required this.color,
    required this.workedHours,
    required this.plannedHours,
    required this.extraHours,
    required this.workedShifts,
    required this.plannedShifts,
  });
}

class _WorkTelemetrySummary {
  final int targetHours;
  final double totalWorkedHours;
  final double totalPlannedHours;
  final double totalExtraHours;
  final List<_ShiftCategoryStats> categories;

  const _WorkTelemetrySummary({
    required this.targetHours,
    required this.totalWorkedHours,
    required this.totalPlannedHours,
    required this.totalExtraHours,
    required this.categories,
  });

  int get progressPercent =>
      targetHours <= 0 ? 0 : ((totalWorkedHours / targetHours) * 100).round().clamp(0, 999);
}

class _HabitRankingEntry {
  final Habit habit;
  final int ratePercent;
  final int currentStreak;
  final int maxStreak;
  final int completedInRange;
  final int expectedInRange;
  final int vacationProtectedDays;
  final int heavyDutyProtectedDays;

  const _HabitRankingEntry({
    required this.habit,
    required this.ratePercent,
    required this.currentStreak,
    required this.maxStreak,
    required this.completedInRange,
    required this.expectedInRange,
    required this.vacationProtectedDays,
    required this.heavyDutyProtectedDays,
  });
}

// --- CUSTOM PAINTERS ---

void _drawDashedLine(
  Canvas canvas,
  Offset p1,
  Offset p2,
  Paint paint, {
  double dash = 4,
  double gap = 4,
}) {
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist <= 0) return;
  final ux = dx / dist;
  final uy = dy / dist;
  double cur = 0;
  while (cur < dist) {
    final next = math.min(cur + dash, dist);
    canvas.drawLine(
      Offset(p1.dx + ux * cur, p1.dy + uy * cur),
      Offset(p1.dx + ux * next, p1.dy + uy * next),
      paint,
    );
    cur += dash + gap;
  }
}

void _drawMonoLabel(
  Canvas canvas,
  String text,
  Offset offset, {
  required Color color,
  double fontSize = 9,
  FontWeight fontWeight = FontWeight.w600,
  bool centerHorizontally = false,
  bool rightAlign = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: AppTheme.monoStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double dx = offset.dx;
  if (centerHorizontally) {
    dx -= tp.width / 2;
  } else if (rightAlign) {
    dx -= tp.width;
  }
  tp.paint(canvas, Offset(dx, offset.dy));
}

class _EvolutionChartPainter extends CustomPainter {
  final List<_DailyCompliancePoint> points;
  final double avgRatio;
  final int? selectedIndex;
  final Color accentColor;
  final bool isDark;
  final double leftPad;
  final double rightPad;

  const _EvolutionChartPainter({
    required this.points,
    required this.avgRatio,
    required this.selectedIndex,
    required this.accentColor,
    required this.isDark,
    required this.leftPad,
    required this.rightPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const topPad = 12.0;
    const bottomPad = 20.0;
    final plotLeft = leftPad;
    final plotRight = size.width - rightPad;
    final plotWidth = math.max(1.0, plotRight - plotLeft);
    final plotHeight = math.max(1.0, size.height - topPad - bottomPad);
    final plotBottom = topPad + plotHeight;

    final gridColor = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
    final mutedText = isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted;
    final trendColor = isDark ? const Color(0xFF67E8F9) : const Color(0xFF0284C7);
    final shieldColor = const Color(0xFFD97706);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Líneas guía horizontales: 0%, 50%, 100%
    for (final level in const [0.0, 0.5, 1.0]) {
      final y = plotBottom - (plotHeight * level);
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), gridPaint);
      _drawMonoLabel(
        canvas,
        '${(level * 100).round()}%',
        Offset(plotLeft - 5, y - 5),
        color: mutedText,
        fontSize: 8.5,
        rightAlign: true,
      );
    }

    final slotWidth = plotWidth / points.length;
    final barWidth = math.min(18.0, math.max(4.0, slotWidth * 0.56));
    final List<Offset> trendPoints = [];
    final xLabelStep = points.length > 20 ? 5 : (points.length > 12 ? 3 : 2);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = plotLeft + slotWidth * (i + 0.5);
      final barHeight = (plotHeight * p.ratio).clamp(2.0, plotHeight);
      final barTop = plotBottom - barHeight;
      final isSelected = selectedIndex == i;
      final isProtected = p.isVacation || p.isHeavyDuty;

      if (isSelected) {
        final crosshairPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.45)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(cx, topPad), Offset(cx, plotBottom), crosshairPaint);
      }

      final Color barFill;
      if (isProtected) {
        barFill = shieldColor.withValues(alpha: isSelected ? 0.9 : 0.45);
      } else if (p.ratio <= 0.01) {
        barFill = gridColor.withValues(alpha: isDark ? 0.6 : 0.7);
      } else {
        barFill = accentColor.withValues(
          alpha: isSelected ? 1.0 : (0.42 + p.ratio * 0.48),
        );
      }

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barWidth / 2, barTop, barWidth, barHeight),
        topLeft: const Radius.circular(2.5),
        topRight: const Radius.circular(2.5),
      );
      canvas.drawRRect(rrect, Paint()..color = barFill);

      if (isSelected) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      trendPoints.add(Offset(cx, barTop));

      if (i == 0 || i == points.length - 1 || i % xLabelStep == 0) {
        _drawMonoLabel(
          canvas,
          p.date.day.toString().padLeft(2, '0'),
          Offset(cx, plotBottom + 5),
          color: isSelected ? accentColor : mutedText,
          fontSize: 8.5,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          centerHorizontally: true,
        );
      }
    }

    // Línea punteada de media mensual
    final avgY = plotBottom - (plotHeight * avgRatio.clamp(0.0, 1.0));
    _drawDashedLine(
      canvas,
      Offset(plotLeft, avgY),
      Offset(plotRight, avgY),
      Paint()
        ..color = accentColor.withValues(alpha: 0.85)
        ..strokeWidth = 1.2,
      dash: 5,
      gap: 4,
    );

    // Curva de tendencia suavizada
    if (trendPoints.length >= 2) {
      final path = Path()..moveTo(trendPoints.first.dx, trendPoints.first.dy);
      for (int i = 0; i < trendPoints.length - 1; i++) {
        final cur = trendPoints[i];
        final next = trendPoints[i + 1];
        final mid = Offset((cur.dx + next.dx) / 2, (cur.dy + next.dy) / 2);
        path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
      }
      path.lineTo(trendPoints.last.dx, trendPoints.last.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = trendColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..strokeCap = StrokeCap.round,
      );
    }

    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < trendPoints.length) {
      final selPt = trendPoints[selectedIndex!];
      canvas.drawCircle(selPt, 4.0, Paint()..color = trendColor);
      canvas.drawCircle(
        selPt,
        2.0,
        Paint()..color = isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EvolutionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.avgRatio != avgRatio ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}

class _WeekdayChartPainter extends CustomPainter {
  final List<double> rates;
  final int bestIndex;
  final Color accentColor;
  final bool isDark;

  const _WeekdayChartPainter({
    required this.rates,
    required this.bestIndex,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const letters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const topPad = 18.0;
    const bottomPad = 22.0;
    final plotHeight = math.max(1.0, size.height - topPad - bottomPad);
    final plotBottom = topPad + plotHeight;

    final gridColor = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
    final textPrimary = isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary;
    final textMuted = isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted;

    // Líneas de referencia 50% y 100%
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, topPad), Offset(size.width, topPad), gridPaint);
    canvas.drawLine(
      Offset(0, plotBottom - plotHeight * 0.5),
      Offset(size.width, plotBottom - plotHeight * 0.5),
      gridPaint,
    );
    canvas.drawLine(Offset(0, plotBottom), Offset(size.width, plotBottom), gridPaint);

    final slotWidth = size.width / 7;
    final barWidth = math.min(28.0, slotWidth * 0.54);

    for (int i = 0; i < 7; i++) {
      final rate = i < rates.length ? rates[i] : 0.0;
      final isBest = i == bestIndex && rate > 0;
      final cx = slotWidth * (i + 0.5);
      final h = (plotHeight * rate).clamp(3.0, plotHeight);
      final top = plotBottom - h;

      // Marco sutil de columna completa
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barWidth / 2, topPad, barWidth, plotHeight),
          const Radius.circular(3),
        ),
        Paint()..color = gridColor.withValues(alpha: isDark ? 0.25 : 0.35),
      );

      // Barra de rendimiento
      final barColor = isBest
          ? accentColor
          : (rate > 0
              ? (isDark
                  ? AppTheme.obsidianTextSecondary.withValues(alpha: 0.72)
                  : AppTheme.boneTextSecondary.withValues(alpha: 0.68))
              : gridColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barWidth / 2, top, barWidth, h),
          const Radius.circular(3),
        ),
        Paint()..color = barColor,
      );

      // Etiqueta porcentaje arriba
      _drawMonoLabel(
        canvas,
        '${(rate * 100).round()}%',
        Offset(cx, topPad - 14),
        color: isBest ? accentColor : textMuted,
        fontSize: 9,
        fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
        centerHorizontally: true,
      );

      // Letra día L-D abajo
      _drawMonoLabel(
        canvas,
        letters[i],
        Offset(cx, plotBottom + 6),
        color: isBest ? accentColor : textPrimary,
        fontSize: 10.5,
        fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
        centerHorizontally: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeekdayChartPainter oldDelegate) {
    return oldDelegate.rates != rates ||
        oldDelegate.bestIndex != bestIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}

class _WorkTelemetryChartPainter extends CustomPainter {
  final _WorkTelemetrySummary summary;
  final Color accentColor;
  final bool isDark;

  const _WorkTelemetryChartPainter({
    required this.summary,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxScale = math.max(
      summary.targetHours.toDouble(),
      math.max(summary.totalWorkedHours, summary.totalPlannedHours),
    );
    final safeScale = maxScale <= 0 ? 120.0 : maxScale * 1.05;

    final trackRect = Rect.fromLTWH(0, 14, size.width, 22);
    final borderColor = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
    final bgFill = isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated;
    final textMuted = isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted;

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      Paint()..color = bgFill,
    );

    // Barra ghost de horas planificadas en el cuadrante
    final plannedW = ((summary.totalPlannedHours / safeScale) * size.width).clamp(0.0, size.width);
    if (plannedW > 0) {
      final plannedRect = Rect.fromLTWH(0, 42, plannedW, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plannedRect, const Radius.circular(3)),
        Paint()..color = textMuted.withValues(alpha: 0.28),
      );
      _drawMonoLabel(
        canvas,
        'PLAN // ${summary.totalPlannedHours.round()}H',
        Offset(math.min(plannedW + 6, size.width - 68), 43),
        color: textMuted,
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
      );
    }

    // Segmentos apilados por tipo de turno (Mañana, Tarde, Noche)
    double cursorX = 0;
    for (final cat in summary.categories) {
      final w = ((cat.workedHours / safeScale) * size.width).clamp(0.0, size.width - cursorX);
      if (w <= 0) continue;
      final segRect = Rect.fromLTWH(cursorX, trackRect.top + 3, w, trackRect.height - 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(segRect, const Radius.circular(2.5)),
        Paint()..color = cat.color,
      );
      cursorX += w + 1.5;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Línea vertical punteada de Meta Mensual
    final targetX = ((summary.targetHours / safeScale) * size.width).clamp(8.0, size.width - 8.0);
    _drawDashedLine(
      canvas,
      Offset(targetX, 6),
      Offset(targetX, 62),
      Paint()
        ..color = accentColor
        ..strokeWidth = 1.5,
      dash: 3,
      gap: 3,
    );
    _drawMonoLabel(
      canvas,
      'META ${summary.targetHours}H',
      Offset(math.min(targetX, size.width - 28), 0),
      color: accentColor,
      fontSize: 8.5,
      fontWeight: FontWeight.w800,
      centerHorizontally: true,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkTelemetryChartPainter oldDelegate) {
    return oldDelegate.summary != summary ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}

// --- COMPONENTES UI ---

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? trailing;
  final Color? trailingColor;
  final bool isDark;

  const _SectionHeaderRow({
    required this.title,
    this.trailing,
    this.trailingColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted;
    final lineColor = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                flex: 1000,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Container(height: 1, color: lineColor),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.monoStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: trailingColor ?? textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _MonthArrowButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            width: 1.0,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _RangePill({
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.14)
              : (isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.monoStyle(
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? accentColor
                : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.monoStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
          ),
        ),
      ],
    );
  }
}

class _EmptyTelemetryBox extends StatelessWidget {
  final String message;
  final bool isDark;

  const _EmptyTelemetryBox({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          width: 1.0,
        ),
      ),
      child: Text(
        message,
        style: AppTheme.monoStyle(
          fontSize: 11.5,
          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary,
        ),
      ),
    );
  }
}

class _StatBentoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isDark;

  const _StatBentoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.bentoCard(
        isLight: !isDark,
        borderRadius: AppTheme.radiusMd,
        borderColor: accentColor.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTheme.monoStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                ),
              ),
              Icon(icon, size: 15, color: accentColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTheme.monoStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTheme.bodyStyle(
              fontSize: 11.5,
              color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.monoStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor ??
                (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
          ),
        ),
      ],
    );
  }
}

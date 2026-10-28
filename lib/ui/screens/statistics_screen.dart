import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/streak_utils.dart';
import '../../domain/models/habit.dart';
import '../theme/app_theme.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  int _calculatePerfectDays(List<Habit> habits, List<String> pausedDates) {
    if (habits.isEmpty) return 0;
    
    Set<String> allDates = {};
    for (var h in habits) {
      allDates.addAll(h.completedDates);
    }
    
    int perfectDays = 0;
    
    for (var dateStr in allDates) {
      if (pausedDates.contains(dateStr)) continue;
      
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      
      final expectedHabits = habits.where((h) => h.activeWeekdays.contains(date.weekday)).toList();
      if (expectedHabits.isEmpty) continue;
      
      bool isPerfect = expectedHabits.every((h) => h.completedDates.contains(dateStr));
      if (isPerfect) perfectDays++;
    }
    
    return perfectDays;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calcular Racha Global Máxima
    int globalMaxStreak = 0;
    for (var habit in habits) {
      final maxStreak = StreakUtils.calculateMaxStreak(habit, settings.vacationDates);
      if (maxStreak > globalMaxStreak) globalMaxStreak = maxStreak;
    }

    // Calcular Días Perfectos
    final perfectDays = _calculatePerfectDays(habits, settings.vacationDates);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
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
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                width: AppTheme.borderPrecision,
              ),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera de sección: Trofeos Globales
                Row(
                  children: [
                    Text(
                      'RESUMEN // RENDIMIENTO GLOBAL',
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Bento Grid de métricas clave (2 columnas)
                Row(
                  children: [
                    Expanded(
                      child: _StatBentoCard(
                        title: 'RACHA MÁXIMA',
                        value: '${globalMaxStreak}d',
                        subtitle: 'Récord consecutivo',
                        icon: Icons.bolt_rounded,
                        accentColor: AppTheme.dynamicAccent(isDark),
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
                const SizedBox(height: 28),

                // Cabecera de sección: Desglose
                Row(
                  children: [
                    Text(
                      'DESGLOSE // POR HÁBITO',
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '[${habits.length.toString().padLeft(2, '0')}]',
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dynamicAccent(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (habits.isEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.bentoCard(isLight: !isDark),
                      child: Text(
                        '// No hay datos de hábitos registrados todavía.',
                        style: AppTheme.monoStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                        ),
                      ),
                    ),
                  )
                else
                  ...habits.map((habit) {
                    final maxStreak = StreakUtils.calculateMaxStreak(habit, settings.vacationDates);
                    final currentStreak = StreakUtils.calculateCurrentStreak(habit, settings.vacationDates);
                    
                    int successCount = 0;
                    int expectedCount = 0;
                    DateTime checkDate = DateTime.now();
                    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
                    
                    for (int i = 0; i < 30; i++) {
                      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
                      
                      if (!settings.vacationDates.contains(dateStr) && habit.activeWeekdays.contains(checkDate.weekday)) {
                        expectedCount++;
                        if (habit.completedDates.contains(dateStr)) {
                          successCount++;
                        }
                      }
                      checkDate = checkDate.subtract(const Duration(days: 1));
                    }
                    
                    final rate = expectedCount == 0 ? 0 : ((successCount / expectedCount) * 100).toInt();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
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
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: habit.color,
                                  borderRadius: BorderRadius.circular(2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: habit.color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  habit.name,
                                  style: AppTheme.displayStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '$rate%',
                                style: AppTheme.monoStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: habit.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (rate / 100).clamp(0.0, 1.0),
                              minHeight: 3.5,
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
                                value: '${currentStreak}d',
                                isDark: isDark,
                              ),
                              _MiniStat(
                                label: 'RÉCORD',
                                value: '${maxStreak}d',
                                isDark: isDark,
                              ),
                              _MiniStat(
                                label: 'ÚLTIMOS 30D',
                                value: '$successCount / $expectedCount',
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                ),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppTheme.monoStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTheme.bodyStyle(
              fontSize: 11,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
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

  const _MiniStat({
    required this.label,
    required this.value,
    required this.isDark,
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/streak_utils.dart';
import '../../domain/models/habit.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  int _calculatePerfectDays(List<Habit> habits, List<String> pausedDates) {
    if (habits.isEmpty) return 0;
    
    // Recopilar todas las fechas únicas de la historia
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
      
      // Hábitos que estaban programados para este día de la semana
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
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    // Calcular Racha Global Máxima
    int globalMaxStreak = 0;
    for (var habit in habits) {
      final maxStreak = StreakUtils.calculateMaxStreak(habit, settings.vacationDates);
      if (maxStreak > globalMaxStreak) globalMaxStreak = maxStreak;
    }

    // Calcular Días Perfectos
    final perfectDays = _calculatePerfectDays(habits, settings.vacationDates);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tus Trofeos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor?.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Racha Máxima',
                    value: '$globalMaxStreak',
                    subtitle: 'días seguidos',
                    icon: Icons.emoji_events_rounded,
                    color: const Color(0xFFFFD700), // Oro
                    cardColor: cardColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Días Perfectos',
                    value: '$perfectDays',
                    subtitle: '100% completado',
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFF4FC3F7), // Cian
                    cardColor: cardColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              'Desglose por Hábito',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor?.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            if (habits.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No hay hábitos para analizar',
                    style: TextStyle(color: textColor?.withOpacity(0.4)),
                  ),
                ),
              )
            else
              ...habits.map((habit) {
                final maxStreak = StreakUtils.calculateMaxStreak(habit, settings.vacationDates);
                final currentStreak = StreakUtils.calculateCurrentStreak(habit, settings.vacationDates);
                
                // Calcular tasa de éxito de los últimos 30 días
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
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: habit.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              habit.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '$rate%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: habit.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MiniStat(label: 'Racha Actual', value: '$currentStreak', icon: Icons.local_fire_department, color: const Color(0xFFE6A590)),
                          _MiniStat(label: 'Récord', value: '$maxStreak', icon: Icons.star_rounded, color: const Color(0xFFFFD700)),
                          _MiniStat(label: 'Últimos 30d', value: '$successCount/$expectedCount', icon: Icons.calendar_month_rounded, color: Colors.grey),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color cardColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
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
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

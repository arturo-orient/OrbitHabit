import '../domain/models/habit.dart';

class StreakUtils {
  /// Calculates the current streak for a habit based on YYYY-MM-DD strings.
  /// Iterates backwards from today or yesterday and stops immediately when a gap is found.
  /// This ensures O(K) where K is the size of the current streak, NOT O(N) of all history!
  static int calculateCurrentStreak(Habit habit, [List<String> pausedDates = const []]) {
    if (habit.completedDates.isEmpty) return 0;

    DateTime checkDate = DateTime.now();
    int streak = 0;
    bool isFirstActiveDay = true;
    int maxLookup = 0; // prevent infinite loops if completedDates is buggy

    while (maxLookup < 3650) { // 10 years max
      maxLookup++;
      
      final formatted = _formatDate(checkDate);

      if (pausedDates.contains(formatted)) {
        // Skip vacation days completely! They don't break the streak and they don't count towards it.
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      if (!habit.activeWeekdays.contains(checkDate.weekday)) {
        // Skip inactive days! They don't break the streak.
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      
      if (habit.completedDates.contains(formatted)) {
        streak++;
        isFirstActiveDay = false;
      } else {
        if (isFirstActiveDay) {
          // Missing today doesn't break the streak (yet)
          isFirstActiveDay = false;
        } else {
          // Gap on a required past day
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calculates the maximum (all-time best) streak for a habit.
  static int calculateMaxStreak(Habit habit, [List<String> pausedDates = const []]) {
    if (habit.completedDates.isEmpty) return 0;

    // Parse to local date-only DateTime objects to ignore time zone shifts
    final dates = habit.completedDates.map((d) {
      final parts = d.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList()
      ..sort((a, b) => a.compareTo(b));

    DateTime current = dates.first;
    DateTime end = DateTime.now();
    
    // Normalize end to 00:00:00 to prevent timezone drift
    end = DateTime(end.year, end.month, end.day);

    int maxStreak = 0;
    int currentStreak = 0;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final formatted = _formatDate(current);

      if (pausedDates.contains(formatted)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      if (!habit.activeWeekdays.contains(current.weekday)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      if (habit.completedDates.contains(formatted)) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        // Only break if it's strictly before today. Today can be empty without breaking max streak if it's still ongoing.
        if (current.isBefore(end)) {
          currentStreak = 0;
        }
      }

      current = current.add(const Duration(days: 1));
    }

    return maxStreak;
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

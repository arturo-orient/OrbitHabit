import '../domain/models/habit.dart';

class StreakUtils {
  /// Devuelve el número de ISO week para una fecha dada (Lunes = 1)
  static int _getIsoWeekNumber(DateTime date) {
    int dayOfYear = int.parse(date.difference(DateTime(date.year, 1, 1)).inDays.toString()) + 1;
    int w = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (w < 1) {
      w = _getIsoWeekNumber(DateTime(date.year - 1, 12, 31));
    } else if (w > 52) {
      DateTime lastDayOfYear = DateTime(date.year, 12, 31);
      if (lastDayOfYear.weekday < 4) {
        w = 1;
      }
    }
    return w;
  }

  /// Devuelve el string del año y semana (ej. "2023-W45")
  static String _getIsoWeekString(DateTime date) {
    final week = _getIsoWeekNumber(date);
    // Si la semana es 1 pero estamos en diciembre, es la semana 1 del año siguiente
    int year = date.year;
    if (week == 1 && date.month == 12) year++;
    // Si la semana es 52 o 53 pero estamos en enero, es del año anterior
    if (week >= 52 && date.month == 1) year--;
    
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  /// Helper para saber cuántas veces se ha completado el hábito en la semana de la fecha dada
  static int getCompletionsInWeek(Habit habit, DateTime date) {
    final weekStr = _getIsoWeekString(date);
    int count = 0;
    for (final completedStr in habit.completedDates) {
      final dt = DateTime.tryParse(completedStr);
      if (dt != null && _getIsoWeekString(dt) == weekStr) {
        count++;
      }
    }
    return count;
  }

  static int calculateCurrentStreak(Habit habit, [List<String> pausedDates = const []]) {
    if (habit.completedDates.isEmpty) return 0;

    if (habit.frequencyType == 1) {
      // Hábito Flexible (por semanas)
      DateTime checkDate = DateTime.now();
      int consecutiveWeeks = 0;
      int completionsThisWeek = getCompletionsInWeek(habit, checkDate);
      bool isCurrentWeek = true;
      
      while (true) {
        final completions = getCompletionsInWeek(habit, checkDate);
        if (completions >= habit.targetDaysPerWeek) {
          consecutiveWeeks++;
        } else {
          // Si estamos en la semana actual, fallar el objetivo todavía no rompe la racha (puede que quede semana)
          if (!isCurrentWeek) {
            break; // Racha rota en el pasado
          }
        }
        isCurrentWeek = false;
        checkDate = checkDate.subtract(const Duration(days: 7));
      }
      
      // La racha numérica mostrada será la base de semanas logradas * target
      // más lo que llevemos esta semana, para que los números sean comparables a los de días.
      int baseStreak = consecutiveWeeks * habit.targetDaysPerWeek;
      if (completionsThisWeek < habit.targetDaysPerWeek) {
        return baseStreak + completionsThisWeek;
      } else {
        return baseStreak; // Si ya cumplió esta semana, `consecutiveWeeks` ya lo incluyó
      }
    }

    // Hábito Días Específicos
    DateTime checkDate = DateTime.now();
    int streak = 0;
    bool isFirstActiveDay = true;
    int maxLookup = 0; 

    while (maxLookup < 3650) { 
      maxLookup++;
      final formatted = _formatDate(checkDate);

      if (pausedDates.contains(formatted)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      if (!habit.activeWeekdays.contains(checkDate.weekday)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      
      if (habit.completedDates.contains(formatted)) {
        streak++;
        isFirstActiveDay = false;
      } else {
        if (isFirstActiveDay) {
          isFirstActiveDay = false;
        } else {
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int calculateMaxStreak(Habit habit, [List<String> pausedDates = const []]) {
    if (habit.completedDates.isEmpty) return 0;
    
    if (habit.frequencyType == 1) {
      // Flexible: contar semanas consecutivas logradas
      // 1. Agrupar completions por semana
      Map<String, int> weekCounts = {};
      for (final dateStr in habit.completedDates) {
        final dt = DateTime.tryParse(dateStr);
        if (dt != null) {
          final wStr = _getIsoWeekString(dt);
          weekCounts[wStr] = (weekCounts[wStr] ?? 0) + 1;
        }
      }
      
      // 2. Extraer todas las semanas únicas y ordenarlas cronológicamente
      List<String> sortedWeeks = weekCounts.keys.toList()..sort();
      
      if (sortedWeeks.isEmpty) return 0;
      
      int maxWeeks = 0;
      int currentWeeks = 0;
      
      // Necesitamos iterar semana a semana desde la primera registrada hasta hoy
      final sortedDates = habit.completedDates.toList()..sort();
      DateTime current = DateTime.tryParse(sortedDates.first) ?? DateTime.now();
      DateTime end = DateTime.now();
      
      while (current.isBefore(end) || _getIsoWeekString(current) == _getIsoWeekString(end)) {
        final wStr = _getIsoWeekString(current);
        final count = weekCounts[wStr] ?? 0;
        
        if (count >= habit.targetDaysPerWeek) {
          currentWeeks++;
          if (currentWeeks > maxWeeks) maxWeeks = currentWeeks;
        } else {
           // Si es la semana actual, aún no está rota (puede acabarla)
           if (_getIsoWeekString(current) != _getIsoWeekString(end)) {
             currentWeeks = 0;
           }
        }
        current = current.add(const Duration(days: 7));
      }
      
      return maxWeeks * habit.targetDaysPerWeek;
    }

    // Días Específicos
    final dates = habit.completedDates.map((d) {
      final parts = d.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList()
      ..sort((a, b) => a.compareTo(b));

    DateTime current = dates.first;
    DateTime end = DateTime.now();
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

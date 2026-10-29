import 'package:flutter/material.dart';
import 'habit.dart';

class ScheduleBlock {
  final String id;
  final String title;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int colorValue;
  final String? habitId; // Optional link to an existing Habit ID
  final List<int> daysOfWeek; // 1 = Monday, ..., 7 = Sunday
  final bool hasMonthlyHourTarget;
  final int monthlyTargetHours; // e.g. 120
  final List<String> completedDates; // Dates in YYYY-MM-DD when this shift was completed
  final List<String> assignedDates; // Specific YYYY-MM-DD dates assigned on the shift calendar
  final double extraHours; // Extra overtime hours logged

  const ScheduleBlock({
    required this.id,
    required this.title,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.colorValue,
    this.habitId,
    required this.daysOfWeek,
    this.hasMonthlyHourTarget = false,
    this.monthlyTargetHours = 120,
    this.completedDates = const [],
    this.assignedDates = const [],
    this.extraHours = 0.0,
  });

  Color get color => Color(colorValue);

  int get startInMinutes => startHour * 60 + startMinute;
  int get endInMinutes => endHour * 60 + endMinute;

  /// True if the time range crosses midnight (e.g. 23:00 to 07:00)
  bool get isOvernight => endInMinutes <= startInMinutes;

  /// Total duration of the block in minutes
  int get durationInMinutes {
    if (isOvernight) {
      return (1440 - startInMinutes) + endInMinutes;
    }
    return endInMinutes - startInMinutes;
  }

  /// Formatted duration in human-readable text (e.g. "8h", "1h 30m")
  String get formattedDuration {
    final total = durationInMinutes;
    final h = total ~/ 60;
    final m = total % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// Time range format (e.g. "23:00 - 07:00")
  String get formattedTimeRange {
    final sH = startHour.toString().padLeft(2, '0');
    final sM = startMinute.toString().padLeft(2, '0');
    final eH = endHour.toString().padLeft(2, '0');
    final eM = endMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }

  /// Checks if this block applies to a given weekday (1..7)
  bool appliesToWeekday(int weekday) {
    return daysOfWeek.contains(weekday);
  }

  /// Checks if this block applies to a specific calendar date (DateTime).
  /// If [assignedDates] has items, it takes priority; otherwise falls back to weekday.
  bool appliesToDate(DateTime date) {
    final iso = date.toIso8601String().split('T').first;
    if (assignedDates.isNotEmpty) {
      return assignedDates.contains(iso);
    }
    // Si es un turno/actividad planificable con meta de horas mensual
    // y aún no se ha asignado a ningún día en el calendario, no debe dibujarse todos los días:
    if (hasMonthlyHourTarget) {
      return false;
    }
    return appliesToWeekday(date.weekday);
  }

  /// Checks whether this block is currently active at [now].
  /// Correctly handles overnight shifts crossing midnight!
  bool isActiveAt(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final appliesToday = appliesToDate(now);
    final appliesYesterday = appliesToDate(now.subtract(const Duration(days: 1)));

    if (!isOvernight) {
      // Normal block within same day (e.g. 08:00 - 09:00)
      if (!appliesToday) return false;
      return currentMinutes >= startInMinutes && currentMinutes < endInMinutes;
    } else {
      // Overnight block (e.g. 23:00 - 07:00)
      if (currentMinutes >= startInMinutes) {
        // Evening phase: started today
        return appliesToday;
      } else if (currentMinutes < endInMinutes) {
        // Morning phase: started yesterday night!
        return appliesYesterday;
      }
      return false;
    }
  }

  /// Minutes remaining until this block finishes (or null if not currently active)
  int? minutesRemainingAt(DateTime now) {
    if (!isActiveAt(now)) return null;
    final currentMinutes = now.hour * 60 + now.minute;
    if (!isOvernight) {
      return endInMinutes - currentMinutes;
    } else {
      if (currentMinutes >= startInMinutes) {
        return (1440 - currentMinutes) + endInMinutes;
      } else {
        return endInMinutes - currentMinutes;
      }
    }
  }

  /// Effective completed dates combining block's own dates and linked habit's dates
  List<String> getEffectiveCompletedDates([Habit? linkedHabit]) {
    final set = Set<String>.from(completedDates);
    if (linkedHabit != null) {
      set.addAll(linkedHabit.completedDates);
    }
    return set.toList();
  }

  /// Calculate total worked hours in a specific month
  double getMonthlyWorkedHours(DateTime month, [Habit? linkedHabit]) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final allDates = getEffectiveCompletedDates(linkedHabit);
    final completedInMonth = allDates.where((d) => d.startsWith(prefix)).length;
    final shiftHours = durationInMinutes / 60.0;
    return (completedInMonth * shiftHours) + extraHours;
  }

  /// Whether the monthly target has been reached or exceeded
  bool isTargetReached(DateTime month, [Habit? linkedHabit]) {
    if (!hasMonthlyHourTarget) return false;
    return getMonthlyWorkedHours(month, linkedHabit) >= monthlyTargetHours;
  }

  /// Overtime hours worked beyond the monthly target
  double getOvertimeHours(DateTime month, [Habit? linkedHabit]) {
    if (!hasMonthlyHourTarget) return 0.0;
    final total = getMonthlyWorkedHours(month, linkedHabit);
    return total > monthlyTargetHours ? total - monthlyTargetHours : 0.0;
  }

  /// Total number of assigned shifts in a given month
  int getAssignedShiftsInMonth(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return assignedDates.where((d) => d.startsWith(prefix)).length;
  }

  /// Total planned hours in a given month based on calendar assignments
  double getPlannedHoursInMonth(DateTime month) {
    final count = getAssignedShiftsInMonth(month);
    return count * (durationInMinutes / 60.0);
  }

  ScheduleBlock copyWith({
    String? id,
    String? title,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? colorValue,
    String? habitId,
    bool clearHabitId = false,
    List<int>? daysOfWeek,
    bool? hasMonthlyHourTarget,
    int? monthlyTargetHours,
    List<String>? completedDates,
    List<String>? assignedDates,
    double? extraHours,
  }) {
    return ScheduleBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      colorValue: colorValue ?? this.colorValue,
      habitId: clearHabitId ? null : (habitId ?? this.habitId),
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      hasMonthlyHourTarget: hasMonthlyHourTarget ?? this.hasMonthlyHourTarget,
      monthlyTargetHours: monthlyTargetHours ?? this.monthlyTargetHours,
      completedDates: completedDates ?? this.completedDates,
      assignedDates: assignedDates ?? this.assignedDates,
      extraHours: extraHours ?? this.extraHours,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'colorValue': colorValue,
      'habitId': habitId,
      'daysOfWeek': daysOfWeek,
      'hasMonthlyHourTarget': hasMonthlyHourTarget,
      'monthlyTargetHours': monthlyTargetHours,
      'completedDates': completedDates,
      'assignedDates': assignedDates,
      'extraHours': extraHours,
    };
  }

  factory ScheduleBlock.fromMap(Map<dynamic, dynamic> map) {
    return ScheduleBlock(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Actividad',
      startHour: map['startHour'] as int? ?? 9,
      startMinute: map['startMinute'] as int? ?? 0,
      endHour: map['endHour'] as int? ?? 10,
      endMinute: map['endMinute'] as int? ?? 0,
      colorValue: map['colorValue'] as int? ?? 0xFF84A59D,
      habitId: map['habitId'] as String?,
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5, 6, 7],
      hasMonthlyHourTarget: map['hasMonthlyHourTarget'] as bool? ?? false,
      monthlyTargetHours: map['monthlyTargetHours'] as int? ?? 120,
      completedDates: (map['completedDates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      assignedDates: (map['assignedDates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      extraHours: (map['extraHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Agrupación unificada de turnos bajo una sola actividad madre (ej: "Trabajar")
class WorkShiftGroup {
  final String title;
  final String? habitId;
  final Habit? habit;
  final List<ScheduleBlock> shifts;
  final int monthlyTargetHours;

  const WorkShiftGroup({
    required this.title,
    this.habitId,
    this.habit,
    required this.shifts,
    this.monthlyTargetHours = 120,
  });

  Color get color => habit?.color ?? (shifts.isNotEmpty ? shifts.first.color : const Color(0xFFD4FF00));

  /// Calcula el total de horas reales trabajadas en el mes (solo turnos efectivamente completados o días pasados)
  double getMonthlyWorkedHours(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final todayIso = now.toIso8601String().split('T').first;
    double total = 0.0;

    final Set<String> completedSet = {};
    for (final s in shifts) {
      completedSet.addAll(s.completedDates.where((d) => d.startsWith(prefix)));
    }
    if (habit != null) {
      completedSet.addAll(habit!.completedDates.where((d) => d.startsWith(prefix)));
    }

    if (completedSet.isNotEmpty) {
      for (final dateIso in completedSet) {
        final shift = shifts.firstWhere(
          (s) => s.assignedDates.contains(dateIso),
          orElse: () => shifts.firstWhere(
            (s) => s.completedDates.contains(dateIso),
            orElse: () => shifts.first,
          ),
        );
        total += (shift.durationInMinutes / 60.0);
      }
      for (final s in shifts) {
        total += s.extraHours;
      }
      return total;
    }

    // Si no hay completedDates explícitas pero hay assignedDates en el calendario:
    // Solo contar como trabajadas las fechas que ya han ocurrido (d <= todayIso)
    final anyHasAssigned = shifts.any((s) => s.assignedDates.any((d) => d.startsWith(prefix)));
    if (anyHasAssigned) {
      for (final s in shifts) {
        final pastCount = s.assignedDates.where((d) => d.startsWith(prefix) && d.compareTo(todayIso) <= 0).length;
        total += pastCount * (s.durationInMinutes / 60.0);
        total += s.extraHours;
      }
    }

    return total;
  }

  /// Calcula el total de horas planificadas en el cuadrante (incluye días futuros)
  double getMonthlyPlannedHours(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    double total = 0.0;
    for (final s in shifts) {
      final count = s.assignedDates.where((d) => d.startsWith(prefix)).length;
      total += count * (s.durationInMinutes / 60.0);
    }
    return total;
  }

  /// Total de turnos planificados en el mes
  int getMonthlyPlannedShiftsCount(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    int count = 0;
    for (final s in shifts) {
      count += s.assignedDates.where((d) => d.startsWith(prefix)).length;
    }
    return count;
  }

  /// Total de turnos trabajados en el mes
  int getMonthlyWorkedShiftsCount(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final todayIso = now.toIso8601String().split('T').first;

    final Set<String> completedSet = {};
    for (final s in shifts) {
      completedSet.addAll(s.completedDates.where((d) => d.startsWith(prefix)));
    }
    if (habit != null) {
      completedSet.addAll(habit!.completedDates.where((d) => d.startsWith(prefix)));
    }
    if (completedSet.isNotEmpty) {
      return completedSet.length;
    }

    int count = 0;
    for (final s in shifts) {
      count += s.assignedDates.where((d) => d.startsWith(prefix) && d.compareTo(todayIso) <= 0).length;
    }
    return count;
  }

  /// Total de turnos realizados / asignados en el mes
  int getMonthlyShiftsCount(DateTime month) {
    final worked = getMonthlyWorkedShiftsCount(month);
    if (worked > 0) return worked;
    return getMonthlyPlannedShiftsCount(month);
  }

  /// Desglose detallado por turno individual
  List<ShiftBreakdownItem> getBreakdown(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final isFutureMonth = month.year > now.year || (month.year == now.year && month.month > now.month);
    final todayIso = now.toIso8601String().split('T').first;

    return shifts.map((s) {
      final assigned = s.assignedDates.where((d) => d.startsWith(prefix)).length;
      final completed = s.completedDates.where((d) => d.startsWith(prefix)).length;

      int count;
      if (isFutureMonth) {
        count = assigned;
      } else {
        final pastAssigned = s.assignedDates.where((d) => d.startsWith(prefix) && d.compareTo(todayIso) <= 0).length;
        count = completed > 0 ? completed : pastAssigned;
        if (count == 0 && assigned > 0) {
          count = assigned;
        }
      }

      final hours = count * (s.durationInMinutes / 60.0);
      return ShiftBreakdownItem(
        shift: s,
        shiftsCount: count,
        totalHours: hours,
      );
    }).toList();
  }

  bool isTargetReached(DateTime month) {
    return getMonthlyWorkedHours(month) >= monthlyTargetHours;
  }

  double getOvertimeHours(DateTime month) {
    final worked = getMonthlyWorkedHours(month);
    return worked > monthlyTargetHours ? worked - monthlyTargetHours : 0.0;
  }
}

class ShiftBreakdownItem {
  final ScheduleBlock shift;
  final int shiftsCount;
  final double totalHours;

  const ShiftBreakdownItem({
    required this.shift,
    required this.shiftsCount,
    required this.totalHours,
  });
}

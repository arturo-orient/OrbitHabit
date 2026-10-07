import 'package:flutter/material.dart';

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

  /// Checks whether this block is currently active at [now].
  /// Correctly handles overnight shifts crossing midnight!
  bool isActiveAt(DateTime now) {
    final currentMinutes = now.hour * 60 + now.minute;
    final todayWeekday = now.weekday;

    if (!isOvernight) {
      // Normal block within same day (e.g. 08:00 - 09:00)
      if (!daysOfWeek.contains(todayWeekday)) return false;
      return currentMinutes >= startInMinutes && currentMinutes < endInMinutes;
    } else {
      // Overnight block (e.g. 23:00 - 07:00)
      if (currentMinutes >= startInMinutes) {
        // Evening phase: started today
        return daysOfWeek.contains(todayWeekday);
      } else if (currentMinutes < endInMinutes) {
        // Morning phase: started yesterday night!
        final yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1;
        return daysOfWeek.contains(yesterdayWeekday);
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

  /// Calculate total worked hours in a specific month
  double getMonthlyWorkedHours(DateTime month) {
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final completedInMonth = completedDates.where((d) => d.startsWith(prefix)).length;
    final shiftHours = durationInMinutes / 60.0;
    return (completedInMonth * shiftHours) + extraHours;
  }

  /// Whether the monthly target has been reached or exceeded
  bool isTargetReached(DateTime month) {
    if (!hasMonthlyHourTarget) return false;
    return getMonthlyWorkedHours(month) >= monthlyTargetHours;
  }

  /// Overtime hours worked beyond the monthly target
  double getOvertimeHours(DateTime month) {
    if (!hasMonthlyHourTarget) return 0.0;
    final total = getMonthlyWorkedHours(month);
    return total > monthlyTargetHours ? total - monthlyTargetHours : 0.0;
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
      extraHours: (map['extraHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

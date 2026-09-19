import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class Habit {
  final String id;
  final String name;
  final int colorValue; // ARGB
  final int targetDays;
  final Set<String> completedDates; // Format: YYYY-MM-DD
  final int orderIndex;
  
  // Nuevos campos del Sistema Avanzado de Metas
  final bool isNumeric;
  final int dailyTarget;
  final String dailyUnit;
  final Map<String, int> dailyProgress; 
  final List<int> activeWeekdays; // 1 = Lunes, 7 = Domingo
  final bool hasMonthlyTarget;

  // Nuevos campos de Frecuencia Semanal Flexible
  final int frequencyType; // 0 = Días Específicos, 1 = Flexible
  final int targetDaysPerWeek; // ej. 3 días a la semana

  Habit({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.targetDays,
    required this.orderIndex,
    Set<String>? completedDates,
    this.isNumeric = false,
    this.dailyTarget = 1,
    this.dailyUnit = '',
    Map<String, int>? dailyProgress,
    List<int>? activeWeekdays,
    this.hasMonthlyTarget = true,
    this.frequencyType = 0,
    this.targetDaysPerWeek = 3,
  })  : completedDates = completedDates ?? {},
        dailyProgress = dailyProgress ?? {},
        activeWeekdays = activeWeekdays ?? [1, 2, 3, 4, 5, 6, 7];

  Color get color => Color(colorValue);

  Habit copyWith({
    String? id,
    String? name,
    int? colorValue,
    int? targetDays,
    int? orderIndex,
    Set<String>? completedDates,
    bool? isNumeric,
    int? dailyTarget,
    String? dailyUnit,
    Map<String, int>? dailyProgress,
    List<int>? activeWeekdays,
    bool? hasMonthlyTarget,
    int? frequencyType,
    int? targetDaysPerWeek,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      targetDays: targetDays ?? this.targetDays,
      orderIndex: orderIndex ?? this.orderIndex,
      completedDates: completedDates ?? this.completedDates,
      isNumeric: isNumeric ?? this.isNumeric,
      dailyTarget: dailyTarget ?? this.dailyTarget,
      dailyUnit: dailyUnit ?? this.dailyUnit,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      hasMonthlyTarget: hasMonthlyTarget ?? this.hasMonthlyTarget,
      frequencyType: frequencyType ?? this.frequencyType,
      targetDaysPerWeek: targetDaysPerWeek ?? this.targetDaysPerWeek,
    );
  }

  // To/From Map for manual Hive serialization (without generators)
  Map<dynamic, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'targetDays': targetDays,
      'orderIndex': orderIndex,
      'completedDates': completedDates.toList(),
      'isNumeric': isNumeric,
      'dailyTarget': dailyTarget,
      'dailyUnit': dailyUnit,
      'dailyProgress': dailyProgress,
      'activeWeekdays': activeWeekdays,
      'hasMonthlyTarget': hasMonthlyTarget,
      'frequencyType': frequencyType,
      'targetDaysPerWeek': targetDaysPerWeek,
    };
  }

  factory Habit.fromMap(Map<dynamic, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['colorValue'] as int,
      targetDays: map['targetDays'] as int,
      orderIndex: map['orderIndex'] as int? ?? 0,
      completedDates: (map['completedDates'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? {},
      // Migración segura para datos antiguos:
      isNumeric: map['isNumeric'] as bool? ?? false,
      dailyTarget: map['dailyTarget'] as int? ?? 1,
      dailyUnit: map['dailyUnit'] as String? ?? '',
      dailyProgress: (map['dailyProgress'] as Map<dynamic, dynamic>?)?.map((key, value) => MapEntry(key.toString(), value as int)) ?? {},
      activeWeekdays: (map['activeWeekdays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [1, 2, 3, 4, 5, 6, 7],
      hasMonthlyTarget: map['hasMonthlyTarget'] as bool? ?? true,
      frequencyType: map['frequencyType'] as int? ?? 0,
      targetDaysPerWeek: map['targetDaysPerWeek'] as int? ?? 3,
    );
  }
}

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final map = reader.readMap();
    return Habit.fromMap(map);
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer.writeMap(obj.toMap());
  }
}

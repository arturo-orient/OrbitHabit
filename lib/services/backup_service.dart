import 'dart:convert';
import '../domain/models/habit.dart';
import '../domain/models/schedule_block.dart';
import '../domain/models/user_settings.dart';

class BackupService {
  /// Exporta el estado completo de la app (hábitos, horarios y vacaciones) en formato JSON
  static String exportToJson({
    required List<Habit> habits,
    required List<ScheduleBlock> blocks,
    required UserSettings settings,
  }) {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'habits': habits.map((h) => h.toMap()).toList(),
      'scheduleBlocks': blocks.map((b) => b.toMap()).toList(),
      'vacationDates': settings.vacationDates,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Valida y deserializa un archivo JSON de respaldo de forma segura
  static ({List<Habit> habits, List<ScheduleBlock> blocks, List<String> vacationDates}) parseFromJson(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('El JSON de backup debe ser un objeto válido.');
      }

      final habitsRaw = decoded['habits'];
      if (habitsRaw is! List) {
        throw const FormatException('El campo "habits" es inválido o no existe.');
      }

      final blocksRaw = decoded['scheduleBlocks'];
      if (blocksRaw is! List) {
        throw const FormatException('El campo "scheduleBlocks" es inválido o no existe.');
      }

      final vacationRaw = decoded['vacationDates'];
      final List<String> vacationDates = (vacationRaw is List)
          ? vacationRaw.map((e) => e.toString()).toList()
          : <String>[];

      final habits = habitsRaw
          .map((item) => Habit.fromMap(Map<dynamic, dynamic>.from(item as Map)))
          .toList();

      final blocks = blocksRaw
          .map((item) => ScheduleBlock.fromMap(Map<dynamic, dynamic>.from(item as Map)))
          .toList();

      return (
        habits: habits,
        blocks: blocks,
        vacationDates: vacationDates,
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Error al procesar el archivo de copia de seguridad: $e');
    }
  }
}

class DemoSeederService {
  /// Genera un conjunto de demostración visualmente rico y realista para el mes actual
  static ({List<Habit> habits, List<ScheduleBlock> blocks}) generateDemoData(DateTime now) {
    final year = now.year;
    final month = now.month;
    final today = now.day;
    final prefix = '$year-${month.toString().padLeft(2, '0')}';

    String fmt(int day) => '$prefix-${day.toString().padLeft(2, '0')}';

    // a) Hábito madre "Trabajar"
    final workPastDays = <String>{};
    final morningAssigned = <String>[];
    final afternoonAssigned = <String>[];
    final nightAssigned = <String>[];

    for (int d = 1; d <= 28; d++) {
      final isPast = d <= today;

      if (d % 3 == 1) {
        morningAssigned.add(fmt(d));
        if (isPast) workPastDays.add(fmt(d));
      } else if (d % 3 == 2) {
        afternoonAssigned.add(fmt(d));
        if (isPast) workPastDays.add(fmt(d));
      } else if (d % 6 == 0) {
        nightAssigned.add(fmt(d));
        if (isPast) workPastDays.add(fmt(d));
      }
    }

    final morningCompleted = morningAssigned.where((d) => d.compareTo(fmt(today)) <= 0).toList();
    final afternoonCompleted = afternoonAssigned.where((d) => d.compareTo(fmt(today)) <= 0).toList();
    final nightCompleted = nightAssigned.where((d) => d.compareTo(fmt(today)) <= 0).toList();

    final workHabit = Habit(
      id: 'demo_work',
      name: 'Trabajar',
      colorValue: 0xFF84A59D,
      targetDays: 16,
      orderIndex: 0,
      completedDates: workPastDays,
    );

    final morningBlock = ScheduleBlock(
      id: 'demo_shift_morning',
      title: 'Turno Mañana',
      startHour: 7,
      startMinute: 0,
      endHour: 15,
      endMinute: 0,
      colorValue: 0xFF84A59D,
      habitId: 'demo_work',
      daysOfWeek: [1, 2, 3, 4, 5],
      hasMonthlyHourTarget: true,
      monthlyTargetHours: 120,
      assignedDates: morningAssigned,
      completedDates: morningCompleted,
    );

    final afternoonBlock = ScheduleBlock(
      id: 'demo_shift_afternoon',
      title: 'Turno Tarde',
      startHour: 15,
      startMinute: 0,
      endHour: 23,
      endMinute: 0,
      colorValue: 0xFFE5D08F,
      habitId: 'demo_work',
      daysOfWeek: [1, 2, 3, 4, 5],
      hasMonthlyHourTarget: true,
      monthlyTargetHours: 120,
      assignedDates: afternoonAssigned,
      completedDates: afternoonCompleted,
    );

    final nightBlock = ScheduleBlock(
      id: 'demo_shift_night',
      title: 'Turno Noche',
      startHour: 23,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      colorValue: 0xFF9EA1D4,
      habitId: 'demo_work',
      daysOfWeek: [1, 2, 3, 4, 5],
      hasMonthlyHourTarget: true,
      monthlyTargetHours: 120,
      assignedDates: nightAssigned,
      completedDates: nightCompleted,
      extraHours: 4.0,
    );

    // c) 3 hábitos regulares:
    // 1. Entrenamiento Fuerza (Lunes, Miércoles, Viernes)
    final gymDates = <String>{};
    for (int d = 1; d <= today; d++) {
      final dt = DateTime(year, month, d);
      if ([1, 3, 5].contains(dt.weekday)) {
        if (d != today || d % 2 == 1) {
          gymDates.add(fmt(d));
        }
      }
    }
    final gymHabit = Habit(
      id: 'demo_gym',
      name: 'Entrenamiento Fuerza',
      colorValue: 0xFFE5989B,
      targetDays: 12,
      orderIndex: 1,
      activeWeekdays: [1, 3, 5],
      completedDates: gymDates,
    );

    // 2. Lectura Técnica (diario)
    final readDates = <String>{};
    for (int d = 1; d <= today; d++) {
      if (d % 4 != 0) {
        readDates.add(fmt(d));
      }
    }
    final readingHabit = Habit(
      id: 'demo_reading',
      name: 'Lectura Técnica',
      colorValue: 0xFFB5A6C9,
      targetDays: 25,
      orderIndex: 2,
      activeWeekdays: [1, 2, 3, 4, 5, 6, 7],
      completedDates: readDates,
    );

    // 3. Hidratación (numérico, 2000 ml)
    final waterDates = <String>{};
    final waterProgress = <String, int>{};
    for (int d = 1; d <= today; d++) {
      final val = (d % 3 == 0) ? 1500 : 2000;
      waterProgress[fmt(d)] = val;
      if (val >= 2000) {
        waterDates.add(fmt(d));
      }
    }
    final waterHabit = Habit(
      id: 'demo_water',
      name: 'Hidratación',
      colorValue: 0xFF9EA1D4,
      targetDays: 28,
      orderIndex: 3,
      isNumeric: true,
      dailyTarget: 2000,
      dailyUnit: 'ml',
      dailyProgress: waterProgress,
      completedDates: waterDates,
    );

    return (
      habits: [workHabit, gymHabit, readingHabit, waterHabit],
      blocks: [morningBlock, afternoonBlock, nightBlock],
    );
  }
}

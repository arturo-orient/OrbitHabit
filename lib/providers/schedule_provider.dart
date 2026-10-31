import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/schedule_block.dart';
import 'habit_provider.dart';

class ScheduleNotifier extends Notifier<List<ScheduleBlock>> {
  static const String _storageKey = 'schedule_blocks';

  @override
  List<ScheduleBlock> build() {
    final db = ref.read(databaseProvider);
    final rawList = db.getSetting(_storageKey);

    if (rawList == null) {
      return const [];
    }

    try {
      if (rawList is List) {
        final list = rawList
            .map((item) => ScheduleBlock.fromMap(Map<dynamic, dynamic>.from(item as Map)))
            .where((b) => !b.id.startsWith('default_'))
            .toList();
        return list;
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  Future<void> _persist() async {
    final db = ref.read(databaseProvider);
    final serialized = state.map((b) => b.toMap()).toList();
    await db.saveSetting(_storageKey, serialized);
  }

  Future<void> replaceAllBlocks(List<ScheduleBlock> blocks) async {
    state = blocks;
    await _persist();
  }

  Future<void> addBlock(ScheduleBlock block) async {
    state = [...state, block];
    await _persist();
  }

  Future<void> updateBlock(ScheduleBlock updated) async {
    state = [
      for (final b in state)
        if (b.id == updated.id) updated else b,
    ];
    await _persist();
  }

  Future<void> syncDateWithHabit(String habitId, String dateIso, bool isCompleted) async {
    final matchingBlocks = state.where((b) => b.habitId == habitId).toList();
    if (matchingBlocks.isEmpty) return;

    if (!isCompleted) {
      state = [
        for (final b in state)
          if (b.habitId == habitId)
            b.copyWith(
              completedDates: b.completedDates.where((d) => d != dateIso).toList(),
            )
          else
            b,
      ];
      await _persist();
      return;
    }

    // isCompleted == true:
    // a) Comprueba si ya existe algún bloque con b.habitId == habitId que ya tenga dateIso en completedDates.
    final alreadyCompleted = matchingBlocks.any((b) => b.completedDates.contains(dateIso));
    if (alreadyCompleted) return;

    // b) Si no existe, busca el bloque con b.habitId == habitId que tenga dateIso en assignedDates.
    ScheduleBlock? targetBlock;
    for (final b in matchingBlocks) {
      if (b.assignedDates.contains(dateIso)) {
        targetBlock = b;
        break;
      }
    }

    // c) Si ninguno lo tiene en assignedDates, busca el primero cuyo daysOfWeek contenga DateTime.tryParse(dateIso)?.weekday.
    if (targetBlock == null) {
      final weekday = DateTime.tryParse(dateIso)?.weekday;
      if (weekday != null) {
        for (final b in matchingBlocks) {
          if (b.daysOfWeek.contains(weekday)) {
            targetBlock = b;
            break;
          }
        }
      }
    }

    // d) Como fallback final si ninguno coincide, toma únicamente el primer bloque de la lista con b.habitId == habitId.
    targetBlock ??= matchingBlocks.first;

    // e) Añade dateIso a completedDates ÚNICAMENTE en ese bloque objetivo y persiste.
    final targetId = targetBlock.id;
    state = [
      for (final b in state)
        if (b.id == targetId)
          b.copyWith(
            completedDates: b.completedDates.contains(dateIso)
                ? b.completedDates
                : [...b.completedDates, dateIso],
          )
        else
          b,
    ];
    await _persist();
  }

  Future<void> toggleDateForBlock(String blockId, String dateIso) async {
    String? linkedHabitId;

    state = [
      for (final b in state)
        if (b.id == blockId) ...[
          (() {
            linkedHabitId = b.habitId;
            final isDone = b.completedDates.contains(dateIso);
            return b.copyWith(
              completedDates: isDone
                  ? (List<String>.from(b.completedDates)..remove(dateIso))
                  : (List<String>.from(b.completedDates)..add(dateIso)),
            );
          })()
        ] else
          b,
    ];
    await _persist();

    if (linkedHabitId != null) {
      final habits = ref.read(habitsProvider);
      final habitIndex = habits.indexWhere((h) => h.id == linkedHabitId);
      if (habitIndex != -1) {
        final habit = habits[habitIndex];
        final newDates = Set<String>.from(habit.completedDates);
        final anyBlockStillCompleted = state.any((b) => b.habitId == linkedHabitId && b.completedDates.contains(dateIso));
        if (anyBlockStillCompleted) {
          newDates.add(dateIso);
        } else {
          newDates.remove(dateIso);
        }
        await ref.read(habitsProvider.notifier).updateHabit(habit.copyWith(completedDates: newDates));
      }
    }
  }

  /// Actualiza en una sola transición todos los bloques laborales para vincularlos al hábito objetivo
  Future<void> relinkWorkBlocksToHabit(String targetHabitId) async {
    state = [
      for (final b in state)
        if (b.hasMonthlyHourTarget ||
            b.title.toLowerCase().contains('trabaj') ||
            b.title.toLowerCase().contains('turno'))
          b.copyWith(habitId: targetHabitId)
        else
          b,
    ];
    await _persist();
  }

  /// Elimina los bloques vinculados a un hábito eliminado para no dejar huérfanos
  Future<void> unlinkHabitFromBlocks(String deletedHabitId) async {
    state = state.where((b) => b.habitId != deletedHabitId).toList();
    await _persist();
  }

  /// Asigna o desasigna un turno a una fecha ISO (YYYY-MM-DD)
  Future<void> toggleShiftOnDate(String blockId, String dateIso) async {
    state = [
      for (final b in state)
        if (b.id == blockId)
          b.copyWith(
            assignedDates: b.assignedDates.contains(dateIso)
                ? (List<String>.from(b.assignedDates)..remove(dateIso))
                : (List<String>.from(b.assignedDates)..add(dateIso)),
          )
        else
          b.copyWith(
            assignedDates: List<String>.from(b.assignedDates)..remove(dateIso),
          ),
    ];
    await _persist();
  }

  /// Limpia cualquier turno asignado en una fecha concreta
  Future<void> clearShiftOnDate(String dateIso) async {
    state = [
      for (final b in state)
        b.copyWith(
          assignedDates: List<String>.from(b.assignedDates)..remove(dateIso),
        ),
    ];
    await _persist();
  }

  /// Asigna un turno a múltiples fechas a la vez
  Future<void> batchAssignShift(String blockId, List<String> datesIso) async {
    state = [
      for (final b in state)
        if (b.id == blockId)
          b.copyWith(
            assignedDates: (Set<String>.from(b.assignedDates)..addAll(datesIso)).toList(),
          )
        else
          b.copyWith(
            assignedDates: b.assignedDates.where((d) => !datesIso.contains(d)).toList(),
          ),
    ];
    await _persist();
  }

  Future<void> addExtraHours(String blockId, double hours) async {
    state = [
      for (final b in state)
        if (b.id == blockId)
          b.copyWith(extraHours: (b.extraHours + hours).clamp(0.0, 500.0))
        else
          b,
    ];
    await _persist();
  }

  Future<void> deleteBlock(String id) async {
    state = state.where((b) => b.id != id).toList();
    await _persist();
  }

  Future<void> reorderBlocks(int oldIndex, int newIndex) async {
    final list = [...state];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _persist();
  }
}

final scheduleProvider = NotifierProvider<ScheduleNotifier, List<ScheduleBlock>>(() {
  return ScheduleNotifier();
});

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
    state = [
      for (final b in state)
        if (b.habitId == habitId)
          b.copyWith(
            completedDates: isCompleted
                ? (b.completedDates.contains(dateIso)
                    ? b.completedDates
                    : [...b.completedDates, dateIso])
                : (b.completedDates.where((d) => d != dateIso).toList()),
          )
        else
          b,
    ];
    await _persist();
  }

  Future<void> toggleDateForBlock(String blockId, String dateIso) async {
    String? linkedHabitId;
    bool isNowDone = false;

    state = [
      for (final b in state)
        if (b.id == blockId) ...[
          (() {
            linkedHabitId = b.habitId;
            final isDone = b.completedDates.contains(dateIso);
            isNowDone = !isDone;
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
        if (isNowDone) {
          newDates.add(dateIso);
        } else {
          newDates.remove(dateIso);
        }
        await ref.read(habitsProvider.notifier).updateHabit(habit.copyWith(completedDates: newDates));
      }
    }
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

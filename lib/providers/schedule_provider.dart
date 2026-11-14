import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/habit.dart';
import '../domain/models/schedule_block.dart';
import '../services/notification_service.dart';
import 'habit_provider.dart';
import 'settings_provider.dart';

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
    Future.microtask(() async {
      try {
        final habits = ref.read(habitsProvider);
        final settings = ref.read(settingsProvider);
        await NotificationService().syncAllTaskReminders(
          habits: habits,
          blocks: state,
          globalEnabled: settings.notificationsEnabled,
          postActivityReminderEnabled: settings.postActivityReminderEnabled,
          vacationDates: settings.vacationDates.toSet(),
          dailyHour: settings.notificationHour,
          dailyMinute: settings.notificationMinute,
        );
      } catch (_) {}
    });
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

  bool _blockMatchesHabit(ScheduleBlock b, Habit? habit, String habitId) {
    if (b.habitId == habitId) return true;
    if (b.habitId != null || habit == null) return false;
    final hName = habit.name.trim().toLowerCase();
    final bTitle = b.title.trim().toLowerCase();
    if (hName == bTitle) return true;
    if (hName.contains('trabaj') && bTitle.contains('trabaj')) return true;
    if (hName.contains('turno') && bTitle.contains('turno')) return true;
    return false;
  }

  Habit? _findHabitForBlock(ScheduleBlock block, List<Habit> habits) {
    if (block.habitId != null) {
      final exact = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == block.habitId,
            orElse: () => null,
          );
      if (exact != null) return exact;
    }
    final bTitle = block.title.trim().toLowerCase();
    return habits.cast<Habit?>().firstWhere(
          (h) =>
              h != null &&
              (h.name.trim().toLowerCase() == bTitle ||
                  (h.name.toLowerCase().contains('trabaj') && bTitle.contains('trabaj')) ||
                  (h.name.toLowerCase().contains('turno') && bTitle.contains('turno'))),
          orElse: () => null,
        );
  }

  Future<void> syncDateWithHabit(String habitId, String dateIso, bool isCompleted) async {
    Habit? targetHabit;
    try {
      final habits = ref.read(habitsProvider);
      targetHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == habitId,
            orElse: () => null,
          );
    } catch (_) {}

    final matchingBlocks =
        state.where((b) => _blockMatchesHabit(b, targetHabit, habitId)).toList();
    if (matchingBlocks.isEmpty) return;

    if (!isCompleted) {
      state = [
        for (final b in state)
          if (_blockMatchesHabit(b, targetHabit, habitId))
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
    // a) Comprueba si ya existe algún bloque vinculado que ya tenga dateIso en completedDates.
    final alreadyCompleted = matchingBlocks.any((b) => b.completedDates.contains(dateIso));
    if (alreadyCompleted) return;

    // b) Si no existe, busca el bloque vinculado que tenga dateIso en assignedDates.
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

    // d) Como fallback final si ninguno coincide, toma únicamente el primer bloque vinculado.
    targetBlock ??= matchingBlocks.first;

    // e) Añade dateIso SOLO a completedDates (NUNCA a assignedDates para evitar siluetas fantasma).
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

  /// Alias explícito para marcar/desmarcar la ejecución de un turno/bloque en un día concreto.
  Future<void> toggleShiftCompletion(String blockId, String dateIso) {
    return toggleDateForBlock(blockId, dateIso);
  }

  Future<void> toggleDateForBlock(String blockId, String dateIso) async {
    ScheduleBlock? toggledBlock;

    state = [
      for (final b in state)
        if (b.id == blockId) ...[
          (() {
            final isDone = b.completedDates.contains(dateIso);
            // Marcar/desmarcar completado NUNCA modifica assignedDates.
            final updated = b.copyWith(
              completedDates: isDone
                  ? (List<String>.from(b.completedDates)..remove(dateIso))
                  : (List<String>.from(b.completedDates)..add(dateIso)),
            );
            toggledBlock = updated;
            return updated;
          })()
        ] else
          b,
    ];
    await _persist();

    if (toggledBlock != null) {
      final habits = ref.read(habitsProvider);
      final linkedHabit = _findHabitForBlock(toggledBlock!, habits);
      if (linkedHabit != null) {
        final newDates = Set<String>.from(linkedHabit.completedDates);
        final anyBlockStillCompleted = state.any(
          (b) => _blockMatchesHabit(b, linkedHabit, linkedHabit.id) && b.completedDates.contains(dateIso),
        );
        if (anyBlockStillCompleted) {
          newDates.add(dateIso);
        } else {
          newDates.remove(dateIso);
        }
        await ref.read(habitsProvider.notifier).updateHabit(linkedHabit.copyWith(completedDates: newDates));
      }
    }
  }

  /// Desmarca un día concreto en un conjunto de bloques (y en su hábito vinculado si procede) sin tocar assignedDates.
  Future<void> clearCompletedDateForBlocks(
    List<String> blockIds,
    String dateIso, {
    String? linkedHabitId,
  }) async {
    final targetIds = blockIds.toSet();
    state = [
      for (final b in state)
        if (targetIds.contains(b.id) && b.completedDates.contains(dateIso))
          b.copyWith(
            completedDates: b.completedDates.where((d) => d != dateIso).toList(),
          )
        else
          b,
    ];
    await _persist();

    final habits = ref.read(habitsProvider);
    Habit? targetHabit;
    if (linkedHabitId != null) {
      targetHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == linkedHabitId,
            orElse: () => null,
          );
    } else if (blockIds.isNotEmpty) {
      final sampleBlock = state.cast<ScheduleBlock?>().firstWhere(
            (b) => b != null && targetIds.contains(b.id),
            orElse: () => null,
          );
      if (sampleBlock != null) {
        targetHabit = _findHabitForBlock(sampleBlock, habits);
      }
    }

    if (targetHabit != null) {
      final anyBlockStillCompleted = state.any(
        (b) => _blockMatchesHabit(b, targetHabit, targetHabit!.id) && b.completedDates.contains(dateIso),
      );
      if (!anyBlockStillCompleted && targetHabit.completedDates.contains(dateIso)) {
        final newDates = Set<String>.from(targetHabit.completedDates)..remove(dateIso);
        await ref.read(habitsProvider.notifier).updateHabit(targetHabit.copyWith(completedDates: newDates));
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

  /// Limpia fechas históricas clonadas por versiones anteriores entre turnos de un mismo hábito
  /// para que cada día completado del pasado solo cuente en el turno principal y no duplique horas.
  Future<void> deduplicateClonedShiftDates() async {
    final byHabit = <String, List<ScheduleBlock>>{};
    for (final b in state) {
      if (b.habitId != null && b.habitId!.isNotEmpty) {
        byHabit.putIfAbsent(b.habitId!, () => []).add(b);
      }
    }

    bool changed = false;
    final updatedById = <String, ScheduleBlock>{};

    for (final entry in byHabit.entries) {
      final group = entry.value;
      if (group.length <= 1) continue;

      final primary = group.first;
      final primaryDates = <String>{
        ...primary.completedDates,
        ...primary.assignedDates,
      };
      if (primaryDates.isEmpty) continue;

      for (int i = 1; i < group.length; i++) {
        final secondary = group[i];
        final filteredCompleted = secondary.completedDates
            .where((d) => !primaryDates.contains(d))
            .toList();
        final filteredAssigned = secondary.assignedDates
            .where((d) => !primaryDates.contains(d))
            .toList();

        if (filteredCompleted.length != secondary.completedDates.length ||
            filteredAssigned.length != secondary.assignedDates.length) {
          changed = true;
          updatedById[secondary.id] = secondary.copyWith(
            completedDates: filteredCompleted,
            assignedDates: filteredAssigned,
          );
        }
      }
    }

    if (changed) {
      state = [
        for (final b in state) updatedById[b.id] ?? b,
      ];
      await _persist();
    }
  }

  /// Asigna o desasigna un turno a una fecha ISO (YYYY-MM-DD) preservando otros turnos del mismo día
  Future<void> toggleShiftOnDate(String blockId, String dateIso) async {
    state = [
      for (final b in state)
        if (b.id == blockId)
          (() {
            final isAssigned = b.assignedDates.contains(dateIso);
            return b.copyWith(
              assignedDates: isAssigned
                  ? (List<String>.from(b.assignedDates)..remove(dateIso))
                  : (List<String>.from(b.assignedDates)..add(dateIso)),
              completedDates: isAssigned
                  ? (List<String>.from(b.completedDates)..remove(dateIso))
                  : b.completedDates,
            );
          })()
        else
          b,
    ];
    await _persist();
  }

  /// Limpia cualquier turno asignado en una fecha concreta
  Future<void> clearShiftOnDate(String dateIso) async {
    state = [
      for (final b in state)
        b.copyWith(
          assignedDates: List<String>.from(b.assignedDates)..remove(dateIso),
          completedDates: List<String>.from(b.completedDates)..remove(dateIso),
        ),
    ];
    await _persist();
  }

  /// Asigna un turno a múltiples fechas a la vez preservando otros turnos en esas fechas
  Future<void> batchAssignShift(String blockId, List<String> datesIso) async {
    state = [
      for (final b in state)
        if (b.id == blockId)
          b.copyWith(
            assignedDates: (Set<String>.from(b.assignedDates)..addAll(datesIso)).toList(),
          )
        else
          b,
    ];
    await _persist();
  }

  Future<void> addExtraHours(String blockId, double hours, [DateTime? targetMonth]) async {
    final month = targetMonth ?? DateTime.now();
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    state = [
      for (final b in state)
        if (b.id == blockId)
          (() {
            final currentMap = Map<String, double>.from(b.monthlyExtraHours);
            final currentHours = currentMap[key] ?? (currentMap.isEmpty ? b.extraHours : 0.0);
            final updatedHours = (currentHours + hours).clamp(0.0, 500.0);
            currentMap[key] = updatedHours;
            return b.copyWith(
              monthlyExtraHours: currentMap,
              extraHours: updatedHours,
            );
          })()
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

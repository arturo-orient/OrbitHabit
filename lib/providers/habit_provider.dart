import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/habit.dart';
import '../data/database_service.dart';
import '../services/widget_service.dart';

import 'schedule_provider.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('DatabaseService should be overridden in main');
});

class HabitNotifier extends Notifier<List<Habit>> {
  @override
  List<Habit> build() {
    // Inicializa leyendo de la base de datos y ordena
    final habits = ref.read(databaseProvider).getAllHabits();
    habits.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    // Notificamos al widget al iniciar por si algo cambió en background o reseteo
    Future.microtask(() => WidgetService.updateWidget(habits));
    return habits;
  }

  Future<void> replaceAllHabits(List<Habit> habits) async {
    final sorted = List<Habit>.from(habits)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    await ref.read(databaseProvider).replaceAllHabits(sorted);
    state = sorted;
    WidgetService.updateWidget(state);
  }

  Future<void> addHabit(Habit habit) async {
    // Asigna el orderIndex al final de la lista
    final newHabit = habit.copyWith(orderIndex: state.length);
    await ref.read(databaseProvider).saveHabit(newHabit);
    state = [...state, newHabit];
    WidgetService.updateWidget(state);
  }

  Future<void> updateHabit(Habit habit) async {
    await ref.read(databaseProvider).saveHabit(habit);
    final newState = [
      for (final h in state)
        if (h.id == habit.id) habit else h
    ];
    newState.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    state = newState;
    WidgetService.updateWidget(state);
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final habits = List<Habit>.from(state);
    final item = habits.removeAt(oldIndex);
    habits.insert(newIndex, item);
    
    // Update orderIndex for all and save to DB
    final db = ref.read(databaseProvider);
    for (int i = 0; i < habits.length; i++) {
      final updatedHabit = habits[i].copyWith(orderIndex: i);
      habits[i] = updatedHabit;
      await db.saveHabit(updatedHabit); // Fire and forget can be risky but fine for MVP. Let's await.
    }
    
    state = habits;
    WidgetService.updateWidget(state);
  }

  Future<void> deleteHabit(String id) async {
    await ref.read(databaseProvider).deleteHabit(id);
    state = state.where((h) => h.id != id).toList();
    WidgetService.updateWidget(state);
    try {
      await ref.read(scheduleProvider.notifier).unlinkHabitFromBlocks(id);
    } catch (_) {}
  }

  Future<void> toggleDay(String habitId, String dateIso) async {
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    
    final habit = state[habitIndex];
    final newDates = Set<String>.from(habit.completedDates);
    final isAdding = !newDates.contains(dateIso);
    if (isAdding) {
      newDates.add(dateIso);
    } else {
      newDates.remove(dateIso);
    }
    await updateHabit(habit.copyWith(completedDates: newDates));

    try {
      ref.read(scheduleProvider.notifier).syncDateWithHabit(habitId, dateIso, isAdding);
    } catch (_) {}
  }

  Future<void> updateProgress(String habitId, String dateIso, int delta) async {
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    
    final habit = state[habitIndex];
    if (!habit.isNumeric) return; 
    
    final wasCompleted = habit.completedDates.contains(dateIso);

    final currentProgress = habit.dailyProgress[dateIso] ?? 0;
    final newProgress = (currentProgress + delta).clamp(0, 9999);
    
    final newDailyProgressMap = Map<String, int>.from(habit.dailyProgress);
    newDailyProgressMap[dateIso] = newProgress;
    
    final isNowCompleted = newProgress >= habit.dailyTarget;
    final newDates = Set<String>.from(habit.completedDates);
    if (isNowCompleted) {
      newDates.add(dateIso);
    } else {
      newDates.remove(dateIso);
    }
    
    await updateHabit(habit.copyWith(
      dailyProgress: newDailyProgressMap,
      completedDates: newDates,
    ));

    if (wasCompleted != isNowCompleted) {
      try {
        await ref.read(scheduleProvider.notifier).syncDateWithHabit(habitId, dateIso, isNowCompleted);
      } catch (_) {}
    }
  }

  /// Unifica hábitos duplicados de turnos de trabajo bajo un solo hábito madre
  Future<void> consolidateWorkHabits(List<dynamic> rawBlocks) async {
    final habits = List<Habit>.from(state);
    final workHabits = habits.where((h) {
      final name = h.name.toLowerCase();
      return name.contains('trabaj') || name.contains('turno');
    }).toList();

    if (workHabits.length > 1) {
      final primary = workHabits.firstWhere(
        (h) => h.completedDates.isNotEmpty,
        orElse: () => workHabits.first,
      );

      final Set<String> mergedDates = {};
      for (final wh in workHabits) {
        mergedDates.addAll(wh.completedDates);
      }

      final unifiedHabit = primary.copyWith(
        name: 'Trabajar',
        completedDates: mergedDates,
      );

      final db = ref.read(databaseProvider);
      await db.saveHabit(unifiedHabit);

      for (final wh in workHabits) {
        if (wh.id != primary.id) {
          await db.deleteHabit(wh.id);
        }
      }

      final newHabits = habits
          .where((h) => h.id == primary.id || !workHabits.any((wh) => wh.id == h.id))
          .map((h) => h.id == primary.id ? unifiedHabit : h)
          .toList();
      state = newHabits;

      try {
        await ref.read(scheduleProvider.notifier).relinkWorkBlocksToHabit(primary.id);
      } catch (_) {}
    }
  }

  void resetState() {
    state = const [];
  }
}

final habitsProvider = NotifierProvider<HabitNotifier, List<Habit>>(() {
  return HabitNotifier();
});

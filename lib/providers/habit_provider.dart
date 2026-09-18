import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/habit.dart';
import '../data/database_service.dart';
import '../services/widget_service.dart';

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
  }

  Future<void> toggleDay(String habitId, String dateIso) async {
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    
    final habit = state[habitIndex];
    final newDates = Set<String>.from(habit.completedDates);
    if (newDates.contains(dateIso)) {
      newDates.remove(dateIso);
    } else {
      newDates.add(dateIso);
    }
    await updateHabit(habit.copyWith(completedDates: newDates));
  }

  Future<void> updateProgress(String habitId, String dateIso, int delta) async {
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    
    final habit = state[habitIndex];
    if (!habit.isNumeric) return; 
    
    final currentProgress = habit.dailyProgress[dateIso] ?? 0;
    final newProgress = (currentProgress + delta).clamp(0, 9999);
    
    final newDailyProgressMap = Map<String, int>.from(habit.dailyProgress);
    newDailyProgressMap[dateIso] = newProgress;
    
    final newDates = Set<String>.from(habit.completedDates);
    if (newProgress >= habit.dailyTarget) {
      newDates.add(dateIso);
    } else {
      newDates.remove(dateIso);
    }
    
    await updateHabit(habit.copyWith(
      dailyProgress: newDailyProgressMap,
      completedDates: newDates,
    ));
  }

  void resetState() {
    state = const [];
  }
}

final habitsProvider = NotifierProvider<HabitNotifier, List<Habit>>(() {
  return HabitNotifier();
});

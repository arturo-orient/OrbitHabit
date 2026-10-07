import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/schedule_block.dart';
import 'habit_provider.dart';

class ScheduleNotifier extends Notifier<List<ScheduleBlock>> {
  static const String _storageKey = 'schedule_blocks';

  @override
  List<ScheduleBlock> build() {
    final db = ref.read(databaseProvider);
    final rawList = db.getSetting(_storageKey);

    if (rawList == null || (rawList is List && rawList.isEmpty)) {
      // Default initial schedule template (especially tailored for night-shift & healthy habit rhythm)
      return _defaultSchedule();
    }

    try {
      if (rawList is List) {
        return rawList
            .map((item) => ScheduleBlock.fromMap(Map<dynamic, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback
    }
    return _defaultSchedule();
  }

  static List<ScheduleBlock> _defaultSchedule() {
    return [
      const ScheduleBlock(
        id: 'default_work',
        title: 'Trabajo Nocturno',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4, // Periwinkle
        daysOfWeek: [1, 2, 3, 4, 5], // Lunes a Viernes
      ),
      const ScheduleBlock(
        id: 'default_gym',
        title: 'Entrenamiento / Gym',
        startHour: 8,
        startMinute: 0,
        endHour: 9,
        endMinute: 30,
        colorValue: 0xFF84A59D, // Verde Salvia
        daysOfWeek: [1, 2, 3, 4, 5, 6],
      ),
      const ScheduleBlock(
        id: 'default_sleep',
        title: 'Descanso & Sueño',
        startHour: 10,
        startMinute: 30,
        endHour: 17,
        endMinute: 30,
        colorValue: 0xFFB5A6C9, // Azul Lavanda
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      ),
    ];
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

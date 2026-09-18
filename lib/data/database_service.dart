import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/habit.dart';

class DatabaseService {
  static const String _habitsBoxName = 'habits_box';
  static const String _settingsBoxName = 'settings_box';
  
  late Box<Habit> _habitsBox;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(HabitAdapter());
    _habitsBox = await Hive.openBox<Habit>(_habitsBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  Future<void> saveHabit(Habit habit) async {
    await _habitsBox.put(habit.id, habit);
  }

  Future<void> deleteHabit(String id) async {
    await _habitsBox.delete(id);
  }

  List<Habit> getAllHabits() {
    try {
      final habits = _habitsBox.values.toList();
      return habits;
    } catch (e) {
      _habitsBox.clear();
      return [];
    }
  }

  // --- App Settings Box Helpers ---
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> wipeAllData() async {
    await _habitsBox.clear();
    await _settingsBox.clear();
  }
}

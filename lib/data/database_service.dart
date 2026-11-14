import 'package:hive_flutter/hive_flutter.dart';
import '../core/app_version.dart';
import '../domain/models/habit.dart';

class DatabaseService {
  static const String _habitsBoxName = 'habits_box';
  static const String _settingsBoxName = 'settings_box';
  static const String kHasSeenVacationTutorialKey = 'has_seen_vacation_tutorial';
  
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

  Future<void> replaceAllHabits(List<Habit> habits) async {
    await _habitsBox.clear();
    for (final habit in habits) {
      await _habitsBox.put(habit.id, habit);
    }
  }

  // --- App Settings Box Helpers ---
  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> deleteSetting(String key) async {
    await _settingsBox.delete(key);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  String? getLastSeenAppVersion() {
    final val = getSetting(kLastSeenAppVersionKey);
    return val is String ? val : null;
  }

  Future<void> setLastSeenAppVersion(String version) async {
    await saveSetting(kLastSeenAppVersionKey, version);
  }

  bool getHasSeenVacationTutorial() {
    final val = getSetting(kHasSeenVacationTutorialKey);
    return val is bool ? val : false;
  }

  Future<void> setHasSeenVacationTutorial(bool seen) async {
    await saveSetting(kHasSeenVacationTutorialKey, seen);
  }

  Future<void> wipeAllData() async {
    await _habitsBox.clear();
    await _settingsBox.clear();
  }
}

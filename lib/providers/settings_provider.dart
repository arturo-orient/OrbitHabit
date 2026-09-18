import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/user_settings.dart';
import '../services/notification_service.dart';
import 'habit_provider.dart';

class SettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    final db = ref.read(databaseProvider);
    final map = db.getSetting('user_settings');
    if (map == null) {
      return UserSettings.defaultSettings();
    }
    try {
      return UserSettings.fromMap(Map<dynamic, dynamic>.from(map));
    } catch (e) {
      return UserSettings.defaultSettings();
    }
  }

  Future<void> updateSettings(UserSettings newSettings) async {
    state = newSettings;
    final db = ref.read(databaseProvider);
    await db.saveSetting('user_settings', newSettings.toMap());
    
    // Sincronizar alarma diaria con NotificationService
    try {
      await NotificationService().scheduleDailyReminder(
        hour: newSettings.notificationHour,
        minute: newSettings.notificationMinute,
      );
    } catch (e) {
      // Evitamos que falle si se corre en entornos no soportados
    }
  }

  Future<void> resetAppToFactoryDefaults() async {
    final db = ref.read(databaseProvider);
    await db.wipeAllData();
    state = UserSettings.defaultSettings();
    ref.read(habitsProvider.notifier).resetState();
  }

  Future<void> addVacationDates(List<DateTime> dates) async {
    final formatted = dates.map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}').toList();
    final newDates = Set<String>.from(state.vacationDates)..addAll(formatted);
    await updateSettings(state.copyWith(vacationDates: newDates.toList()..sort()));
  }

  Future<void> clearVacationDates() async {
    await updateSettings(state.copyWith(vacationDates: []));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(() {
  return SettingsNotifier();
});

// A simple global notifier to trigger the premium Confetti Celebration (Riverpod 3.x compliant)
class ConfettiNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
}

final confettiStateProvider = NotifierProvider<ConfettiNotifier, bool>(() {
  return ConfettiNotifier();
});

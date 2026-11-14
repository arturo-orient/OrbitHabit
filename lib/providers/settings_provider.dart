import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_version.dart';
import '../domain/models/user_settings.dart';
import '../services/notification_service.dart';
import 'habit_provider.dart';
import 'schedule_provider.dart';

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
    final wasFirstTime = state.isFirstTime;
    state = newSettings;
    final db = ref.read(databaseProvider);
    await db.saveSetting('user_settings', newSettings.toMap());

    // Si acaba de completar el Onboarding por primera vez (instalación limpia),
    // registramos la versión actual como vista para no solapar el modal de novedades.
    if (wasFirstTime && !newSettings.isFirstTime) {
      await db.setLastSeenAppVersion(kCurrentAppVersion);
    }
    
    // Sincronizar alarmas y recordatorios con NotificationService
    try {
      final habits = ref.read(habitsProvider);
      final blocks = ref.read(scheduleProvider);
      await NotificationService().syncAllTaskReminders(
        habits: habits,
        blocks: blocks,
        globalEnabled: newSettings.notificationsEnabled,
        postActivityReminderEnabled: newSettings.postActivityReminderEnabled,
        vacationDates: newSettings.vacationDates.toSet(),
        dailyHour: newSettings.notificationHour,
        dailyMinute: newSettings.notificationMinute,
      );
    } catch (e) {
      // Evitamos que falle si se corre en entornos no soportados
    }
  }

  bool shouldShowReleaseNotes() {
    if (state.isFirstTime) return false;
    final db = ref.read(databaseProvider);
    final lastSeen = db.getLastSeenAppVersion();
    return lastSeen != kCurrentAppVersion;
  }

  Future<void> markReleaseNotesSeen([String version = kCurrentAppVersion]) async {
    final db = ref.read(databaseProvider);
    await db.setLastSeenAppVersion(version);
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

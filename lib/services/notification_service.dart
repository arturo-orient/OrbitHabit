import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../domain/models/habit.dart';
import '../domain/models/schedule_block.dart';

/// Modelo descriptivo para mostrar los recordatorios configurados en Ajustes.
class ActiveTaskReminderInfo {
  final String id;
  final String title;
  final String category; // 'HÁBITO' | 'TURNO / 24H'
  final String scheduleLabel;
  final int colorValue;
  final String? habitId;
  final String? blockId;

  const ActiveTaskReminderInfo({
    required this.id,
    required this.title,
    required this.category,
    required this.scheduleLabel,
    required this.colorValue,
    this.habitId,
    this.blockId,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Icono principal de notificaciones en Android. Protegido del shrinker en `res/raw/keep.xml`.
  static const String _defaultIcon = '@mipmap/ic_launcher';

  static const AndroidNotificationChannel _dailyChannel = AndroidNotificationChannel(
    'daily_reminder_channel',
    'Recordatorio Diario',
    description: 'Recordatorio general diario para completar tus hábitos del día',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _habitChannel = AndroidNotificationChannel(
    'habit_reminders_channel',
    'Recordatorios de Hábitos',
    description: 'Avisos personalizados para cada hábito de tu órbita',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _shiftChannel = AndroidNotificationChannel(
    'shift_reminders_channel',
    'Avisos de Turnos y Horarios',
    description: 'Avisos previos al inicio de tus turnos y bloques 24h',
    importance: Importance.max,
  );
  static const AndroidNotificationChannel _testChannel = AndroidNotificationChannel(
    'test_channel',
    'Pruebas',
    description: 'Avisos de prueba lanzados desde Ajustes',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Future<bool>? _initFuture;
  String? _lastError;

  /// Último error interno (útil para mostrarlo en la UI al probar avisos).
  String? get lastError => _lastError;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _ensureInitialized();
  }

  bool get _isRunningInTest {
    if (Zone.current[#test.declarer] != null) return true;
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      if (bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Inicialización perezosa e idempotente: cualquier método la invoca antes de operar,
  /// de modo que un fallo puntual al arrancar no deja el servicio muerto para siempre.
  Future<bool> _ensureInitialized() {
    if (kIsWeb) return Future.value(false);
    if (_isRunningInTest) {
      _lastError = 'MissingPluginException: test environment';
      return Future.value(false);
    }
    if (_isInitialized) return Future.value(true);
    return _initFuture ??= _doInit().then((ok) {
      if (!ok) _initFuture = null; // permitir reintento en la siguiente llamada
      return ok;
    });
  }

  Future<bool> _doInit() async {
    // 1. Zona horaria (aislada: si falla, usamos un fallback y seguimos).
    try {
      tz.initializeTimeZones();
      String zoneName = 'Europe/Madrid';
      try {
        zoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      } catch (_) {}
      try {
        tz.setLocalLocation(tz.getLocation(zoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Europe/Madrid'));
      }
    } catch (e) {
      _lastError = 'Zona horaria: $e';
    }

    // 2. Plugin nativo.
    try {
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings(_defaultIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      );

      final android = _android;
      if (android != null) {
        for (final channel in const [_dailyChannel, _habitChannel, _shiftChannel, _testChannel]) {
          await android.createNotificationChannel(channel);
        }
      }

      _isInitialized = true;
      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Inicialización: $e';
      return false;
    }
  }

  /// Solicita el permiso de notificaciones (Android 13+) y, solo si hace falta,
  /// el de alarmas exactas (Android 12+/14+).
  Future<bool> requestPermissions({bool includeExactAlarms = true}) async {
    if (kIsWeb) return false;
    if (!await _ensureInitialized()) return false;
    try {
      final android = _android;
      if (android == null) return true;
      final notifGranted = await android.requestNotificationsPermission() ?? true;
      if (includeExactAlarms) {
        final canExact = await android.canScheduleExactNotifications() ?? true;
        if (!canExact) {
          await android.requestExactAlarmsPermission();
        }
      }
      return notifGranted;
    } catch (e) {
      _lastError = 'Permisos: $e';
      return false;
    }
  }

  /// Consulta el estado real de permisos de notificaciones y alarmas exactas en Android.
  Future<({bool notificationsEnabled, bool exactAlarmsPermitted})> getPermissionStatus() async {
    if (kIsWeb) {
      return (notificationsEnabled: false, exactAlarmsPermitted: false);
    }
    final ready = await _ensureInitialized();
    if (!ready) {
      // En tests unitarios sin plugin nativo devolvemos estado operativo seguro sin bloquear UI.
      final missingPlugin = (_lastError ?? '').contains('MissingPluginException');
      return (
        notificationsEnabled: missingPlugin,
        exactAlarmsPermitted: false,
      );
    }
    try {
      final android = _android;
      if (android == null) {
        return (notificationsEnabled: true, exactAlarmsPermitted: true);
      }
      final enabled = await android.areNotificationsEnabled() ?? true;
      final canExact = await android.canScheduleExactNotifications() ?? false;
      return (notificationsEnabled: enabled, exactAlarmsPermitted: canExact);
    } catch (_) {
      return (notificationsEnabled: true, exactAlarmsPermitted: false);
    }
  }

  /// Usa alarmas exactas si el sistema lo permite; si no, cae a inexactas sin fallar.
  Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      final canExact = await _android?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  NotificationDetails _detailsFor(AndroidNotificationChannel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: _defaultIcon,
        enableVibration: true,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final preferredMode = await _scheduleMode();
    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: preferredMode,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      if (preferredMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        try {
          await _notificationsPlugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: matchDateTimeComponents,
          );
          return;
        } catch (fallbackErr) {
          _lastError = 'Aviso $id (fallback): $fallbackErr';
          return;
        }
      }
      _lastError = 'Aviso $id: $e';
    }
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!await _ensureInitialized()) return;

    try {
      await _notificationsPlugin.cancel(id: 0);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _safeZonedSchedule(
        id: 0,
        title: 'Es hora de orbitar',
        body: 'Entra a OrbitHabit y marca tus logros de hoy.',
        scheduledDate: scheduledDate,
        notificationDetails: _detailsFor(_dailyChannel),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      _lastError = 'Aviso diario: $e';
    }
  }

  String _isoDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Sincronizador determinista de 2 tipos:
  /// Tipo A) Por hábito (`DateTimeComponents.time` o `DateTimeComponents.dayOfWeekAndTime`)
  /// Tipo B) Post-actividad +10 min en modo 24H para los próximos 14 días.
  Future<void> syncAllTaskReminders({
    required List<Habit> habits,
    required List<ScheduleBlock> blocks,
    required bool globalEnabled,
    bool postActivityReminderEnabled = true,
    Set<String> vacationDates = const {},
    int? dailyHour,
    int? dailyMinute,
  }) async {
    if (!await _ensureInitialized()) return;

    try {
      await _notificationsPlugin.cancelAll();

      if (!globalEnabled) {
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      final todayIso = _isoDate(now);
      final habitDetails = _detailsFor(_habitChannel);
      final shiftDetails = _detailsFor(_shiftChannel);

      // Nivel 2: Recordatorios por Hábito (hora exacta elegida + días activos)
      for (final habit in habits) {
        if (!habit.hasReminder || habit.reminderHour == null) continue;

        final rHour = habit.reminderHour!;
        final rMinute = habit.reminderMinute ?? 0;
        final baseId = (habit.id.hashCode.abs() % 80000) * 10 + 1000;
        final bodyText = habit.subTasks.isNotEmpty
            ? 'Tienes ${habit.subTasks.length} pasos preparados para hoy.'
            : 'Toca para registrar tu progreso en tu órbita.';
        final isEveryDay =
            habit.activeWeekdays.isEmpty || habit.activeWeekdays.toSet().length >= 7;

        if (isEveryDay) {
          var scheduledDate = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            rHour,
            rMinute,
          );
          if (!scheduledDate.isAfter(now) ||
              habit.completedDates.contains(todayIso) ||
              vacationDates.contains(todayIso)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }
          // Evitar empezar en un día marcado como vacaciones (máx 14 días)
          for (int guard = 0; guard < 14; guard++) {
            final iso = _isoDate(scheduledDate);
            if (!vacationDates.contains(iso)) break;
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          await _safeZonedSchedule(
            id: baseId,
            title: 'Recordatorio · ${habit.name}',
            body: bodyText,
            scheduledDate: scheduledDate,
            notificationDetails: habitDetails,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } else {
          final uniqueWeekdays = habit.activeWeekdays.where((w) => w >= 1 && w <= 7).toSet();
          for (final weekday in uniqueWeekdays) {
            int deltaDays = (weekday - now.weekday + 7) % 7;
            var scheduledDate = tz.TZDateTime(
              tz.local,
              now.year,
              now.month,
              now.day + deltaDays,
              rHour,
              rMinute,
            );
            final firstIso = _isoDate(scheduledDate);
            final skipToday = deltaDays == 0 &&
                (habit.completedDates.contains(todayIso) || vacationDates.contains(firstIso));
            if (!scheduledDate.isAfter(now) || skipToday) {
              scheduledDate = scheduledDate.add(const Duration(days: 7));
            }

            await _safeZonedSchedule(
              id: baseId + weekday,
              title: 'Recordatorio · ${habit.name}',
              body: bodyText,
              scheduledDate: scheduledDate,
              notificationDetails: habitDetails,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          }
        }
      }

      // Nivel 3: Recordatorio Post-Actividad (+10 min tras finalizar en Modo 24H)
      if (postActivityReminderEnabled) {
        final habitById = <String, Habit>{for (final h in habits) h.id: h};

        for (final block in blocks) {
          if (!block.hasReminder) continue;

          final baseId = (block.id.hashCode.abs() % 80000) * 20 + 1000000;
          final linkedHabit =
              block.habitId != null ? habitById[block.habitId!] : null;

          // Empezamos desde ayer (-1) para cubrir turnos nocturnos iniciados ayer que acaban hoy.
          for (int dayOffset = -1; dayOffset < 14; dayOffset++) {
            final targetDay = DateTime(now.year, now.month, now.day + dayOffset);
            final dateIso = _isoDate(targetDay);

            final bool isAlreadyCompleted = block.completedDates.contains(dateIso) ||
                (linkedHabit != null && linkedHabit.completedDates.contains(dateIso));
            if (isAlreadyCompleted || vacationDates.contains(dateIso)) {
              continue;
            }

            final bool appliesOnDay = block.assignedDates.isNotEmpty
                ? block.assignedDates.contains(dateIso)
                : block.daysOfWeek.contains(targetDay.weekday);

            if (!appliesOnDay) continue;

            final endDay = block.isOvernight
                ? DateTime(targetDay.year, targetDay.month, targetDay.day + 1)
                : targetDay;
            final shiftEnd = tz.TZDateTime(
              tz.local,
              endDay.year,
              endDay.month,
              endDay.day,
              block.endHour,
              block.endMinute,
            );
            final notifyAt = shiftEnd.add(const Duration(minutes: 10));

            if (!notifyAt.isAfter(now)) continue;

            await _safeZonedSchedule(
              id: baseId + dayOffset + 1,
              title: '✓ ¿Completaste "${block.title}"?',
              body:
                  'Ha terminado tu horario (${block.formattedTimeRange}). Toca para registrarlo en tu órbita.',
              scheduledDate: notifyAt,
              notificationDetails: shiftDetails,
            );
          }
        }
      }
    } catch (e) {
      _lastError = 'Sincronización: $e';
    }
  }

  /// Devuelve la hora formateada HH:MM del aviso post-actividad (+10 min tras finalizar).
  static String formatPostActivityTime(ScheduleBlock block) {
    final totalMin = (block.endHour * 60 + block.endMinute + 10) % 1440;
    final hh = (totalMin ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMin % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Devuelve el resumen estructurado de todos los recordatorios por hábito y por turno activos.
  List<ActiveTaskReminderInfo> buildActiveRemindersList({
    required List<Habit> habits,
    required List<ScheduleBlock> blocks,
  }) {
    const dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final List<ActiveTaskReminderInfo> items = [];

    for (final habit in habits) {
      if (!habit.hasReminder || habit.reminderHour == null) continue;
      final hh = habit.reminderHour!.toString().padLeft(2, '0');
      final mm = (habit.reminderMinute ?? 0).toString().padLeft(2, '0');
      final daysLabel = (habit.activeWeekdays.isEmpty || habit.activeWeekdays.length >= 7)
          ? 'Todos los días'
          : (habit.activeWeekdays.toSet().toList()..sort())
              .where((d) => d >= 1 && d <= 7)
              .map((d) => dayLetters[d - 1])
              .join(' ');
      items.add(
        ActiveTaskReminderInfo(
          id: 'habit_${habit.id}',
          title: habit.name,
          category: 'HÁBITO',
          scheduleLabel: '$hh:$mm · $daysLabel',
          colorValue: habit.colorValue,
          habitId: habit.id,
        ),
      );
    }

    for (final block in blocks) {
      if (!block.hasReminder) continue;
      items.add(
        ActiveTaskReminderInfo(
          id: 'block_${block.id}',
          title: block.title,
          category: 'TURNO / 24H',
          scheduleLabel: 'Al finalizar +10m (${formatPostActivityTime(block)})',
          colorValue: block.colorValue,
          blockId: block.id,
        ),
      );
    }

    return items;
  }

  /// Lanza un aviso inmediato. Devuelve `null` si todo fue bien o un mensaje
  /// legible con el motivo del fallo para mostrarlo al usuario.
  Future<String?> showTestNotification() async {
    if (kIsWeb) return 'Las notificaciones no están disponibles en la versión web.';
    if (!await _ensureInitialized()) {
      return 'No se pudo iniciar el sistema de avisos. ${_lastError ?? ''}'.trim();
    }
    try {
      final android = _android;
      if (android != null) {
        await android.requestNotificationsPermission();
        final enabled = await android.areNotificationsEnabled() ?? true;
        if (!enabled) {
          return 'Las notificaciones están desactivadas para OrbitHabit. Actívalas en Ajustes del sistema > Apps > OrbitHabit > Notificaciones.';
        }
      }

      await _notificationsPlugin.show(
        id: 1,
        title: '🔔 Prueba de Aviso · OrbitHabit',
        body: '¡Tus recordatorios de hábitos y turnos están activos!',
        notificationDetails: _detailsFor(_testChannel),
      );
      return null;
    } catch (e) {
      _lastError = 'Prueba: $e';
      return 'Error al enviar el aviso: $e';
    }
  }
}

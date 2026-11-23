// This is a basic Flutter widget test for OrbitHabit.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbithabit/main.dart';
import 'package:orbithabit/domain/models/habit.dart';
import 'package:orbithabit/domain/models/achievement.dart';
import 'package:orbithabit/domain/models/schedule_block.dart';
import 'package:orbithabit/utils/streak_utils.dart';
import 'package:orbithabit/data/database_service.dart';
import 'package:orbithabit/providers/habit_provider.dart';
import 'package:orbithabit/providers/schedule_provider.dart';
import 'package:orbithabit/domain/models/user_settings.dart';
import 'package:orbithabit/services/backup_service.dart';
import 'package:orbithabit/services/schedule_poster_service.dart';
import 'package:orbithabit/utils/poster_saver.dart';
import 'package:orbithabit/ui/widgets/orbit_clock_24.dart';
import 'package:orbithabit/ui/widgets/schedule_block_card.dart';
import 'package:orbithabit/ui/widgets/guided_tour_overlay.dart';
import 'package:orbithabit/ui/widgets/release_notes_sheet.dart';
import 'package:orbithabit/ui/widgets/unified_task_sheet.dart';
import 'package:orbithabit/ui/widgets/orbit_tracker.dart';
import 'package:orbithabit/ui/screens/settings_screen.dart';
import 'package:orbithabit/ui/screens/shift_calendar_screen.dart';
import 'package:orbithabit/ui/screens/statistics_screen.dart';
import 'package:orbithabit/services/notification_service.dart';
import 'package:orbithabit/core/app_version.dart';
import 'package:flutter/material.dart';

class FakeDatabaseService extends DatabaseService {
  final Map<String, dynamic> _settings = {};
  final Map<String, Habit> _habits = {};

  @override
  Future<void> init() async {
    // No-op to bypass Hive initialization in test environment
  }

  @override
  Future<void> saveHabit(Habit habit) async {
    _habits[habit.id] = habit;
  }

  @override
  Future<void> replaceAllHabits(List<Habit> habits) async {
    _habits.clear();
    for (final h in habits) {
      _habits[h.id] = h;
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.remove(id);
  }

  @override
  List<Habit> getAllHabits() {
    return _habits.values.toList();
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }
}

void main() {
  group('OrbitHabit Tests', () {
    testWidgets('Onboarding welcome flow smoke test', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();

      // Build our app with the overridden database provider
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(fakeDb),
          ],
          child: const OrbitHabitApp(),
        ),
      );

      // Verify that the Onboarding is loaded on first launch and displays the welcome message
      expect(find.text('Sintoniza tu Vida'), findsOneWidget);
      expect(find.text('El Método Orbital'), findsNothing);
    });

    test('Achievement dynamic calculation logic tests', () {
      // 1. Initially with empty habits
      final emptyHabitsList = <Habit>[];
      final achievementsEmpty = Achievement.calculate(emptyHabitsList);

      final firstStepsTrophy = achievementsEmpty.firstWhere((a) => a.id == 'first_steps');
      final constellTrophy = achievementsEmpty.firstWhere((a) => a.id == 'habits_5');

      expect(firstStepsTrophy.isUnlocked, isFalse);
      expect(firstStepsTrophy.progress, 0.0);
      expect(constellTrophy.isUnlocked, isFalse);
      expect(constellTrophy.progress, 0.0);

      // 2. Add 5 habits to unlock Constelación Completa
      final fiveHabitsList = List.generate(5, (index) => Habit(
        id: 'h_$index',
        name: 'Hábito $index',
        colorValue: 0xFF84A59D,
        targetDays: 10,
        orderIndex: index,
      ));
      final achievementsWithFive = Achievement.calculate(fiveHabitsList);
      final constellTrophyWithFive = achievementsWithFive.firstWhere((a) => a.id == 'habits_5');
      final firstStepsWithFive = achievementsWithFive.firstWhere((a) => a.id == 'first_steps');

      expect(constellTrophyWithFive.isUnlocked, isTrue);
      expect(constellTrophyWithFive.progress, 1.0);
      expect(firstStepsWithFive.isUnlocked, isFalse); // Still no completed dates

      // 3. Complete 1 day in one habit to unlock Primeros Pasos
      fiveHabitsList[0].completedDates.add('2026-05-31');
      final achievementsWithCompletion = Achievement.calculate(fiveHabitsList);
      final firstStepsWithCompletion = achievementsWithCompletion.firstWhere((a) => a.id == 'first_steps');

      expect(firstStepsWithCompletion.isUnlocked, isTrue);
      expect(firstStepsWithCompletion.progress, 1.0);
    });

    test('ScheduleBlock overnight shift and active state logic', () {
      // 1. Overnight night-shift block: 23:00 to 07:00, Monday to Friday
      const nightShift = ScheduleBlock(
        id: 'shift_1',
        title: 'Trabajo Nocturno',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5], // L-V
      );

      expect(nightShift.isOvernight, isTrue);
      expect(nightShift.durationInMinutes, 8 * 60); // 8 hours
      expect(nightShift.formattedDuration, '8h');
      expect(nightShift.formattedTimeRange, '23:00 - 07:00');

      // Monday night at 23:30 -> Active!
      final mondayNight = DateTime(2026, 10, 5, 23, 30); // 2026-10-05 was a Monday
      expect(nightShift.isActiveAt(mondayNight), isTrue);

      // Tuesday early morning at 03:00 -> Active! (started Monday night)
      final tuesdayEarlyMorning = DateTime(2026, 10, 6, 3, 0); // Tuesday
      expect(nightShift.isActiveAt(tuesdayEarlyMorning), isTrue);

      // Tuesday afternoon at 14:00 -> Not active
      final tuesdayAfternoon = DateTime(2026, 10, 6, 14, 0);
      expect(nightShift.isActiveAt(tuesdayAfternoon), isFalse);

      // Saturday night at 23:30 -> Not active (Saturday is not in [1,2,3,4,5])
      final saturdayNight = DateTime(2026, 10, 10, 23, 30);
      expect(nightShift.isActiveAt(saturdayNight), isFalse);

      // 2. Daytime block: Gym 08:00 to 09:30
      const gymBlock = ScheduleBlock(
        id: 'gym_1',
        title: 'Gym',
        startHour: 8,
        startMinute: 0,
        endHour: 9,
        endMinute: 30,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      );

      expect(gymBlock.isOvernight, isFalse);
      expect(gymBlock.durationInMinutes, 90);
      expect(gymBlock.formattedDuration, '1h 30m');
      expect(gymBlock.isActiveAt(DateTime(2026, 10, 6, 8, 30)), isTrue);
      expect(gymBlock.isActiveAt(DateTime(2026, 10, 6, 10, 0)), isFalse);

      // 3. Monthly hour target: 120h work goal with overtime and Dedicado achievement
      final workMonth = DateTime.now();
      final currentMonthPrefix = '${workMonth.year}-${workMonth.month.toString().padLeft(2, '0')}';
      final workBlock = ScheduleBlock(
        id: 'work_120',
        title: 'Trabajo Turno',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        completedDates: List.generate(14, (i) => '$currentMonthPrefix-${(i + 1).toString().padLeft(2, '0')}'), // 14 shifts * 8h = 112h
        extraHours: 0.0,
      );

      expect(workBlock.getMonthlyWorkedHours(workMonth), 112.0);
      expect(workBlock.isTargetReached(workMonth), isFalse);

      // Add 2 more shifts (16 shifts * 8h = 128h) -> reaches and exceeds 120h!
      final completedWorkBlock = workBlock.copyWith(
        completedDates: List.generate(16, (i) => '$currentMonthPrefix-${(i + 1).toString().padLeft(2, '0')}'),
      );

      expect(completedWorkBlock.getMonthlyWorkedHours(workMonth), 128.0);
      expect(completedWorkBlock.isTargetReached(workMonth), isTrue);
      expect(completedWorkBlock.getOvertimeHours(workMonth), 8.0); // 8h extra!

      // Verifica que el antiguo logro 'ee_dedicated' / 'dedicated' fue eliminado
      final achievementsWithWork = Achievement.calculate([], [], [completedWorkBlock]);
      expect(
        achievementsWithWork.any((a) => a.id == 'ee_dedicated' || a.id == 'dedicated'),
        isFalse,
      );
    });

    test('Past days filled in habit (days 1 to 4) are counted in schedule block monthly hours', () {
      final workMonth = DateTime(2026, 10, 8);
      // User filled days 1 to 4 in Habit 'Trabajo'
      final habitTrabajo = Habit(
        id: 'habit_trabajo',
        name: 'Trabajo',
        colorValue: 0xFF9EA1D4,
        targetDays: 20,
        orderIndex: 0,
        completedDates: {'2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04'},
      );

      // Block created today (day 8) with empty block.completedDates but linked to habitTrabajo
      final scheduleTrabajo = const ScheduleBlock(
        id: 'block_trabajo',
        title: 'Trabajo',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        habitId: 'habit_trabajo',
        completedDates: [], // empty inside the block itself!
        extraHours: 0.0,
      );

      // 4 shifts * 8h = 32 hours should be counted from linked habit!
      final workedHours = scheduleTrabajo.getMonthlyWorkedHours(workMonth, habitTrabajo);
      expect(workedHours, 32.0);
      expect(scheduleTrabajo.getEffectiveCompletedDates(habitTrabajo).length, 4);
    });

    test('WorkShiftGroup breakdown hours matches getMonthlyWorkedHours and ignores future assigned dates', () {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month, 1);
      final todayIso = now.toIso8601String().split('T').first;
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final tomorrowIso = tomorrow.toIso8601String().split('T').first;

      const shiftMorning = ScheduleBlock(
        id: 'shift_m',
        title: 'Mañana',
        startHour: 7,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        completedDates: [],
        assignedDates: [],
        extraHours: 0.0,
      );

      final shiftWithAssignments = shiftMorning.copyWith(
        assignedDates: [todayIso, tomorrowIso], // today (assigned) + tomorrow (future)
        completedDates: [todayIso], // today marked completed
      );

      final group = WorkShiftGroup(
        title: 'Trabajo',
        shifts: [shiftWithAssignments],
        monthlyTargetHours: 120,
      );

      // Today completed is counted, but tomorrow is future and ignored in worked hours
      final workedHours = group.getMonthlyWorkedHours(month);
      expect(workedHours, 8.0); // 1 shift * 8h = 8h

      final breakdown = group.getBreakdown(month);
      expect(breakdown.length, 1);
      expect(breakdown.first.shiftsCount, 1);
      expect(breakdown.first.totalHours, 8.0);
    });

    test('StreakUtils breaks streak if an active day strictly before today was missed', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final yesterdayIso = yesterday.toIso8601String().split('T').first;

      final habit = Habit(
        id: 'daily_habit',
        name: 'Daily',
        colorValue: 0xFF84A59D,
        targetDays: 30,
        orderIndex: 0,
        activeWeekdays: [1, 2, 3, 4, 5, 6, 7], // Every day active
        completedDates: {}, // Missed yesterday and today
      );

      // Missed yesterday strictly before today -> streak is 0
      final streak = StreakUtils.calculateCurrentStreak(habit);
      expect(streak, 0);

      // Completed yesterday but today not completed yet -> streak is 1 (today is forgiven because in-progress)
      final habitWithYesterday = habit.copyWith(completedDates: {yesterdayIso});
      final streakWithYesterday = StreakUtils.calculateCurrentStreak(habitWithYesterday);
      expect(streakWithYesterday, 1);
    });

    test('BackupService exports and parses DemoSeederService data without loss', () {
      final now = DateTime(2026, 10, 31);
      final demo = DemoSeederService.generateDemoData(now);
      final settings = UserSettings(
        userName: 'Arturo',
        avatarEmoji: '⚡',
        avatarColorValue: 0xFF84A59D,
        notificationHour: 21,
        notificationMinute: 0,
        themeMode: 'dark',
        isFirstTime: false,
        vacationDates: ['2026-10-12', '2026-10-13'],
      );

      final jsonStr = BackupService.exportToJson(
        habits: demo.habits,
        blocks: demo.blocks,
        settings: settings,
      );

      final restored = BackupService.parseFromJson(jsonStr);
      expect(restored.habits.length, demo.habits.length);
      expect(restored.blocks.length, demo.blocks.length);
      expect(restored.vacationDates, ['2026-10-12', '2026-10-13']);
      expect(restored.habits.first.id, 'demo_work');
      expect(restored.blocks.first.id, 'demo_shift_morning');
    });

    test('ScheduleBlock monthlyExtraHours isolates overtime per month without carrying over', () {
      final october = DateTime(2026, 10, 1);
      final november = DateTime(2026, 11, 1);

      const block = ScheduleBlock(
        id: 'shift_overtime',
        title: 'Turno Rotativo',
        startHour: 8,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        monthlyExtraHours: {
          '2026-10': 15.0,
        },
        extraHours: 0.0,
      );

      // Octubre cuenta con 15 horas extra
      expect(block.getExtraHoursForMonth(october), 15.0);
      // Noviembre no arrastra las horas de Octubre (devuelve 0.0)
      expect(block.getExtraHoursForMonth(november), 0.0);

      // Verificamos que getMonthlyWorkedHours solo incluye las horas extra en Octubre
      expect(block.getMonthlyWorkedHours(october), 15.0);
      expect(block.getMonthlyWorkedHours(november), 0.0);

      // Probamos añadir horas extra a Noviembre usando copyWith
      final updatedMap = Map<String, double>.from(block.monthlyExtraHours);
      updatedMap['2026-11'] = 8.5;
      final updatedBlock = block.copyWith(monthlyExtraHours: updatedMap);

      expect(updatedBlock.getExtraHoursForMonth(october), 15.0);
      expect(updatedBlock.getExtraHoursForMonth(november), 8.5);
    });

    test('SchedulePosterService renders high-resolution 1080x1440 PNG byte stream', () async {
      final now = DateTime(2026, 10, 1);
      final demo = DemoSeederService.generateDemoData(now);

      final pngBytes = await SchedulePosterService.renderMonthlyPosterPng(
        month: now,
        blocks: demo.blocks,
        userName: 'Arturo',
        isDark: true,
      );

      expect(pngBytes, isNotEmpty);
      // Validar cabecera mágica de archivo PNG (89 50 4E 47 0D 0A 1A 0A)
      expect(pngBytes[0], 0x89);
      expect(pngBytes[1], 0x50);
      expect(pngBytes[2], 0x4E);
      expect(pngBytes[3], 0x47);
    });

    test('DemoSeederService.isDemoModeActive accurately detects demo prefixes and user data', () {
      final now = DateTime.now();
      final demo = DemoSeederService.generateDemoData(now);

      // Demo data should be detected as active
      expect(DemoSeederService.isDemoModeActive(demo.habits, demo.blocks), isTrue);

      // Regular user habits without 'demo_' prefix should return false
      final userHabit = Habit(
        id: 'user_habit_meditation',
        name: 'Meditación',
        colorValue: 0xFF84A59D,
        targetDays: 20,
        orderIndex: 0,
      );
      final userBlock = ScheduleBlock(
        id: 'user_block_study',
        title: 'Estudio',
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
      );

      expect(DemoSeederService.isDemoModeActive([userHabit], [userBlock]), isFalse);
    });

    test('OrbitClock24 splits overnight shifts: evening start today, morning finish tomorrow', () {
      final today = DateTime(2026, 11, 1, 10, 0); // Nov 1st 10:00 AM
      final tomorrow = DateTime(2026, 11, 2, 10, 0);
      final todayIso = '2026-11-01';

      // Night shift: 23:00 to 07:00, assigned only to Nov 1st
      final nightShift = ScheduleBlock(
        id: 'night_shift',
        title: 'Turno Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        assignedDates: [todayIso],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
      );

      // On Nov 1st: shift starts tonight!
      // Must NOT show 00:00-07:00 in the morning because yesterday was day off.
      // Must only show 23:00-24:00 in the evening!
      final todaySegments = OrbitClock24.getSegmentsForDay([nightShift], today);
      expect(todaySegments.length, 1);
      expect(todaySegments.first.startMinutes, 1380); // 23:00
      expect(todaySegments.first.sweepMinutes, 60);   // Until 24:00 (midnight)
      expect(todaySegments.first.isForTonight, isTrue);

      // On Nov 2nd: shift finishes this morning (00:00-07:00)!
      // Must show 00:00-07:00 carried over from yesterday night.
      final tomorrowSegments = OrbitClock24.getSegmentsForDay([nightShift], tomorrow);
      expect(tomorrowSegments.length, 1);
      expect(tomorrowSegments.first.startMinutes, 0);    // 00:00
      expect(tomorrowSegments.first.sweepMinutes, 420);  // 7 hours until 07:00
      expect(tomorrowSegments.first.isFromYesterday, isTrue);
    });

    test('Assigned shift for today without completion does NOT count into worked hours', () {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month, 1);
      final todayIso = now.toIso8601String().split('T').first;

      final nightShift = ScheduleBlock(
        id: 'shift_today_only',
        title: 'Turno Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        assignedDates: [todayIso], // Assigned for tonight
        completedDates: [],        // NOT completed yet!
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
      );

      final group = WorkShiftGroup(
        title: 'Turno Noche',
        shifts: [nightShift],
        monthlyTargetHours: 120,
      );

      // Worked hours must be 0.0, because today's shift has not been worked yet!
      expect(group.getMonthlyWorkedHours(month), 0.0);
      expect(nightShift.getMonthlyWorkedHours(month), 0.0);
    });

    test('PosterSaver saves bytes and returns accessible file path', () async {
      final testBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final savedPath = await PosterSaver.save(
        bytes: testBytes,
        fileName: 'orbit_test_poster.png',
      );

      expect(savedPath, isNotNull);
      expect(savedPath, contains('orbit_test_poster.png'));
    });

    test('toggleShiftOnDate supports multiple tasks on the same date without overwriting', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scheduleProvider.notifier);
      final block1 = ScheduleBlock(
        id: 'block_morning',
        title: 'Mañana',
        startHour: 7,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
      );
      final block2 = ScheduleBlock(
        id: 'block_evening',
        title: 'Tarde',
        startHour: 15,
        startMinute: 0,
        endHour: 23,
        endMinute: 0,
        colorValue: 0xFFF28482,
        daysOfWeek: [1, 2, 3, 4, 5],
      );

      await notifier.replaceAllBlocks([block1, block2]);

      const dateIso = '2026-11-10';
      // Toggle date on block 1
      await notifier.toggleShiftOnDate(block1.id, dateIso);
      var state = container.read(scheduleProvider);
      expect(state.firstWhere((b) => b.id == block1.id).assignedDates, contains(dateIso));

      // Toggle date on block 2 -> both must have dateIso!
      await notifier.toggleShiftOnDate(block2.id, dateIso);
      state = container.read(scheduleProvider);
      expect(state.firstWhere((b) => b.id == block1.id).assignedDates, contains(dateIso));
      expect(state.firstWhere((b) => b.id == block2.id).assignedDates, contains(dateIso));

      // Toggling block 1 again removes dateIso only from block 1
      await notifier.toggleShiftOnDate(block1.id, dateIso);
      state = container.read(scheduleProvider);
      expect(state.firstWhere((b) => b.id == block1.id).assignedDates, isNot(contains(dateIso)));
      expect(state.firstWhere((b) => b.id == block2.id).assignedDates, contains(dateIso));
    });

    test('SchedulePosterService.renderMonthlyPosterPng generates valid PNG applying includedBlockIds and showTelemetryFooter', () async {
      final block1 = ScheduleBlock(
        id: 'b1',
        title: 'Mañana',
        startHour: 8,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-05'],
      );
      final block2 = ScheduleBlock(
        id: 'b2',
        title: 'Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-05'],
      );

      // Only include block1, no footer
      final bytesOnlyB1 = await SchedulePosterService.renderMonthlyPosterPng(
        month: DateTime(2026, 11),
        blocks: [block1, block2],
        userName: 'Arturo',
        isDark: true,
        includedBlockIds: {'b1'},
        showTelemetryFooter: false,
      );

      expect(bytesOnlyB1, isNotEmpty);
      expect(bytesOnlyB1[0], 0x89);
      expect(bytesOnlyB1[1], 0x50);
      expect(bytesOnlyB1[2], 0x4E);
      expect(bytesOnlyB1[3], 0x47);

      // Full poster with both blocks and footer
      final bytesFull = await SchedulePosterService.renderMonthlyPosterPng(
        month: DateTime(2026, 11),
        blocks: [block1, block2],
        userName: 'Arturo',
        isDark: false,
        showTelemetryFooter: true,
      );

      expect(bytesFull, isNotEmpty);
      expect(bytesFull[0], 0x89);
    });

    test('computeHeavyDutyShieldDates detects shifts >= 12h and protects secondary habit streaks', () {
      // 1. Guardias y turnos:
      // - 2026-11-01: 8h shift (under 12h threshold) -> NO shield
      // - 2026-11-02: 12h marathon shift -> SHIELD
      // - 2026-11-03: Two 8h shifts = 16h total -> SHIELD
      const regularShift = ScheduleBlock(
        id: 's_8h',
        title: 'Turno 8h',
        startHour: 8,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-01', '2026-11-03'],
      );
      const marathonShift = ScheduleBlock(
        id: 's_12h',
        title: 'Guardia 12h',
        startHour: 8,
        startMinute: 0,
        endHour: 20,
        endMinute: 0,
        colorValue: 0xFFF28482,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-02'],
      );
      const extraShift = ScheduleBlock(
        id: 's_extra_8h',
        title: 'Refuerzo 8h',
        startHour: 16,
        startMinute: 0,
        endHour: 24,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-03'],
      );

      final blocks = [regularShift, marathonShift, extraShift];
      final shieldDates = StreakUtils.computeHeavyDutyShieldDates(blocks);

      expect(shieldDates.contains('2026-11-01'), isFalse);
      expect(shieldDates.contains('2026-11-02'), isTrue);
      expect(shieldDates.contains('2026-11-03'), isTrue);

      final habit = Habit(
        id: 'read_book',
        name: 'Leer 20 páginas',
        colorValue: 0xFF84A59D,
        targetDays: 21,
        orderIndex: 0,
        activeWeekdays: [1, 2, 3, 4, 5, 6, 7],
        completedDates: {'2026-11-01'},
      );

      final streakWithShield = StreakUtils.calculateMaxStreak(habit, shieldDates.toList());
      expect(streakWithShield, 1);
    });

    test('ScheduleNotifier deletes sub-task/shift block permanently while preserving sibling shifts', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(scheduleProvider.notifier);
      const parentHabitId = 'work_hospital';

      const shiftA = ScheduleBlock(
        id: 'shift_a',
        title: 'Mañana',
        startHour: 7,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFFF28482,
        habitId: parentHabitId,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-01'],
      );
      const shiftB = ScheduleBlock(
        id: 'shift_b',
        title: 'Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        habitId: parentHabitId,
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-01'],
      );

      await notifier.replaceAllBlocks([shiftA, shiftB]);
      expect(container.read(scheduleProvider).length, 2);

      // Eliminamos la subtarea B
      await notifier.deleteBlock(shiftB.id);

      final remaining = container.read(scheduleProvider);
      expect(remaining.length, 1);
      expect(remaining.first.id, 'shift_a');
      expect(remaining.any((b) => b.id == 'shift_b'), isFalse);
    });

    test('Habit SubTasks checklist toggles and automatically marks parent habit complete when all done', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(habitsProvider.notifier);
      const dateIso = '2026-11-05';

      final habit = Habit(
        id: 'gym_routine',
        name: 'Gimnasio',
        colorValue: 0xFF84A59D,
        targetDays: 20,
        orderIndex: 0,
        subTasks: const [
          SubTask(id: 'st_warmup', title: 'Calentamiento 10m'),
          SubTask(id: 'st_bench', title: 'Press banca'),
        ],
      );

      await notifier.addHabit(habit);
      expect(container.read(habitsProvider).first.completedDates.contains(dateIso), isFalse);

      // 1. Completar primera subtarea
      await notifier.toggleSubTask('gym_routine', 'st_warmup', dateIso);
      var currentHabit = container.read(habitsProvider).first;
      expect(currentHabit.subTasks.first.isCompletedOn(dateIso), isTrue);
      expect(currentHabit.subTasks.last.isCompletedOn(dateIso), isFalse);
      expect(currentHabit.completedDates.contains(dateIso), isFalse);

      // 2. Completar segunda subtarea -> ¡Hábito principal completado automáticamente!
      await notifier.toggleSubTask('gym_routine', 'st_bench', dateIso);
      currentHabit = container.read(habitsProvider).first;
      expect(currentHabit.subTasks.every((st) => st.isCompletedOn(dateIso)), isTrue);
      expect(currentHabit.completedDates.contains(dateIso), isTrue);

      // 3. Desmarcar una subtarea -> Hábito principal pasa a incompleto
      await notifier.toggleSubTask('gym_routine', 'st_warmup', dateIso);
      currentHabit = container.read(habitsProvider).first;
      expect(currentHabit.completedDates.contains(dateIso), isFalse);
    });

    test('SubTask reordering correctly assigns orderIndex and preserves task properties', () {
      final subTasks = [
        const SubTask(id: 'st_1', title: 'Paso 1', orderIndex: 0),
        const SubTask(id: 'st_2', title: 'Paso 2', orderIndex: 1),
        const SubTask(id: 'st_3', title: 'Paso 3', orderIndex: 2),
      ];

      // Simulate moving st_3 (index 2) to top (index 0)
      final reordered = List<SubTask>.from(subTasks);
      final item = reordered.removeAt(2);
      reordered.insert(0, item);

      for (int i = 0; i < reordered.length; i++) {
        reordered[i] = reordered[i].copyWith(orderIndex: i);
      }

      expect(reordered[0].title, 'Paso 3');
      expect(reordered[0].orderIndex, 0);
      expect(reordered[1].title, 'Paso 1');
      expect(reordered[1].orderIndex, 1);
      expect(reordered[2].title, 'Paso 2');
      expect(reordered[2].orderIndex, 2);
    });

    test('Cloning/duplicating habit produces fresh habit with clean progress and cloned subtasks', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(habitsProvider.notifier);
      final original = Habit(
        id: 'habit_original',
        name: 'Rutina Foco',
        colorValue: 0xFF10B981,
        targetDays: 25,
        orderIndex: 0,
        completedDates: {'2026-11-01', '2026-11-02'},
        subTasks: const [
          SubTask(id: 'st_a', title: 'Revisar notas', completedDates: {'2026-11-01'}),
          SubTask(id: 'st_b', title: 'Ejecutar bloque 45m', completedDates: {'2026-11-01'}),
        ],
      );

      await notifier.addHabit(original);

      // Duplicate logic
      final duplicatedTitle = '${original.name} (Copia)';
      final duplicatedSubTasks = original.subTasks.asMap().entries.map((entry) {
        return SubTask(
          id: 'subtask_clone_${entry.key}',
          title: entry.value.title,
          completedDates: const {},
          orderIndex: entry.key,
        );
      }).toList();

      final duplicatedHabit = Habit(
        id: 'habit_clone',
        name: duplicatedTitle,
        colorValue: original.colorValue,
        targetDays: original.targetDays,
        orderIndex: 1,
        completedDates: const {},
        subTasks: duplicatedSubTasks,
      );

      await notifier.addHabit(duplicatedHabit);

      final state = container.read(habitsProvider);
      expect(state.length, 2);

      final cloned = state.firstWhere((h) => h.id == 'habit_clone');
      expect(cloned.name, 'Rutina Foco (Copia)');
      expect(cloned.completedDates, isEmpty);
      expect(cloned.subTasks.length, 2);
      expect(cloned.subTasks.first.title, 'Revisar notas');
      expect(cloned.subTasks.first.completedDates, isEmpty);
      expect(cloned.subTasks.last.title, 'Ejecutar bloque 45m');
      expect(cloned.subTasks.last.completedDates, isEmpty);
    });

    testWidgets('GuidedTourOverlay renders 7-step Spotlight tour and triggers interactive target tap', (WidgetTester tester) async {
      final targetKey = GlobalKey();
      int currentStep = 0;
      bool interactiveTapped = false;

      final steps = [
        GuidedTourStepData(
          stepNumber: 1,
          title: 'Dos vistas conectadas',
          body: 'Cambia entre ÓRBITA y 24H.',
          targetKey: targetKey,
        ),
        GuidedTourStepData(
          stepNumber: 3,
          title: 'Crea tu primera tarea',
          body: 'Toca el botón iluminado.',
          targetKey: targetKey,
          isInteractiveAction: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    Center(
                      child: ElevatedButton(
                        key: targetKey,
                        onPressed: () {},
                        child: const Text('Añadir Hábito'),
                      ),
                    ),
                    GuidedTourOverlay(
                      currentStepIndex: currentStep,
                      steps: steps,
                      onNext: () => setState(() => currentStep = 1),
                      onPrevious: () => setState(() => currentStep = 0),
                      onSkip: () {},
                      onInteractiveTargetTap: () {
                        interactiveTapped = true;
                      },
                      onCreateFirstTask: () {},
                      onExploreWithDemo: () {},
                      onStartFromScratch: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Dos vistas conectadas'), findsOneWidget);
      expect(find.text('[ PASO 01 / 02 ]'), findsOneWidget);

      await tester.tap(find.text('[ SIGUIENTE → ]'));
      await tester.pump();
      expect(find.text('Crea tu primera tarea'), findsOneWidget);
      expect(find.text('Toca el botón iluminado para continuar'), findsOneWidget);

      await tester.tap(find.text('Toca el botón iluminado para continuar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(interactiveTapped, isTrue);
    });

    testWidgets('ReleaseNotesSheet renders current version, feature blocks, and persists seen version', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(fakeDb),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: ReleaseNotesSheet(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verifica versión actual y cabecera
      expect(find.text('[ NOVEDADES // v$kCurrentAppVersion ]'), findsOneWidget);
      expect(find.text('NUEVA VERSIÓN · $kCurrentReleaseDate'), findsOneWidget);
      expect(find.text('Qué hay de nuevo en OrbitHabit'), findsOneWidget);

      // Verifica los bloques de novedades destacados
      expect(find.text('Nuevo Tutorial Guiado Paso a Paso'), findsOneWidget);
      expect(find.text('Subtareas Micro-Segmentadas y Duplicación'), findsOneWidget);
      expect(find.text('Horarios Puntuales por Día, Minutos Exactos y Horas Extra'), findsOneWidget);
      expect(find.text('Escudo de Guardia Pesada (+12h) y Nuevo Icono'), findsOneWidget);

      // Verifica que el botón inferior persiste la versión vista
      expect(fakeDb.getLastSeenAppVersion(), isNull);
      await tester.tap(find.text('[ ¡ENTENDIDO, A PROBARLO! ]'));
      await tester.pumpAndSettle();
      expect(fakeDb.getLastSeenAppVersion(), kCurrentAppVersion);
    });

    test('WorkShiftGroup deduplicates legacy cloned dates across Nocturno and Mañanas shifts in past months', () {
      final october = DateTime(2026, 10, 1);
      final octoberDates = List.generate(
        18,
        (i) => '2026-10-${(i + 1).toString().padLeft(2, '0')}',
      );

      final workHabit = Habit(
        id: 'habit_trabajar',
        name: 'Trabajar',
        colorValue: 0xFFEAB308,
        targetDays: 20,
        orderIndex: 0,
        completedDates: octoberDates.toSet(),
      );

      final nocturno = ScheduleBlock(
        id: 'shift_nocturno',
        title: 'Nocturno',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFFEAB308,
        habitId: 'habit_trabajar',
        daysOfWeek: const [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        completedDates: octoberDates,
        assignedDates: octoberDates,
      );

      // Cloned secondary shift from legacy version with the same 18 October dates
      final mananas = ScheduleBlock(
        id: 'shift_mananas',
        title: 'Mañanas',
        startHour: 7,
        startMinute: 30,
        endHour: 14,
        endMinute: 30,
        colorValue: 0xFFEAB308,
        habitId: 'habit_trabajar',
        daysOfWeek: const [1, 2, 3, 4, 5],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
        completedDates: octoberDates,
        assignedDates: octoberDates,
      );

      final group = WorkShiftGroup(
        title: 'Trabajar',
        habitId: 'habit_trabajar',
        habit: workHabit,
        shifts: [nocturno, mananas],
        monthlyTargetHours: 120,
      );

      expect(group.getMonthlyShiftsCount(october), 18);
      expect(group.getMonthlyWorkedHours(october), 144.0);

      final breakdown = group.getBreakdown(october);
      expect(breakdown.first.shiftsCount, 18);
      expect(breakdown.first.totalHours, 144.0);
      expect(breakdown.last.shiftsCount, 0);
      expect(breakdown.last.totalHours, 0.0);
    });

    test('Habit and ScheduleBlock serialize and deserialize reminder fields accurately', () {
      final habit = Habit(
        id: 'rem_habit_1',
        name: 'Leer 20 min',
        colorValue: 0xFF84A59D,
        targetDays: 20,
        orderIndex: 0,
        hasReminder: true,
        reminderHour: 21,
        reminderMinute: 30,
      );

      expect(habit.formattedReminderTime, '21:30');
      final habitMap = habit.toMap();
      final restoredHabit = Habit.fromMap(habitMap);
      expect(restoredHabit.hasReminder, isTrue);
      expect(restoredHabit.reminderHour, 21);
      expect(restoredHabit.reminderMinute, 30);
      expect(restoredHabit.formattedReminderTime, '21:30');

      final clearedHabit = restoredHabit.copyWith(hasReminder: false, clearReminderTime: true);
      expect(clearedHabit.hasReminder, isFalse);
      expect(clearedHabit.reminderHour, isNull);
      expect(clearedHabit.formattedReminderTime, isNull);

      final block = const ScheduleBlock(
        id: 'rem_block_1',
        title: 'Turno Mañana',
        startHour: 7,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFFEAB308,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasReminder: true,
        reminderOffsetMinutes: 30,
      );

      final blockMap = block.toMap();
      final restoredBlock = ScheduleBlock.fromMap(blockMap);
      expect(restoredBlock.hasReminder, isTrue);
      expect(restoredBlock.reminderOffsetMinutes, 30);
    });

    testWidgets('SettingsScreen hides Datos, Backup y Laboratorio and shows Probar aviso button', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(fakeDb),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica que la sección "Datos, Backup y Laboratorio" ya no existe en Ajustes
      expect(find.text('Datos, Backup y Laboratorio'), findsNothing);
      expect(find.text('Exportar Copia de Seguridad'), findsNothing);
      expect(find.text('Purgar Todos los Datos'), findsNothing);

      // Verifica que Probar aviso ya no existe y Novedades no tiene emojis
      expect(find.text('[ 🔔 Probar aviso ]'), findsNothing);
      expect(find.text('Novedades de la versión (v$kCurrentAppVersion)'), findsOneWidget);
    });

    test('ScheduleNotifier keeps unplanned extra days out of assignedDates and syncs 24H -> Habit bidirectionally', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      final habit = Habit(
        id: 'h_work',
        name: 'Trabajar',
        colorValue: 0xFFEAB308,
        targetDays: 20,
        orderIndex: 0,
      );
      final block = const ScheduleBlock(
        id: 'b_night',
        title: 'Nocturno',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFFEAB308,
        habitId: 'h_work',
        daysOfWeek: [1, 2, 3, 4, 5],
        assignedDates: ['2026-11-09'],
      );

      await container.read(habitsProvider.notifier).addHabit(habit);
      await container.read(scheduleProvider.notifier).addBlock(block);

      const extraDay = '2026-11-14'; // No estaba asignado en Calendario

      // 1. Marcar desde 24H (toggleDateForBlock): debe sincronizar Habit y NO ensuciar assignedDates
      await container.read(scheduleProvider.notifier).toggleDateForBlock('b_night', extraDay);

      var currentBlock = container.read(scheduleProvider).firstWhere((b) => b.id == 'b_night');
      var currentHabit = container.read(habitsProvider).firstWhere((h) => h.id == 'h_work');
      expect(currentBlock.completedDates, contains(extraDay));
      expect(currentHabit.completedDates, contains(extraDay));
      expect(currentBlock.assignedDates, isNot(contains(extraDay)));
      expect(currentBlock.assignedDates, equals(['2026-11-09']));

      // 2. Desmarcar día extra: no debe quedar silueta fantasma en assignedDates ni completedDates
      await container.read(scheduleProvider.notifier).toggleDateForBlock('b_night', extraDay);

      currentBlock = container.read(scheduleProvider).firstWhere((b) => b.id == 'b_night');
      currentHabit = container.read(habitsProvider).firstWhere((h) => h.id == 'h_work');
      expect(currentBlock.completedDates, isNot(contains(extraDay)));
      expect(currentHabit.completedDates, isNot(contains(extraDay)));
      expect(currentBlock.assignedDates, isNot(contains(extraDay)));
      expect(currentBlock.assignedDates, equals(['2026-11-09']));

      // 3. Marcar desde Órbita (toggleDay) -> syncDateWithHabit tampoco debe ensuciar assignedDates
      await container.read(habitsProvider.notifier).toggleDay('h_work', extraDay);
      currentBlock = container.read(scheduleProvider).firstWhere((b) => b.id == 'b_night');
      expect(currentBlock.completedDates, contains(extraDay));
      expect(currentBlock.assignedDates, isNot(contains(extraDay)));

      // 4. Desmarcar desde Órbita
      await container.read(habitsProvider.notifier).toggleDay('h_work', extraDay);
      currentBlock = container.read(scheduleProvider).firstWhere((b) => b.id == 'b_night');
      expect(currentBlock.completedDates, isNot(contains(extraDay)));
      expect(currentBlock.assignedDates, isNot(contains(extraDay)));
    });

    test('Achievements revoke in real time and unlock all 10 special day achievements', () {
      const specialDates = <String, String>{
        'epiphany_day': '2026-01-06',
        'pi_day': '2026-03-14',
        'fathers_day': '2026-03-19',
        'book_day': '2026-04-23',
        'workers_day': '2026-05-01',
        'mothers_day': '2026-05-03', // primer domingo de mayo de 2026
        'san_juan': '2026-06-24',
        'back_to_school': '2026-09-01',
        'leap_or_palindrome': '2026-11-11',
        'new_years_eve': '2026-12-31',
      };

      final habitWithSpecialDays = Habit(
        id: 'h_special',
        name: 'Constancia Anual',
        colorValue: 0xFF84A59D,
        targetDays: 30,
        orderIndex: 0,
        completedDates: specialDates.values.toSet(),
      );

      final unlockedList = Achievement.calculate([habitWithSpecialDays]);
      for (final id in specialDates.keys) {
        final trophy = unlockedList.firstWhere((a) => a.id == id);
        expect(trophy.isUnlocked, isTrue, reason: 'Expected $id to be unlocked');
      }
      expect(unlockedList.firstWhere((a) => a.id == 'fathers_day').title, 'Yo soy tu padre');
      expect(unlockedList.firstWhere((a) => a.id == 'mothers_day').title, 'Amor de Madre');
      expect(unlockedList.firstWhere((a) => a.id == 'new_years_eve').title, 'Última Órbita');

      // Revocación inmediata cuando el usuario desmarca o borra sus fechas
      final habitRevoked = habitWithSpecialDays.copyWith(completedDates: const {});
      final revokedList = Achievement.calculate([habitRevoked]);
      for (final id in specialDates.keys) {
        final trophy = revokedList.firstWhere((a) => a.id == id);
        expect(trophy.isUnlocked, isFalse, reason: 'Expected $id to be revoked');
      }
      expect(revokedList.firstWhere((a) => a.id == 'first_steps').isUnlocked, isFalse);

      // También se desbloquea/revoca desde un ScheduleBlock en vista 24H
      const blockOnPiDay = ScheduleBlock(
        id: 'b_pi',
        title: 'Estudio',
        startHour: 9,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
        colorValue: 0xFF84DCC6,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        completedDates: ['2026-03-14'],
      );
      final viaBlock = Achievement.calculate([], [], [blockOnPiDay]);
      expect(viaBlock.firstWhere((a) => a.id == 'pi_day').isUnlocked, isTrue);

      final revokedViaBlock = Achievement.calculate([], [], [blockOnPiDay.copyWith(completedDates: [])]);
      expect(revokedViaBlock.firstWhere((a) => a.id == 'pi_day').isUnlocked, isFalse);
    });

    testWidgets('SettingsScreen shows unsaved changes dialog on back and 3-step Vacation tutorial', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(fakeDb),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    child: const Text('Abrir Ajustes'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Ajustes'));
      await tester.pumpAndSettle();

      // 1. Probar el mini-tutorial de Modo Vacaciones desde [ ? ]
      expect(fakeDb.getHasSeenVacationTutorial(), isFalse);
      await tester.tap(find.text('[ ? ]'));
      await tester.pumpAndSettle();

      expect(find.text('Escudo de Rachas'), findsOneWidget);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Silencio Inteligente'), findsOneWidget);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Selección Flexible'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(fakeDb.getHasSeenVacationTutorial(), isTrue);

      // 2. Probar detección de cambios sin guardar al volver atrás
      await tester.enterText(find.byType(TextField), 'Nuevo Alias');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Cambios sin guardar'), findsOneWidget);
      expect(find.text('Descartar'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      // Debe haber cerrado SettingsScreen sin guardar el alias
      expect(find.text('Abrir Ajustes'), findsOneWidget);
    });

    test('NotificationService builds active task reminders and reads permission status safely', () async {
      final service = NotificationService();
      final habitWithReminder = Habit(
        id: 'h_rem',
        name: 'Leer 20m',
        colorValue: 0xFF84A59D,
        targetDays: 20,
        orderIndex: 0,
        activeWeekdays: [1, 3, 5],
        hasReminder: true,
        reminderHour: 21,
        reminderMinute: 30,
      );
      final habitWithoutReminder = Habit(
        id: 'h_norem',
        name: 'Agua',
        colorValue: 0xFF84DCC6,
        targetDays: 25,
        orderIndex: 1,
        hasReminder: false,
      );
      const blockWithReminder = ScheduleBlock(
        id: 'b_rem',
        title: 'Turno Mañana',
        startHour: 8,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFFFBBF24,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasReminder: true,
        reminderOffsetMinutes: 15,
      );
      const blockWithoutReminder = ScheduleBlock(
        id: 'b_norem',
        title: 'Turno Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF84A59D,
        daysOfWeek: [1, 2],
        hasReminder: false,
      );

      final reminders = service.buildActiveRemindersList(
        habits: [habitWithReminder, habitWithoutReminder],
        blocks: [blockWithReminder, blockWithoutReminder],
      );

      expect(reminders.length, 2);
      expect(reminders[0].title, 'Leer 20m');
      expect(reminders[0].category, 'HÁBITO');
      expect(reminders[0].scheduleLabel, contains('21:30'));
      expect(reminders[1].title, 'Turno Mañana');
      expect(reminders[1].category, 'TURNO / 24H');
      expect(reminders[1].scheduleLabel, 'Aviso: 10m antes y 10m después');

      final status = await service.getPermissionStatus();
      expect(status.notificationsEnabled, isTrue);
    });

    testWidgets('SettingsScreen displays simplified notification controls and deletes individual reminders', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      await container.read(habitsProvider.notifier).addHabit(
        Habit(
          id: 'h_med',
          name: 'Meditar',
          colorValue: 0xFF84DCC6,
          targetDays: 20,
          orderIndex: 0,
          hasReminder: true,
          reminderHour: 19,
          reminderMinute: 45,
        ),
      );
      await container.read(scheduleProvider.notifier).addBlock(
        const ScheduleBlock(
          id: 'b_shift',
          title: 'Turno Mañana',
          startHour: 8,
          startMinute: 0,
          endHour: 16,
          endMinute: 0,
          colorValue: 0xFFFBBF24,
          daysOfWeek: [1, 2, 3, 4, 5],
          hasReminder: true,
          reminderOffsetMinutes: 30,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notificaciones activas'), findsOneWidget);
      expect(find.text('Recordatorio post-actividad'), findsOneWidget);
      expect(find.text('Hora del Recordatorio'), findsNothing);
      expect(find.text('Cambiar Hora'), findsNothing);
      expect(find.text('[ 🔔 Probar aviso ]'), findsNothing);

      final headerFinder = find.text('RECORDATORIOS CONFIGURADOS');
      await tester.ensureVisible(headerFinder);
      expect(headerFinder, findsOneWidget);

      expect(find.text('Meditar'), findsOneWidget);
      expect(find.text('Turno Mañana'), findsOneWidget);
      expect(find.text('HÁBITO'), findsOneWidget);
      expect(find.text('TURNO / 24H'), findsOneWidget);
      expect(find.text('Aviso: 10m antes y 10m después'), findsOneWidget);

      // Eliminar el recordatorio del hábito Meditar
      final deleteHabitFinder = find.byKey(const Key('delete_reminder_habit_h_med'));
      await tester.ensureVisible(deleteHabitFinder);
      await tester.tap(deleteHabitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Meditar'), findsNothing);
      expect(find.text('Recordatorio eliminado'), findsOneWidget);
      expect(
        container.read(habitsProvider).firstWhere((h) => h.id == 'h_med').hasReminder,
        isFalse,
      );

      // Eliminar también el del bloque horario 24H
      final deleteBlockFinder = find.byKey(const Key('delete_reminder_block_b_shift'));
      await tester.ensureVisible(deleteBlockFinder);
      await tester.tap(deleteBlockFinder);
      await tester.pumpAndSettle();

      expect(find.text('Turno Mañana'), findsNothing);
      expect(find.text('No hay recordatorios individuales activos'), findsOneWidget);
    });

    testWidgets('StatisticsScreen renders 3 CustomPainter charts, toggles range, and shows protected days', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      String iso(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final todayIso = iso(now);
      final prevDay1 = iso(DateTime(prevMonth.year, prevMonth.month, 2));
      final prevDay2Vac = iso(DateTime(prevMonth.year, prevMonth.month, 3));
      final prevDay3Heavy = iso(DateTime(prevMonth.year, prevMonth.month, 4));
      final prevDay4 = iso(DateTime(prevMonth.year, prevMonth.month, 5));

      await fakeDb.saveSetting(
        'user_settings',
        UserSettings(
          userName: 'Tester',
          avatarEmoji: '',
          avatarColorValue: 0,
          notificationHour: 21,
          notificationMinute: 0,
          themeMode: 'dark',
          isFirstTime: false,
          vacationDates: [prevDay2Vac],
        ).toMap(),
      );
      await container.read(habitsProvider.notifier).addHabit(
        Habit(
          id: 'h_read',
          name: 'Lectura Nocturna',
          colorValue: 0xFF84A59D,
          targetDays: 20,
          orderIndex: 0,
          activeWeekdays: [1, 2, 3, 4, 5, 6, 7],
          completedDates: {prevDay1, prevDay4, todayIso},
        ),
      );
      await container.read(scheduleProvider.notifier).addBlock(
        ScheduleBlock(
          id: 'b_morning',
          title: 'Turno Mañana',
          startHour: 8,
          startMinute: 0,
          endHour: 15,
          endMinute: 0,
          colorValue: 0xFFFBBF24,
          daysOfWeek: [1, 2, 3, 4, 5],
          hasMonthlyHourTarget: true,
          monthlyTargetHours: 120,
          assignedDates: [prevDay1, prevDay3Heavy, todayIso],
          completedDates: [prevDay1, prevDay3Heavy, todayIso],
          monthlyExtraHours: {
            '${now.year}-${now.month.toString().padLeft(2, '0')}': 2.0,
          },
        ),
      );
      await container.read(scheduleProvider.notifier).addBlock(
        ScheduleBlock(
          id: 'b_night',
          title: 'Turno Nocturno',
          startHour: 23,
          startMinute: 0,
          endHour: 7,
          endMinute: 0,
          colorValue: 0xFF84DCC6,
          daysOfWeek: [1, 2, 3, 4, 5],
          hasMonthlyHourTarget: true,
          monthlyTargetHours: 120,
          assignedDates: [prevDay3Heavy],
          completedDates: [prevDay3Heavy],
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const StatisticsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica los 3 bloques de gráficas vectoriales y el ranking
      expect(find.text('EVOLUCIÓN DE CUMPLIMIENTO'), findsOneWidget);
      expect(find.text('[ 14 DÍAS ]'), findsOneWidget);
      expect(find.text('[ MES COMPLETO ]'), findsOneWidget);
      expect(find.textContaining('RENDIMIENTO SEMANAL'), findsOneWidget);
      expect(find.textContaining('TELEMETRÍA DE HORAS'), findsOneWidget);
      expect(find.text('REALES'), findsOneWidget);
      expect(find.text('PLANIFICADAS'), findsOneWidget);
      expect(find.text('EXTRAS'), findsOneWidget);
      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('DESGLOSE // RANKING DE CONSTANCIA'), findsOneWidget);
      expect(find.text('Lectura Nocturna'), findsOneWidget);

      // Alternar a MES COMPLETO e inspeccionar barra
      await tester.tap(find.text('[ MES COMPLETO ]'));
      await tester.pumpAndSettle();
      expect(find.text('TOCA O DESLIZA UNA BARRA PARA INSPECCIONAR EL DÍA'), findsOneWidget);

      final evoPaint = find.byKey(const ValueKey('evolution_chart_touch_area'));
      await tester.tap(evoPaint);
      await tester.pump();
      expect(find.textContaining('HÁBITOS'), findsWidgets);

      // Navegar al mes anterior donde están Vacaciones + Escudo +12h y Turno Nocturno
      await tester.ensureVisible(find.byIcon(Icons.chevron_left_rounded));
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Noche'), findsOneWidget);
      expect(find.textContaining('ESCUDO RACHA //'), findsOneWidget);
    });

    test('OrbitClock24.getContinuousArcsForDay emits single continuous arc for overnight shift and preserves UserSettings backwards compat', () {
      final today = DateTime(2026, 11, 14, 14, 0);
      final todayIso = today.toIso8601String().split('T').first;
      final nightShift = ScheduleBlock(
        id: 'night_continuous',
        title: 'Turno Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        assignedDates: [todayIso],
      );

      final continuousArcs = OrbitClock24.getContinuousArcsForDay([nightShift], today);
      expect(continuousArcs.length, 1);
      expect(continuousArcs.first.startMinutes, 1380); // 23:00
      expect(continuousArcs.first.sweepMinutes, 480);  // 8 horas continuas

      // Backwards compatibility para UserSettings antiguos sin campos de notificaciones
      final legacy = UserSettings.fromMap({
        'userName': 'Arturo',
        'avatarEmoji': '',
        'avatarColorValue': 0,
        'notificationHour': 21,
        'notificationMinute': 0,
        'themeMode': 'dark',
        'isFirstTime': false,
        'vacationDates': <String>[],
      });
      expect(legacy.notificationsEnabled, isTrue);
      expect(legacy.postActivityReminderEnabled, isTrue);

      final modified = legacy.copyWith(
        notificationsEnabled: false,
        postActivityReminderEnabled: false,
      );
      final roundtrip = UserSettings.fromMap(modified.toMap());
      expect(roundtrip.notificationsEnabled, isFalse);
      expect(roundtrip.postActivityReminderEnabled, isFalse);
    });

    testWidgets('ScheduleBlockCard visually differentiates pending and completed states', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      final todayIso = DateTime.now().toIso8601String().split('T').first;
      const pendingBlock = ScheduleBlock(
        id: 'b_pending',
        title: 'Estudio Deep Work',
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
        colorValue: 0xFF22C55E,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      );
      final completedBlock = pendingBlock.copyWith(
        id: 'b_done',
        completedDates: [todayIso],
        hasMonthlyHourTarget: true,
        monthlyTargetHours: 120,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Column(
                children: [
                  ScheduleBlockCard(block: pendingBlock, onTap: () {}),
                  ScheduleBlockCard(block: completedBlock, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Solo muestra un indicador único ('Hecho hoy') sin duplicar '[ ✓ COMPLETADO ]' ni 'Turno Hecho'
      expect(find.text('[ ✓ COMPLETADO ]'), findsNothing);
      expect(find.text('Turno Hecho'), findsNothing);
      expect(find.text('Hecho hoy'), findsOneWidget);
      expect(find.text('Marcar hoy'), findsOneWidget);
    });

    test('NotificationService.planBlockNotifications schedules pre (-10m / <10m fallback) and post (+10m) with disjoint IDs', () {
      final service = NotificationService();
      // Lunes 2026-11-16 12:00
      final mondayNoon = DateTime(2026, 11, 16, 12, 0);

      const afternoonBlock = ScheduleBlock(
        id: 'block_walk',
        title: 'Caminar',
        startHour: 14,
        startMinute: 0,
        endHour: 15,
        endMinute: 0,
        colorValue: 0xFF22C55E,
        daysOfWeek: [1, 2, 3, 4, 5],
        hasReminder: true,
      );

      final planned = service.planBlockNotifications(
        block: afternoonBlock,
        now: mondayNoon,
      );

      // L-V durante 14 días = 10 días activos * 2 notificaciones = 20
      expect(planned.length, 20);
      expect(planned.where((n) => n.isPre).length, 10);
      expect(planned.where((n) => !n.isPre).length, 10);

      final firstPre = planned.firstWhere((n) => n.isPre);
      final firstPost = planned.firstWhere((n) => !n.isPre);
      expect(firstPre.title, 'En 10 min empieza: Caminar');
      expect(firstPre.triggerAt, DateTime(2026, 11, 16, 13, 50));
      expect(firstPost.title, '¿Completaste Caminar?');
      expect(firstPost.triggerAt, DateTime(2026, 11, 16, 15, 10));

      // Ningún ID debe colisionar
      final uniqueIds = planned.map((n) => n.id).toSet();
      expect(uniqueIds.length, planned.length);

      // Fallback en el mismo día cuando faltan <10 min para iniciar
      final soonBlock = afternoonBlock.copyWith(
        id: 'block_soon',
        startHour: 12,
        startMinute: 5,
        endHour: 12,
        endMinute: 30,
      );
      final soonPlanned = service.planBlockNotifications(
        block: soonBlock,
        now: mondayNoon,
      );
      final todayPreSoon = soonPlanned.firstWhere(
        (n) => n.isPre && n.triggerAt.day == 16,
      );
      expect(todayPreSoon.triggerAt, DateTime(2026, 11, 16, 12, 5));

      // Turno nocturno iniciado ayer (23:00 - 07:00) + omisión de día completado hoy
      final tuesday6am = DateTime(2026, 11, 17, 6, 0);
      const nightBlock = ScheduleBlock(
        id: 'block_night',
        title: 'Turno Noche',
        startHour: 23,
        startMinute: 0,
        endHour: 7,
        endMinute: 0,
        colorValue: 0xFF9EA1D4,
        daysOfWeek: [1, 2], // Lunes y Martes
        completedDates: ['2026-11-17'], // Martes ya marcado
        hasReminder: true,
      );
      final nightPlanned = service.planBlockNotifications(
        block: nightBlock,
        now: tuesday6am,
      );
      // El post-aviso de ayer lunes (termina martes 07:10) SÍ se programa
      expect(
        nightPlanned.any(
          (n) => !n.isPre && n.triggerAt == DateTime(2026, 11, 17, 7, 10),
        ),
        isTrue,
      );
      // Las notificaciones del martes 17 (ya completado) se omiten
      expect(
        nightPlanned.any(
          (n) => n.isPre && n.triggerAt.day == 17,
        ),
        isFalse,
      );
    });

    test('OrbitPainter marks active weekdays and leaves excluded weekend days clean regardless of frequencyType', () {
      final weekdayHabitFreq0 = Habit(
        id: 'h_walk0',
        name: 'Caminar',
        colorValue: 0xFF22C55E,
        targetDays: 20,
        orderIndex: 0,
        activeWeekdays: [1, 2, 3, 4, 5],
        frequencyType: 0,
      );
      final weekdayHabitFreq1 = Habit(
        id: 'h_walk1',
        name: 'Leer',
        colorValue: 0xFFFBBF24,
        targetDays: 15,
        orderIndex: 1,
        activeWeekdays: [1, 2, 3, 4, 5],
        frequencyType: 1,
      );

      final friday = DateTime(2026, 11, 13); // weekday 5
      final saturday = DateTime(2026, 11, 14); // weekday 6
      final sunday = DateTime(2026, 11, 15); // weekday 7

      expect(
        OrbitPainter.isHabitScheduledForDate(
          weekdayHabitFreq0,
          friday,
          '2026-11-13',
          const [],
          false,
        ),
        isTrue,
      );
      expect(
        OrbitPainter.isHabitScheduledForDate(
          weekdayHabitFreq1,
          friday,
          '2026-11-13',
          const [],
          false,
        ),
        isTrue,
      );
      expect(
        OrbitPainter.isHabitScheduledForDate(
          weekdayHabitFreq1,
          saturday,
          '2026-11-14',
          const [],
          false,
        ),
        isFalse,
      );
      expect(
        OrbitPainter.isHabitScheduledForDate(
          weekdayHabitFreq0,
          sunday,
          '2026-11-15',
          const [],
          false,
        ),
        isFalse,
      );
    });

    testWidgets('UnifiedTaskSheet locks reminder when 24H mode is off and unlocks double alerts when enabled', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(fakeDb),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: UnifiedTaskSheet(defaultEnableSchedule: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const lockedMsg =
          'Activa el modo 24H y asigna un horario para recibir notificaciones de esta tarea';
      expect(find.text(lockedMsg), findsOneWidget);

      // Verificamos que el switch de recordatorio esté deshabilitado sin Modo 24H
      final switchesWithout24H = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switchesWithout24H.last.onChanged, isNull);
      expect(switchesWithout24H.last.value, isFalse);

      // Activamos el switch de "Reloj 24h (Rutina diaria)"
      final clockSwitchFinder = find.byWidgetPredicate(
        (w) => w is SwitchListTile && w.title is Row,
      ).first;
      await tester.ensureVisible(clockSwitchFinder);
      await tester.tap(clockSwitchFinder);
      await tester.pumpAndSettle();

      const unlockedMsg =
          'Aviso 10 min antes de empezar y 10 min después de finalizar';
      expect(find.text(unlockedMsg), findsOneWidget);
      expect(find.text('DOBLE AVISO MODO 24H'), findsNothing);
      final switchesWith24H = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switchesWith24H.last.onChanged, isNotNull);
    });

    test('Bidirectional unmarking of past dates removes completion from both Habit and ScheduleBlock without ghost auto-complete', () async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final yesterdayIso = yesterday.toIso8601String().split('T').first;

      await container.read(habitsProvider.notifier).addHabit(
        Habit(
          id: 'h_work',
          name: 'Trabajar',
          colorValue: 0xFFFBBF24,
          targetDays: 20,
          orderIndex: 0,
          completedDates: {yesterdayIso},
        ),
      );
      await container.read(scheduleProvider.notifier).addBlock(
        ScheduleBlock(
          id: 'b_work',
          title: 'Turno Mañana',
          startHour: 10,
          startMinute: 30,
          endHour: 18,
          endMinute: 15,
          colorValue: 0xFFFBBF24,
          habitId: 'h_work',
          daysOfWeek: const [1, 2, 3, 4, 5],
          hasMonthlyHourTarget: true,
          monthlyTargetHours: 120,
          assignedDates: [yesterdayIso],
          completedDates: [yesterdayIso],
        ),
      );

      // Exact minutes duration: 10:30 -> 18:15 = 7h 45m = 7.75h
      final blockInitial = container.read(scheduleProvider).first;
      expect(blockInitial.durationHours, 7.75);
      expect(blockInitial.formattedDuration, '7h 45m');
      expect(ScheduleBlock.formatHours(7.5), '7.5h');
      expect(ScheduleBlock.formatHours(7.75), '7.75h');
      expect(ScheduleBlock.formatHours(8.0), '8h');

      // 1. Unmark past date from HabitNotifier.toggleHabitForDate
      await container.read(habitsProvider.notifier).toggleHabitForDate('h_work', yesterday);
      var habit = container.read(habitsProvider).first;
      var block = container.read(scheduleProvider).first;
      expect(habit.completedDates.contains(yesterdayIso), isFalse);
      expect(block.completedDates.contains(yesterdayIso), isFalse);

      // Even though yesterdayIso is in assignedDates, worked hours must now be 0.0 (not ghost-completed)
      final group = WorkShiftGroup(
        title: 'Trabajar',
        habitId: habit.id,
        habit: habit,
        shifts: [block],
      );
      expect(group.getEffectiveWorkedDatesForShift(block, yesterday), isEmpty);
      expect(block.getMonthlyWorkedHours(yesterday, habit), 0.0);

      // 2. Re-mark only on Habit, then unmark via ScheduleNotifier.toggleShiftCompletion
      await container.read(habitsProvider.notifier).updateHabit(
        habit.copyWith(completedDates: {yesterdayIso}),
      );
      await container.read(scheduleProvider.notifier).toggleShiftCompletion('b_work', yesterday);
      habit = container.read(habitsProvider).first;
      block = container.read(scheduleProvider).first;
      expect(habit.completedDates.contains(yesterdayIso), isFalse);
      expect(block.completedDates.contains(yesterdayIso), isFalse);
    });

    testWidgets('ShiftCalendarScreen supports one-off day blocks, daily extra hours badge, and hides one-off blocks from top palette', (WidgetTester tester) async {
      final fakeDb = FakeDatabaseService();
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(fakeDb)],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      final day10Iso = '${now.year}-${now.month.toString().padLeft(2, '0')}-10';

      await container.read(scheduleProvider.notifier).addBlock(
        const ScheduleBlock(
          id: 'b_fixed',
          title: 'Mañana Fijo',
          startHour: 8,
          startMinute: 0,
          endHour: 15,
          endMinute: 30,
          colorValue: 0xFF84A59D,
          daysOfWeek: [1, 2, 3, 4, 5],
          hasMonthlyHourTarget: true,
        ),
      );
      await container.read(scheduleProvider.notifier).addBlock(
        ScheduleBlock(
          id: 'b_oneoff',
          title: 'Sábado Especial',
          startHour: 9,
          startMinute: 0,
          endHour: 14,
          endMinute: 0,
          colorValue: 0xFFFBBF24,
          daysOfWeek: const [],
          hasMonthlyHourTarget: true,
          assignedDates: [day10Iso],
          isOneOffDayBlock: true,
        ),
      );

      // Add +1.5h daily extra hours on day 10
      await container
          .read(scheduleProvider.notifier)
          .addExtraHoursForDate('b_oneoff', day10Iso, 1.5, DateTime(now.year, now.month, 1));

      final updatedOneOff =
          container.read(scheduleProvider).firstWhere((b) => b.id == 'b_oneoff');
      expect(updatedOneOff.getExtraHoursForDate(day10Iso), 1.5);
      expect(updatedOneOff.getExtraHoursForMonth(DateTime(now.year, now.month, 1)), 1.5);
      expect(ScheduleBlock.fromMap(updatedOneOff.toMap()).isOneOffDayBlock, isTrue);
      expect(ScheduleBlock.fromMap(updatedOneOff.toMap()).getExtraHoursForDate(day10Iso), 1.5);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const ShiftCalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 'Mañana Fijo' appears in top palette; 'Sábado Especial' ONLY appears inside day 10 cell (once), not in top palette
      expect(find.text('Mañana Fijo'), findsOneWidget);
      expect(find.text('Sábado Especial'), findsOneWidget);
      // High-contrast daily extra hours badge '+1.5h' is visible on the calendar grid
      expect(find.text('+1.5h'), findsOneWidget);

      // Tapping day 10 opens the day actions sheet with both options
      await tester.tap(find.text('Sábado Especial'));
      await tester.pumpAndSettle();
      expect(find.text('1. ASIGNAR TURNO EXISTENTE'), findsOneWidget);
      expect(find.text('[ + Horario específico solo para este día ]'), findsOneWidget);
      expect(find.text('PUNTUAL'), findsOneWidget);
    });
  });
}

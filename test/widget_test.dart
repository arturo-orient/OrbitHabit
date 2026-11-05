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

      // Test Achievement 'ee_dedicated'
      final achievementsWithWork = Achievement.calculate([], [], [completedWorkBlock]);
      final dedicatedTrophy = achievementsWithWork.firstWhere((a) => a.id == 'ee_dedicated');
      expect(dedicatedTrophy.isUnlocked, isTrue);
      expect(dedicatedTrophy.title, '🔥 Dedicado');
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
  });
}

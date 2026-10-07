// This is a basic Flutter widget test for OrbitHabit.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbithabit/main.dart';
import 'package:orbithabit/domain/models/habit.dart';
import 'package:orbithabit/domain/models/achievement.dart';
import 'package:orbithabit/domain/models/schedule_block.dart';
import 'package:orbithabit/data/database_service.dart';
import 'package:orbithabit/providers/habit_provider.dart';

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
      final workMonth = DateTime(2026, 10, 1);
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
        completedDates: List.generate(14, (i) => '2026-10-${(i + 1).toString().padLeft(2, '0')}'), // 14 shifts * 8h = 112h
        extraHours: 0.0,
      );

      expect(workBlock.getMonthlyWorkedHours(workMonth), 112.0);
      expect(workBlock.isTargetReached(workMonth), isFalse);

      // Add 2 more shifts (16 shifts * 8h = 128h) -> reaches and exceeds 120h!
      final completedWorkBlock = workBlock.copyWith(
        completedDates: List.generate(16, (i) => '2026-10-${(i + 1).toString().padLeft(2, '0')}'),
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
  });
}

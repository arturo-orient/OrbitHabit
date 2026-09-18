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
  });
}

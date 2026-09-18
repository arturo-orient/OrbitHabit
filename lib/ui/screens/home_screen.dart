import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/streak_utils.dart';
import '../../services/sound_service.dart';
import '../widgets/orbit_tracker.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/day_details_sheet.dart';
import '../widgets/dotted_background.dart';
import '../widgets/habit_progress_card.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/achievements_sheet.dart';
import '../../domain/models/achievement.dart';
import '../widgets/trophy_overlay.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _currentMonth = DateTime.now();

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _showAddHabitSheet() {
    final habits = ref.read(habitsProvider);
    if (habits.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo de 8 hábitos alcanzado.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHabitSheet(),
    );
  }

  void _editHabit(Habit habit) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitSheet(habitToEdit: habit),
    );
  }

  void _showDayDetails(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailsSheet(date: date),
    );
  }


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return 'Buenos Días,';
    } else if (hour >= 12 && hour < 20) {
      return 'Buenas Tardes,';
    } else {
      return 'Buenas Noches,';
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final settings = ref.watch(settingsProvider);
    final showConfetti = ref.watch(confettiStateProvider);
    final monthName = _getMonthName(_currentMonth.month);

    // Nighttime color smoothing: after 22:00 (10 PM), in Dark or Sage themes,
    // we gently desaturate/dim habit colors to make it extra soothing for the eyes.
    final isLateNight = DateTime.now().hour >= 22 || DateTime.now().hour < 6;
    final isRelaxedTheme = settings.themeMode == 'dark' || settings.themeMode == 'sage';
    final shouldDim = isLateNight && isRelaxedTheme;

    final activeHabits = shouldDim
        ? habits.map((h) {
            // Smooth the colors for a peaceful sleep-friendly palette
            final dimmedColor = h.color.withOpacity(0.65);
            return h.copyWith(colorValue: dimmedColor.value);
          }).toList()
        : habits;

    // Dynamic reactive listener to trigger the vector Confetti Celebration on "Perfect Days"
    // and slide in the premium PlayStation-style Achievement Unlocked Popup!
    ref.listen<List<Habit>>(habitsProvider, (previous, next) {
      if (previous == null || previous.isEmpty || next.isEmpty) return;

      // 1. Check for Perfect Day Confetti Celebration
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final prevAllCompleted = previous.every((h) => h.completedDates.contains(todayStr));
      final nextAllCompleted = next.every((h) => h.completedDates.contains(todayStr));

      if (!prevAllCompleted && nextAllCompleted) {
        // Play peaceful celebration, trigger vector confetti and sound
        ref.read(confettiStateProvider.notifier).show();
        SoundService().playPerfectDay(); // Play deep Tibetan Bowl chime!
        HapticFeedback.heavyImpact();
      }

      // 2. Check for Newly Unlocked Achievements
      try {
        final prevAchievements = Achievement.calculate(previous);
        final nextAchievements = Achievement.calculate(next);

        for (final nextAch in nextAchievements) {
          if (nextAch.isUnlocked) {
            final prevAch = prevAchievements.firstWhere(
              (a) => a.id == nextAch.id,
              orElse: () => Achievement(
                id: nextAch.id,
                title: nextAch.title,
                description: nextAch.description,
                progress: 0.0,
                progressText: '',
                isUnlocked: false,
                colorValue: nextAch.colorValue,
              ),
            );

            if (!prevAch.isUnlocked) {
              // Play high quality PlayStation-style chime sound
              SoundService().playTrophy();
              HapticFeedback.heavyImpact();
              // Spawn the premium overlay notification
              TrophyOverlay.show(context, nextAch);
            }
          }
        }
      } catch (e) {
        // Silent robust catch
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DottedBackground(),
            ),
            Column(
              children: [
                const SizedBox(height: 16),
                // Cabecera Dinámica: Saludo según Hora del Día + Avatar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 28,
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            settings.userName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                        Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '📊',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: settings.avatarColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: settings.avatarColor.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                settings.avatarEmoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Botón del Mes (Pastilla central)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFFE6A590)),
                          onPressed: () => _changeMonth(-1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          settings.vacationDates.contains(DateTime.now().toIso8601String().split('T').first) 
                            ? 'EN PAUSA 🏖️' 
                            : monthName.toUpperCase(),
                          style: TextStyle(
                            color: settings.vacationDates.contains(DateTime.now().toIso8601String().split('T').first)
                              ? const Color(0xFF4FC3F7) // Azul piscina para vacaciones
                              : const Color(0xFFE6A590),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFFE6A590)),
                          onPressed: () => _changeMonth(1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Orbit Tracker (La Rueda)
                Expanded(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OrbitTracker(
                          habits: activeHabits, // Render dimmed colors at night!
                          currentMonth: _currentMonth,
                          onDayColumnTapped: _showDayDetails,
                        ),
                      ),
                    ),
                  ),
                ),

                // Lista de Hábitos con cálculo de Rachas
                Expanded(
                  flex: 4,
                  child: activeHabits.isEmpty
                      ? Center(child: Text('Sin hábitos', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4))))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: activeHabits.length,
                          itemBuilder: (context, index) {
                            final habit = activeHabits[index];
                            final monthPrefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
                            final completedThisMonth = habit.completedDates.where((d) => d.startsWith(monthPrefix)).length;
                            final percentage = habit.hasMonthlyTarget 
                                ? (completedThisMonth / habit.targetDays * 100).clamp(0, 100).toInt()
                                : null;
                            
                            final streak = StreakUtils.calculateCurrentStreak(habit, settings.vacationDates);

                            return GestureDetector(
                              onTap: () => _editHabit(habit),
                              child: HabitProgressCard(
                                name: habit.name,
                                color: habit.color,
                                percentage: percentage,
                                streak: streak,
                              ),
                            );
                          },
                        ),
                ),

                // Botón Añadir Hábito (Inferior)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _showAddHabitSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA2B395), // Verde salvia
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Añadir Hábito',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.add, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Fullscreen vector celebration overlay
            if (showConfetti)
              Positioned.fill(
                child: ConfettiOverlay(
                  onFinished: () {
                    ref.read(confettiStateProvider.notifier).hide();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }
}

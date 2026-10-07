import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../domain/models/schedule_block.dart';
import '../../providers/schedule_provider.dart';
import '../widgets/trophy_overlay.dart';
import '../widgets/orbit_clock_24.dart';
import '../widgets/add_schedule_block_sheet.dart';
import '../widgets/schedule_block_card.dart';
import '../widgets/monthly_work_target_card.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _currentMonth = DateTime.now();
  int _selectedView = 0; // 0 = Órbita Mensual, 1 = Reloj Horario 24h

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _showAddScheduleBlockSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddScheduleBlockSheet(),
    );
  }

  void _editScheduleBlock(ScheduleBlock block) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddScheduleBlockSheet(blockToEdit: block),
    );
  }

  String _getTodayDateLabel() {
    final now = DateTime.now();
    const dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final dayName = dayNames[now.weekday - 1];
    final monthName = _getMonthName(now.month);
    return '$dayName, ${now.day} de $monthName'.toUpperCase();
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
    final scheduleBlocks = ref.watch(scheduleProvider);
    final showConfetti = ref.watch(confettiStateProvider);
    final monthName = _getMonthName(_currentMonth.month);

    final now = DateTime.now();
    // Filter and sort today's schedule blocks (including overnight shifts from yesterday)
    final todayBlocks = scheduleBlocks.where((b) {
      return b.appliesToWeekday(now.weekday) ||
          (b.isOvernight && b.appliesToWeekday(now.weekday == 1 ? 7 : now.weekday - 1));
    }).toList()
      ..sort((a, b) => a.startInMinutes.compareTo(b.startInMinutes));

    final monthlyWorkBlocks = scheduleBlocks.where((b) => b.hasMonthlyHourTarget).toList();

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
        final prevAchievements = Achievement.calculate(previous, settings.vacationDates, scheduleBlocks);
        final nextAchievements = Achievement.calculate(next, settings.vacationDates, scheduleBlocks);

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

    // Reactive listener for Schedule changes (e.g. unlocking "Dedicado" when reaching 120h of work!)
    ref.listen<List<ScheduleBlock>>(scheduleProvider, (previous, next) {
      if (previous == null || previous.isEmpty || next.isEmpty) return;
      try {
        final currentHabits = ref.read(habitsProvider);
        final prevAchievements = Achievement.calculate(currentHabits, settings.vacationDates, previous);
        final nextAchievements = Achievement.calculate(currentHabits, settings.vacationDates, next);

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
              SoundService().playTrophy();
              HapticFeedback.heavyImpact();
              TrophyOverlay.show(context, nextAch);
            }
          }
        }
      } catch (_) {}
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
                const SizedBox(height: 20),

                // Selector de Vista Zen: [ 🪐 Órbita ] | [ ⏰ Reloj 24h ]
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewTab(0, '🪐 Órbita'),
                        _buildViewTab(1, '⏰ Reloj 24h'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // VISTA 0: ÓRBITA MENSUAL CLÁSICA
                if (_selectedView == 0) ...[
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

                  // Lista de Hábitos y Metas Mensuales de Horas
                  Expanded(
                    flex: 4,
                    child: (activeHabits.isEmpty && monthlyWorkBlocks.isEmpty)
                        ? Center(
                            child: Text(
                              'Sin hábitos ni metas',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: monthlyWorkBlocks.length + activeHabits.length,
                            itemBuilder: (context, index) {
                              if (index < monthlyWorkBlocks.length) {
                                final block = monthlyWorkBlocks[index];
                                return MonthlyWorkTargetCard(
                                  block: block,
                                  currentMonth: _currentMonth,
                                  onTap: () => _editScheduleBlock(block),
                                );
                              }

                              final habitIndex = index - monthlyWorkBlocks.length;
                              final habit = activeHabits[habitIndex];
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
                ] else ...[
                  // VISTA 1: RELOJ ORBITAL 24H (HORARIO / RUTINA)
                  // Pastilla de Fecha de Hoy
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.today, size: 16, color: Color(0xFFE6A590)),
                          const SizedBox(width: 8),
                          Text(
                            _getTodayDateLabel(),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFE6A590),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Reloj Orbital de 24 Horas
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: OrbitClock24(
                            blocks: todayBlocks,
                            onBlockTapped: _editScheduleBlock,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lista de Bloques del Horario de Hoy
                  Expanded(
                    flex: 4,
                    child: todayBlocks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sin bloques para hoy',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Añade tus turnos de trabajo, descanso y hábitos.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: todayBlocks.length,
                            itemBuilder: (context, index) {
                              final block = todayBlocks[index];
                              return ScheduleBlockCard(
                                block: block,
                                onTap: () => _editScheduleBlock(block),
                              );
                            },
                          ),
                  ),

                  // Botón Añadir Bloque Horario (Inferior)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _showAddScheduleBlockSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9EA1D4), // Periwinkle
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Añadir Bloque Horario',
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

  Widget _buildViewTab(int index, String title) {
    final isSelected = _selectedView == index;
    final theme = Theme.of(context);
    const activeColor = Color(0xFF84A59D); // Verde salvia Zen

    return GestureDetector(
      onTap: () {
        if (_selectedView != index) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedView = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: activeColor.withOpacity(0.4), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeColor
                : theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

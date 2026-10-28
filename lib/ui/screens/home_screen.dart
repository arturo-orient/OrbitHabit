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
import '../widgets/unified_task_sheet.dart';
import '../widgets/staggered_accordion_item.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'shift_calendar_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  DateTime _currentMonth = DateTime.now();
  int _selectedView = 0; // 0 = Órbita Mensual, 1 = Reloj Horario 24h
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Esperar a que el lienzo esté completamente pintado antes de iniciar la cascada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _entranceController.forward(from: 0.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _replayEntrance() {
    if (mounted) {
      _entranceController.forward(from: 0.0);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
    _replayEntrance();
  }

  void _showAddScheduleBlockSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const UnifiedTaskSheet(defaultEnableSchedule: true),
        ),
      ),
    );
  }

  void _editScheduleBlock(ScheduleBlock block) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: UnifiedTaskSheet(blockToEdit: block),
        ),
      ),
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

    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const UnifiedTaskSheet(defaultEnableSchedule: false),
        ),
      ),
    );
  }

  void _editHabit(Habit habit) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: UnifiedTaskSheet(habitToEdit: habit),
        ),
      ),
    );
  }

  void _showDayDetails(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DayDetailsSheet(date: date),
        ),
      ),
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
    final yesterday = now.subtract(const Duration(days: 1));
    // Filter and sort today's schedule blocks (including overnight shifts from yesterday)
    final todayBlocks = scheduleBlocks.where((b) {
      return b.appliesToDate(now) ||
          (b.isOvernight && b.appliesToDate(yesterday));
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

    // Filter out habits that already have their dedicated rich MonthlyWorkTargetCard
    final regularHabits = activeHabits.where((h) {
      return !monthlyWorkBlocks.any((b) =>
          b.habitId == h.id ||
          b.title.trim().toLowerCase() == h.name.trim().toLowerCase());
    }).toList();

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.25),
                radius: 1.1,
                colors: [
                  isDark ? const Color(0xFF141418) : const Color(0xFFFAF9F6),
                  isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
                ],
              ),
              border: Border.symmetric(
                vertical: BorderSide(
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                  width: AppTheme.borderPrecision,
                ),
              ),
            ),
            child: Column(
              children: [
                // TOP BAR: BRAND & CONTROLS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                        width: AppTheme.borderPrecision,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Marca & Usuario
                      Row(
                        children: [
                          Text(
                            'OrbitHabit',
                            style: AppTheme.displayStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: AppTheme.radiusXs,
                            ),
                            child: Text(
                              settings.userName.toUpperCase(),
                              style: AppTheme.monoStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppTheme.dynamicAccent(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Cluster de Controles de Precisión
                      Row(
                        children: [
                          // Selector de vista compacto [ ÓRBITA | 24H ]
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: AppTheme.bentoCard(
                              isLight: !isDark,
                              borderRadius: AppTheme.radiusXs,
                            ),
                            child: Row(
                              children: [
                                _buildCompactViewTab(0, Icons.adjust_rounded, 'ÓRBITA'),
                                _buildCompactViewTab(1, Icons.schedule_rounded, '24H'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Estadísticas
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: AppTheme.bentoCard(
                                isLight: !isDark,
                                borderRadius: AppTheme.radiusXs,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.bar_chart_rounded,
                                size: 17,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Ajustes
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: AppTheme.bentoCard(
                                isLight: !isDark,
                                borderRadius: AppTheme.radiusXs,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.tune_rounded,
                                size: 17,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // VISTA 0: ÓRBITA MENSUAL CLÁSICA
                if (_selectedView == 0) ...[
                  // Barra de Estado del Mes (Instrumento)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Selector del mes
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _changeMonth(-1),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: AppTheme.bentoCard(
                                  isLight: !isDark,
                                  borderRadius: AppTheme.radiusXs,
                                ),
                                child: Icon(
                                  Icons.chevron_left,
                                  size: 16,
                                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                settings.vacationDates.contains(DateTime.now().toIso8601String().split('T').first)
                                    ? 'PAUSA'
                                    : monthName.toUpperCase(),
                                style: AppTheme.monoStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _changeMonth(1),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: AppTheme.bentoCard(
                                  isLight: !isDark,
                                  borderRadius: AppTheme.radiusXs,
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Telemetría del mes
                        Text(
                          '// RADIAL DIAL',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                      ],
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
                            habits: activeHabits,
                            scheduleBlocks: scheduleBlocks,
                            currentMonth: _currentMonth,
                            onDayColumnTapped: _showDayDetails,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Separador de Sección Técnico
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'REGISTRO // HÁBITOS',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '[${regularHabits.length.toString().padLeft(2, '0')}]',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.dynamicAccent(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de Hábitos y Metas Mensuales de Horas
                  Expanded(
                    flex: 4,
                    child: (regularHabits.isEmpty && monthlyWorkBlocks.isEmpty)
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: monthlyWorkBlocks.length + regularHabits.length,
                            itemBuilder: (context, index) {
                              if (index < monthlyWorkBlocks.length) {
                                final block = monthlyWorkBlocks[index];
                                return StaggeredAccordionItem(
                                  key: ValueKey('work_block_${block.id}'),
                                  index: index,
                                  parentAnimation: _entranceController,
                                  child: MonthlyWorkTargetCard(
                                    block: block,
                                    currentMonth: _currentMonth,
                                    onTap: () => _editScheduleBlock(block),
                                  ),
                                );
                              }

                              final habitIndex = index - monthlyWorkBlocks.length;
                              final habit = regularHabits[habitIndex];
                              final monthPrefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
                              final completedThisMonth = habit.completedDates.where((d) => d.startsWith(monthPrefix)).length;
                              final percentage = habit.hasMonthlyTarget 
                                  ? (completedThisMonth / habit.targetDays * 100).clamp(0, 100).toInt()
                                  : null;
                              
                              final streak = StreakUtils.calculateCurrentStreak(habit, settings.vacationDates);

                              // Telemetría de los 7 días de la semana en curso (Lunes a Domingo)
                              final now = DateTime.now();
                              final todayIso = now.toIso8601String().split('T').first;
                              final monday = now.subtract(Duration(days: now.weekday - 1));
                              final weeklyCompletions = List.generate(7, (i) {
                                final d = monday.add(Duration(days: i));
                                final iso = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                return habit.completedDates.contains(iso);
                              });

                              return StaggeredAccordionItem(
                                key: ValueKey('habit_${habit.id}'),
                                index: index,
                                parentAnimation: _entranceController,
                                child: HabitProgressCard(
                                  name: habit.name,
                                  color: habit.color,
                                  percentage: percentage,
                                  streak: streak,
                                  weeklyCompletions: weeklyCompletions,
                                  isCompletedToday: habit.completedDates.contains(todayIso),
                                  onToggleToday: () {
                                    SoundService().playCheck();
                                    ref.read(habitsProvider.notifier).toggleDay(habit.id, todayIso);
                                  },
                                  onTap: () => _editHabit(habit),
                                ),
                              );
                            },
                          ),
                  ),

                  // Botón Añadir Hábito (Bento de precisión)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _showAddHabitSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                          foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusSm,
                            side: BorderSide(
                              color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: AppTheme.dynamicAccent(isDark),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Añadir Hábito',
                              style: AppTheme.bodyStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // VISTA 1: RELOJ ORBITAL 24H (HORARIO / RUTINA)
                  // Barra Superior del Reloj 24h: Fecha + Botón Planificador de Turnos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                            borderRadius: AppTheme.radiusSm,
                            border: Border.all(
                              color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: AppTheme.dynamicAccent(isDark),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getTodayDateLabel(),
                                style: AppTheme.monoStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTheme.obsidianTextPrimary
                                      : AppTheme.boneTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ShiftCalendarScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.12),
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.35),
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 14,
                                  color: AppTheme.dynamicAccent(isDark),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cuadrante Turnos',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.dynamicAccent(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                              return StaggeredAccordionItem(
                                key: ValueKey('schedule_block_${block.id}'),
                                index: index,
                                parentAnimation: _entranceController,
                                child: ScheduleBlockCard(
                                  block: block,
                                  onTap: () => _editScheduleBlock(block),
                                ),
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
          ),
        ),
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

  Widget _buildCompactViewTab(int index, IconData icon, String label) {
    final isSelected = _selectedView == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_selectedView != index) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedView = index;
          });
          _replayEntrance();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? AppTheme.dynamicAccent(isDark)
                  : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.monoStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary)
                    : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: AppTheme.bentoCard(
          isLight: !isDark,
          borderRadius: AppTheme.radiusMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: AppTheme.radiusSm,
                border: Border.all(
                  color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                  width: AppTheme.borderPrecision,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.adjust_rounded,
                size: 20,
                color: AppTheme.dynamicAccent(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '// SISTEMA EN ESPERA',
              style: AppTheme.monoStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No hay hábitos ni bloques configurados todavía.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showAddHabitSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.radiusXs,
                  side: BorderSide(
                    color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                    width: AppTheme.borderPrecision,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: AppTheme.dynamicAccent(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    'INICIALIZAR HÁBITO',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

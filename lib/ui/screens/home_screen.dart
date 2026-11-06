import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/settings_provider.dart';
import '../../domain/models/user_settings.dart';
import '../../utils/streak_utils.dart';
import '../../services/sound_service.dart';
import '../../services/backup_service.dart';
import '../widgets/orbit_tracker.dart';
import '../widgets/day_details_sheet.dart';
import '../widgets/habit_progress_card.dart';
import '../widgets/confetti_overlay.dart';
import '../../domain/models/achievement.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/schedule_provider.dart';
import '../widgets/trophy_overlay.dart';
import '../widgets/orbit_clock_24.dart';
import '../widgets/schedule_block_card.dart';
import '../widgets/monthly_work_target_card.dart';
import '../widgets/unified_task_sheet.dart';
import '../widgets/staggered_accordion_item.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import '../widgets/orbit_guide_sheet.dart';
import 'shift_calendar_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  DateTime _currentMonth = DateTime.now();
  int _selectedView = 0; // 0 = Órbita Mensual, 1 = Reloj Horario 24h
  int? _tourStep; // null = inactivo, 0..4 = tour guiado interactivo
  late AnimationController _entranceController;

  void _goToTourStep(int? step) {
    HapticFeedback.selectionClick();
    setState(() {
      _tourStep = step;
      if (step != null) {
        if (step == 2 || step == 3) {
          _selectedView = 1;
        } else {
          _selectedView = 0;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Esperar a que el lienzo esté completamente pintado antes de iniciar la cascada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(habitsProvider.notifier).consolidateWorkHabits(ref.read(scheduleProvider));
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

  void _editScheduleGroup(WorkShiftGroup group) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: UnifiedTaskSheet(
            habitToEdit: group.habit,
            blockToEdit: group.shifts.isNotEmpty ? group.shifts.first : null,
          ),
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

  void _showReorderHabitsSheet() {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final habits = ref.watch(habitsProvider);
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                  width: AppTheme.borderPrecision,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 20, color: AppTheme.dynamicAccent(isDark)),
                          const SizedBox(width: 8),
                          Text(
                            'Reordenar Hábitos',
                            style: AppTheme.displayStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.15),
                            borderRadius: AppTheme.radiusXs,
                            border: Border.all(
                              color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.35),
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                          child: Text(
                            'Listo',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.dynamicAccent(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mantén pulsado y arrastra cualquier hábito para cambiar su posición en la lista.',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        physics: const BouncingScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: habits.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.selectionClick();
                          ref.read(habitsProvider.notifier).reorderHabits(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 0,
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final h = habits[index];
                          return Container(
                            key: ValueKey(h.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: h.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    h.name,
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  h.hasMonthlyTarget ? '${h.targetDays} días' : '${h.subTasks.length} subtareas',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReorderBlocksSheet() {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final allBlocks = ref.watch(scheduleProvider);
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                  width: AppTheme.borderPrecision,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 20, color: AppTheme.dynamicAccent(isDark)),
                          const SizedBox(width: 8),
                          Text(
                            'Reordenar Horarios 24h',
                            style: AppTheme.displayStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.15),
                            borderRadius: AppTheme.radiusXs,
                            border: Border.all(
                              color: AppTheme.dynamicAccent(isDark).withValues(alpha: 0.35),
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                          child: Text(
                            'Listo',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.dynamicAccent(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Arrastra para cambiar el orden de tus bloques en el reloj y en la lista diaria.',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        physics: const BouncingScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: allBlocks.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.selectionClick();
                          ref.read(scheduleProvider.notifier).reorderBlocks(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 0,
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final b = allBlocks[index];
                          return Container(
                            key: ValueKey(b.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 18,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: b.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    b.title,
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${b.startHour.toString().padLeft(2, '0')}:${b.startMinute.toString().padLeft(2, '0')} - ${b.endHour.toString().padLeft(2, '0')}:${b.endMinute.toString().padLeft(2, '0')}',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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




  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final settings = ref.watch(settingsProvider);
    final scheduleBlocks = ref.watch(scheduleProvider);
    final showConfetti = ref.watch(confettiStateProvider);
    final monthName = _getMonthName(_currentMonth.month);

    final heavyDutyShield = StreakUtils.computeHeavyDutyShieldDates(scheduleBlocks);
    final effectiveVacationDates = {...settings.vacationDates, ...heavyDutyShield}.toList();

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    // Filter and sort today's schedule blocks (including overnight shifts from yesterday)
    final todayBlocks = scheduleBlocks.where((b) {
      return b.appliesToDate(now) ||
          (b.isOvernight && b.appliesToDate(yesterday));
    }).toList()
      ..sort((a, b) => a.startInMinutes.compareTo(b.startInMinutes));

    // Modelo de Vista Orbital ensamblado de forma limpia y desacoplada
    final orbitVm = _computeOrbitViewModel(
      habits: habits,
      scheduleBlocks: scheduleBlocks,
      settings: settings,
      now: now,
    );
    final workShiftGroups = orbitVm.workShiftGroups;
    final regularHabits = orbitVm.regularHabits;
    final orbitHabits = orbitVm.orbitHabits;

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
                      // Marca
                      Text(
                        'OrbitHabit',
                        style: AppTheme.displayStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                        ),
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

                          // Tour Guiado Interactivo / Manual Técnico
                          GestureDetector(
                            onTap: () => _goToTourStep(0),
                            onLongPress: () {
                              HapticFeedback.selectionClick();
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => FractionallySizedBox(
                                  heightFactor: 0.88,
                                  child: OrbitGuideSheet(
                                    onStartTour: () => _goToTourStep(0),
                                  ),
                                ),
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
                                Icons.help_outline_rounded,
                                size: 17,
                                color: _tourStep != null
                                    ? AppTheme.dynamicAccent(isDark)
                                    : (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
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

                // BANNER: MODO DEMO ACTIVO
                if (DemoSeederService.isDemoModeActive(habits, scheduleBlocks))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1A10) : const Color(0xFFFFFBEB),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFFE5D08F).withValues(alpha: 0.3) : const Color(0xFFFDE68A),
                          width: AppTheme.borderPrecision,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.science_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFFE5D08F) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'MODO DEMO ACTIVO · Datos de prueba',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFE5D08F) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await DemoSeederService.exitDemoMode(ref);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: Text(
                                  'Modo Demo desactivado',
                                  style: AppTheme.bodyStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFFE5D08F).withValues(alpha: 0.15) : const Color(0xFFFEF3C7),
                              borderRadius: AppTheme.radiusXs,
                              border: Border.all(
                                color: isDark ? const Color(0xFFE5D08F).withValues(alpha: 0.4) : const Color(0xFFF59E0B),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '✕ Salir de la Demo',
                              style: AppTheme.displayStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE5D08F) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Transición Dimensional Suiza entre Modo Órbita (Rueda Mensual) y Reloj 24h
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
                        ),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.965, end: 1.0).animate(
                            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: _selectedView == 0
                        ? Column(
                            key: const ValueKey<int>(0),
                            children: [
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

                        // Botón Calendario (unificado con Vista 24H)
                        _buildCalendarButton(isDark),
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
                            habits: orbitHabits,
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        Text(
                          'HÁBITOS',
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
                        if (habits.length > 1) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _showReorderHabitsSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                borderRadius: AppTheme.radiusXs,
                                border: Border.all(
                                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                  width: AppTheme.borderPrecision,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_vert_rounded, size: 13, color: AppTheme.dynamicAccent(isDark)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'REORDENAR',
                                    style: AppTheme.monoStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Lista de Hábitos y Metas Mensuales de Horas
                  Expanded(
                    flex: 4,
                    child: (regularHabits.isEmpty && workShiftGroups.isEmpty)
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: workShiftGroups.length + regularHabits.length,
                            itemBuilder: (context, index) {
                              if (index < workShiftGroups.length) {
                                final group = workShiftGroups[index];
                                return StaggeredAccordionItem(
                                  key: ValueKey('work_group_${group.title}_${group.shifts.map((s) => s.id).join("_")}'),
                                  index: index,
                                  parentAnimation: _entranceController,
                                  child: MonthlyWorkTargetCard(
                                    group: group,
                                    currentMonth: _currentMonth,
                                    onTap: () => _editScheduleGroup(group),
                                    onEditShift: (shift) => _editScheduleBlock(shift),
                                  ),
                                );
                              }

                              final habitIndex = index - workShiftGroups.length;
                              final habit = regularHabits[habitIndex];
                              final monthPrefix = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';
                              final completedThisMonth = habit.completedDates.where((d) => d.startsWith(monthPrefix)).length;
                              final percentage = habit.hasMonthlyTarget 
                                  ? (completedThisMonth / habit.targetDays * 100).clamp(0, 100).toInt()
                                  : null;
                              
                              final streak = StreakUtils.calculateCurrentStreak(habit, effectiveVacationDates);

                              // Telemetría de los 7 días de la semana en curso (Lunes a Domingo)
                              final now = DateTime.now();
                              final todayIso = now.toIso8601String().split('T').first;
                              final weeklyCompletions = List.generate(7, (i) {
                                final d = DateTime(now.year, now.month, now.day - (now.weekday - 1) + i);
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
                                  subTasks: habit.subTasks,
                                  todayIso: todayIso,
                                  onToggleSubTask: (st) {
                                    HapticFeedback.selectionClick();
                                    SoundService().playCheck();
                                    ref.read(habitsProvider.notifier).toggleSubTask(habit.id, st.id, todayIso);
                                  },
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
                ],
              )
            : Column(
                key: const ValueKey<int>(1),
                children: [
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
                        _buildCalendarButton(isDark),
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

                  // Separador de Sección Técnico para 24h
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                    child: Row(
                      children: [
                        Text(
                          'HOY // BLOQUES 24H',
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
                          '[${todayBlocks.length.toString().padLeft(2, '0')}]',
                          style: AppTheme.monoStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.dynamicAccent(isDark),
                          ),
                        ),
                        if (scheduleBlocks.length > 1) ...[
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _showReorderBlocksSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                borderRadius: AppTheme.radiusXs,
                                border: Border.all(
                                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                  width: AppTheme.borderPrecision,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_vert_rounded, size: 13, color: AppTheme.dynamicAccent(isDark)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'REORDENAR',
                                    style: AppTheme.monoStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Lista de Bloques del Horario de Hoy
                  Expanded(
                    flex: 4,
                    child: todayBlocks.isEmpty
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                              decoration: AppTheme.bentoCard(
                                isLight: !isDark,
                                borderRadius: AppTheme.radiusMd,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '// SIN BLOQUES PARA HOY',
                                    style: AppTheme.monoStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Añade tus turnos de trabajo, descanso y hábitos.',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13,
                                      color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
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

                  // Botón Añadir Bloque Horario (Bento de precisión)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _showAddScheduleBlockSheet,
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
                              'Añadir Bloque Horario',
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
                ],
              ),
            ),
          ),
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
        if (_tourStep != null)
          _buildTourOverlay(isDark),
        ],
      ),
    ),
  );
}

  Widget _buildTourOverlay(bool isDark) {
    if (_tourStep == null) return const SizedBox.shrink();

    final step = _tourStep!;
    final accent = AppTheme.dynamicAccent(isDark);

    final List<({
      String tag,
      String title,
      String body,
      IconData icon,
      String focusText,
    })> tourSteps = [
      (
        tag: 'PASO 1 DE 5 // VISTA MENSUAL',
        title: '¡Bienvenido a tu Rueda del Mes! 🪐',
        body: 'Olvídate de las listas aburridas. Aquí cada anillo es uno de tus hábitos y los números del 1 al 31 son los días del mes. Cuando cumples un día, su casilla se ilumina a todo color. Si un día te toca descansar, dejamos el hueco limpio para que no te agobies.',
        icon: Icons.adjust_rounded,
        focusText: 'Enfocando la Rueda Orbital concéntrica',
      ),
      (
        tag: 'PASO 2 DE 5 // HÁBITOS & TRABAJO',
        title: 'Tus Hábitos y tu Bolsa de Horas 💼',
        body: 'Aquí abajo verás tus hábitos diarios y tu tarjeta de trabajo. Si trabajas por turnos (mañanas, tardes o noches), todos se agrupan en una sola tarjeta para sumar tus horas del mes (por ejemplo, 120h) sin llenar la pantalla de ruido. Puedes pulsar \'Registrar Hoy\' para fichar en un segundo.',
        icon: Icons.work_outline_rounded,
        focusText: 'Enfocando las Tarjetas inferiores y Turnos agrupados',
      ),
      (
        tag: 'PASO 3 DE 5 // CICLO DIARIO',
        title: 'Tu Día en 24 Horas ⏰',
        body: 'Hemos cambiado a la vista de Reloj 24H. Es como ver todo tu día de un vistazo desde las 00:00 hasta la medianoche. El puntito brillante se mueve en tiempo real contigo, y si tienes un turno de noche que cruza las 12 de la noche, el reloj lo une sin romperse. Además, si tocas cualquier franja de color, puedes editarla.',
        icon: Icons.schedule_rounded,
        focusText: 'Enfocando el Reloj Polar 24h y los arcos táctiles',
      ),
      (
        tag: 'PASO 4 DE 5 // PLANIFICADOR RÁPIDO',
        title: 'Pinta tu Mes en Segundos 🗓️',
        body: '¿Tienes horarios rotativos que cambian cada semana? Pulsa en \'Cuadrante Turnos\'. Ahí podrás elegir tu turno como si fuera un pincel, tocar los días del calendario para armar tu mes entero y descargar un póster en imagen de alta calidad para compartirlo.',
        icon: Icons.calendar_month_rounded,
        focusText: 'Enfocando el botón Cuadrante Turnos (arriba a la derecha)',
      ),
      (
        tag: 'PASO 5 DE 5 // LISTOS PARA COMENZAR',
        title: '¡Todo listo para despegar! 🚀',
        body: 'Si quieres trastear con la app llena de datos antes de crear tus propios hábitos, pulsa el botón de abajo para activar el Modo Demo. Podrás quitarlo cuando quieras con un solo clic desde la barra superior.',
        icon: Icons.rocket_launch_rounded,
        focusText: 'Todo configurado para empezar',
      ),
    ];

    final current = tourSteps[step.clamp(0, 4)];

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.40),
        child: SafeArea(
          child: Column(
            children: [
              // Indicador visual superior de sección enfocada
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 16, right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141418) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(current.icon, size: 15, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        current.focusText,
                        style: AppTheme.monoStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Tarjeta Neo-Bento Flotante del Tour
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera del Tour
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              current.tag,
                              style: AppTheme.monoStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 1.0,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _tourStep = null);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Barra de progreso de 5 pasos
                        Row(
                          children: List.generate(5, (index) {
                            final isPassed = index <= step;
                            return Expanded(
                              child: Container(
                                height: 3.5,
                                margin: EdgeInsets.only(right: index < 4 ? 6.0 : 0.0),
                                decoration: BoxDecoration(
                                  color: isPassed
                                      ? accent
                                      : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Título Humano
                        Text(
                          current.title,
                          style: AppTheme.displayStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Descripción Humana
                        Text(
                          current.body,
                          style: AppTheme.bodyStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Botones de Navegación del Tour
                        if (step == 4) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _tourStep = null);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: BorderSide(
                                      color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                  ),
                                  child: Text(
                                    '¡Entendido, empezar!',
                                    style: AppTheme.displayStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    await DemoSeederService.seedDemoData(ref);
                                    _replayEntrance();
                                    setState(() => _tourStep = null);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                        backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                                        content: Text(
                                          'Órbita de demostración cargada con éxito ⚡',
                                          style: AppTheme.monoStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                  ),
                                  child: Text(
                                    '⚡ Probar Modo Demo',
                                    style: AppTheme.displayStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (step > 0)
                                TextButton(
                                  onPressed: () => _goToTourStep(step - 1),
                                  child: Text(
                                    '← Anterior',
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                )
                              else
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _tourStep = null);
                                  },
                                  child: Text(
                                    'Cerrar tutorial',
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: () => _goToTourStep(step + 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Siguiente',
                                      style: AppTheme.displayStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.black : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: isDark ? Colors.black : Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }

  Widget _buildCalendarButton(bool isDark) {
    final accent = AppTheme.dynamicAccent(isDark);
    return GestureDetector(
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
          color: accent.withValues(alpha: 0.12),
          borderRadius: AppTheme.radiusSm,
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: AppTheme.borderPrecision,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: accent,
            ),
            const SizedBox(width: 6),
            Text(
              'Calendario',
              style: AppTheme.monoStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactViewTab(int index, IconData icon, String label) {
    final isSelected = _selectedView == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);

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
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.45 : 0.35)
                : Colors.transparent,
            width: AppTheme.borderPrecision,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? accent
                  : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTheme.monoStyle(
                fontSize: 11.5,
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
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await DemoSeederService.seedDemoData(ref);
                _replayEntrance();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                      backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                      content: Text(
                        'Órbita de demostración cargada con éxito ⚡',
                        style: AppTheme.monoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dynamicAccent(isDark),
                        ),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.radiusXs,
                  side: BorderSide(
                    color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                    width: AppTheme.borderPrecision,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppTheme.dynamicAccent(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    '⚡ CARGAR ÓRBITA DEMO',
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

  /// Ensambla el modelo de vista orbital desacoplando turnos rotativos y hábitos
  ({
    List<WorkShiftGroup> workShiftGroups,
    List<Habit> regularHabits,
    List<Habit> orbitHabits,
  }) _computeOrbitViewModel({
    required List<Habit> habits,
    required List<ScheduleBlock> scheduleBlocks,
    required UserSettings settings,
    required DateTime now,
  }) {
    final monthlyWorkBlocks = scheduleBlocks.where((b) => b.hasMonthlyHourTarget).toList();

    // Agrupación unificada de turnos bajo una sola actividad madre ("Trabajar" / "Trabajo")
    final List<WorkShiftGroup> workShiftGroups = [];
    final Set<String> processedWorkBlockIds = {};

    for (final b in monthlyWorkBlocks) {
      if (processedWorkBlockIds.contains(b.id)) continue;

      Habit? linkedHabit;
      // 1. Prioridad: vinculación explícita por ID
      if (b.habitId != null) {
        linkedHabit = habits.cast<Habit?>().firstWhere(
              (h) => h?.id == b.habitId,
              orElse: () => null,
            );
      }
      // 2. Fallback secundario: coincidencia por título o palabras clave
      linkedHabit ??= habits.cast<Habit?>().firstWhere(
            (h) =>
                h != null &&
                (h.name.trim().toLowerCase() == b.title.trim().toLowerCase() ||
                 (h.name.toLowerCase().contains('trabaj') && b.title.toLowerCase().contains('trabaj')) ||
                 (h.name.toLowerCase().contains('turno') && b.title.toLowerCase().contains('turno'))),
            orElse: () => null,
          );

      final List<ScheduleBlock> groupBlocks = [];
      for (final other in monthlyWorkBlocks) {
        if (processedWorkBlockIds.contains(other.id)) continue;

        bool belongs = false;
        if (linkedHabit != null) {
          if (other.habitId == linkedHabit.id) belongs = true;
          if (other.title.trim().toLowerCase() == linkedHabit.name.trim().toLowerCase()) belongs = true;
          if (linkedHabit.name.toLowerCase().contains('trabaj') && other.title.toLowerCase().contains('trabaj')) belongs = true;
          if (linkedHabit.name.toLowerCase().contains('turno') && other.title.toLowerCase().contains('turno')) belongs = true;
        } else {
          if (other.id == b.id) belongs = true;
          if (other.title.toLowerCase().contains('trabaj') && b.title.toLowerCase().contains('trabaj')) belongs = true;
          if (other.title.toLowerCase().contains('turno') && b.title.toLowerCase().contains('turno')) belongs = true;
        }

        if (belongs) {
          groupBlocks.add(other);
          processedWorkBlockIds.add(other.id);
        }
      }

      if (groupBlocks.isEmpty) {
        groupBlocks.add(b);
        processedWorkBlockIds.add(b.id);
      }

      String groupTitle = linkedHabit?.name ?? b.title;
      final lowerTitle = groupTitle.toLowerCase();
      if (lowerTitle.contains('nocturno') || lowerTitle.contains('mañana') || lowerTitle.contains('tarde') || lowerTitle.contains('guardia')) {
        if (lowerTitle.startsWith('trabajar') || lowerTitle.contains('trabajar')) {
          groupTitle = 'Trabajar';
        } else if (lowerTitle.startsWith('trabajo') || lowerTitle.contains('trabajo')) {
          groupTitle = 'Trabajo';
        } else if (lowerTitle.startsWith('turno')) {
          groupTitle = 'Turno de Trabajo';
        }
      }

      workShiftGroups.add(WorkShiftGroup(
        title: groupTitle,
        habitId: linkedHabit?.id,
        habit: linkedHabit,
        shifts: groupBlocks,
        monthlyTargetHours: b.monthlyTargetHours,
      ));
    }

    // Suavizado nocturno en temas relajados (Dark / Sage)
    final isLateNight = now.hour >= 22 || now.hour < 6;
    final isRelaxedTheme = settings.themeMode == 'dark' || settings.themeMode == 'sage';
    final shouldDim = isLateNight && isRelaxedTheme;

    final activeHabits = shouldDim
        ? habits.map((h) {
            final dimmedColor = h.color.withOpacity(0.65);
            return h.copyWith(colorValue: dimmedColor.value);
          }).toList()
        : habits;

    // Hábitos regulares que no pertenecen a ningún grupo laboral
    final regularHabits = activeHabits.where((h) {
      final hName = h.name.trim().toLowerCase();
      return !workShiftGroups.any((g) =>
          g.habitId == h.id ||
          g.title.trim().toLowerCase() == hName ||
          (hName.contains('trabaj') && g.title.toLowerCase().contains('trabaj')) ||
          (hName.contains('turno') && g.title.toLowerCase().contains('turno')) ||
          g.shifts.any((s) => s.habitId == h.id || s.title.trim().toLowerCase() == hName));
    }).toList();

    // Hábitos para la Rueda Orbital (exactamente 1 anillo por actividad madre)
    final List<Habit> orbitHabits = [];
    final todayStr = now.toIso8601String().split('T').first;
    for (final g in workShiftGroups) {
      final Set<String> groupCompletedDates = {};
      for (final s in g.shifts) {
        groupCompletedDates.addAll(s.completedDates);
      }
      if (g.habit != null) {
        groupCompletedDates.addAll(g.habit!.completedDates);
      }
      final actualCompletedDates = groupCompletedDates.where((d) => d.compareTo(todayStr) <= 0).toSet();

      orbitHabits.add(Habit(
        id: g.habitId ?? 'work_${g.title}',
        name: g.title,
        colorValue: g.color.value,
        targetDays: 20,
        orderIndex: 0,
        completedDates: actualCompletedDates,
        hasMonthlyTarget: true,
      ));
    }
    orbitHabits.addAll(regularHabits);

    return (
      workShiftGroups: workShiftGroups,
      regularHabits: regularHabits,
      orbitHabits: orbitHabits,
    );
  }
}
